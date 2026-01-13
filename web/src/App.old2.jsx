// App.jsx
// Screenshot reference (if you need it): /mnt/data/Screenshot 2025-11-24 at 11.05.43 AM.png

import React, { useEffect, useState, useRef } from "react";
import "./styles.css";
import QRCode from "qrcode";
// Optional: npm i qr-scanner
// import QrScanner from "qr-scanner";

const API = "http://localhost:4000";

export default function App() {
  const [role, setRole] = useState("teacher"); // 'teacher' or 'student'
  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <header className="max-w-6xl mx-auto mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold">ClassCheck — Attendance</h1>
        <div className="flex gap-2">
          <button
            className={`px-3 py-1 rounded ${
              role === "teacher" ? "btn-selected" : "btn-unselected"
            }`}
            onClick={() => setRole("teacher")}
          >
            Teacher
          </button>
          <button
            className={`px-3 py-1 rounded ${
              role === "student" ? "btn-selected" : "btn-unselected"
            }`}
            onClick={() => setRole("student")}
          >
            Student
          </button>
        </div>
      </header>

      <main className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-6">
        <section className="md:col-span-2 bg-white p-6 rounded shadow">
          {role === "teacher" ? <TeacherView /> : <StudentView />}
        </section>

        <aside className="bg-white p-6 rounded shadow">
          <DashboardPanel />
        </aside>
      </main>
    </div>
  );
}

