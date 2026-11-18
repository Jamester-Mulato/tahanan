import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { query } from "../config/db";

export interface AttachmentInput {
  fileName?: string;
  mimeType?: string;
  dataBase64?: string;
  storagePath?: string;
  publicUrl?: string;
}

export async function saveAttachmentFile(
  concernId: string,
  fileName = "attachment.jpg",
  mimeType = "image/jpeg",
  dataBase64: string
) {
  const uploadsDir = path.resolve(process.cwd(), "uploads");
  await fs.mkdir(uploadsDir, { recursive: true });

  const cleanName = fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
  const uniquePrefix = `att_${Date.now()}_${crypto.randomBytes(4).toString("hex")}`;
  const diskFileName = `${uniquePrefix}_${cleanName}`;
  const filePath = path.join(uploadsDir, diskFileName);

  const cleanBase64 = dataBase64.replace(/^data:[^;]+;base64,/, "");
  const buffer = Buffer.from(cleanBase64, "base64");
  await fs.writeFile(filePath, buffer);

  const publicUrl = `/uploads/${diskFileName}`;
  return addAttachment(concernId, filePath, publicUrl, mimeType, fileName);
}

export async function listConcerns(
  boardingHouseId: string,
  ownTenantId?: string
) {
  const result = await query(
    `
    SELECT
      c.id,
      c.tenant_id AS "tenantId",
      t.full_name AS "tenantName",
      c.reported_room_id AS "reportedRoomId",
      r.room_number AS "roomNumber",
      c.category,
      c.subject,
      c.details,
      c.status,
      c.rating,
      c.owner_response AS "ownerResponse",
      c.responded_at AS "respondedAt",
      c.created_at AS "createdAt",
      c.updated_at AS "updatedAt",
      COALESCE(
        json_agg(
          json_build_object(
            'id', ca.id,
            'publicUrl', ca.public_url,
            'fileName', ca.file_name,
            'mimeType', ca.mime_type,
            'createdAt', ca.created_at
          )
        ) FILTER (WHERE ca.id IS NOT NULL),
        '[]'::json
      ) AS attachments
    FROM concerns c
    JOIN tenants t ON t.id = c.tenant_id
    LEFT JOIN rooms r ON r.id = c.reported_room_id
    LEFT JOIN concern_attachments ca ON ca.concern_id = c.id
    WHERE c.boarding_house_id = $1
      AND ($2::uuid IS NULL OR c.tenant_id = $2::uuid)
    GROUP BY c.id, t.full_name, r.room_number
    ORDER BY c.created_at DESC
    `,
    [boardingHouseId, ownTenantId ?? null]
  );

  return result.rows;
}

export async function createConcern(
  boardingHouseId: string,
  tenantId: string,
  roomId: string | undefined,
  category: string,
  subject: string,
  details: string,
  attachments?: AttachmentInput[]
) {
  const result = await query(
    `
    INSERT INTO concerns (
      boarding_house_id,
      tenant_id,
      reported_room_id,
      category,
      subject,
      details
    )
    VALUES ($1, $2, $3, $4::concern_category, $5, $6)
    RETURNING
      id,
      tenant_id AS "tenantId",
      reported_room_id AS "reportedRoomId",
      category,
      subject,
      details,
      status,
      created_at AS "createdAt"
    `,
    [boardingHouseId, tenantId, roomId ?? null, category, subject.trim(), details.trim()]
  );

  const concern = result.rows[0];
  const savedAttachments: any[] = [];

  if (attachments && Array.isArray(attachments)) {
    for (const att of attachments) {
      if (att.dataBase64) {
        const saved = await saveAttachmentFile(
          concern.id,
          att.fileName,
          att.mimeType,
          att.dataBase64
        );
        savedAttachments.push(saved);
      } else if (att.storagePath) {
        const saved = await addAttachment(
          concern.id,
          att.storagePath,
          att.publicUrl,
          att.mimeType,
          att.fileName
        );
        savedAttachments.push(saved);
      }
    }
  }

  concern.attachments = savedAttachments;
  return concern;
}

export async function updateConcern(
  concernId: string,
  boardingHouseId: string,
  status: "unread" | "pending" | "resolved",
  ownerResponse?: string,
  respondedBy?: string
) {
  const result = await query(
    `
    UPDATE concerns
    SET
      status = $3::concern_status,
      owner_response = COALESCE($4, owner_response),
      responded_by = COALESCE($5, responded_by),
      responded_at = CASE
        WHEN $4 IS NOT NULL AND length(trim($4)) > 0 THEN NOW()
        ELSE responded_at
      END
    WHERE id = $1
      AND boarding_house_id = $2
    RETURNING
      id,
      status,
      owner_response AS "ownerResponse",
      responded_at AS "respondedAt",
      updated_at AS "updatedAt"
    `,
    [concernId, boardingHouseId, status, ownerResponse ?? null, respondedBy ?? null]
  );

  return result.rows[0] ?? null;
}

export async function updateConcernRating(
  concernId: string,
  boardingHouseId: string,
  tenantId: string,
  rating: number
) {
  const result = await query(
    `
    UPDATE concerns
    SET
      rating = $4,
      updated_at = NOW()
    WHERE id = $1
      AND boarding_house_id = $2
      AND tenant_id = $3
      AND status = 'resolved'
    RETURNING
      id,
      rating,
      updated_at AS "updatedAt"
    `,
    [concernId, boardingHouseId, tenantId, rating]
  );

  return result.rows[0] ?? null;
}

export async function addAttachment(
  concernId: string,
  storagePath: string,
  publicUrl: string | undefined,
  mimeType: string | undefined,
  fileName: string | undefined
) {
  const result = await query(
    `
    INSERT INTO concern_attachments (
      concern_id, storage_path, public_url, mime_type, file_name
    )
    VALUES ($1, $2, $3, $4, $5)
    RETURNING
      id,
      concern_id AS "concernId",
      storage_path AS "storagePath",
      public_url AS "publicUrl",
      mime_type AS "mimeType",
      file_name AS "fileName",
      created_at AS "createdAt"
    `,
    [concernId, storagePath, publicUrl ?? null, mimeType ?? null, fileName ?? null]
  );

  return result.rows[0];
}

