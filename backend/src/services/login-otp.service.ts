import crypto from "node:crypto";
import type { Request } from "express";
import { query } from "../config/db";
import { env } from "../config/env";
import { hashPassword, verifyPassword } from "../utils/password";
import { HttpError, } from "../utils/http-error";
import { logAuthEvent } from "./auth-events.service";
import { sendLoginOtp, sendRegistrationOtp, sendPasswordResetCode } from "./mail.service";

export type OtpPurpose = "login" | "register" | "reset";

export const OTP_EXPIRY_MINUTES = 5;
export const OTP_MAX_ATTEMPTS = 3;
export const OTP_RESEND_COOLDOWN_SECONDS = 60;
export const OTP_MAX_RESENDS = 3;

export function maskEmail(email: string): string {
  const [local, domain] = email.split("@");
  if (!domain) return "your email";
  const shown = local.slice(0, 2);
  return `${shown}${"*".repeat(Math.max(1, local.length - 2))}@${domain}`;
}

function sixDigits(): string {
  return String(crypto.randomInt(0, 1_000_000)).padStart(6, "0");
}

export interface OtpChallenge {
  challengeId: string;
  maskedEmail: string;
  expiresIn: number;
  resendIn: number;
}

async function deliver(
  challengeId: string,
  input: {
    userId: string;
    email: string;
    name: string;
    purpose: OtpPurpose;
    req?: Request;
  }
): Promise<void> {
  const code = sixDigits();
  const codeHash = await hashPassword(code);
  await query(
    `UPDATE login_otps
        SET code_hash = $2,
            attempts = 0,
            used = FALSE,
            expires_at = now() + ($3 || ' minutes')::interval,
            last_sent_at = now()
      WHERE id = $1`,
    [challengeId, codeHash, String(OTP_EXPIRY_MINUTES)]
  );

  try {
    if (input.purpose === "register") {
      await sendRegistrationOtp({
        to: input.email,
        name: input.name,
        code,
        expiresMinutes: OTP_EXPIRY_MINUTES
      });
    } else if (input.purpose === "reset") {
      await sendPasswordResetCode({
        to: input.email,
        name: input.name,
        code,
        expiresMinutes: OTP_EXPIRY_MINUTES
      });
    } else {
      await sendLoginOtp({
        to: input.email,
        name: input.name,
        code,
        expiresMinutes: OTP_EXPIRY_MINUTES
      });
    }
  } catch (error) {
    // A slow or unreachable SMTP server must not turn a valid registration
    // into a 500 that leaves a pending account behind. The challenge stays
    // valid and the failure is recorded — but the code itself is a credential,
    // so it is only printed when OTP_DEBUG_CODES is explicitly enabled on a
    // local demo box.
    const reason = error instanceof Error ? error.message : String(error);
    console.error(
      `[otp-delivery-failed] to=${input.email} purpose=${input.purpose}: ${reason}`
    );
    if (env.OTP_DEBUG_CODES) {
      console.error(`[otp-debug] to=${input.email} purpose=${input.purpose} code=${code}`);
    }
    await logAuthEvent({
      eventType: "OTP_DELIVERY_FAILED",
      userId: input.userId,
      email: input.email,
      req: input.req,
      details: { purpose: input.purpose, reason }
    });
    return;
  }

  await logAuthEvent({
    eventType: "OTP_SENT",
    userId: input.userId,
    email: input.email,
    req: input.req,
    details: { purpose: input.purpose }
  });
}

/** Creates a fresh challenge and cancels any previous unused code of that purpose. */
export async function startOtp(input: {
  userId: string;
  email: string;
  name: string;
  purpose: OtpPurpose;
  req?: Request;
}): Promise<OtpChallenge> {
  // 60-second cooldown plus at most 3 resends per 15 minutes, per purpose.
  const recent = await query<{ n: number }>(
    `SELECT count(*)::int AS n FROM login_otps
      WHERE user_id = $1
        AND purpose = $2
        AND created_at > now() - interval '15 minutes'`,
    [input.userId, input.purpose]
  );
  if ((recent.rows[0]?.n ?? 0) >= OTP_MAX_RESENDS + 1) {
    throw new HttpError(
      429,
      "OTP_RESEND_LIMIT",
      "Too many codes requested. Try again in a few minutes."
    );
  }

  await query(
    "UPDATE login_otps SET used = TRUE WHERE user_id = $1 AND purpose = $2 AND used = FALSE",
    [input.userId, input.purpose]
  );

  const created = await query<{ id: string }>(
    `INSERT INTO login_otps (user_id, code_hash, expires_at, purpose, ip_address, user_agent)
     VALUES ($1, 'pending', now(), $2, $3, $4)
     RETURNING id`,
    [input.userId, input.purpose, input.req?.ip ?? null, input.req?.get("user-agent") ?? null]
  );

  const challengeId = created.rows[0].id;
  await deliver(challengeId, input);

  return {
    challengeId,
    maskedEmail: maskEmail(input.email),
    expiresIn: OTP_EXPIRY_MINUTES * 60,
    resendIn: OTP_RESEND_COOLDOWN_SECONDS
  };
}

