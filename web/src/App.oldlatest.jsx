// App.jsx (patched by assistant)
// Replace your current App.jsx with this file.
// - Keeps UI/styles intact
// - Adds a small "Copy token" button (dev only) which copies tokenString to clipboard
// - Adds a commented MANUAL_TOKEN_TTL variable you can uncomment to force TTL during dev
// - Fixes enroll flow (uses /api/students which server now implements)

import React, { useEffect, useState, useRef } from "react";
import "./styles.css";
import QRCode from "qrcode";

const API = "http://localhost:4000";

// DEV: if you want to force token expiry time during development, uncomment and set seconds.
// const MANUAL_TOKEN_TTL = 60; // <-- uncomment to force token TTL for testing

export default function App() {
  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <header className="max-w-6xl mx-auto mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold">AttendX - Teacher Dashboard</h1>
      </header>

      <main className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-6">
        <section className="md:col-span-2 bg-white p-6 rounded shadow">
          <TeacherView />
        </section>

        <aside className="bg-white p-6 rounded shadow">
          <DashboardPanel />
        </aside>
      </main>
    </div>
  );
}

/* ---------------- TeacherView ---------------- */
function TeacherView() {
  const [classId, setClassId] = useState("CS101");
  const [teacherId, setTeacherId] = useState("T001");
  const [sessionId, setSessionId] = useState(
    () => localStorage.getItem("activeSessionId") || null
  );
  const [windowPayload, setWindowPayload] = useState(null);
  const [tokenString, setTokenString] = useState(null);
  const [pin, setPin] = useState(null);
  const [countdown, setCountdown] = useState(0);
  const [timerPaused, setTimerPaused] = useState(false);
  const canvasRef = useRef(null);
  const rotationRef = useRef(null);
  const countdownRef = useRef(null);

  useEffect(() => {
    if (sessionId) startRotation(sessionId);
    return () => {
      stopRotation();
      clearInterval(countdownRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function startSession() {
    try {
      const pseudoSessionId = `local-${Date.now()}`;
      setSessionId(pseudoSessionId);
      localStorage.setItem("activeSessionId", pseudoSessionId);
      localStorage.setItem("activeClassId", classId || "");
      window.dispatchEvent(new Event("local-storage"));
      window.dispatchEvent(new Event("storage"));
      startRotation(pseudoSessionId);
    } catch (err) {
      console.error("startSession error", err);
      alert("Failed to start session (local). Check console.");
    }
  }

  async function endSession() {
    stopRotation();
    setSessionId(null);
    localStorage.removeItem("activeSessionId");
    localStorage.removeItem("activeClassId");
    window.dispatchEvent(new Event("local-storage"));
    window.dispatchEvent(new Event("storage"));
    setWindowPayload(null);
    setTokenString(null);
    setPin(null);
    setCountdown(0);
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext("2d");
      ctx.clearRect(0, 0, canvas.width || 300, canvas.height || 300);
    }
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
    fetchWindow(sid);
    if (rotationRef.current) clearInterval(rotationRef.current);
    rotationRef.current = setInterval(() => fetchWindow(sid), 15000);
    if (countdownRef.current) clearInterval(countdownRef.current);
    countdownRef.current = setInterval(() => {
      setCountdown((c) => (c > 0 ? c - 1 : 0));
    }, 1000);
  }

  async function fetchWindow(sid = sessionId) {
    try {
      const res = await fetch(
        `${API}/api/token?classId=${encodeURIComponent(
          classId
        )}&t=${Date.now()}`
      );
      if (!res.ok) throw new Error("token fetch failed");
      const data = await res.json();
      // tokenString is returned by server; keep it so user can copy
      const tokenStr = data.tokenString || JSON.stringify(data);
      setWindowPayload(data);
      setTokenString(tokenStr);
      setPin(data.pin || null);
      // respect MANUAL_TOKEN_TTL if set in code (dev)
      // eslint-disable-next-line no-undef
      const ttl =
        typeof MANUAL_TOKEN_TTL !== "undefined"
          ? MANUAL_TOKEN_TTL
          : data.expiresIn || 15;
      setCountdown(ttl);

      const canvas = canvasRef.current;
      if (canvas) {
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width || 300, canvas.height || 300);
        await QRCode.toCanvas(canvas, tokenStr, { width: 300 });
      }
    } catch (err) {
      console.error("fetchWindow error", err);
      if (
        err?.message?.includes("failed") ||
        err?.message === "Failed to fetch"
      ) {
        alert(
          `Failed to fetch token from server at ${API}. Is backend running?`
        );
        stopRotation();
      }
    }
  }

  function copyTokenToClipboard() {
    if (!tokenString) return;
    navigator.clipboard
      .writeText(tokenString)
      .then(() => alert("Token copied to clipboard (dev)."))
      .catch(() => alert("Copy failed."));
  }

  async function toggleTimer() {
    try {
      const endpoint = timerPaused ? '/api/timer/resume' : '/api/timer/pause';
      const res = await fetch(`${API}${endpoint}`, { method: 'POST' });
      if (res.ok) {
        setTimerPaused(!timerPaused);
      }
    } catch (err) {
      console.error('toggle timer error', err);
    }
  }

  return (
    <div>
      <div className="flex items-start gap-6">
        <div>
          <div className="bg-slate-100 p-4 rounded-md">
            <canvas
              ref={canvasRef}
              className="block"
              style={{ width: 300, height: 300 }}
            />
          </div>
          <div className="mt-2 text-sm text-gray-600">
            PIN: <span className="font-medium">{pin ?? "—"}</span>
          </div>
          <div className="mt-1 text-xs text-gray-500">
            Expires in: <span className="font-semibold">{countdown}s</span>
          </div>
          {/* Dev-only: show token string and copy button for testing. Comment out before shipping. */}
          <div className="mt-2 text-xs">
            {/* <div className="truncate" style={{ maxWidth: 300 }}>{tokenString || "—"}</div> */}
            <button
              onClick={copyTokenToClipboard}
              className="mt-1 px-2 py-1 border rounded text-xs"
            >
              Copy token (dev)
            </button>
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
                  className="px-4 py-2 bg-indigo-600 text-white rounded mr-2"
                  onClick={() => fetchWindow(sessionId)}
                >
                  Refresh QR
                </button>
                <button
                  className="px-4 py-2 bg-amber-600 text-white rounded mr-2"
                  onClick={toggleTimer}
                >
                  {timerPaused ? '▶️ Resume' : '⏸️ Pause'} Timer
                </button>
                <button
                  className="px-4 py-2 bg-red-600 text-white rounded"
                  onClick={endSession}
                >
                  End Session
                </button>
                <div className="mt-2 text-xs text-gray-500">
                  Active session: <span className="font-medium">{sessionId}</span>
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
          <ApproveAllButton />
          <RejectFlaggedAllButton />
        </div>
      </div>
    </div>
  );
}

/* Approve/Reject helpers */
function ApproveAllButton() {
  async function click() {
    const classId = localStorage.getItem("activeClassId") || null;
    const sessionId = localStorage.getItem("activeSessionId") || null;
    if (!sessionId && !classId)
      return alert("Start a session (or set class) first");
    try {
      const url = sessionId
        ? `${API}/api/attendanceFeed?sessionId=${encodeURIComponent(
            sessionId
          )}&t=${Date.now()}`
        : `${API}/api/attendanceFeed?classId=${encodeURIComponent(
            classId
          )}&t=${Date.now()}`;
      const res = await fetch(url, { cache: "no-store" });
      const data = await res.json();
      const ids = (data.pending || []).map((p) => p.id);
      await Promise.all(
        ids.map((id) =>
          fetch(`${API}/api/approve`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ id, sessionId, classId }),
          })
        )
      );
      window.dispatchEvent(new Event("local-storage"));
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

function RejectFlaggedAllButton() {
  async function click() {
    const classId = localStorage.getItem("activeClassId") || null;
    const sessionId = localStorage.getItem("activeSessionId") || null;
    if (!sessionId && !classId)
      return alert("Start a session (or set class) first");
    try {
      const url = sessionId
        ? `${API}/api/attendanceFeed?sessionId=${encodeURIComponent(
            sessionId
          )}&t=${Date.now()}`
        : `${API}/api/attendanceFeed?classId=${encodeURIComponent(
            classId
          )}&t=${Date.now()}`;
      const res = await fetch(url, { cache: "no-store" });
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
      window.dispatchEvent(new Event("local-storage"));
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

/* ---------------- StudentView ---------------- */
function StudentView() {
  const [scanResult, setScanResult] = useState(null);
  const [status, setStatus] = useState("idle");
  const [studentId, setStudentId] = useState("S123");
  const [enrollName, setEnrollName] = useState("");
  const [enrollId, setEnrollId] = useState("");

  async function enrollStudent() {
    if (!enrollId || !enrollName) return alert("Enter roll no and name");
    try {
      const res = await fetch(`${API}/api/students`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: enrollId, name: enrollName }),
      });
      if (!res.ok) {
        const txt = await res.text();
        throw new Error(txt || "enroll failed");
      }
      alert("Student enrolled. Now use that ID to scan and check-in.");
      setEnrollName("");
      setEnrollId("");
    } catch (err) {
      console.error("enroll error", err);
      alert("Enroll failed (check server). See console.");
    }
  }

  async function onScanMock() {
    const pasted = prompt("Paste token string (from teacher QR):");
    if (!pasted) return;
    try {
      let windowPayload;
      try {
        windowPayload = JSON.parse(pasted);
      } catch {
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
      const signature = await biometricSignMock(
        studentId,
        JSON.stringify(windowPayload)
      );
      setStatus("uploading");

      let res = await fetch(`${API}/api/verify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          studentId,
          token: windowPayload.tokenString || JSON.stringify(windowPayload),
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
      window.dispatchEvent(new Event("local-storage"));
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
    </div>
  );
}

/* ---------------- DashboardPanel ---------------- */
function DashboardPanel() {
  const [present, setPresent] = useState([]);
  const [pending, setPending] = useState([]);
  const [flagged, setFlagged] = useState([]);
  const [sessionId, setSessionId] = useState(
    () => localStorage.getItem("activeSessionId") || null
  );
  const [classId, setClassId] = useState(
    () => localStorage.getItem("activeClassId") || ""
  );

  const suppressRef = useRef(0);
  const abortRef = useRef(null);

  function feedUrl(currentSessionId = sessionId, currentClassId = classId) {
    const ts = Date.now();
    if (currentSessionId)
      return `${API}/api/attendanceFeed?sessionId=${encodeURIComponent(
        currentSessionId
      )}&t=${ts}`;
    if (currentClassId)
      return `${API}/api/attendanceFeed?classId=${encodeURIComponent(
        currentClassId
      )}&t=${ts}`;
    return `${API}/api/attendanceFeed?t=${ts}`;
  }

  useEffect(() => {
    let running = true;
    const t = setInterval(() => {
      if (running) fetchFeed();
    }, 1000); // Poll every 1 second for near-realtime updates
    fetchFeed();

    function onStorageChange() {
      setSessionId(localStorage.getItem("activeSessionId") || null);
      setClassId(localStorage.getItem("activeClassId") || "");
      fetchFeed();
    }
    window.addEventListener("storage", onStorageChange);
    window.addEventListener("local-storage", onStorageChange);

    return () => {
      running = false;
      clearInterval(t);
      if (abortRef.current) abortRef.current.abort();
      window.removeEventListener("storage", onStorageChange);
      window.removeEventListener("local-storage", onStorageChange);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessionId, classId]);

  async function fetchFeed() {
    if (Date.now() < suppressRef.current) return;
    if (abortRef.current) {
      abortRef.current.abort();
      abortRef.current = null;
    }
    const controller = new AbortController();
    abortRef.current = controller;
    try {
      const url = feedUrl();
      console.log("[Dashboard] Fetching:", url);
      const res = await fetch(url, {
        cache: "no-store",
        signal: controller.signal,
      });
      if (!res.ok) {
        console.error("[Dashboard] Feed fetch failed:", res.status, res.statusText);
        throw new Error("feed fetch failed");
      }
      const data = await res.json();
      console.log("[Dashboard] Feed data:", data);
      setPresent(data.present || []);
      setPending(data.pending || []);
      setFlagged(data.flagged || []);
    } catch (err) {
      if (err.name === "AbortError") return;
      console.warn("fetchFeed error", err);
    } finally {
      abortRef.current = null;
    }
  }

  async function approve(id) {
    try {
      const body = { id };
      if (sessionId) body.sessionId = sessionId;
      else if (classId) body.classId = classId;
      const res = await fetch(`${API}/api/approve`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error("approve failed");
      await fetchFeed();
      window.dispatchEvent(new Event("local-storage"));
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
      const res = await fetch(`${API}/api/reject`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error("reject failed");
      await fetchFeed();
      window.dispatchEvent(new Event("local-storage"));
    } catch (err) {
      console.warn("reject error", err);
      alert("Reject failed (check console).");
    }
  }

  async function clearData(
    confirmText = "Are you sure you want to clear attendance for this session/class? This cannot be undone."
  ) {
    const sid = sessionId || null;
    const cid = classId || "";
    const scope = sid ? { sessionId: sid } : cid ? { classId: cid } : null;
    if (!scope)
      return alert(
        "No active session or class set. Start a session or set a class first."
      );
    if (!window.confirm(confirmText)) return;

    try {
      if (abortRef.current) {
        abortRef.current.abort();
        abortRef.current = null;
      }
      try {
        localStorage.removeItem("attendance");
        localStorage.removeItem("attendance_backup");
      } catch (e) {}
      const res = await fetch(`${API}/api/attendance/clear`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...scope, t: Date.now() }),
      });
      if (!res.ok) {
        const text = await res.text();
        console.error("clear failed", res.status, text);
        const doLocal = window.confirm(
          "Server clear failed. Clear UI locally only? (server data will remain)"
        );
        if (doLocal) {
          setPresent([]);
          setPending([]);
          setFlagged([]);
          window.dispatchEvent(new Event("local-storage"));
          alert("Cleared locally (server still has data).");
        } else alert("Clear aborted.");
        return;
      }
      setPresent([]);
      setPending([]);
      setFlagged([]);
      suppressRef.current = Date.now() + 1500;
      setTimeout(async () => {
        await fetchFeed();
        alert("Attendance cleared on server.");
        window.dispatchEvent(new Event("local-storage"));
      }, 400);
    } catch (err) {
      console.error("clear error", err);
      const doLocal = window.confirm(
        "Network error. Clear UI locally only? (server may be down)"
      );
      if (doLocal) {
        setPresent([]);
        setPending([]);
        setFlagged([]);
        alert("Cleared locally.");
      }
    }
  }

  async function exportCsv() {
    const url = sessionId
      ? `${API}/api/export?sessionId=${encodeURIComponent(
          sessionId
        )}&t=${Date.now()}`
      : classId
      ? `${API}/api/export?classId=${encodeURIComponent(
          classId
        )}&t=${Date.now()}`
      : `${API}/api/export?t=${Date.now()}`;
    window.open(url, "_blank");
  }

  async function exportAndClear() {
    const sid = sessionId || null;
    const cid = classId || "";
    const scope = sid ? { sessionId: sid } : cid ? { classId: cid } : null;
    if (!scope)
      return alert(
        "No active session or class set. Start a session or set a class first."
      );
    if (
      !window.confirm(
        "Export CSV and then clear attendance for this session/class? This will delete records on the server."
      )
    )
      return;
    try {
      const res = await fetch(`${API}/api/export-and-clear`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...scope, t: Date.now() }),
      });
      if (res.ok) {
        const blob = await res.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `attendance_export_${Date.now()}.csv`;
        document.body.appendChild(a);
        a.click();
        a.remove();
        window.URL.revokeObjectURL(url);
        setPresent([]);
        setPending([]);
        setFlagged([]);
        suppressRef.current = Date.now() + 1500;
        setTimeout(async () => {
          await fetchFeed();
          alert("Exported and cleared on server.");
          window.dispatchEvent(new Event("local-storage"));
        }, 400);
        return;
      }
      const exportUrl = sessionId
        ? `${API}/api/export?sessionId=${encodeURIComponent(
            sessionId
          )}&t=${Date.now()}`
        : `${API}/api/export?classId=${encodeURIComponent(
            classId
          )}&t=${Date.now()}`;
      window.open(exportUrl, "_blank");
      setTimeout(
        () => clearData("Confirm: delete attendance AFTER export?"),
        800
      );
    } catch (err) {
      console.error("exportAndClear error", err);
      alert("Export & Clear failed (network).");
    }
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
              {s.studentId}
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

/* small helpers */
function Section({ title, children }) {
  return (
    <div className="mb-4">
      <h4 className="text-sm font-medium mb-2">{title}</h4>
      <div className="text-sm text-gray-700">{children}</div>
    </div>
  );
}

async function biometricSignMock(studentId, token) {
  await sleep(400);
  return btoa(`sig:${studentId}:${token}:${Date.now()}`);
}
function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
