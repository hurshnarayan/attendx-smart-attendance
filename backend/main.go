package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"math/rand"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	_ "github.com/mattn/go-sqlite3"
)

var db *sql.DB
var timerPaused = false
var timerMutex sync.RWMutex
var sessionTimers = make(map[string]time.Time) // classId -> expiresAt
var sessionMutex sync.RWMutex

const SECRET = "super-secret-key-production"
const TOKEN_DURATION = 15 * time.Second

type TokenResponse struct {
	TokenString string `json:"tokenString"`
	PIN         string `json:"pin"`
	ExpiresIn   int    `json:"expiresIn"`
	WindowID    string `json:"windowId"`
	Paused      bool   `json:"paused"`
}

type AttendanceRecord struct {
	ID        int    `json:"id"`
	StudentID string `json:"studentId"`
	Name      string `json:"name,omitempty"`
	Status    string `json:"status"`
	Reason    string `json:"reason,omitempty"`
	Time      string `json:"time"`
	ClassID   string `json:"classId,omitempty"`
}

func main() {
	rand.Seed(time.Now().UnixNano())
	
	var err error
	db, err = sql.Open("sqlite3", "./attendance.db")
	if err != nil {
		panic(err)
	}

	initDB()

	r := gin.Default()
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"*"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	// Teacher endpoints
	r.GET("/api/token", getToken)
	r.POST("/api/timer/pause", pauseTimer)
	r.POST("/api/timer/resume", resumeTimer)
	r.GET("/api/timer/status", getTimerStatus)

	// Student endpoints
	r.POST("/api/attendance/mark", markAttendance)
	r.POST("/api/students", enrollStudent)

	// Dashboard endpoints
	r.GET("/api/attendance", getAttendance)
	r.GET("/api/attendanceFeed", getAttendanceFeed) // Live feed for dashboard
	r.GET("/api/debug/attendance", debugAttendance) // Debug: show all records
	r.POST("/api/approve", approveAttendance)
	r.POST("/api/reject", rejectAttendance)
	r.GET("/api/export", exportCSV)
	r.POST("/api/attendance/clear", clearAttendance)
	r.POST("/api/export-and-clear", exportAndClear)

	fmt.Println("🚀 Server running on http://localhost:4000")
	r.Run(":4000")
}

func initDB() {
	schema := `
	CREATE TABLE IF NOT EXISTS sessions (
		window_id TEXT PRIMARY KEY,
		token TEXT,
		pin TEXT,
		expires_at DATETIME,
		class_id TEXT
	);

	CREATE TABLE IF NOT EXISTS attendance (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		student_id TEXT,
		name TEXT,
		status TEXT,
		reason TEXT,
		time DATETIME DEFAULT CURRENT_TIMESTAMP,
		class_id TEXT,
		window_id TEXT,
		device_hash TEXT
	);

	CREATE TABLE IF NOT EXISTS students (
		student_id TEXT PRIMARY KEY,
		name TEXT,
		device_hash TEXT,
		enrolled_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	`
	db.Exec(schema)
}

func generateToken(windowID string) string {
	nonce := fmt.Sprintf("%d", rand.Int63())
	return windowID + ":" + nonce
}

func signToken(token string) string {
	h := hmac.New(sha256.New, []byte(SECRET))
	h.Write([]byte(token))
	return hex.EncodeToString(h.Sum(nil))
}

func getToken(c *gin.Context) {
	classID := c.Query("classId")
	if classID == "" {
		classID = "DEFAULT"
	}

	windowID := strconv.FormatInt(time.Now().Unix(), 10)
	token := generateToken(windowID)
	signature := signToken(token)
	pin := fmt.Sprintf("%04d", rand.Intn(10000))
	
	timerMutex.RLock()
	paused := timerPaused
	timerMutex.RUnlock()
	
	var expiresAt time.Time
	var expiresInSeconds int
	
	if paused {
		// When paused, set expiry far in future
		expiresAt = time.Now().Add(365 * 24 * time.Hour)
		expiresInSeconds = 999999
	} else {
		expiresAt = time.Now().Add(TOKEN_DURATION)
		expiresInSeconds = int(TOKEN_DURATION.Seconds())
	}
	
	tokenString := token + ":" + signature

	db.Exec("DELETE FROM sessions WHERE class_id=?", classID)
	db.Exec("INSERT INTO sessions (window_id, token, pin, expires_at, class_id) VALUES (?, ?, ?, ?, ?)",
		windowID, tokenString, pin, expiresAt, classID)

	sessionMutex.Lock()
	sessionTimers[classID] = expiresAt
	sessionMutex.Unlock()

	c.JSON(200, TokenResponse{
		TokenString: tokenString,
		PIN:         pin,
		ExpiresIn:   expiresInSeconds,
		WindowID:    windowID,
		Paused:      paused,
	})
}

