import crypto from "node:crypto";
import type { Request } from "express";
import { query } from "../config/db";
import { env } from "../config/env";
import { signAccessToken } from "../utils/auth-token";
import {
  verifyGoogleAccessToken,
  verifyGoogleIdToken
} from "./google-auth.service";
import { hashPassword, verifyPassword } from "../utils/password";
import { HttpError } from "../utils/http-error";
import { logAuthEvent } from "./auth-events.service";
import {
  createRefreshToken,
  revokeAllRefreshTokens,
  rotateRefreshToken
} from "./refresh-token.service";
import {
  createPasswordResetToken,
  consumePasswordResetToken,
  logDevelopmentResetToken,
  passwordResetTtlMinutes,
  revokePasswordResetTokens
} from "./password-reset.service";
import {
  sendLockoutAlert,
  sendPasswordChangedAlert,
  sendPasswordResetCode
} from "./mail.service";
import {
  clearIpFailures,
  ipBlockSeconds,
  recordIpFailure
} from "./throttle.service";

export interface PublicUser {
  id: string;
  username: string | null;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  isAdmin: boolean;
}

interface UserRow {
  id: string;
  username?: string | null;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  isAdmin: boolean;
  password_hash?: string | null;
  token_version: number;
  status: string;
  failed_login_count?: number;
  locked_until?: string | null;
}

interface GoogleCredential {
  idToken?: string;
  accessToken?: string;
}

const USER_COLUMNS = `id, username, email, display_name AS "displayName",
  avatar_url AS "avatarUrl", is_admin AS "isAdmin", token_version, status`;

const PASSWORD_COLUMNS = `${USER_COLUMNS}, password_hash,
  failed_login_count, locked_until`;

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "23505"
  );
}

function publicUser(user: UserRow): PublicUser {
  return {
    id: user.id,
    username: user.username ?? null,
    email: user.email,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
    isAdmin: Boolean(user.isAdmin)
  };
}

export function usernameProblem(username: string): string | null {
  if (username.length < 7) return "Username must be at least 7 characters.";
  if (username.length > 16) return "Username must be at most 16 characters.";
  if (!/^[A-Za-z][A-Za-z0-9]*$/.test(username)) {
    return "Username must start with a letter and use letters and digits only.";
  }
  return null;
}

export async function usernameAvailable(username: string): Promise<boolean> {
  const value = username.trim();
  if (usernameProblem(value)) return false;
  const taken = await query("SELECT 1 FROM users WHERE lower(username) = lower($1)", [value]);
  return (taken.rowCount ?? 0) === 0;
}

async function issueSession(user: UserRow, req?: Request) {
  const accessToken = signAccessToken({
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    tokenVersion: user.token_version
  });
  const refresh = await createRefreshToken(user.id, req);

  // A new session starts the idle clock. Without this, an account whose last
  // request was more than IDLE_TIMEOUT_SECONDS ago would be rejected as idle
  // on the very first authenticated call after signing in.
  await query("UPDATE users SET last_activity_at = now() WHERE id = $1", [
    user.id
  ]);

  return {
    accessToken,
    refreshToken: refresh.refreshToken,
    refreshExpiresAt: refresh.refreshExpiresAt,
    user: publicUser(user)
  };
}

function passwordProblem(password: string): string | null {
  if (password.length < 9) {
    return "Password must be at least 9 characters.";
  }
  if (password.length > 64) {
    return "Password must be at most 64 characters.";
  }
  if (!/[A-Z]/.test(password) || !/\d/.test(password)) {
    return "Password must include an uppercase letter and a number.";
  }
  return null;
}

export async function assertPasswordNotReused(userId: string, password: string) {
  const history = await query<{ password_hash: string }>(
    `SELECT password_hash
       FROM password_history
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT 3`,
    [userId]
  );

  for (const row of history.rows) {
    if (await verifyPassword(password, row.password_hash)) {
      throw new HttpError(
        400,
        "PASSWORD_REUSED",
        "You cannot reuse a recent password."
      );
    }
  }
}

