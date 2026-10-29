import type { NextFunction, Request, Response } from "express";
import { corsOrigins } from "../config/env";
import { logAuthEvent } from "../services/auth-events.service";

/**
 * CSRF protection for a token-based API.
 *
 * Tahanan never authenticates with a cookie: every protected call carries
 * `Authorization: Bearer <JWT>`. A cross-site form or image therefore cannot
 * ride an ambient session. This guard adds the explicit server-side check the
 * handout asks for: a state-changing request that arrives with a browser
 * `Origin` header must come from the app's own origin (or an allowlisted one).
 * Anything else is refused and written to the activity log as CSRF_REJECTED.
 *
 * Native clients (Android) send no Origin header, so they pass — their
 * protection is the bearer token itself, which a foreign site cannot read.
 */
const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

function isAllowedOrigin(origin: string, req: Request): boolean {
  let parsed: URL;
  try {
    parsed = new URL(origin);
  } catch {
    return false;
  }

  const host = (req.get("host") ?? "").toLowerCase();
  if (host && parsed.host.toLowerCase() === host) return true;

  if (corsOrigins === "*") return false;
  return corsOrigins.some((allowed) => allowed === parsed.origin);
}

export async function csrfGuard(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  if (SAFE_METHODS.has(req.method)) {
    next();
    return;
  }

  const origin = req.get("origin");
  if (!origin || isAllowedOrigin(origin, req)) {
    next();
    return;
  }

  await logAuthEvent({
    eventType: "CSRF_REJECTED",
    req,
    details: { origin, path: req.originalUrl, method: req.method }
  });

  res.status(403).json({
    error: "CSRF_REJECTED",
    message: "This request did not come from the Tahanan app."
  });
}