func pauseTimer(c *gin.Context) {
	timerMutex.Lock()
	timerPaused = true
	timerMutex.Unlock()

	// Update all existing sessions to never expire
	db.Exec("UPDATE sessions SET expires_at = datetime('now', '+1 year')")

	c.JSON(200, gin.H{"paused": true})
}

func resumeTimer(c *gin.Context) {
	timerMutex.Lock()
	timerPaused = false
	timerMutex.Unlock()

	// Reset all sessions to 15 seconds from now
	newExpiry := time.Now().Add(TOKEN_DURATION)
	db.Exec("UPDATE sessions SET expires_at = ?", newExpiry)

	c.JSON(200, gin.H{"paused": false})
}

func getTimerStatus(c *gin.Context) {
	timerMutex.RLock()
	paused := timerPaused
	timerMutex.RUnlock()
	c.JSON(200, gin.H{"paused": paused})
}

func markAttendance(c *gin.Context) {
	var req struct {
		StudentID    string `json:"studentId"`
		Name         string `json:"name"`
		Token        string `json:"token"`
		PIN          string `json:"pin"`
		DeviceHash   string `json:"deviceHash"`
		BiometricSig string `json:"biometricSig"`
		AuthMethod   string `json:"authMethod"` // "biometric" or "fallback"
		ClassID      string `json:"classId"`
	}
	c.BindJSON(&req)

	if req.ClassID == "" {
		req.ClassID = "DEFAULT"
	}

	// Get student name from database if available
	if req.Name == "" {
		db.QueryRow("SELECT name FROM students WHERE student_id=?", req.StudentID).Scan(&req.Name)
		if req.Name == "" {
			req.Name = req.StudentID
		}
	}

	// Verify session
	var dbToken, dbPIN, windowID string
	var expiresAt time.Time
	err := db.QueryRow("SELECT window_id, token, pin, expires_at FROM sessions WHERE class_id=? LIMIT 1", req.ClassID).
		Scan(&windowID, &dbToken, &dbPIN, &expiresAt)

	if err != nil {
		c.JSON(400, gin.H{"error": "No active session"})
		return
	}

	timerMutex.RLock()
	paused := timerPaused
	timerMutex.RUnlock()

	if !paused && time.Now().After(expiresAt) {
		c.JSON(400, gin.H{"error": "Session expired"})
		return
	}

	if req.Token != dbToken {
		c.JSON(400, gin.H{"error": "Invalid token"})
		return
	}

	if req.PIN != dbPIN {
		c.JSON(400, gin.H{"error": "Invalid PIN"})
		return
	}

	// Check duplicate
	var count int
	db.QueryRow("SELECT COUNT(*) FROM attendance WHERE student_id=? AND window_id=?",
		req.StudentID, windowID).Scan(&count)

	if count > 0 {
		c.JSON(400, gin.H{"error": "Already marked attendance"})
		return
	}

	// Check device enrollment
	var enrolledDevice string
	db.QueryRow("SELECT device_hash FROM students WHERE student_id=?", req.StudentID).Scan(&enrolledDevice)

	status := "present"
	reason := ""

	// Determine status based on auth method and device
	if enrolledDevice == "" {
		// First time - enroll device
		db.Exec("INSERT INTO students (student_id, name, device_hash) VALUES (?, ?, ?)",
			req.StudentID, req.Name, req.DeviceHash)
		
		// If first time but used fallback, still flag
		if req.AuthMethod == "fallback" {
			status = "flagged"
			reason = "Used PIN/pattern fallback instead of biometric"
		}
	} else if enrolledDevice != req.DeviceHash {
		// Different device - always flag
		status = "flagged"
		reason = "Different device detected"
	} else if req.AuthMethod == "fallback" {
		// Same device but used fallback instead of biometric - flag for review
		status = "flagged"
		reason = "Used PIN/pattern fallback instead of biometric"
	}
	// If biometric auth on same device = present (no flag)

	// Mark attendance
	db.Exec(
		"INSERT INTO attendance (student_id, name, status, reason, class_id, window_id, device_hash) VALUES (?, ?, ?, ?, ?, ?, ?)",
		req.StudentID, req.Name, status, reason, req.ClassID, windowID, req.DeviceHash)

	c.JSON(200, gin.H{
		"success":    true,
		"status":     status,
		"studentId":  req.StudentID,
		"name":       req.Name,
		"authMethod": req.AuthMethod,
	})
}

