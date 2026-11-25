// Serves the built Flutter web app from build/web with no caching.
// Used for the local demo: node scripts/serve-web.js
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..", "build", "web");
const port = Number(process.env.PORT || 5173);

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".wasm": "application/wasm",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".map": "application/json; charset=utf-8"
};

const server = http.createServer((req, res) => {
  let url = decodeURIComponent((req.url || "/").split("?")[0]);
  if (url === "/") url = "/index.html";

  const file = path.join(root, url);
  if (!file.startsWith(root)) {
    res.writeHead(403).end("Forbidden");
    return;
  }

  fs.readFile(file, (error, buffer) => {
    if (error) {
      fs.readFile(path.join(root, "index.html"), (fallbackError, index) => {
        if (fallbackError) {
          res.writeHead(404).end("Not found");
          return;
        }
        res
          .writeHead(200, {
            "content-type": "text/html; charset=utf-8",
            "cache-control": "no-store"
          })
          .end(index);
      });
      return;
    }

    res
      .writeHead(200, {
        "content-type": types[path.extname(file)] || "application/octet-stream",
        "cache-control": "no-store"
      })
      .end(buffer);
  });
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Tahanan web: http://127.0.0.1:${port}  (root: ${root})`);
});
