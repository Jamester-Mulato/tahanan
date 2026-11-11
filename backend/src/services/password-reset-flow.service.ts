import crypto from "node:crypto";
import type { Request } from "express";
import { query } from "../config/db";
import { env } from "../config/env";
import { SEEDED_QUESTIONS, SEEDED_KEYS } from "../security/questions";
import { hashPassword, verifyPassword } from "../utils/password";
import { HttpError } from "../utils/http-error";
import { logAuthEvent } from "./auth-events.service";
import {
  assertPasswordNotReused,
  recordPasswordHistory
} from "./auth.service";
import { sendPasswordChangedAlert } from "./mail.service";

const RESET_TOKEN_MINUTES = 10;

export function seededQuestionList() {
  return SEEDED_KEYS.map((key) => ({
    key,
    text:
      key === "Q6"
        ? SEEDED_QUESTIONS.A.text
        : key === "Q1"
          ? SEEDED_QUESTIONS.B.text
          : SEEDED_QUESTIONS.C.text
  }));
}

async function findUser(identifier: string) {
  const result = await query<{ id: string; email: string; display_name: string; locked_until: string | null }>(
    `SELECT id, email, display_name, locked_until
       FROM users
      WHERE lower(username) = lower($1) OR lower(email) = lower($1)`,
    [identifier]
  );
  return result.rows[0] ?? null;
}

function lockoutSeconds(count: number): number | null {
  if (count === 3) return env.LOCKOUT_TIER1_SECONDS;
  if (count === 6) return env.LOCKOUT_TIER2_SECONDS;
  if (count >= 9) return env.LOCKOUT_TIER3_SECONDS;
  return null;
}

/** Always returns the three seeded questions so unknown users look identical. */
export async function questionsFor(identifier: string) {
  const user = await findUser(identifier);
  await logAuthEvent({
    eventType: "RESET_REQUESTED",
    userId: user?.id,
    email: user?.email,
    details: { identifier }
  });
  return { user, questions: seededQuestionList() };
}

export async function verifySecurityAnswer(input: {
  identifier: string;
  question: string;
  answer: string;
  reanswer: string;
  req?: Request;
}) {
  if (input.answer !== input.reanswer) {
    throw new HttpError(422, "ANSWER_MISMATCH", "Answers do not match.");
  }

  const user = await findUser(input.identifier);
  if (!user) {
    // Same message and status as a wrong answer.
    throw new HttpError(401, "RESET_DENIED", "One of those details is incorrect.");
  }

  // A wrong answer already counts toward the shared lockout, so an active lock
  // has to stop the recovery flow too. Without this the reset path would be a
  // way around the sign-in lockout.
  if (user.locked_until) {
    const left = Math.ceil(
      (new Date(user.locked_until).getTime() - Date.now()) / 1000
    );
    if (left > 0) {
      throw new HttpError(
        423,
        "ACCOUNT_LOCKED",
        `Too many attempts. Try again in ${left} seconds.`,
        { retryAfter: left }
      );
    }
    // Expired: drop the lock but keep the streak so the tiers still progress.
    await query("UPDATE users SET locked_until = NULL WHERE id = $1", [user.id]);
  }

  const stored = await query<{ answer_hash: string }>(
    "SELECT answer_hash FROM security_answers WHERE user_id = $1 AND question_key = $2",
    [user.id, input.question]
  );
  const hash = stored.rows[0]?.answer_hash;
  const ok = hash
    ? await verifyPassword(input.answer.trim().toLowerCase(), hash)
    : false;

  if (!ok) {
    await query(
      "UPDATE users SET failed_login_count = failed_login_count + 1, updated_at = now() WHERE id = $1",
      [user.id]
    );
    const count = await query<{ failed_login_count: number }>(
      "SELECT failed_login_count FROM users WHERE id = $1",
      [user.id]
    );
    const seconds = lockoutSeconds(count.rows[0]?.failed_login_count ?? 1);
    if (seconds) {
      const attempts = count.rows[0]?.failed_login_count ?? 1;
      await query(
        "UPDATE users SET locked_until = now() + ($1 || ' seconds')::interval WHERE id = $2",
        [String(seconds), user.id]
      );
      if (attempts === 3 || attempts === 6 || attempts === 9) {
        await logAuthEvent({
          eventType:
            attempts === 9
              ? "LOCKOUT_TIER_3"
              : attempts === 6
                ? "LOCKOUT_TIER_2"
                : "LOCKOUT_TIER_1",
          userId: user.id,
          email: user.email,
          usernameTyped: input.identifier,
          req: input.req,
          details: { attempts, seconds, source: "reset" }
        });
      }
      throw new HttpError(
        423,
        "ACCOUNT_LOCKED",
        `Too many attempts. Try again in ${seconds} seconds.`,
        { retryAfter: seconds }
      );
    }
    throw new HttpError(401, "RESET_DENIED", "One of those details is incorrect.");
  }

  return user;
}

