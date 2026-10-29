import fs from "node:fs";
import path from "node:path";
import type { ErrorRequestHandler } from "express";
import { ZodError } from "zod";
import { HttpError } from "../utils/http-error";

const logDir = path.resolve(process.cwd(), "logs");
const logFile = path.join(logDir, "error.log");

/**
 * Real errors go to `backend/logs/error.log` (outside the served tree and
 * git-ignored). Users only ever see a generic message, never a stack trace,
 * SQL text or file path.
 */
function writeErrorLog(
  req: Parameters<ErrorRequestHandler>[1],
  error: unknown
): void {
  const stack = error instanceof Error ? error.stack ?? error.message : String(error);
  const line = [
    new Date().toISOString(),
    req.method,
    req.originalUrl,
    req.ip ?? "-",
    stack
  ].join(" | ");

  try {
    fs.mkdirSync(logDir, { recursive: true });
    fs.appendFileSync(logFile, `${line}\n`, "utf8");
  } catch (writeError) {
    console.error("[error-log]", writeError);
  }
  console.error(`[ERROR] ${line}`);
}

export const errorHandler: ErrorRequestHandler = (error, req, res, _next) => {
  if (error instanceof ZodError) {
    res.status(400).json({
      error: "VALIDATION_ERROR",
      message: "Request validation failed.",
      details: error.issues
    });
    return;
  }

  if (error instanceof HttpError) {
    res.status(error.status).json({
      error: error.code,
      message: error.message,
      ...(error.details ? { details: error.details } : {})
    });
    return;
  }

  writeErrorLog(req, error);
  res.status(500).json({
    error: "INTERNAL_SERVER_ERROR",
    message: "An unexpected server error occurred."
  });
};
