import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import { requireMembership } from "../middleware/require-membership";
import { asyncRoute } from "../utils/async-route";
import {
  createConcern,
  listConcerns,
  updateConcern,
  updateConcernRating,
  addAttachment,
  saveAttachmentFile
} from "../services/concern.service";
import { query } from "../config/db";
import type { AuthenticatedRequest } from "../types/auth";

export const concernRouter = Router();

async function resolveOwnTenantId(userId: string, boardingHouseId: string) {
  const result = await query<{ tenantId: string }>(
    `
    SELECT tenant_id AS "tenantId"
    FROM tenant_account_associations
    WHERE user_id = $1
      AND boarding_house_id = $2
    LIMIT 1
    `,
    [userId, boardingHouseId]
  );
  return result.rows[0]?.tenantId ?? null;
}

concernRouter.get(
  "/:boardingHouseId",
  requireAuth,
  requireMembership,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const membership = res.locals.membership as { role: "owner" | "tenant" };

    const tenantId = membership.role === "tenant"
      ? await resolveOwnTenantId(req.authUser!.id, req.params.boardingHouseId as string)
      : undefined;

    res.json({
      concerns: await listConcerns(req.params.boardingHouseId as string, tenantId ?? undefined)
    });
  })
);

concernRouter.post(
  "/:boardingHouseId",
  requireAuth,
  requireMembership,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z.object({
      tenantId: z.string().uuid().optional(),
      roomId: z.string().uuid().optional(),
      category: z.enum([
        "maintenance",
        "utilities",
        "cleanliness",
        "security",
        "noise",
        "other"
      ]),
      subject: z.string().trim().min(1).max(200),
      details: z.string().trim().min(1).max(20000),
      attachments: z.array(
        z.object({
          fileName: z.string().optional(),
          mimeType: z.string().optional(),
          dataBase64: z.string().optional(),
          storagePath: z.string().optional(),
          publicUrl: z.string().optional()
        })
      ).optional()
    }).parse(req.body);

    const tenantId =
      body.tenantId ??
      await resolveOwnTenantId(req.authUser!.id, req.params.boardingHouseId as string);

    if (!tenantId) {
      res.status(400).json({
        error: "TENANT_ASSOCIATION_REQUIRED",
        message: "Your account is not associated with a tenant record yet."
      });
      return;
    }

    res.status(201).json(
      await createConcern(
        req.params.boardingHouseId as string,
        tenantId,
        body.roomId,
        body.category,
        body.subject,
        body.details,
        body.attachments
      )
    );
  })
);

concernRouter.patch(
  "/:boardingHouseId/:concernId",
  requireAuth,
  requireMembership,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const membership = res.locals.membership as { role: "owner" | "tenant" };
    const body = z.object({
      status: z.enum(["unread", "pending", "resolved"]),
      ownerResponse: z.string().trim().max(20000).optional()
    }).parse(req.body);

    if (membership.role === "tenant") {
      const ownTenantId = await resolveOwnTenantId(
        req.authUser!.id,
        req.params.boardingHouseId as string
      );
      if (!ownTenantId) {
        res.status(403).json({
          error: "FORBIDDEN",
          message: "You are not associated with a tenant record in this boarding house."
        });
        return;
      }

      const chk = await query(
        "SELECT id FROM concerns WHERE id = $1 AND boarding_house_id = $2 AND tenant_id = $3",
        [req.params.concernId, req.params.boardingHouseId, ownTenantId]
      );
      if ((chk.rowCount ?? 0) === 0) {
        res.status(403).json({
          error: "FORBIDDEN",
          message: "You can only update the status of your own concerns."
        });
        return;
      }
    }

    const updated = await updateConcern(
      req.params.concernId as string,
      req.params.boardingHouseId as string,
      body.status,
      membership.role === "owner" ? body.ownerResponse : undefined,
      membership.role === "owner" ? req.authUser!.id : undefined
    );

    if (!updated) {
      res.status(404).json({ error: "CONCERN_NOT_FOUND" });
      return;
    }

    res.json(updated);
  })
);

concernRouter.patch(
  "/:boardingHouseId/:concernId/rating",
  requireAuth,
  requireMembership,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z.object({
      rating: z.number().int().min(0).max(5)
    }).parse(req.body);

    const ownTenantId = await resolveOwnTenantId(
      req.authUser!.id,
      req.params.boardingHouseId as string
    );

    if (!ownTenantId) {
      res.status(403).json({
        error: "FORBIDDEN",
        message: "You are not associated with a tenant record."
      });
      return;
    }

    const updated = await updateConcernRating(
      req.params.concernId as string,
      req.params.boardingHouseId as string,
      ownTenantId,
      body.rating
    );

    if (!updated) {
      res.status(404).json({
        error: "CONCERN_NOT_FOUND_OR_NOT_RESOLVED",
        message: "Concern not found or is not in resolved status."
      });
      return;
    }

    res.json(updated);
  })
);

concernRouter.post(
  "/:boardingHouseId/:concernId/attachments",
  requireAuth,
  requireMembership,
  asyncRoute(async (req, res) => {
    const body = z.object({
      storagePath: z.string().trim().min(1).max(1000).optional(),
      publicUrl: z.string().optional(),
      mimeType: z.string().trim().max(100).optional(),
      fileName: z.string().trim().max(255).optional(),
      dataBase64: z.string().optional()
    }).parse(req.body);

    if (body.dataBase64) {
      const attachment = await saveAttachmentFile(
        req.params.concernId as string,
        body.fileName,
        body.mimeType,
        body.dataBase64
      );
      res.status(201).json(attachment);
      return;
    }

    if (!body.storagePath) {
      res.status(400).json({ error: "STORAGE_PATH_OR_DATA_REQUIRED" });
      return;
    }

    const attachment = await addAttachment(
      req.params.concernId as string,
      body.storagePath,
      body.publicUrl,
      body.mimeType,
      body.fileName
    );

    res.status(201).json(attachment);
  })
);