export async function recordPasswordHistory(userId: string, passwordHash: string) {
  await query(
    "INSERT INTO password_history (user_id, password_hash) VALUES ($1, $2)",
    [userId, passwordHash]
  );
  await query(
    `DELETE FROM password_history
      WHERE user_id = $1
        AND id NOT IN (
          SELECT id FROM password_history
           WHERE user_id = $1
           ORDER BY created_at DESC
           LIMIT 3
        )`,
    [userId]
  );
}

function lockoutSeconds(count: number): number | null {
  if (count === 3) return env.LOCKOUT_TIER1_SECONDS;
  if (count === 6) return env.LOCKOUT_TIER2_SECONDS;
  if (count >= 9) return env.LOCKOUT_TIER3_SECONDS;
  return null;
}

/**
 * Counts one failed attempt for the IP and, when the seeded threshold is
 * crossed, writes `IP_BLOCKED` and persists the block. Returns the block
 * duration in seconds (0 when the IP is still below the threshold).
 */
async function noteIpFailure(
  ip: string | undefined,
  identifier: string,
  req?: Request
): Promise<number> {
  const seconds = await recordIpFailure(ip);
  if (seconds > 0) {
    await logAuthEvent({
      eventType: "IP_BLOCKED",
      email: identifier,
      usernameTyped: identifier,
      req,
      details: { seconds, threshold: env.IP_BLOCK_THRESHOLD, ip }
    });
  }
  return seconds;
}

async function registerFailedAttempt(
  user: UserRow,
  req?: Request
): Promise<number> {  const updated = await query<{ failed_login_count: number }>(
    `UPDATE users
        SET failed_login_count = failed_login_count + 1,
            updated_at = now()
      WHERE id = $1
      RETURNING failed_login_count`,
    [user.id]
  );

  const count = updated.rows[0]?.failed_login_count ?? 1;
  const seconds = lockoutSeconds(count);

  if (seconds) {
    await query(
      `UPDATE users
          SET locked_until = now() + ($1 || ' seconds')::interval
        WHERE id = $2`,
      [String(seconds), user.id]
    );

    // One alert per tier, never once per attempt (handout 9). Failures past
    // nine still extend the tier-3 lock, but they do not send another e-mail.
    const atTierBoundary = count === 3 || count === 6 || count === 9;
    if (!atTierBoundary) return seconds;

    await logAuthEvent({
      eventType:
        count >= 9
          ? "LOCKOUT_TIER_3"
          : count >= 6
            ? "LOCKOUT_TIER_2"
            : "LOCKOUT_TIER_1",
      userId: user.id,
      email: user.email,
      req,
      details: { attempts: count, seconds }
    });
    try {
      await sendLockoutAlert({
        to: user.email,
        name: user.displayName,
        attempts: count,
        seconds,
        ip: req?.ip,
        userAgent: req?.get("user-agent")
      });
      await logAuthEvent({
        eventType: "ALERT_EMAIL_SENT",
        userId: user.id,
        email: user.email,
        req,
        details: { kind: "lockout", attempts: count, seconds }
      });
    } catch (error) {
      await logAuthEvent({
        eventType: "ALERT_EMAIL_FAILED",
        userId: user.id,
        email: user.email,
        req,
        details: { kind: "lockout" }
      });
    }
    return seconds;
  }

  return 0;
}

// A real hash for unknown emails so the response time does not reveal whether
// the account exists.
const dummyHashPromise = hashPassword(
  "tahanan-invalid-password-placeholder"
).catch(() => "");