export async function createResetToken(userId: string, req?: Request) {
  const token = crypto.randomBytes(24).toString("hex");
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
  await query(
    `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, now() + ($3 || ' minutes')::interval)`,
    [userId, tokenHash, String(RESET_TOKEN_MINUTES)]
  );
  await logAuthEvent({
    eventType: "RESET_TOKEN_ISSUED",
    userId,
    req,
    details: { minutes: RESET_TOKEN_MINUTES }
  });
  return { token, expiresIn: RESET_TOKEN_MINUTES * 60 };
}

export async function resetPasswordWithToken(input: {
  token: string;
  password: string;
  req?: Request;
}) {
  const password = input.password;
  if (password.length < 9) {
    throw new HttpError(400, "WEAK_PASSWORD", "Password must be at least 9 characters.");
  }
  if (password.length > 64) {
    throw new HttpError(400, "WEAK_PASSWORD", "Password must be at most 64 characters.");
  }
  if (password === password.toLowerCase() || !/\d/.test(password)) {
    throw new HttpError(
      400,
      "WEAK_PASSWORD",
      "Password must include an uppercase letter and a number."
    );
  }

  const tokenHash = crypto.createHash("sha256").update(input.token).digest("hex");
  const found = await query<{ id: string; user_id: string }>(
    `SELECT id, user_id
       FROM password_reset_tokens
      WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now()`,
    [tokenHash]
  );
  const row = found.rows[0];
  if (!row) {
    throw new HttpError(
      401,
      "RESET_TOKEN_INVALID",
      "This reset has expired. Start the forgotten-password steps again."
    );
  }

  await assertPasswordNotReused(row.user_id, password);
  const passwordHash = await hashPassword(password);

  await query(
    `UPDATE users
        SET password_hash = $1,
            password_changed_at = now(),
            token_version = token_version + 1,
            failed_login_count = 0,
            locked_until = NULL,
            updated_at = now()
      WHERE id = $2`,
    [passwordHash, row.user_id]
  );
  await query("UPDATE password_reset_tokens SET used_at = now() WHERE id = $1", [row.id]);
  await query("UPDATE password_reset_tokens SET used_at = now() WHERE user_id = $1 AND used_at IS NULL", [row.user_id]);
  await query("DELETE FROM auth_refresh_tokens WHERE user_id = $1", [row.user_id]);
  await recordPasswordHistory(row.user_id, passwordHash);

  const user = await query<{ email: string; display_name: string }>(
    "SELECT email, display_name FROM users WHERE id = $1",
    [row.user_id]
  );
  if (user.rows[0]) {
    try {
      await sendPasswordChangedAlert({
        to: user.rows[0].email,
        name: user.rows[0].display_name,
        ip: input.req?.ip,
        userAgent: input.req?.get("user-agent")
      });
      await logAuthEvent({
        eventType: "ALERT_EMAIL_SENT",
        userId: row.user_id,
        email: user.rows[0].email,
        req: input.req,
        details: { kind: "password_changed" }
      });
    } catch {
      // The password change already succeeded; a mail failure is not fatal.
    }
  }

  await logAuthEvent({
    eventType: "PASSWORD_CHANGED",
    userId: row.user_id,
    req: input.req
  });

  return { ok: true };
}
