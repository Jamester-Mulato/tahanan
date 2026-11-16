import { query } from "../config/db";

export async function listRooms(boardingHouseId: string) {
  const result = await query(
    `
    SELECT
      room_id AS id,
      room_number AS "roomNumber",
      capacity,
      occupied_slots AS "occupiedSlots",
      available_slots AS "availableSlots",
      occupancy_status AS "occupancyStatus"
    FROM v_room_occupancy
    WHERE boarding_house_id = $1
    ORDER BY room_number
    `,
    [boardingHouseId]
  );

  return result.rows;
}

export async function createRoom(
  boardingHouseId: string,
  roomNumber: string,
  capacity: number
) {
  const result = await query(
    `
    INSERT INTO rooms (boarding_house_id, room_number, capacity)
    VALUES ($1, $2, $3)
    RETURNING
      id,
      room_number AS "roomNumber",
      capacity
    `,
    [boardingHouseId, roomNumber.trim(), capacity]
  );

  return result.rows[0];
}

export async function updateRoom(
  roomId: string,
  roomNumber: string | undefined,
  capacity: number | undefined,
  boardingHouseId: string
) {
  const result = await query(
    `
    UPDATE rooms
    SET
      room_number = COALESCE($2, room_number),
      capacity = COALESCE($3, capacity)
    WHERE id = $1
      AND boarding_house_id = $4
      AND status = 'active'
    RETURNING
      id,
      room_number AS "roomNumber",
      capacity
    `,
    [roomId, roomNumber?.trim() ?? null, capacity ?? null, boardingHouseId]
  );

  return result.rows[0] ?? null;
}

export async function archiveRoom(roomId: string, boardingHouseId: string) {
  const activeAssignments = await query(
    `
    SELECT 1
    FROM tenant_room_assignments tra
    JOIN rooms r ON r.id = tra.room_id
    WHERE r.id = $1
      AND r.boarding_house_id = $2
      AND tra.ended_at IS NULL
    LIMIT 1
    `,
    [roomId, boardingHouseId]
  );

  if ((activeAssignments.rowCount ?? 0) > 0) {
    throw new Error("Room still has active tenants. Reassign them before archiving.");
  }

  const result = await query(
    `
    UPDATE rooms
    SET status = 'archived'
    WHERE id = $1
      AND boarding_house_id = $2
      AND status = 'active'
    `,
    [roomId, boardingHouseId]
  );

  return result.rowCount === 1;
}