export async function registerWithPassword(
  input: {
    displayName: string;
    email: string;
    password: string;
    username: string;
    privacyConsent?: boolean;
  },
  req?: Request
) {
  if (input.privacyConsent !== true) {
    throw new HttpError(
      400,
      "PRIVACY_CONSENT_REQUIRED",
      "Please agree to the Privacy Notice to register."
    );
  }

  const email = input.email.trim().toLowerCase();
  const displayName = input.displayName.trim();
  const username = input.username.trim();
  const problem = passwordProblem(input.password);
  if (problem) throw new HttpError(400, "WEAK_PASSWORD", problem);

  const usernameIssue = usernameProblem(username);
  if (usernameIssue) throw new HttpError(400, "INVALID_USERNAME", usernameIssue);

  const usernameTaken = await query<{ id: string }>(
    "SELECT id FROM users WHERE lower(username) = lower($1)",
    [username]
  );
  if ((usernameTaken.rowCount ?? 0) > 0) {
    throw new HttpError(409, "USERNAME_TAKEN", "That username is already taken.");
  }

  const existing = await query<{
    id: string;
    password_hash: string | null;
  }>("SELECT id, password_hash FROM users WHERE lower(email) = $1", [email]);

  const passwordHash = await hashPassword(input.password);

  if (existing.rowCount && existing.rowCount > 0) {
    const row = existing.rows[0];

    if (row.password_hash) {
      throw new HttpError(
        409,
        "EMAIL_IN_USE",
        "An account with this email already exists. Log in instead."
      );
    }

    // A Google-era account without a password can finish registration.
    const updated = await query<UserRow>(
      `UPDATE users
          SET display_name = $1,
              username = $2,
              password_hash = $3,
              password_changed_at = now(),
              privacy_consent_at = COALESCE(privacy_consent_at, now()),
              failed_login_count = 0,
              locked_until = NULL,
              token_version = token_version + 1,
              updated_at = now()
        WHERE id = $4
        RETURNING ${USER_COLUMNS}`,
      [displayName, username, passwordHash, row.id]
    );

    await recordPasswordHistory(row.id, passwordHash);
    await logAuthEvent({
      eventType: "REGISTRATION_COMPLETED",
      userId: row.id,
      email,
      req
    });

    return issueSession(updated.rows[0], req);
  }

  try {
    const inserted = await query<UserRow>(
      `INSERT INTO users (
         auth_provider, auth_provider_uid, email, display_name, username,
         password_hash, password_changed_at, privacy_consent_at
       )
       VALUES ('password', $1, $2, $3, $4, $5, now(), now())
       RETURNING ${USER_COLUMNS}`,
      [email, email, displayName, username, passwordHash]
    );

    const user = inserted.rows[0];
    await recordPasswordHistory(user.id, passwordHash);
    await logAuthEvent({
      eventType: "REGISTERED",
      userId: user.id,
      email,
      req
    });

    return issueSession(user, req);
  } catch (error) {
    if (isUniqueViolation(error)) {
      const constraint = (error as { constraint?: string }).constraint;
      if (constraint === "uq_user_username_ci") {
        throw new HttpError(409, "USERNAME_TAKEN", "That username is already taken.");
      }
      throw new HttpError(
        409,
        "EMAIL_IN_USE",
        "An account with this email already exists. Log in instead."
      );
    }
    throw error;
  }
}