export async function verifyOtp(input: {
  challengeId: string;
  code: string;
  purpose: OtpPurpose;
  req?: Request;
}): Promise<{ userId: string; email: string; name: string }> {
  const found = await query<{
    id: string;
    user_id: string;
    purpose: string;
    code_hash: string;
    expires_at: string;
    attempts: number;
    used: boolean;
  }>(
    `SELECT id, user_id, purpose, code_hash, expires_at, attempts, used
       FROM login_otps
      WHERE id = $1`,
    [input.challengeId]
  );

  const row = found.rows[0];
  if (!row || row.purpose !== input.purpose) {
    throw new HttpError(401, "OTP_INVALID", "That code is invalid or expired. Request a new one.");
  }

  const user = await query<{ email: string; display_name: string }>(
    "SELECT email, display_name FROM users WHERE id = $1",
    [row.user_id]
  );
  const identity = user.rows[0];

  const fail = async (reason: string) => {
    await logAuthEvent({
      eventType: "OTP_FAILED",
      userId: row.user_id,
      email: identity?.email,
      req: input.req,
      details: { purpose: input.purpose, reason }
    });
  };

  if (row.used) {
    await fail("already_used");
    throw new HttpError(
      401,
      "OTP_INVALID",
      "That code was already used. Request a new one.",
      { reason: "already_used" }
    );
  }

  if (new Date(row.expires_at).getTime() < Date.now()) {
    await query("UPDATE login_otps SET used = TRUE WHERE id = $1", [row.id]);
    await fail("expired");
    throw new HttpError(
      401,
      "OTP_INVALID",
      "That code has expired. Request a new one.",
      { reason: "expired" }
    );
  }

  if (row.attempts >= OTP_MAX_ATTEMPTS) {
    await query("UPDATE login_otps SET used = TRUE WHERE id = $1", [row.id]);
    await fail("too_many_attempts");
    throw new HttpError(
      401,
      "OTP_INVALID",
      "Too many wrong codes. Request a new one.",
      { reason: "too_many_attempts" }
    );
  }

  const ok = await verifyPassword(input.code, row.code_hash);
  if (!ok) {
    const attempts = row.attempts + 1;
    const exhausted = attempts >= OTP_MAX_ATTEMPTS;
    await query(
      "UPDATE login_otps SET attempts = $2, used = CASE WHEN $3 THEN TRUE ELSE used END WHERE id = $1",
      [row.id, attempts, exhausted]
    );
    await fail(exhausted ? "too_many_attempts" : "wrong_code");
    throw new HttpError(
      401,
      "OTP_INVALID",
      exhausted
        ? "Too many wrong codes. Request a new one."
        : `That code is wrong. ${OTP_MAX_ATTEMPTS - attempts} ${
            OTP_MAX_ATTEMPTS - attempts === 1 ? "try" : "tries"
          } left.`,
      { reason: exhausted ? "too_many_attempts" : "wrong_code" }
    );
  }

  await query("UPDATE login_otps SET used = TRUE WHERE id = $1", [row.id]);
  return {
    userId: row.user_id,
    email: identity?.email ?? "",
    name: identity?.display_name ?? ""
  };
}

export async function resendOtp(input: {
  challengeId: string;
  purpose: OtpPurpose;
  req?: Request;
}): Promise<OtpChallenge> {
  const found = await query<{
    id: string;
    user_id: string;
    purpose: string;
    used: boolean;
    resend_count: number;
    last_sent_at: string;
  }>(
    "SELECT id, user_id, purpose, used, resend_count, last_sent_at FROM login_otps WHERE id = $1",
    [input.challengeId]
  );

  const row = found.rows[0];
  if (!row || row.used || row.purpose !== input.purpose) {
    throw new HttpError(401, "OTP_INVALID", "That code is invalid or expired. Request a new one.");
  }

  const sinceLast = (Date.now() - new Date(row.last_sent_at).getTime()) / 1000;
  if (sinceLast < OTP_RESEND_COOLDOWN_SECONDS) {
    const left = Math.ceil(OTP_RESEND_COOLDOWN_SECONDS - sinceLast);
    throw new HttpError(429, "OTP_COOLDOWN", `Wait ${left} seconds before requesting another code.`, { retryAfter: left });
  }

  if (row.resend_count >= OTP_MAX_RESENDS) {
    throw new HttpError(429, "OTP_RESEND_LIMIT", "Too many codes requested. Start again later.");
  }

  const user = await query<{ email: string; display_name: string }>(
    "SELECT email, display_name FROM users WHERE id = $1",
    [row.user_id]
  );
  const identity = user.rows[0];
  if (!identity) {
    throw new HttpError(401, "OTP_INVALID", "That code is invalid or expired. Request a new one.");
  }

  await query("UPDATE login_otps SET resend_count = resend_count + 1 WHERE id = $1", [row.id]);
  await deliver(row.id, {
    userId: row.user_id,
    email: identity.email,
    name: identity.display_name,
    purpose: input.purpose,
    req: input.req
  });

  return {
    challengeId: row.id,
    maskedEmail: maskEmail(identity.email),
    expiresIn: OTP_EXPIRY_MINUTES * 60,
    resendIn: OTP_RESEND_COOLDOWN_SECONDS
  };
}

// ---------------------------------------------------------------
// Purpose-specific wrappers used by the routes
// ---------------------------------------------------------------
export const startLoginOtp = (input: {
  userId: string;
  email: string;
  name: string;
  req?: Request;
}) => startOtp({ ...input, purpose: "login" });

export const verifyLoginOtp = (input: {
  challengeId: string;
  code: string;
  req?: Request;
}) => verifyOtp({ ...input, purpose: "login" });

export const resendLoginOtp = (input: {
  challengeId: string;
  req?: Request;
}) => resendOtp({ ...input, purpose: "login" });
