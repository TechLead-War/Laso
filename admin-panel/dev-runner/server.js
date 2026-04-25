// Local-only helper that lets the admin panel's "Generate" button fire the
// app-store screenshot script. Listens on http://127.0.0.1:5099 and only
// accepts the small whitelist of flags the dashboard form produces. No
// dependencies — uses Node's built-in http + child_process.
//
// Usage:
//   node admin-panel/dev-runner/server.js
//
// Then click "Generate" in the admin panel's App Screenshots page.

const http = require("http");
const { spawn } = require("child_process");
const path = require("path");

// Server lives at admin-panel/dev-runner/, so the repo root is two levels up.
const REPO_ROOT = path.resolve(__dirname, "..", "..");
const SCRIPT = "./Scripts/capture-app-store-screenshots.sh";

// Whitelist regex — only these CLI flag shapes are forwarded to the script.
const ALLOWED_FLAG = /^--(shots|folder-suffix|override-name|override-overall-score|override-sleep-score|override-activity-score|workers)=.*/;

const server = http.createServer((req, res) => {
  // Permissive CORS — server is bound to 127.0.0.1 only, so this is just
  // for the browser running on http://localhost:5002.
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === "GET" && req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true, repoRoot: REPO_ROOT }));
    return;
  }

  if (req.method !== "POST" || req.url !== "/api/generate-screenshots") {
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Not found" }));
    return;
  }

  let body = "";
  req.on("data", (chunk) => {
    body += chunk;
    if (body.length > 64 * 1024) {
      // Hard cap — args payload should be tiny.
      req.destroy();
    }
  });

  req.on("end", () => {
    let payload = {};
    try { payload = JSON.parse(body); } catch (_) { payload = {}; }

    const requestedArgs = Array.isArray(payload.args) ? payload.args : [];
    const args = requestedArgs.filter((a) => typeof a === "string" && ALLOWED_FLAG.test(a));

    console.log(`[run] ${SCRIPT} ${args.join(" ")}`);
    const startedAt = Date.now();

    const child = spawn(SCRIPT, args, { cwd: REPO_ROOT });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (d) => { stdout += d.toString(); });
    child.stderr.on("data", (d) => { stderr += d.toString(); });

    child.on("error", (err) => {
      console.error("[error]", err.message);
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ success: false, error: err.message }));
    });

    child.on("close", (code) => {
      const ms = Date.now() - startedAt;
      console.log(`[done] exit ${code} in ${(ms / 1000).toFixed(1)}s`);
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({
        success: code === 0,
        exitCode: code,
        durationMs: ms,
        // Tail the output so the dashboard can show the last lines without
        // hauling megabytes back over HTTP.
        stdoutTail: stdout.slice(-4000),
        stderrTail: stderr.slice(-2000),
      }));
    });
  });
});

const PORT = 5099;
server.listen(PORT, "127.0.0.1", () => {
  console.log(`Screenshot helper listening on http://127.0.0.1:${PORT}`);
  console.log(`Repo root: ${REPO_ROOT}`);
  console.log(`Click "Generate" in the admin panel App Screenshots page.`);
});
