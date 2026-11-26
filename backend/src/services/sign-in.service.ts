import type { Request } from "express";
import { query } from "../config/db";
import { HttpError } from "../utils/http-error";
import { hashPassword, verifyPassword } from "../utils/password";
import { logAuthEvent } from "./auth-events.service";
import { lockoutFor } from "./credential-policy";
import { sendFailedLoginAlert } from "./mail.service";
import {
  clearIpFailures,
  ipBlockSeconds,
  recordIpBlock
} from "./throttle.service";
import { PASSWORD_COLUMNS, USER_COLUMNS, type UserRow } from "./user-record";

/**
 * The whole password sign-in decision lives here: IP throttle, lock state,
 * password check, failure streak, tier events and the warning e-mail. The
 * route only maps an outcome to JSON.
 */

export type SignInOutcome =
  | { kind: "ok"; user: UserRow }
  | { kind: "ip-blocked"; retryAfter: number }
  | { kind: "account-locked"; retryAfter: number }
  | { kind: "rejected"; attempts: number };

export type SignInFailure = Exclude<SignInOutcome, { kind: "ok" }>;

export function signInError(outcome: SignInFailure): HttpError {
  switch (outcome.kind) {
    case "ip-blocked":
      return new HttpError(
        429,
        "IP_BLOCKED",
        `Too many failed attempts. Try again in ${outcome.retryAfter} seconds.`,
        { retryAfter: outcome.retryAfter }
      );
    case "account-locked":
      return new HttpError(
        423,
        "ACCOUNT_LOCKED",
        `Too many attempts. Try again in ${outcome.retryAfter} seconds.`,
        { retryAfter: outcome.retryAfter }
      );
    case "rejected":
      return new HttpError(
        401,
        "INVALID_CREDENTIALS",
        "Invalid username or password.",
        { attempts: outcome.attempts }
      );
  }
}

// A real hash for unknown emails so the response time does not reveal whether
// the account exists.
const dummyHashPromise = hashPassword(
  "tahanan-invalid-password-placeholder"
).catch(() => "");

/**
 * Counts one failure against the account, applies the seeded tier lock, logs
 * the tier event and — when `alert` is set — e-mails the owner. Shared by the
 * password sign-in and the security-question recovery flow so both progress
 * through the same streak.
 */
export async function recordFailedAttempt(input: {
  user: Pick<UserRow, "id" | "email" | "displayName">;
  req?: Request;
  identifier?: string;
  source: string;
  alert: boolean;
}): Promise<{ attempts: number; seconds: number }> {
  const updated = await query<{ failed_login_count: number }>(
    `UPDATE users
        SET failed_login_count = failed_login_count + 1,
            updated_at = now()
      WHERE id = $1
      RETURNING failed_login_count`,
    [input.user.id]
  );

  const attempts = updated.rows[0]?.failed_login_count ?? 1;
  const lock = lockoutFor(attempts);
  let seconds = 0;

  if (lock) {
    seconds = lock.seconds;
    await query(
      `UPDATE users
          SET locked_until = now() + ($1 || ' seconds')::interval
        WHERE id = $2`,
      [String(seconds), input.user.id]
    );
    await logAuthEvent({
      eventType: lock.event,
      userId: input.user.id,
      email: input.user.email,
      usernameTyped: input.identifier,
      req: input.req,
      details: { attempts, seconds, source: input.source }
    });
  }

  if (input.alert) {
    try {
      await sendFailedLoginAlert({
        to: input.user.email,
        name: input.user.displayName,
        attempts,
        seconds: seconds || undefined,
        ip: input.req?.ip,
        userAgent: input.req?.get("user-agent")
      });
      await logAuthEvent({
        eventType: "ALERT_EMAIL_SENT",
        userId: input.user.id,
        email: input.user.email,
        req: input.req,
        details: { kind: "failed_login", attempts, seconds }
      });
    } catch {
      await logAuthEvent({
        eventType: "ALERT_EMAIL_FAILED",
        userId: input.user.id,
        email: input.user.email,
        req: input.req,
        details: { kind: "failed_login", attempts }
      });
    }
  }

  return { attempts, seconds };
}

export async function attemptPasswordSignIn(
  input: { identifier: string; password: string },
  req?: Request
): Promise<SignInOutcome> {
  const ip = req?.ip;

  const blocked = await ipBlockSeconds(ip);
  if (blocked > 0) {
    await logAuthEvent({
      eventType: "IP_BLOCKED",
      email: input.identifier,
      usernameTyped: input.identifier,
      req,
      details: { seconds: blocked, source: "sign_in" }
    });
    return { kind: "ip-blocked", retryAfter: blocked };
  }

  const identifier = input.identifier.trim().toLowerCase();
  const result = await query<UserRow & { password_hash: string | null }>(
    `SELECT ${PASSWORD_COLUMNS}
       FROM users
      WHERE lower(username) = $1 OR lower(email) = $1`,
    [identifier]
  );
  const user = result.rows[0];

  if (!user || !user.password_hash) {
    await verifyPassword(input.password, await dummyHashPromise);
    await recordIpBlock(ip, input.identifier, req, "unknown_account");
    await logAuthEvent({
      eventType: "LOGIN_FAILED",
      email: identifier,
      usernameTyped: input.identifier,
      req,
      details: { reason: "unknown_or_passwordless" }
    });
    return { kind: "rejected", attempts: 0 };
  }

  if (user.locked_until) {
    const left = Math.ceil(
      (new Date(user.locked_until).getTime() - Date.now()) / 1000
    );
    if (left > 0) {
      await logAuthEvent({
        eventType: "LOGIN_BLOCKED",
        userId: user.id,
        email: user.email,
        usernameTyped: input.identifier,
        req,
        details: { seconds: left }
      });
      return { kind: "account-locked", retryAfter: left };
    }

    // The lock has run out, but the failure streak must survive it. The
    // handout's tiers are cumulative consecutive failures, so resetting the
    // counter here would trap every account on tier 1 forever. Only a
    // successful sign-in resets the streak.
    await query("UPDATE users SET locked_until = NULL WHERE id = $1", [
      user.id
    ]);
    user.locked_until = null;
  }

  const ok = await verifyPassword(input.password, user.password_hash);

  if (!ok) {
    const failure = await recordFailedAttempt({
      user,
      req,
      identifier: input.identifier,
      source: "sign_in",
      alert: true
    });
    await recordIpBlock(ip, input.identifier, req, "wrong_password");
    await logAuthEvent({
      eventType: "LOGIN_FAILED",
      userId: user.id,
      email: user.email,
      usernameTyped: input.identifier,
      req,
      details: { reason: "wrong_password", lockedFor: failure.seconds }
    });

    if (failure.seconds > 0) {
      return { kind: "account-locked", retryAfter: failure.seconds };
    }
    return { kind: "rejected", attempts: failure.attempts };
  }

  await query(
    `UPDATE users
        SET failed_login_count = 0,
            locked_until = NULL,
            last_login_at = now(),
            updated_at = now()
      WHERE id = $1`,
    [user.id]
  );
  await clearIpFailures(ip);

  const refreshed = await query<UserRow>(
    `SELECT ${USER_COLUMNS} FROM users WHERE id = $1`,
    [user.id]
  );

  return { kind: "ok", user: refreshed.rows[0] };
}