// ----------------------- TeacherView -----------------------
function TeacherView() {
  const [classId, setClassId] = useState("CS101");
  const [teacherId, setTeacherId] = useState("T001");
  // sessionId is a local pseudo session id used by frontend; server may be token-based
  const [sessionId, setSessionId] = useState(
    () => localStorage.getItem("activeSessionId") || null
  );
  const [windowPayload, setWindowPayload] = useState(null);
  const [pin, setPin] = useState(null);
  const [countdown, setCountdown] = useState(0);
  const canvasRef = useRef(null);
  const rotationRef = useRef(null);
  const countdownRef = useRef(null);

  useEffect(() => {
    // If session already active (from localStorage), start rotation automatically
    if (sessionId) startRotation(sessionId);
    // cleanup on unmount
    return () => {
      stopRotation();
      clearInterval(countdownRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function startSession() {
    // For compatibility with your existing backend we create a local session marker
    // and keep using /api/token to fetch rotating QR payloads.
    try {
      const pseudoSessionId = `local-${Date.now()}`;
      setSessionId(pseudoSessionId);
      localStorage.setItem("activeSessionId", pseudoSessionId);
      // also store classId so dashboard actions can work without explicit session
      localStorage.setItem("activeClassId", classId || "");
      startRotation(pseudoSessionId);
    } catch (err) {
      console.error("startSession error", err);
      alert("Failed to start session (local). Check console.");
    }
  }

  async function endSession() {
    // stop rotation and clear client-side session data
    stopRotation();
    setSessionId(null);
    localStorage.removeItem("activeSessionId");
    localStorage.removeItem("activeClassId");
    setWindowPayload(null);
    setPin(null);
    setCountdown(0);
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext("2d");
      ctx.clearRect(0, 0, canvas.width || 300, canvas.height || 300);
    }
    // If you have a server-side endpoint to end session, call it here.
    console.log("Session ended (client-side).");
  }

  function stopRotation() {
    if (rotationRef.current) {
      clearInterval(rotationRef.current);
      rotationRef.current = null;
    }
    if (countdownRef.current) {
      clearInterval(countdownRef.current);
      countdownRef.current = null;
    }
  }

  function startRotation(sid) {
    // Use the existing /api/token endpoint (the backend that worked earlier)
    fetchWindow(sid);
    if (rotationRef.current) clearInterval(rotationRef.current);
    rotationRef.current = setInterval(() => fetchWindow(sid), 15000);

    if (countdownRef.current) clearInterval(countdownRef.current);
    countdownRef.current = setInterval(() => {
      setCountdown((c) => (c > 0 ? c - 1 : 0));
    }, 1000);
  }

  // fetchWindow uses /api/token?classId=... (same as your previously working UI)
  async function fetchWindow(sid = sessionId) {
    try {
      const res = await fetch(
        `${API}/api/token?classId=${encodeURIComponent(classId)}`
      );
      if (!res.ok) throw new Error("token fetch failed");
      const data = await res.json();
      // keep compatibility: tokenString OR JSON.stringify(data)
      const tokenString = data.tokenString || JSON.stringify(data);
      setWindowPayload(data);
      setPin(data.pin || null);
      setCountdown(data.expiresIn || 15);

      const canvas = canvasRef.current;
      if (canvas) {
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width || 300, canvas.height || 300);
        await QRCode.toCanvas(canvas, tokenString, { width: 300 });
      }
    } catch (err) {
      console.error("fetchWindow error", err);
      if (
        err?.message?.includes("failed") ||
        err?.message === "Failed to fetch"
      ) {
        alert(
          `Failed to fetch token from server at ${API}. Is the backend running?`
        );
        stopRotation();
      }
    }
  }

  return (
    <div>
      <div className="flex items-start gap-6">
        <div>
          <div className="bg-slate-100 p-4 rounded-md">
            <canvas ref={canvasRef} className="block" />
          </div>
          <div className="mt-2 text-sm text-gray-600">
            PIN: <span className="font-medium">{pin ?? "—"}</span>
          </div>
          <div className="mt-1 text-xs text-gray-500">
            Expires in: <span className="font-semibold">{countdown}s</span>
          </div>
        </div>

        <div className="flex-1">
          <label className="block text-sm font-medium text-gray-700">
            Class ID
          </label>
          <input
            value={classId}
            onChange={(e) => setClassId(e.target.value)}
            className="mt-1 p-2 border rounded w-48"
          />

          <label className="block text-sm font-medium text-gray-700 mt-3">
            Teacher ID
          </label>
          <input
            value={teacherId}
            onChange={(e) => setTeacherId(e.target.value)}
            className="mt-1 p-2 border rounded w-48"
          />

          <div className="mt-4">
            {!sessionId ? (
              <button
                className="px-4 py-2 bg-indigo-600 text-white rounded"
                onClick={startSession}
              >
                Start Session
              </button>
            ) : (
              <>
                <button
                  className="px-4 py-2 bg-indigo-600 text-white rounded"
                  onClick={() => fetchWindow(sessionId)}
                >
                  Refresh Now
                </button>
                <button
                  className="ml-2 px-4 py-2 border rounded"
                  onClick={endSession}
                >
                  End Session
                </button>
                <div className="mt-2 text-xs text-gray-500">
                  Active session:{" "}
                  <span className="font-medium">{sessionId}</span>
                </div>
              </>
            )}
          </div>

          <div className="mt-6">
            <h3 className="text-sm font-semibold">Live attendance feed</h3>
            <p className="text-xs text-gray-500">
              (Open the dashboard to view Present / Pending / Flagged)
            </p>
          </div>
        </div>
      </div>

      <div className="mt-6">
        <h3 className="text-sm font-semibold">Teacher actions</h3>
        <div className="mt-2 flex gap-2">
          <ApproveAllButton sessionId={sessionId} />
          <RejectFlaggedAllButton sessionId={sessionId} />
        </div>
      </div>
    </div>
  );
}

// Approve all pending helper component
function ApproveAllButton({ sessionId }) {
  async function click() {
    // use either session or class scope depending on what's available
    const classId = localStorage.getItem("activeClassId") || null;
    if (!sessionId && !classId)
      return alert("Start a session (or set class) first");

    try {
      const url = sessionId
        ? `${API}/api/attendanceFeed?sessionId=${encodeURIComponent(sessionId)}`
        : `${API}/api/attendanceFeed?classId=${encodeURIComponent(classId)}`;
      const res = await fetch(url);
      const data = await res.json();
      const ids = (data.pending || []).map((p) => p.id);
      await Promise.all(
        ids.map((id) =>
          fetch(`${API}/api/approve`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            // server might accept sessionId OR classId; include whichever we have
            body: JSON.stringify({ id, sessionId, classId }),
          })
        )
      );
      console.log("Approved", ids.length, "pending entries");
    } catch (err) {
      console.error("approve all error", err);
      alert("Approve all failed (check console).");
    }
  }
  return (
    <button
      onClick={click}
      className="px-3 py-1 bg-green-500 text-white rounded"
    >
      Approve All Pending
    </button>
  );
}

function RejectFlaggedAllButton({ sessionId }) {
  async function click() {
    const classId = localStorage.getItem("activeClassId") || null;
    if (!sessionId && !classId)
      return alert("Start a session (or set class) first");

    try {
      const url = sessionId
        ? `${API}/api/attendanceFeed?sessionId=${encodeURIComponent(sessionId)}`
        : `${API}/api/attendanceFeed?classId=${encodeURIComponent(classId)}`;
      const res = await fetch(url);
      const data = await res.json();
      const ids = (data.flagged || []).map((p) => p.id);
      await Promise.all(
        ids.map((id) =>
          fetch(`${API}/api/reject`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ id, sessionId, classId }),
          })
        )
      );
      console.log("Rejected", ids.length, "flagged entries");
    } catch (err) {
      console.error("reject flagged all error", err);
      alert("Reject all failed (check console).");
    }
  }
  return (
    <button onClick={click} className="px-3 py-1 bg-red-500 text-white rounded">
      Reject All Flagged
    </button>
  );
}

