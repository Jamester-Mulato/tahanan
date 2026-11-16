import { pool, query } from "../config/db";
import { generateJoinKey, slugifyDomain } from "../utils/ids";

interface CreateHouseInput {
  name: string;
  rooms: Array<{ roomNumber: string; capacity: number }>;
  academicYear?: {
    name: string;
    startsOn: string;
    endsOn: string;
  };
}

export async function createBoardingHouse(
  ownerUserId: string,
  input: CreateHouseInput
) {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    let domain = slugifyDomain(input.name);
    const domainBase = domain;
    let suffix = 1;

    while (true) {
      const collision = await client.query(
        "SELECT 1 FROM boarding_houses WHERE domain = $1 LIMIT 1",
        [domain]
      );

      if ((collision.rowCount ?? 0) === 0) {
        break;
      }

      suffix += 1;
      domain = `${domainBase}-${suffix}`;
    }

    let joinKey = generateJoinKey();
    while (
      ((await client.query(
        "SELECT 1 FROM boarding_houses WHERE join_key = $1 LIMIT 1",
        [joinKey]
      )).rowCount ?? 0) !== 0
    ) {
      joinKey = generateJoinKey();
    }

    const houseResult = await client.query<{
      id: string;
      name: string;
      domain: string;
      join_key: string;
    }>(
      `
      INSERT INTO boarding_houses (
        owner_user_id, name, domain, join_key
      )
      VALUES ($1, $2, $3, $4)
      RETURNING id, name, domain, join_key
      `,
      [ownerUserId, input.name.trim(), domain, joinKey]
    );

    const house = houseResult.rows[0];

    await client.query(
      `
      INSERT INTO boarding_house_memberships (
        boarding_house_id, user_id, role
      )
      VALUES ($1, $2, 'owner')
      `,
      [house.id, ownerUserId]
    );

    for (const room of input.rooms) {
      await client.query(
        `
        INSERT INTO rooms (boarding_house_id, room_number, capacity)
        VALUES ($1, $2, $3)
        `,
        [house.id, room.roomNumber.trim(), room.capacity]
      );
    }

    if (input.academicYear) {
      await client.query(
        `
        INSERT INTO academic_years (
          boarding_house_id, name, starts_on, ends_on, is_active
        )
        VALUES ($1, $2, $3, $4, TRUE)
        `,
        [
          house.id,
          input.academicYear.name.trim(),
          input.academicYear.startsOn,
          input.academicYear.endsOn
        ]
      );
    }

    await client.query("COMMIT");

    return {
      id: house.id,
      name: house.name,
      domain: house.domain,
      joinKey: house.join_key
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function listMyBoardingHouses(userId: string) {
  const result = await query<{
    boardingHouseId: string;
    name: string;
    domain: string;
    joinKey: string;
    role: "owner" | "tenant";
    joinedAt: string;
    ownerName: string;
    ownerEmail: string;
    ownerAvatarUrl: string | null;
  }>(
    `
    SELECT
      bh.id AS "boardingHouseId",
      bh.name,
      bh.domain,
      bh.join_key AS "joinKey",
      m.role::text AS role,
      m.joined_at AS "joinedAt",
      u.display_name AS "ownerName",
      u.email AS "ownerEmail",
      u.avatar_url AS "ownerAvatarUrl"
    FROM boarding_house_memberships m
    JOIN boarding_houses bh ON bh.id = m.boarding_house_id
    JOIN users u ON u.id = bh.owner_user_id
    WHERE m.user_id = $1
      AND m.status = 'active'
      AND bh.is_active = TRUE
    ORDER BY m.joined_at DESC
    `,
    [userId]
  );

  return result.rows;
}

export async function listRemovedBoardingHouses(userId: string) {
  const result = await query<{
    boardingHouseId: string;
    name: string;
    domain: string;
    joinKey: string;
    removedAt: string;
    ownerName: string;
    ownerEmail: string;
  }>(
    `
    SELECT
      bh.id AS "boardingHouseId",
      bh.name,
      bh.domain,
      bh.join_key AS "joinKey",
      m.removed_at AS "removedAt",
      u.display_name AS "ownerName",
      u.email AS "ownerEmail"
    FROM boarding_house_memberships m
    JOIN boarding_houses bh ON bh.id = m.boarding_house_id
    JOIN users u ON u.id = bh.owner_user_id
    WHERE m.user_id = $1
      AND m.status = 'removed'
      AND bh.is_active = TRUE
    ORDER BY m.removed_at DESC
    LIMIT 5
    `,
    [userId]
  );

  return result.rows;
}


export async function joinBoardingHouse(userId: string, rawKeyOrDomain: string) {
  const value = rawKeyOrDomain.trim().toLowerCase();

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const houseResult = await client.query<{
      id: string;
      name: string;
      domain: string;
      join_key: string;
    }>(
      `
      SELECT id, name, domain, join_key
      FROM boarding_houses
      WHERE is_active = TRUE
        AND (lower(join_key) = $1 OR lower(domain) = $1)
      LIMIT 1
      `,
      [value]
    );

    const house = houseResult.rows[0];

    if (!house) {
      await client.query("ROLLBACK");
      return null;
    }

    const existing = await client.query<{
      id: string;
      role: "owner" | "tenant";
      status: "active" | "removed";
    }>(
      `
      SELECT id, role::text AS role, status::text AS status
      FROM boarding_house_memberships
      WHERE boarding_house_id = $1
        AND user_id = $2
      LIMIT 1
      `,
      [house.id, userId]
    );

    if ((existing.rowCount ?? 0) > 0) {
      const membership = existing.rows[0];

      if (membership.role === "owner") {
        await client.query("ROLLBACK");
        throw new Error("You already own this boarding house.");
      }

      await client.query(
        `
        UPDATE boarding_house_memberships
        SET status = 'active', removed_at = NULL, removed_by = NULL
        WHERE id = $1
        `,
        [membership.id]
      );
    } else {
      await client.query(
        `
        INSERT INTO boarding_house_memberships (
          boarding_house_id, user_id, role
        )
        VALUES ($1, $2, 'tenant')
        `,
        [house.id, userId]
      );
    }

    await client.query("COMMIT");

    return {
      id: house.id,
      name: house.name,
      domain: house.domain,
      joinKey: house.join_key,
      role: "tenant" as const
    };
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch {}
    throw error;
  } finally {
    client.release();
  }
}
