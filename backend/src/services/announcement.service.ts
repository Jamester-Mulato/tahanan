import { query } from "../config/db";

export async function listAnnouncements(boardingHouseId: string) {
  const result = await query(
    `
    SELECT
      a.id,
      a.title,
      a.message,
      a.author_user_id AS "authorUserId",
      u.display_name AS "authorName",
      a.published_at AS "publishedAt"
    FROM announcements a
    JOIN users u ON u.id = a.author_user_id
    WHERE a.boarding_house_id = $1
      AND a.status = 'published'
    ORDER BY a.published_at DESC
    `,
    [boardingHouseId]
  );

  return result.rows;
}

export async function createAnnouncement(
  boardingHouseId: string,
  authorUserId: string,
  title: string,
  message: string
) {
  const result = await query(
    `
    INSERT INTO announcements (
      boarding_house_id,
      author_user_id,
      title,
      message,
      status,
      published_at
    )
    VALUES ($1, $2, $3, $4, 'published', NOW())
    RETURNING
      id,
      title,
      message,
      published_at AS "publishedAt"
    `,
    [boardingHouseId, authorUserId, title.trim(), message.trim()]
  );

  return result.rows[0];
}

export async function updateAnnouncement(
  id: string,
  boardingHouseId: string,
  title: string,
  message: string
) {
  const result = await query(
    `
    UPDATE announcements
    SET
      title = $3,
      message = $4,
      updated_at = NOW()
    WHERE id = $1
      AND boarding_house_id = $2
    RETURNING
      id,
      title,
      message,
      published_at AS "publishedAt"
    `,
    [id, boardingHouseId, title.trim(), message.trim()]
  );

  return result.rows[0] ?? null;
}

export async function deleteAnnouncement(id: string, boardingHouseId: string) {
  const result = await query(
    `
    DELETE FROM announcements
    WHERE id = $1
      AND boarding_house_id = $2
    `,
    [id, boardingHouseId]
  );

  return (result.rowCount ?? 0) > 0;
}