// ----------------------- StudentView -----------------------
function StudentView() {
  const [scanResult, setScanResult] = useState(null);
  const [status, setStatus] = useState("idle");
  const [studentId, setStudentId] = useState("S123");
  const [enrollName, setEnrollName] = useState("");
  const [enrollId, setEnrollId] = useState("");
  // camera refs if you add scanning
  const videoRef = useRef(null);
  const scannerRef = useRef(null);

  async function enrollStudent() {
    if (!enrollId || !enrollName) return alert("Enter roll no and name");
    try {
      const res = await fetch(`${API}/api/students`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: enrollId, name: enrollName }),
      });
      if (!res.ok) throw new Error("enroll failed");
      alert("Student enrolled. Now use that ID to scan and check-in.");
      setEnrollName("");
      setEnrollId("");
    } catch (err) {
      console.error("enroll error", err);
      alert("Enroll failed (check server).");
    }
  }

  async function onScanMock() {
    const pasted = prompt("Paste token string (from teacher QR):");
    if (!pasted) return;
    try {
      // token may be just a string or JSON
      let windowPayload;
      try {
        windowPayload = JSON.parse(pasted);
      } catch {
        // if token is a single string, send it as { tokenString: pasted }
        windowPayload = { tokenString: pasted };
      }
      setScanResult(JSON.stringify(windowPayload).slice(0, 200));
      await sendVerify(windowPayload);
    } catch (err) {
      alert(
        "Invalid token pasted — must be JSON or token string from teacher QR."
      );
    }
  }

  async function sendVerify(windowPayload) {
    setStatus("authenticating");
    try {
      // For real app: do WebAuthn here. For demo we use a mock signature.
      const signature = await biometricSignMock(
        studentId,
        JSON.stringify(windowPayload)
      );
      setStatus("uploading");

      // Some backends use /api/verify, others /api/verify-checkin; try verify first, fallback to verify-checkin
      let res = await fetch(`${API}/api/verify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          studentId,
          windowPayload,
          signature,
          clientTs: Math.floor(Date.now() / 1000),
        }),
      });
      if (res.status === 404) {
        res = await fetch(`${API}/api/verify-checkin`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            studentId,
            windowPayload,
            signature,
            clientTs: Math.floor(Date.now() / 1000),
          }),
        });
      }
      const data = await res.json();
      if (data.status === "present") setStatus("present");
      else if (data.status === "pending") setStatus("pending");
      else setStatus("flagged");
    } catch (err) {
      console.error(err);
      setStatus("error");
      alert("Verify failed (check console).");
    }
  }

  return (
    <div>
      <div className="flex items-center gap-4">
        <label className="block text-sm font-medium text-gray-700">
          Student ID
        </label>
        <input
          value={studentId}
          onChange={(e) => setStudentId(e.target.value)}
          className="p-2 border rounded w-36"
        />
      </div>

      <div className="mt-4 flex gap-2">
        <button
          onClick={onScanMock}
          className="px-4 py-2 bg-indigo-600 text-white rounded"
        >
          Paste token & Mark Present
        </button>
      </div>

      <div className="mt-4">
        <div className="text-sm">
          Status: <strong>{status}</strong>
        </div>
        <div className="mt-2 text-xs text-gray-500">
          Scan result: {scanResult ?? "—"}
        </div>
      </div>

      <div className="mt-6 border-t pt-4">
        <h4 className="text-sm font-semibold">Enroll student (quick)</h4>
        <div className="mt-2 flex gap-2">
          <input
            placeholder="Roll no / ID"
            value={enrollId}
            onChange={(e) => setEnrollId(e.target.value)}
            className="p-2 border rounded w-36"
          />
          <input
            placeholder="Name"
            value={enrollName}
            onChange={(e) => setEnrollName(e.target.value)}
            className="p-2 border rounded"
          />
          <button
            onClick={enrollStudent}
            className="px-3 py-1 bg-green-500 text-white rounded"
          >
            Enroll
          </button>
        </div>
        <div className="mt-2 text-xs text-gray-500">
          Enrolled students are shown on server-side list (UI only displays
          id/name.)
        </div>
      </div>

      <div className="mt-6">
        <h4 className="text-sm font-semibold">Notes</h4>
        <ul className="list-disc pl-5 text-xs text-gray-600 mt-2">
          <li>
            Use camera QR scan in production (this demo uses paste / prompt).
          </li>
          <li>
            Biometric signing is done locally with WebAuthn / platform
            authenticator (demo uses mock).
          </li>
          <li>
            App POSTs a single verify request to the backend; response updates
            status.
          </li>
        </ul>
      </div>
    </div>
  );
}

// ----------------------- DashboardPanel -----------------------
function DashboardPanel() {
  const [present, setPresent] = useState([]);
  const [pending, setPending] = useState([]);
  const [flagged, setFlagged] = useState([]);
  // sessionId is optional. If not present we use classId (activeClassId) for server calls
  const [sessionId, setSessionId] = useState(
    () => localStorage.getItem("activeSessionId") || null
  );
  const [classId, setClassId] = useState(
    () => localStorage.getItem("activeClassId") || ""
  );

  useEffect(() => {
    const t = setInterval(fetchFeed, 2000);
    fetchFeed();
    window.addEventListener("storage", onStorageChange);
    return () => {
      clearInterval(t);
      window.removeEventListener("storage", onStorageChange);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessionId, classId]);

  function onStorageChange(e) {
    if (e.key === "activeSessionId") {
      setSessionId(e.newValue);
    }
    if (e.key === "activeClassId") {
      setClassId(e.newValue);
    }
  }

  async function fetchFeed() {
    try {
      // prefer sessionId if available, otherwise classId
      const url = sessionId
        ? `${API}/api/attendanceFeed?sessionId=${encodeURIComponent(sessionId)}`
        : classId
        ? `${API}/api/attendanceFeed?classId=${encodeURIComponent(classId)}`
        : `${API}/api/attendanceFeed`;
      const res = await fetch(url);
      if (!res.ok) throw new Error("feed fetch failed");
      const data = await res.json();
      setPresent(data.present || []);
      setPending(data.pending || []);
      setFlagged(data.flagged || []);
    } catch (err) {
      console.warn("fetchFeed error", err);
    }
  }

  async function approve(id) {
    try {
      const body = { id };
      if (sessionId) body.sessionId = sessionId;
      else if (classId) body.classId = classId;
      await fetch(`${API}/api/approve`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      fetchFeed();
    } catch (err) {
      console.warn("approve error", err);
      alert("Approve failed (check console).");
    }
  }
  async function reject(id) {
    try {
      const body = { id };
      if (sessionId) body.sessionId = sessionId;
      else if (classId) body.classId = classId;
      await fetch(`${API}/api/reject`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      fetchFeed();
    } catch (err) {
      console.warn("reject error", err);
      alert("Reject failed (check console).");
    }
  }

  async function clearData(
    confirmText = "Are you sure you want to clear attendance for this session/class? This cannot be undone."
  ) {
    // allow clearing by session or by class (if session not active)
    const scope = sessionId ? { sessionId } : classId ? { classId } : null;
    if (!scope)
      return alert(
        "No active session or class set. Start a session or set a class first."
      );
    const ok = window.confirm(confirmText);
    if (!ok) return;
    try {
      const res = await fetch(`${API}/api/attendance/clear`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(scope),
      });
      if (!res.ok) {
        const text = await res.text();
        console.error("clear failed", res.status, text);
        alert("Clear failed: " + (text || res.status));
        return;
      }
      // refresh UI
      await fetchFeed();
      alert("Attendance cleared.");
    } catch (err) {
      console.error("clear error", err);
      alert("Failed to clear attendance (network).");
    }
  }

  async function exportCsv() {
    const url = sessionId
      ? `${API}/api/export?sessionId=${encodeURIComponent(sessionId)}`
      : classId
      ? `${API}/api/export?classId=${encodeURIComponent(classId)}`
      : `${API}/api/export`;
    window.open(url, "_blank");
  }

  async function exportAndClear() {
    const scope = sessionId ? { sessionId } : classId ? { classId } : null;
    if (!scope)
      return alert(
        "No active session or class set. Start a session or set a class first."
      );
    const ok = window.confirm(
      "Export CSV and then clear attendance for this session/class? This will delete records on the server."
    );
    if (!ok) return;
    // 1) Export (open in new tab)
    const url = sessionId
      ? `${API}/api/export?sessionId=${encodeURIComponent(sessionId)}`
      : `${API}/api/export?classId=${encodeURIComponent(classId)}`;
    window.open(url, "_blank");
    // 2) small delay then clear (simple approach)
    setTimeout(async () => {
      await clearData("Confirm: delete attendance AFTER export?");
    }, 800);
  }

  return (
    <div>
      <h3 className="text-lg font-semibold mb-3">Dashboard</h3>

      <Section title={`Present (${present.length})`}>
        {present.slice(0, 6).map((s) => (
          <div key={s.id} className="py-1">
            {s.studentId}{" "}
            <span className="text-xs text-gray-400">{s.time}</span>
          </div>
        ))}
      </Section>

      <Section title={`Pending (${pending.length})`}>
        {pending.slice(0, 6).map((s) => (
          <div key={s.id} className="py-1 flex items-center justify-between">
            <div>{s.studentId}</div>
            <div className="flex gap-2">
              <button
                onClick={() => approve(s.id)}
                className="px-2 py-1 bg-green-500 text-white rounded text-xs"
              >
                Approve
              </button>
              <button
                onClick={() => reject(s.id)}
                className="px-2 py-1 bg-red-500 text-white rounded text-xs"
              >
                Reject
              </button>
            </div>
          </div>
        ))}
      </Section>

      <Section title={`Flagged (${flagged.length})`}>
        {flagged.slice(0, 6).map((s) => (
          <div key={s.id} className="py-1 flex items-center justify-between">
            <div>
              {s.studentId}{" "}
              <div className="text-xs text-gray-400">{s.reason}</div>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => approve(s.id)}
                className="px-2 py-1 bg-green-500 text-white rounded text-xs"
              >
                Approve
              </button>
              <button
                onClick={() => reject(s.id)}
                className="px-2 py-1 bg-red-500 text-white rounded text-xs"
              >
                Reject
              </button>
            </div>
          </div>
        ))}
      </Section>

      <div className="mt-4 grid grid-cols-1 gap-2">
        <button onClick={exportCsv} className="w-full px-3 py-2 border rounded">
          Export CSV
        </button>
        <button
          onClick={exportAndClear}
          className="w-full px-3 py-2 bg-indigo-600 text-white rounded"
        >
          Export & Clear
        </button>
        <button
          onClick={() => clearData()}
          className="w-full px-3 py-2 bg-red-500 text-white rounded"
        >
          Clear Data
        </button>
      </div>
    </div>
  );
}

function Section({ title, children }) {
  return (
    <div className="mb-4">
      <h4 className="text-sm font-medium mb-2">{title}</h4>
      <div className="text-sm text-gray-700">{children}</div>
    </div>
  );
}

// ----------------------- Mock helpers -----------------------
async function biometricSignMock(studentId, token) {
  // In real app use WebAuthn navigator.credentials.get(...) to get assertion
  // For demo we return a base64 mock signature
  await sleep(400); // simulate biometric prompt
  return btoa(`sig:${studentId}:${token}:${Date.now()}`);
}
function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
