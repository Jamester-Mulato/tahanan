import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import {
  requireMembership,
  requireOwner
} from "../middleware/require-membership";
import { asyncRoute } from "../utils/async-route";
import {
  getTenantStatuses,
  upsertTenantStatus
} from "../services/status.service";
import type { AuthenticatedRequest } from "../types/auth";

export const statusRouter = Router();

statusRouter.get(
  "/:boardingHouseId/tenants/:tenantId",
  requireAuth,
  requireMembership,
  asyncRoute(async (req, res) => {
    const querySchema = z.object({
      academicYearId: z.string().uuid().optional()
    }).parse(req.query);

    res.json({
      statuses: await getTenantStatuses(
        req.params.tenantId as string,
        req.params.boardingHouseId as string,
        querySchema.academicYearId
      )
    });
  })
);

statusRouter.put(
  "/:boardingHouseId/tenants/:tenantId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z.object({
      academicYearId: z.string().uuid().optional(),
      monthStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
      status: z.enum(["paid", "partial", "unpaid"])
    }).parse(req.body);

    res.json(
      await upsertTenantStatus(
        req.params.boardingHouseId as string,
        req.params.tenantId as string,
        body.academicYearId,
        body.monthStart,
        body.status,
        req.authUser!.id
      )
    );
  })
);

