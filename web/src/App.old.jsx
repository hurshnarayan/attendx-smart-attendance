import React, { useEffect, useState, useRef } from "react";
import "./styles.css";
import QRCode from "qrcode";
// Optional: npm i qr-scanner
import QrScanner from "qr-scanner";

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
  const [token, setToken] = useState(null);
  const [pin, setPin] = useState(null);
  const [countdown, setCountdown] = useState(15);
  const canvasRef = useRef(null);
  const intervalRef = useRef(null);

  useEffect(() => {
    // Fetch initial token and start 15s rotation
    fetchToken();
    // store interval ref so End Session can clear it
    intervalRef.current = setInterval(() => fetchToken(), 15000);
    return () => clearInterval(intervalRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [classId]);

  useEffect(() => {
    // Countdown timer based on current token's validity
    const t = setInterval(() => {
      setCountdown((c) => (c > 0 ? c - 1 : 15));
    }, 1000);
    return () => clearInterval(t);
  }, []);

  async function fetchToken() {
    try {
      const res = await fetch(
        `${API}/api/token?classId=${encodeURIComponent(classId)}`
      );
      if (!res.ok) throw new Error("token fetch failed");
      const data = await res.json();
      setToken(data.tokenString || JSON.stringify(data));
      setPin(data.pin || null);
      setCountdown(data.expiresIn || 15);

      // Render QR to canvas
      const canvas = canvasRef.current;

      if (canvas) {
        // clear and set size to ensure consistent rendering
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width || 300, canvas.height || 300);
        await QRCode.toCanvas(
          canvas,
          data.tokenString || JSON.stringify(data),
          { width: 300 }
        );
      }
    } catch (err) {
      console.error("fetchToken error", err);
    }
  }

  function endSession() {
    // Stop rotation and clear QR from canvas (client-side)
    clearInterval(intervalRef.current);
    setToken(null);
    setPin(null);
    setCountdown(0);
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext("2d");
      ctx.clearRect(0, 0, canvas.width || 300, canvas.height || 300);
    }
    console.log(
      "Session ended (client-side). To invalidate server-side, add an endpoint."
    );
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
        {/* put this under the canvas in TeacherView to show token  */}

        {/* SHOW TOKEN FOR TESTING */}
        {/* <div className="mt-3 text-xs">
          <div className="font-medium mb-1">Raw token (for testing)</div>
          <textarea
            readOnly
            value={token ?? ""}
            className="w-72 h-20 p-2 border rounded text-xs break-words"
          />
          <div className="mt-2">
            <button
              onClick={() => {
                if (!token) return;
                navigator.clipboard.writeText(token);
                alert("Token copied to clipboard");
              }}
              className="px-3 py-1 border rounded"
            >
              Copy token
            </button>
          </div>
        </div> */}

        <div className="flex-1">
          <label className="block text-sm font-medium text-gray-700">
            Class ID
          </label>
          <input
            value={classId}
            onChange={(e) => setClassId(e.target.value)}
            className="mt-1 p-2 border rounded w-48"
          />

          <div className="mt-4">
            <button
              className="px-4 py-2 bg-indigo-600 text-white rounded"
              onClick={fetchToken}
            >
              Refresh Now
            </button>
            <button
              className="ml-2 px-4 py-2 border rounded"
              onClick={endSession}
            >
              End Session
            </button>
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

// Approve all pending helper component (keeps TeacherView small)
function ApproveAllButton() {
  async function click() {
    try {
      const res = await fetch(`${API}/api/attendanceFeed`);
      const data = await res.json();
      const ids = (data.pending || []).map((p) => p.id);
      await Promise.all(
        ids.map((id) =>
          fetch(`${API}/api/approve`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ id }),
          })
        )
      );
      console.log("Approved", ids.length, "pending entries");
    } catch (err) {
      console.error("approve all error", err);
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
    try {
      const res = await fetch(`${API}/api/attendanceFeed`);
      const data = await res.json();
      const ids = (data.flagged || []).map((p) => p.id);
      await Promise.all(
        ids.map((id) =>
          fetch(`${API}/api/reject`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ id }),
          })
        )
      );
      console.log("Rejected", ids.length, "flagged entries");
    } catch (err) {
      console.error("reject flagged all error", err);
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
  const videoRef = useRef(null);
  const scannerRef = useRef(null);

  // Optionally you can use a library like qr-scanner for camera scanning
  // (npm i qr-scanner). If not installed, fallback to prompt.

  async function onScanMock() {
    const token = prompt("Paste token string (from teacher QR):");
    if (!token) return;
    await sendVerify(token);
  }

  async function sendVerify(token) {
    setScanResult(token);
    try {
      setStatus("authenticating");
      const signature = await biometricSignMock(studentId, token);
      setStatus("uploading");
      const res = await fetch(`${API}/api/verify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          studentId,
          token,
          signature,
          clientTs: Math.floor(Date.now() / 1000),
        }),
      });
      const data = await res.json();
      if (data.status === "present") setStatus("present");
      else if (data.status === "pending") setStatus("pending");
      else setStatus("flagged");
    } catch (err) {
      console.error(err);
      setStatus("error");
    }
  }

  // Optional: function to use in-app camera scanning with qr-scanner library.
  // If you want this, install `qr-scanner` and uncomment imports + code.
  // Provided as guidance only.

  //   async function startCameraScan() {
  //     try {
  //       if (!videoRef.current) return;
  //       scannerRef.current = new QrScanner(
  //         videoRef.current,
  //         (result) => {
  //           // result is text from QR
  //           sendVerify(result);
  //           scannerRef.current.stop();
  //         },
  //         { returnDetailedScanResult: true }
  //       );
  //       await scannerRef.current.start();
  //     } catch (err) {
  //       console.error("camera scan error", err);
  //       alert("Camera scanning failed — falling back to paste prompt.");
  //       onScanMock();
  //     }
  //   }

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
        {/* If you install qr-scanner and want camera scanning, enable this: */}
        {/* <button onClick={startCameraScan} className="px-4 py-2 border rounded">
          Scan with Camera
        </button> */}
      </div>

      <div className="mt-4">
        <div className="text-sm">
          Status: <strong>{status}</strong>
        </div>
        <div className="mt-2 text-xs text-gray-500">
          Scan result: {scanResult ?? "—"}
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

  useEffect(() => {
    // Poll attendance every 2s (replace with websocket in prod)
    fetchFeed();
    const t = setInterval(fetchFeed, 2000);
    return () => clearInterval(t);
  }, []);

  async function fetchFeed() {
    try {
      const res = await fetch(`${API}/api/attendanceFeed`);
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
      await fetch(`${API}/api/approve`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id }),
      });
      fetchFeed();
    } catch (err) {
      console.warn("approve error", err);
    }
  }
  async function reject(id) {
    try {
      await fetch(`${API}/api/reject`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id }),
      });
      fetchFeed();
    } catch (err) {
      console.warn("reject error", err);
    }
  }

  async function exportCsv() {
    window.open(`${API}/api/export`, "_blank");
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

      <div className="mt-4">
        <button onClick={exportCsv} className="w-full px-3 py-2 border rounded">
          Export CSV
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