func enrollStudent(c *gin.Context) {
	var req struct {
		StudentID  string `json:"studentId"`
		Name       string `json:"name"`
		DeviceHash string `json:"deviceHash"`
	}
	c.BindJSON(&req)

	db.Exec("INSERT OR REPLACE INTO students (student_id, name, device_hash) VALUES (?, ?, ?)",
		req.StudentID, req.Name, req.DeviceHash)

	c.JSON(200, gin.H{"success": true})
}

// Debug endpoint to see all attendance records
func debugAttendance(c *gin.Context) {
	rows, err := db.Query(`
		SELECT id, student_id, COALESCE(name, ''), status, COALESCE(reason, ''), time, COALESCE(class_id, ''), COALESCE(window_id, '')
		FROM attendance
		ORDER BY id DESC
	`)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var records []map[string]interface{}
	for rows.Next() {
		var id int
		var studentID, name, status, reason, timeStr, classID, windowID string
		rows.Scan(&id, &studentID, &name, &status, &reason, &timeStr, &classID, &windowID)
		records = append(records, map[string]interface{}{
			"id":        id,
			"studentId": studentID,
			"name":      name,
			"status":    status,
			"reason":    reason,
			"time":      timeStr,
			"classId":   classID,
			"windowId":  windowID,
		})
	}

	c.JSON(200, gin.H{
		"total":   len(records),
		"records": records,
	})
}

func getAttendance(c *gin.Context) {
	classID := c.Query("classId")
	if classID == "" {
		classID = "DEFAULT"
	}

	rows, _ := db.Query(`
		SELECT id, student_id, COALESCE(name, student_id), status, COALESCE(reason, ''), time
		FROM attendance
		WHERE class_id=?
		ORDER BY time DESC
	`, classID)
	defer rows.Close()

	var records []AttendanceRecord
	for rows.Next() {
		var r AttendanceRecord
		rows.Scan(&r.ID, &r.StudentID, &r.Name, &r.Status, &r.Reason, &r.Time)
		records = append(records, r)
	}

	c.JSON(200, records)
}

