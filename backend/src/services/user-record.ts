/**
 * The row shape and column lists every session-producing module selects.
 * Kept separate from auth.service so the sign-in decision and the session
 * issuer can share them without importing each other.
 */

export interface UserRow {
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
  last_login_at?: string | null;
}

export const USER_COLUMNS = `id, username, email, display_name AS "displayName",
  avatar_url AS "avatarUrl", is_admin AS "isAdmin", token_version, status`;

export const PASSWORD_COLUMNS = `${USER_COLUMNS}, password_hash,
  failed_login_count, locked_until`;
