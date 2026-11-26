import type { Request } from "express";
import { query } from "../config/db";
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
  passwordProblem as passwordPolicyProblem,
  usernameProblem as usernamePolicyProblem
} from "./credential-policy";
import { revokePasswordResetTokens } from "./password-reset.service";
import {
  sendPasswordChangedAlert
} from "./mail.service";
import { PASSWORD_COLUMNS, USER_COLUMNS, type UserRow } from "./user-record";

export interface PublicUser {
  id: string;
  username: string | null;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  isAdmin: boolean;
}

interface GoogleCredential {
  idToken?: string;
  accessToken?: string;
}

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
  return usernamePolicyProblem(username);
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
  return passwordPolicyProblem(password);
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