// getAttendanceFeed returns categorized attendance for live dashboard updates
func getAttendanceFeed(c *gin.Context) {
	classID := c.Query("classId")
	showAll := c.Query("all") == "true" || classID == ""
	
	fmt.Printf("[Feed] Fetching attendance: classId=%s, showAll=%v\n", classID, showAll)

	var rows *sql.Rows
	var err error

	if showAll {
		// Show ALL records
		rows, err = db.Query(`
			SELECT id, student_id, COALESCE(name, student_id), status, COALESCE(reason, ''), time, COALESCE(class_id, '')
			FROM attendance
			ORDER BY time DESC
		`)
	} else {
		// Filter by classId
		rows, err = db.Query(`
			SELECT id, student_id, COALESCE(name, student_id), status, COALESCE(reason, ''), time, COALESCE(class_id, '')
			FROM attendance
			WHERE class_id=?
			ORDER BY time DESC
		`, classID)
	}
	
	if err != nil {
		fmt.Printf("[Feed] Query error: %v\n", err)
		c.JSON(200, gin.H{
			"present": []AttendanceRecord{},
			"pending": []AttendanceRecord{},
			"flagged": []AttendanceRecord{},
			"total":   0,
		})
		return
	}
	defer rows.Close()

	var present []AttendanceRecord
	var pending []AttendanceRecord
	var flagged []AttendanceRecord

	for rows.Next() {
		var r AttendanceRecord
		var classIDVal string
		rows.Scan(&r.ID, &r.StudentID, &r.Name, &r.Status, &r.Reason, &r.Time, &classIDVal)
		r.ClassID = classIDVal

		fmt.Printf("[Feed] Record: id=%d, student=%s, name=%s, status=%s\n", r.ID, r.StudentID, r.Name, r.Status)

		switch r.Status {
		case "present":
			present = append(present, r)
		case "pending":
			pending = append(pending, r)
		case "flagged":
			flagged = append(flagged, r)
		default:
			// Unknown status goes to pending
			pending = append(pending, r)
		}
	}

	// Return empty arrays instead of null
	if present == nil {
		present = []AttendanceRecord{}
	}
	if pending == nil {
		pending = []AttendanceRecord{}
	}
	if flagged == nil {
		flagged = []AttendanceRecord{}
	}

	fmt.Printf("[Feed] Returning: present=%d, pending=%d, flagged=%d\n", len(present), len(pending), len(flagged))

	c.JSON(200, gin.H{
		"present": present,
		"pending": pending,
		"flagged": flagged,
		"total":   len(present) + len(pending) + len(flagged),
	})
}

func approveAttendance(c *gin.Context) {
	var req struct {
		ID int `json:"id"`
	}
	c.BindJSON(&req)

	db.Exec("UPDATE attendance SET status='present', reason='' WHERE id=?", req.ID)
	c.JSON(200, gin.H{"success": true})
}

func rejectAttendance(c *gin.Context) {
	var req struct {
		ID int `json:"id"`
	}
	c.BindJSON(&req)

	db.Exec("DELETE FROM attendance WHERE id=?", req.ID)
	c.JSON(200, gin.H{"success": true})
}

func exportCSV(c *gin.Context) {
	classID := c.Query("classId")
	exportAll := c.Query("all") == "true"
	
	fmt.Printf("[Export] Exporting CSV: classId=%s, exportAll=%v\n", classID, exportAll)

	var rows *sql.Rows
	var err error

	if exportAll || classID == "" {
		// Export ALL records
		rows, err = db.Query(`
			SELECT student_id, COALESCE(name, student_id), status, COALESCE(reason, ''), time, COALESCE(class_id, 'N/A')
			FROM attendance
			ORDER BY time DESC
		`)
	} else {
		// Export specific class
		rows, err = db.Query(`
			SELECT student_id, COALESCE(name, student_id), status, COALESCE(reason, ''), time, COALESCE(class_id, 'N/A')
			FROM attendance
			WHERE class_id=?
			ORDER BY time DESC
		`, classID)
	}
	
	if err != nil {
		fmt.Printf("[Export] Query error: %v\n", err)
		c.String(500, "Error fetching data: "+err.Error())
		return
	}
	defer rows.Close()

	csv := "Student Name,Student ID,Status,Class,Date,Time,Reason\n"
	recordCount := 0
	for rows.Next() {
		var studentID, name, status, reason, timeStr, classIDVal string
		err := rows.Scan(&studentID, &name, &status, &reason, &timeStr, &classIDVal)
		if err != nil {
			fmt.Printf("[Export] Scan error: %v\n", err)
			continue
		}
		
		// Parse and format time nicely
		date := timeStr
		timeOnly := ""
		if len(timeStr) >= 10 {
			date = timeStr[:10]
			if len(timeStr) >= 19 {
				timeOnly = timeStr[11:19]
			} else if len(timeStr) > 10 {
				timeOnly = timeStr[11:]
			}
		}
		
		// Escape commas and quotes in fields for proper CSV
		name = strings.ReplaceAll(name, "\"", "\"\"")
		reason = strings.ReplaceAll(reason, "\"", "\"\"")
		
		// Quote fields that might contain commas
		csv += fmt.Sprintf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n", 
			name, studentID, status, classIDVal, date, timeOnly, reason)
		recordCount++
	}

	fmt.Printf("[Export] Exported %d records\n", recordCount)

	if recordCount == 0 {
		csv += "\"No records found\",\"\",\"\",\"\",\"\",\"\",\"\"\n"
	}

	filename := "attendance_export"
	if classID != "" {
		filename = fmt.Sprintf("attendance_%s", classID)
	}
	filename += "_" + time.Now().Format("2006-01-02_15-04-05") + ".csv"

	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	c.String(200, csv)
}

