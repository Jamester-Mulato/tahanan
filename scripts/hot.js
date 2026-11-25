// Hot-reload runner. Start it once, then touch `.hot` after any edit:
//   New-Item -Force .hot
// The script sends "r" to the Flutter tool, so the running app reloads in
// about a second instead of rebuilding an APK or a release bundle.
//
//   node scripts/hot.js web       -> http://127.0.0.1:5175
//   node scripts/hot.js android   -> wireless device (adb)
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

const target = (process.argv[2] || "web").toLowerCase();
const root = path.resolve(__dirname, "..");
const log = (...args) => console.log("[hot]", ...args);

function flutterBinary() {
  return process.platform === "win32" ? "flutter.bat" : "flutter";
}

function argsFor(target) {
  if (target === "web") {
    return [
      "run",
      "-d",
      "web-server",
      "--web-port",
      "5175",
      "--web-hostname",
      "127.0.0.1",
    ];
  }
  if (target === "android") {
    return ["run", "-d", "android", "--debug"];
  }
  return ["run", "-d", target];
}

const args = argsFor(target);
log("starting:", "flutter " + args.join(" "));

const child = spawn(flutterBinary(), args, {
  cwd: root,
  shell: true,
  stdio: ["pipe", "inherit", "inherit"],
});

child.on("exit", (code) => {
  log("flutter exited with", code);
  process.exit(code ?? 0);
});

const trigger = path.join(root, ".hot");
let last = 0;
try {
  fs.writeFileSync(trigger, "ready");
  last = fs.statSync(trigger).mtimeMs;
} catch (_) {}

fs.watchFile(trigger, { interval: 400 }, (current) => {
  if (current.mtimeMs === last) return;
  last = current.mtimeMs;
  try {
    child.stdin.write("r");
    log("hot reload sent");
  } catch (error) {
    log("could not send reload:", error.message);
  }
});

// Full restart when a file named `.hot-restart` changes (for state resets).
const restart = path.join(root, ".hot-restart");
let lastRestart = 0;
try {
  fs.writeFileSync(restart, "ready");
  lastRestart = fs.statSync(restart).mtimeMs;
} catch (_) {}

fs.watchFile(restart, { interval: 400 }, (current) => {
  if (current.mtimeMs === lastRestart) return;
  lastRestart = current.mtimeMs;
  try {
    child.stdin.write("R");
    log("hot restart sent");
  } catch (error) {
    log("could not send restart:", error.message);
  }
});