export async function authenticatePassword(
  input: { identifier: string; password: string },
  req?: Request
) {
  const ip = req?.ip;
  const blocked = await ipBlockSeconds(ip);
  if (blocked > 0) {
    await logAuthEvent({
      eventType: "IP_BLOCKED",
      email: input.identifier,
      usernameTyped: input.identifier,
      req,
      details: { seconds: blocked }
    });
    throw new HttpError(
      429,
      "IP_BLOCKED",
      `Too many failed attempts. Try again in ${blocked} seconds.`
    );
  }

  const email = input.identifier.trim().toLowerCase();
  const result = await query<UserRow & { password_hash: string | null }>(
    `SELECT ${PASSWORD_COLUMNS}
       FROM users
      WHERE lower(username) = $1 OR lower(email) = $1`,
    [email]
  );
  const user = result.rows[0];

  if (!user || !user.password_hash) {
    await verifyPassword(input.password, await dummyHashPromise);
    await noteIpFailure(ip, input.identifier, req);
    await logAuthEvent({
      eventType: "LOGIN_FAILED",
      email,
      usernameTyped: input.identifier,
      req,
      details: { reason: "unknown_or_passwordless" }
    });
    throw new HttpError(
      401,
      "INVALID_CREDENTIALS",
      "Invalid username or password."
    );
  }

  if (user.locked_until) {
    const left = Math.ceil(
      (new Date(user.locked_until).getTime() - Date.now()) / 1000
    );
    if (left > 0) {
      await logAuthEvent({
        eventType: "LOGIN_BLOCKED",
        userId: user.id,
        email,
        usernameTyped: input.identifier,
        req,
        details: { seconds: left }
      });
      throw new HttpError(
        423,
        "ACCOUNT_LOCKED",
        `Too many attempts. Try again in ${left} seconds.`,
        { retryAfter: left }
      );
    }

    // The lock has run out, but the failure streak must survive it. The
    // handout's tiers are cumulative consecutive failures (3 -> 15 s,
    // 6 -> 30 s, 9 -> 60 s), so resetting the counter here would trap every
    // account on tier 1 forever. Only a successful sign-in resets the streak.
    await query(
      `UPDATE users
          SET locked_until = NULL
        WHERE id = $1`,
      [user.id]
    );
    user.locked_until = null;
  }

  const ok = await verifyPassword(input.password, user.password_hash);

  if (!ok) {
    const lockedFor = await registerFailedAttempt(user, req);
    await noteIpFailure(ip, input.identifier, req);
    await logAuthEvent({
      eventType: "LOGIN_FAILED",
      userId: user.id,
      email,
      usernameTyped: input.identifier,
      req,
      details: { reason: "wrong_password", lockedFor }
    });

    if (lockedFor > 0) {
      throw new HttpError(
        423,
        "ACCOUNT_LOCKED",
        `Too many attempts. Try again in ${lockedFor} seconds.`,
        { retryAfter: lockedFor }
      );
    }

    throw new HttpError(
      401,
      "INVALID_CREDENTIALS",
      "Invalid username or password."
    );
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

  return refreshed.rows[0];
}

/** Issues the session only after the second factor has passed. */
export async function completeLogin(userId: string, req?: Request) {
  const refreshed = await query<UserRow>(
    `SELECT ${USER_COLUMNS} FROM users WHERE id = $1`,
    [userId]
  );
  const user = refreshed.rows[0];
  if (!user) {
    throw new HttpError(401, "INVALID_CREDENTIALS", "Invalid username or password.");
  }

  await logAuthEvent({
    eventType: "LOGIN_SUCCESS",
    userId: user.id,
    email: user.email,
    req
  });

  return issueSession(user, req);
}

// Kept for the Google-native endpoints and older clients.
export async function loginWithPassword(
  input: { email: string; password: string },
  req?: Request
) {
  const user = await authenticatePassword(
    { identifier: input.email, password: input.password },
    req
  );
  return completeLogin(user.id, req);
}

export async function refreshSession(refreshToken: string, req?: Request) {
  const rotated = await rotateRefreshToken(refreshToken, req);
  if (!rotated) {
    throw new HttpError(
      401,
      "INVALID_REFRESH_TOKEN",
      "Your session has expired. Please sign in again."
    );
  }

  const result = await query<UserRow>(
    `SELECT ${USER_COLUMNS} FROM users WHERE id = $1`,
    [rotated.userId]
  );
  const user = result.rows[0];

  if (!user || user.status !== "active") {
    throw new HttpError(
      401,
      "INVALID_REFRESH_TOKEN",
      "Your session is no longer valid. Please sign in again."
    );
  }

  const accessToken = signAccessToken({
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    tokenVersion: user.token_version
  });

  await logAuthEvent({
    eventType: "SESSION_REFRESHED",
    userId: user.id,
    email: user.email,
    req
  });

  return {
    accessToken,
    refreshToken: rotated.refreshToken,
    refreshExpiresAt: rotated.refreshExpiresAt,
    user: publicUser(user)
  };
}

export async function logoutAll(userId: string, req?: Request) {
  await query(
    "UPDATE users SET token_version = token_version + 1 WHERE id = $1",
    [userId]
  );
  await revokeAllRefreshTokens(userId);
  await logAuthEvent({
    eventType: "LOGGED_OUT_ALL",
    userId,
    req
  });
}

export async function changePassword(
  userId: string,
  currentPassword: string,
  nextPassword: string,
  req?: Request
) {
  const problem = passwordProblem(nextPassword);
  if (problem) throw new HttpError(400, "WEAK_PASSWORD", problem);

  const result = await query<{
    password_hash: string | null;
    email: string;
    displayName: string;
  }>(
    "SELECT password_hash, email, display_name AS \"displayName\" FROM users WHERE id = $1",
    [userId]
  );
  const user = result.rows[0];

  if (!user?.password_hash) {
    throw new HttpError(
      400,
      "NO_PASSWORD",
      "This account does not use a password."
    );
  }

  if (!(await verifyPassword(currentPassword, user.password_hash))) {
    await logAuthEvent({
      eventType: "PASSWORD_CHANGE_FAILED",
      userId,
      email: user.email,
      req
    });
    throw new HttpError(
      401,
      "INVALID_CREDENTIALS",
      "The current password is incorrect."
    );
  }

  await assertPasswordNotReused(userId, nextPassword);

  const nextHash = await hashPassword(nextPassword);
  await query(
    `UPDATE users
        SET password_hash = $1,
            password_changed_at = now(),
            token_version = token_version + 1,
            failed_login_count = 0,
            locked_until = NULL,
            updated_at = now()
      WHERE id = $2`,
    [nextHash, userId]
  );

  await recordPasswordHistory(userId, nextHash);
  await revokeAllRefreshTokens(userId);
  await revokePasswordResetTokens(userId);

  await logAuthEvent({
    eventType: "PASSWORD_CHANGED",
    userId,
    email: user.email,
    req
  });

  try {
    await sendPasswordChangedAlert({
      to: user.email,
      name: user.displayName,
      ip: req?.ip,
      userAgent: req?.get("user-agent")
    });
    await logAuthEvent({
      eventType: "ALERT_EMAIL_SENT",
      userId,
      email: user.email,
      req,
      details: { kind: "password_changed" }
    });
  } catch (_) {
    await logAuthEvent({
      eventType: "ALERT_EMAIL_FAILED",
      userId,
      email: user.email,
      req,
      details: { kind: "password_changed" }
    });
  }
}

export async function requestPasswordReset(email: string, req?: Request) {
  const normalized = email.trim().toLowerCase();
  const result = await query<{
    id: string;
    email: string;
    displayName: string;
  }>(
    `SELECT id, email, display_name AS "displayName"
       FROM users
      WHERE lower(email) = $1
        AND password_hash IS NOT NULL
        AND status = 'active'`,
    [normalized]
  );
  const user = result.rows[0];

  await logAuthEvent({
    eventType: "PASSWORD_RESET_REQUESTED",
    userId: user?.id ?? null,
    email: normalized,
    req,
    details: { knownUser: Boolean(user) }
  });

  if (!user) return;

  const reset = await createPasswordResetToken(user.id);
  logDevelopmentResetToken(user.email, reset.token);

  try {
    await sendPasswordResetCode({
      to: user.email,
      name: user.displayName,
      code: reset.token,
      expiresMinutes: passwordResetTtlMinutes()
    });
    await logAuthEvent({
      eventType: "PASSWORD_RESET_EMAIL_SENT",
      userId: user.id,
      email: user.email,
      req
    });
  } catch (_) {
    await logAuthEvent({
      eventType: "PASSWORD_RESET_EMAIL_FAILED",
      userId: user.id,
      email: user.email,
      req
    });
  }
}

export async function resetPassword(
  token: string,
  nextPassword: string,
  req?: Request
) {
  const problem = passwordProblem(nextPassword);
  if (problem) throw new HttpError(400, "WEAK_PASSWORD", problem);

  const userId = await consumePasswordResetToken(token);
  if (!userId) {
    throw new HttpError(
      400,
      "INVALID_RESET_TOKEN",
      "That reset link is invalid or has expired."
    );
  }

  await assertPasswordNotReused(userId, nextPassword);

  const nextHash = await hashPassword(nextPassword);
  const result = await query<{ email: string; displayName: string }>(
    `UPDATE users
        SET password_hash = $1,
            password_changed_at = now(),
            token_version = token_version + 1,
            failed_login_count = 0,
            locked_until = NULL,
            updated_at = now()
      WHERE id = $2
      RETURNING email, display_name AS "displayName"`,
    [nextHash, userId]
  );

  await recordPasswordHistory(userId, nextHash);
  await revokeAllRefreshTokens(userId);
  await logAuthEvent({
    eventType: "PASSWORD_RESET_COMPLETED",
    userId,
    email: result.rows[0]?.email ?? null,
    req
  });

  const changed = result.rows[0];
  if (changed) {
    try {
      await sendPasswordChangedAlert({
        to: changed.email,
        name: changed.displayName,
        ip: req?.ip,
        userAgent: req?.get("user-agent")
      });
    } catch (_) {
      // The reset already succeeded; the alert is best-effort.
    }
  }
}

async function resolveGoogleIdentity(credential: GoogleCredential) {
  try {
    if (credential.idToken) {
      return await verifyGoogleIdToken(credential.idToken);
    }
    if (credential.accessToken) {
      return await verifyGoogleAccessToken(credential.accessToken);
    }
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(
      401,
      "INVALID_GOOGLE_TOKEN",
      "Google sign-in could not be verified. Please try again."
    );
  }

  throw new HttpError(
    400,
    "MISSING_CREDENTIAL",
    "A Google credential is required."
  );
}

export async function registerWithGoogle(
  input: GoogleCredential & { password: string },
  req?: Request
) {
  const identity = await resolveGoogleIdentity(input);
  const email = identity.email.trim().toLowerCase();
  const problem = passwordProblem(input.password);
  if (problem) throw new HttpError(400, "WEAK_PASSWORD", problem);

  const passwordHash = await hashPassword(input.password);
  const existing = await query<{
    id: string;
    auth_provider: string;
    password_hash: string | null;
  }>(
    `SELECT id, auth_provider, password_hash
       FROM users
      WHERE lower(email) = $1`,
    [email]
  );

  if (existing.rowCount && existing.rowCount > 0) {
    const row = existing.rows[0];

    if (row.auth_provider !== "google") {
      throw new HttpError(
        409,
        "EMAIL_IN_USE",
        "This email is already registered. Log in instead."
      );
    }

    if (row.password_hash) {
      throw new HttpError(
        409,
        "ALREADY_REGISTERED",
        "This Google account already signed up. Log in instead."
      );
    }

    const updated = await query<UserRow>(
      `UPDATE users
          SET auth_provider_uid = $1,
              email = $2,
              display_name = $3,
              avatar_url = $4,
              password_hash = $5,
              password_changed_at = now(),
              token_version = token_version + 1,
              updated_at = now()
        WHERE id = $6
        RETURNING ${USER_COLUMNS}`,
      [
        identity.subject,
        email,
        identity.displayName,
        identity.avatarUrl ?? null,
        passwordHash,
        row.id
      ]
    );

    await recordPasswordHistory(row.id, passwordHash);
    return issueSession(updated.rows[0], req);
  }

  try {
    const inserted = await query<UserRow>(
      `INSERT INTO users (
         auth_provider, auth_provider_uid, email, display_name,
         avatar_url, password_hash, password_changed_at
       )
       VALUES ('google', $1, $2, $3, $4, $5, now())
       RETURNING ${USER_COLUMNS}`,
      [
        identity.subject,
        email,
        identity.displayName,
        identity.avatarUrl ?? null,
        passwordHash
      ]
    );

    await recordPasswordHistory(inserted.rows[0].id, passwordHash);
    return issueSession(inserted.rows[0], req);
  } catch (error) {
    if (isUniqueViolation(error)) {
      throw new HttpError(
        409,
        "ALREADY_REGISTERED",
        "This Google account already signed up. Log in instead."
      );
    }
    throw error;
  }
}

export async function loginWithGoogle(
  input: GoogleCredential,
  req?: Request
) {
  const identity = await resolveGoogleIdentity(input);
  const email = identity.email.trim().toLowerCase();

  const result = await query<UserRow & { password_hash: string | null }>(
    `SELECT ${PASSWORD_COLUMNS}
       FROM users
      WHERE lower(email) = $1
         OR (auth_provider = 'google' AND auth_provider_uid = $2)`,
    [email, identity.subject]
  );
  const user = result.rows[0];

  if (!user) {
    throw new HttpError(
      404,
      "ACCOUNT_NOT_REGISTERED",
      "No account uses this Google email yet. Sign up first."
    );
  }

  if (!user.password_hash) {
    throw new HttpError(
      409,
      "SIGNUP_INCOMPLETE",
      "This Google account still needs a password. Finish signing up first."
    );
  }

  await logAuthEvent({
    eventType: "LOGIN_SUCCESS",
    userId: user.id,
    email: user.email,
    req,
    details: { provider: "google" }
  });

  return issueSession(user, req);
}