func clearAttendance(c *gin.Context) {
	var req struct {
		ClassID   string `json:"classId"`
		SessionID string `json:"sessionId"`
		ClearAll  bool   `json:"clearAll"`
	}
	c.BindJSON(&req)

	fmt.Printf("[Clear] Request: classId=%s, clearAll=%v\n", req.ClassID, req.ClearAll)

	var result sql.Result
	var err error

	if req.ClearAll || req.ClassID == "" {
		// Clear ALL attendance records
		fmt.Printf("[Clear] Clearing ALL attendance records\n")
		result, err = db.Exec("DELETE FROM attendance")
	} else {
		// Clear specific class
		fmt.Printf("[Clear] Clearing attendance for classId=%s\n", req.ClassID)
		result, err = db.Exec("DELETE FROM attendance WHERE class_id=?", req.ClassID)
	}

	if err != nil {
		fmt.Printf("[Clear] Error: %v\n", err)
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	fmt.Printf("[Clear] Deleted %d records\n", rowsAffected)

	c.JSON(200, gin.H{"success": true, "deleted": rowsAffected})
}

func exportAndClear(c *gin.Context) {
	var req struct {
		ClassID   string `json:"classId"`
		SessionID string `json:"sessionId"`
		ClearAll  bool   `json:"clearAll"`
	}
	c.BindJSON(&req)

	fmt.Printf("[ExportAndClear] Request: classId=%s, clearAll=%v\n", req.ClassID, req.ClearAll)

	var rows *sql.Rows
	var err error

	// Export ALL records
	rows, err = db.Query(`
		SELECT student_id, COALESCE(name, student_id), status, COALESCE(reason, ''), time, COALESCE(class_id, 'N/A')
		FROM attendance
		ORDER BY time DESC
	`)
	
	if err != nil {
		fmt.Printf("[ExportAndClear] Query error: %v\n", err)
		c.String(500, "Error fetching data: "+err.Error())
		return
	}
	defer rows.Close()

	csv := "Student Name,Student ID,Status,Class,Date,Time,Reason\n"
	recordCount := 0
	for rows.Next() {
		var studentID, name, status, reason, timeStr, classIDVal string
		err := rows.Scan(&studentID, &name, &status, &reason, &timeStr, &classIDVal)
		if err != nil {
			fmt.Printf("[ExportAndClear] Scan error: %v\n", err)
			continue
		}
		
		// Parse and format time nicely
		date := timeStr
		timeOnly := ""
		if len(timeStr) >= 10 {
			date = timeStr[:10]
			if len(timeStr) >= 19 {
				timeOnly = timeStr[11:19]
			} else if len(timeStr) > 10 {
				timeOnly = timeStr[11:]
			}
		}
		
		// Escape quotes for proper CSV
		name = strings.ReplaceAll(name, "\"", "\"\"")
		reason = strings.ReplaceAll(reason, "\"", "\"\"")
		
		csv += fmt.Sprintf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n", 
			name, studentID, status, classIDVal, date, timeOnly, reason)
		recordCount++
	}

	if recordCount == 0 {
		csv += "\"No records found\",\"\",\"\",\"\",\"\",\"\",\"\"\n"
	}

	// Now clear ALL data
	result, _ := db.Exec("DELETE FROM attendance")
	rowsDeleted, _ := result.RowsAffected()
	
	fmt.Printf("[ExportAndClear] Exported %d records, deleted %d\n", recordCount, rowsDeleted)

	filename := "attendance_export_" + time.Now().Format("2006-01-02_15-04-05") + ".csv"

	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	c.String(200, csv)
}
