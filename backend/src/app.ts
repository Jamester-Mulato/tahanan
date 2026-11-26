import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import { env, corsOrigins } from "./config/env";
import { asyncRoute } from "./utils/async-route";
import { sessionSettings } from "./services/settings.service";
import { errorHandler } from "./middleware/error-handler";
import { csrfGuard } from "./middleware/csrf";
import { authRouter } from "./routes/auth.routes";
import { meRouter } from "./routes/me.routes";
import { boardingHouseRouter } from "./routes/boarding-house.routes";
import { roomRouter } from "./routes/room.routes";
import { tenantRouter } from "./routes/tenant.routes";
import { statusRouter } from "./routes/status.routes";
import { announcementRouter } from "./routes/announcement.routes";
import { concernRouter } from "./routes/concern.routes";
import { dashboardRouter } from "./routes/dashboard.routes";
import { adminRouter } from "./routes/admin.routes";
import { adminConsoleRouter } from "./routes/admin-console.routes";
import { clientErrorsRouter } from "./routes/client-errors.routes";
import { securityRouter } from "./routes/security.routes";
import { recaptchaPage } from "./views/recaptcha-page";

import path from "node:path";
import fs from "node:fs";

export const app = express();

// Behind Tailscale serve / a reverse proxy, the real client IP arrives in
// X-Forwarded-For. Trust exactly one hop so IP blocking and the activity log
// record the phone, not 127.0.0.1.
app.set("trust proxy", 1);

app.disable("x-powered-by");
app.use(
  helmet({
    crossOriginResourcePolicy: { policy: "cross-origin" },
    frameguard: { action: "deny" }
  })
);
app.use(
  cors({
    origin: corsOrigins === "*" ? true : corsOrigins
  })
);
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

// Server-side CSRF check for every state-changing API call.
app.use("/api", (req, res, next) => {
  void csrfGuard(req, res, next);
});

const uploadsDir = path.resolve(process.cwd(), "uploads");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}
app.use("/uploads", express.static(uploadsDir));

if (env.NODE_ENV !== "test") {
  app.use(morgan("combined"));
}

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "tahanan-backend",
    environment: env.NODE_ENV
  });
});

// Runtime settings the clients fetch on load (editable from the admin site).
app.get(
  "/api/config",
  asyncRoute(async (_req, res) => {
    const settings = await sessionSettings();
    res.json({
      idleTimeoutSeconds: settings.idleTimeoutSeconds,
      warningSeconds: settings.warningSeconds
    });
  })
);

// The widget page needs Google's scripts and frames, so it gets a narrower
// route-specific policy instead of the strict API policy.
app.get("/recaptcha", (req, res) => {
  const popup = req.query.popup === "1";

  // The widget is embedded as an iframe in the Flutter web app, so it must
  // be frameable by the app's origin. Remove Helmet's SAMEORIGIN block and
  // allow the parent explicitly in the CSP.
  res.removeHeader("X-Frame-Options");
  res.setHeader("Cross-Origin-Opener-Policy", "unsafe-none");
  res.setHeader(
    "Content-Security-Policy",
    [
      "default-src 'self' https://www.google.com https://www.gstatic.com",
      "script-src 'self' 'unsafe-inline' https://www.google.com https://www.gstatic.com",
      "frame-src https://www.google.com",
      "frame-ancestors *",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https://www.gstatic.com",
      "connect-src 'self' https://www.google.com"
    ].join("; ")
  );

  res.type("html").send(recaptchaPage(env.RECAPTCHA_SITE_KEY, popup));
});

app.use("/api/auth", authRouter);
app.use("/api/me", meRouter);
app.use("/api/boarding-houses", boardingHouseRouter);
app.use("/api/rooms", roomRouter);
app.use("/api/tenants", tenantRouter);
app.use("/api/status", statusRouter);
app.use("/api/announcements", announcementRouter);
app.use("/api/concerns", concernRouter);
app.use("/api/dashboard", dashboardRouter);
app.use("/api/admin", adminRouter);
app.use("/api/admin/console", adminConsoleRouter);
app.use("/api/client-errors", clientErrorsRouter);
app.use("/api/security", securityRouter);

// Standalone admin console (not part of the Flutter app). Same origin as the
// API, so the page talks to /api/admin/console with a bearer token.
const adminPage = path.resolve(process.cwd(), "public", "admin.html");
app.get(["/admin", "/admin/"], (_req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader(
    "Content-Security-Policy",
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data:",
      "connect-src 'self'",
      "frame-ancestors 'none'"
    ].join("; ")
  );
  res.type("html").sendFile(adminPage);
});

// Serve the Flutter web build from the same origin, so the whole product can
// live behind one Tailscale HTTPS endpoint: / = web app, /admin = console,
// /api = API. Skipped on hosts that deploy only the API (for example Render).
const webBuildDir = path.resolve(process.cwd(), "..", "build", "web");
if (fs.existsSync(path.join(webBuildDir, "index.html"))) {
  app.use(express.static(webBuildDir, { index: "index.html" }));
  app.use((req, res, next) => {
    if (req.method !== "GET" && req.method !== "HEAD") return next();
    if (/^\/(api|admin|recaptcha|uploads|health)(\/|$)/.test(req.path)) {
      return next();
    }
    res.sendFile(path.join(webBuildDir, "index.html"));
  });
}

// Unknown paths (including .php/.js probes) answer with a plain 404 so the
// server never reveals source files or a framework error page.
app.use((_req, res) => {
  res.status(404).json({ error: "NOT_FOUND", message: "Page not found." });
});

app.use(errorHandler);
