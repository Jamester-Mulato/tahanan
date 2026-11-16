import { pool, query } from "../config/db";

export async function listTenants(boardingHouseId: string) {
  const result = await query(
    `
    SELECT
      t.id,
      t.full_name AS "fullName",
      t.email,
      t.phone,
      a.user_id AS "userId",
      u.email AS "accountEmail",
      r.room_number AS "roomNumber",
      r.id AS "roomId",
      COALESCE(tms.status::text, 'paid') AS "paymentStatus"
    FROM tenants t
    LEFT JOIN tenant_account_associations a
      ON a.tenant_id = t.id
     AND a.boarding_house_id = t.boarding_house_id
    LEFT JOIN users u ON u.id = a.user_id
    LEFT JOIN tenant_room_assignments tra
      ON tra.tenant_id = t.id
     AND tra.ended_at IS NULL
    LEFT JOIN rooms r ON r.id = tra.room_id
    LEFT JOIN tenant_monthly_statuses tms
      ON tms.tenant_id = t.id
     AND tms.boarding_house_id = t.boarding_house_id
     AND tms.month_start = date_trunc('month', now())::date
    WHERE t.boarding_house_id = $1
      AND t.is_active = TRUE
    ORDER BY t.full_name
    `,
    [boardingHouseId]
  );

  return result.rows;
}

export async function listUnassignedAccounts(boardingHouseId: string) {
  const result = await query(
    `
    SELECT
      membership_id AS "membershipId",
      user_id AS "userId",
      email,
      display_name AS "displayName",
      avatar_url AS "avatarUrl",
      joined_at AS "joinedAt"
    FROM v_unassigned_accounts
    WHERE boarding_house_id = $1
    ORDER BY joined_at DESC
    `,
    [boardingHouseId]
  );

  return result.rows;
}

export async function createTenant(
  boardingHouseId: string,
  fullName: string,
  email?: string,
  phone?: string
) {
  const result = await query(
    `
    INSERT INTO tenants (
      boarding_house_id, full_name, email, phone
    )
    VALUES ($1, $2, NULLIF(lower($3), ''), NULLIF($4, ''))
    RETURNING
      id,
      full_name AS "fullName",
      email,
      phone
    `,
    [boardingHouseId, fullName.trim(), email ?? "", phone ?? ""]
  );

  return result.rows[0];
}

export async function associateAccount(
  boardingHouseId: string,
  tenantId: string,
  userId: string,
  associatedBy: string,
  roomId?: string
) {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const existingAssociation = await client.query(
      `
      SELECT 1
      FROM tenant_account_associations
      WHERE boarding_house_id = $1
        AND user_id = $2
      LIMIT 1
      `,
      [boardingHouseId, userId]
    );

    if ((existingAssociation.rowCount ?? 0) > 0) {
      throw new Error("This Google account is already associated with a tenant.");
    }

    await client.query(
      `
      INSERT INTO tenant_account_associations (
        boarding_house_id, tenant_id, user_id, associated_by
      )
      VALUES ($1, $2, $3, $4)
      `,
      [boardingHouseId, tenantId, userId, associatedBy]
    );

    if (roomId) {
      await client.query(
        `
        INSERT INTO tenant_room_assignments (
          tenant_id, room_id, assigned_by
        )
        VALUES ($1, $2, $3)
        `,
        [tenantId, roomId, associatedBy]
      );
    }

    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function removeMember(
  boardingHouseId: string,
  targetUserId: string,
  removedBy: string
) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const result = await client.query(
      `
      UPDATE boarding_house_memberships
      SET
        status = 'removed',
        removed_at = NOW(),
        removed_by = $3
      WHERE boarding_house_id = $1
        AND user_id = $2
        AND role = 'tenant'
        AND status = 'active'
      RETURNING id
      `,
      [boardingHouseId, targetUserId, removedBy]
    );

    if (result.rowCount === 0) {
      await client.query("ROLLBACK");
      return false;
    }

    const assocRes = await client.query<{ tenant_id: string }>(
      `
      SELECT tenant_id
      FROM tenant_account_associations
      WHERE boarding_house_id = $1 AND user_id = $2
      `,
      [boardingHouseId, targetUserId]
    );

    for (const row of assocRes.rows) {
      await client.query(
        `
        UPDATE tenant_room_assignments
        SET ended_at = NOW()
        WHERE tenant_id = $1 AND ended_at IS NULL
        `,
        [row.tenant_id]
      );
      await client.query(
        `
        DELETE FROM tenant_account_associations
        WHERE boarding_house_id = $1 AND tenant_id = $2
        `,
        [boardingHouseId, row.tenant_id]
      );
      await client.query(
        `
        UPDATE tenants
        SET is_active = FALSE
        WHERE id = $1 AND boarding_house_id = $2
        `,
        [row.tenant_id, boardingHouseId]
      );
    }

    await client.query("COMMIT");
    return true;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function removeTenant(
  boardingHouseId: string,
  tenantId: string,
  removedBy: string
) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const assocRes = await client.query<{ user_id: string }>(
      `
      SELECT user_id
      FROM tenant_account_associations
      WHERE boarding_house_id = $1 AND tenant_id = $2
      `,
      [boardingHouseId, tenantId]
    );

    for (const row of assocRes.rows) {
      await client.query(
        `
        UPDATE boarding_house_memberships
        SET
          status = 'removed',
          removed_at = NOW(),
          removed_by = $3
        WHERE boarding_house_id = $1
          AND user_id = $2
          AND role = 'tenant'
          AND status = 'active'
        `,
        [boardingHouseId, row.user_id, removedBy]
      );
      await client.query(
        `
        DELETE FROM tenant_account_associations
        WHERE boarding_house_id = $1 AND tenant_id = $2
        `,
        [boardingHouseId, tenantId]
      );
    }

    await client.query(
      `
      UPDATE tenant_room_assignments
      SET ended_at = NOW()
      WHERE tenant_id = $1 AND ended_at IS NULL
      `,
      [tenantId]
    );

    const tenantRes = await client.query(
      `
      UPDATE tenants
      SET is_active = FALSE
      WHERE id = $1 AND boarding_house_id = $2
      RETURNING id
      `,
      [tenantId, boardingHouseId]
    );

    await client.query("COMMIT");
    return (tenantRes.rowCount ?? 0) > 0;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

