import type { Request } from "express";
import { pool, query } from "../config/db";
import { HttpError } from "../utils/http-error";
import { logAuthEvent } from "./auth-events.service";

/**
 * The privileged account operations the admin console performs. Both admin
 * routers call these, so the cascade and the session rules have one owner.
 */

/** Revokes every session and access token for an account. */
export async function logoutAllSessions(
  userId: string,
  req?: Request
): Promise<number> {
  await query(
    "UPDATE users SET token_version = token_version + 1, updated_at = now() WHERE id = $1",
    [userId]
  );
  const removed = await query(
    "DELETE FROM auth_refresh_tokens WHERE user_id = $1",
    [userId]
  );
  const sessions = removed.rowCount ?? 0;
  await logAuthEvent({
    eventType: "LOGGED_OUT_ALL",
    userId,
    req,
    details: { sessions, source: "admin" }
  });
  return sessions;
}

export interface DeletedAccount {
  username: string | null;
  email: string;
}

/**
 * Deletes an account and everything it owns. Kept here — next to the schema it
 * knows about — so a new owner-referencing table is added in one place.
 */
export async function deleteAccount(input: {
  userId: string;
  actorId: string;
}): Promise<DeletedAccount> {
  if (input.userId === input.actorId) {
    throw new HttpError(400, "SELF_DELETE", "You cannot delete your own account.");
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    // The audit trail is append-only by trigger; deletion is the one operation
    // that must remove the account's rows with it.
    await client.query(
      "ALTER TABLE auth_events DISABLE TRIGGER auth_events_no_change"
    );

    // Houses owned by the account (with their dependent rows).
    const owned = "bh.owner_user_id = $1";
    await client.query(
      `DELETE FROM tenant_room_assignments tra
        WHERE tra.room_id IN (
                SELECT r.id FROM rooms r JOIN boarding_houses bh ON bh.id = r.boarding_house_id
                 WHERE ${owned})
           OR tra.tenant_id IN (
                SELECT t.id FROM tenants t JOIN boarding_houses bh ON bh.id = t.boarding_house_id
                 WHERE ${owned})`,
      [input.userId]
    );
    await client.query(
      `DELETE FROM concerns c USING boarding_houses bh
        WHERE c.boarding_house_id = bh.id AND ${owned}`,
      [input.userId]
    );
    await client.query(
      `DELETE FROM announcements a USING boarding_houses bh
        WHERE a.boarding_house_id = bh.id AND ${owned}`,
      [input.userId]
    );
    await client.query(
      `DELETE FROM tenant_account_associations x USING boarding_houses bh
        WHERE x.boarding_house_id = bh.id AND ${owned}`,
      [input.userId]
    );
    await client.query(
      `DELETE FROM tenant_monthly_statuses s USING boarding_houses bh
        WHERE s.boarding_house_id = bh.id AND ${owned}`,
      [input.userId]
    );
    await client.query(
      `DELETE FROM academic_years y USING boarding_houses bh
        WHERE y.boarding_house_id = bh.id AND ${owned}`,
      [input.userId]
    );
    await client.query(
      `DELETE FROM tenants t USING boarding_houses bh
        WHERE t.boarding_house_id = bh.id AND ${owned}`,
      [input.userId]
    );
    await client.query(
      `DELETE FROM rooms r USING boarding_houses bh
        WHERE r.boarding_house_id = bh.id AND ${owned}`,
      [input.userId]
    );
    await client.query(
      `DELETE FROM boarding_house_memberships m USING boarding_houses bh
        WHERE m.boarding_house_id = bh.id AND ${owned}`,
      [input.userId]
    );
    await client.query("DELETE FROM boarding_houses WHERE owner_user_id = $1", [
      input.userId
    ]);

    // References in other houses: keep the data, hand it to the acting admin.
    await client.query("DELETE FROM announcements WHERE author_user_id = $1", [
      input.userId
    ]);
    await client.query(
      "UPDATE tenant_account_associations SET associated_by = $2 WHERE associated_by = $1",
      [input.userId, input.actorId]
    );
    await client.query(
      "UPDATE tenant_monthly_statuses SET updated_by = $2 WHERE updated_by = $1",
      [input.userId, input.actorId]
    );
    await client.query(
      "UPDATE tenant_room_assignments SET assigned_by = $2 WHERE assigned_by = $1",
      [input.userId, input.actorId]
    );
    await client.query(
      "UPDATE boarding_house_memberships SET removed_by = NULL WHERE removed_by = $1",
      [input.userId]
    );

    await client.query("DELETE FROM auth_events WHERE user_id = $1", [
      input.userId
    ]);
    const deleted = await client.query<DeletedAccount>(
      "DELETE FROM users WHERE id = $1 RETURNING username, email",
      [input.userId]
    );
    if (!deleted.rowCount) {
      throw new HttpError(404, "USER_NOT_FOUND", "Unknown user.");
    }

    await client.query(
      "ALTER TABLE auth_events ENABLE TRIGGER auth_events_no_change"
    );
    await client.query("COMMIT");
    return deleted.rows[0];
  } catch (error) {
    await client.query("ROLLBACK").catch(() => undefined);
    // The trigger must be restored even when the delete failed.
    await client
      .query("ALTER TABLE auth_events ENABLE TRIGGER auth_events_no_change")
      .catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
}
