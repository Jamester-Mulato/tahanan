import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import {
  requireMembership,
  requireOwner
} from "../middleware/require-membership";
import { asyncRoute } from "../utils/async-route";
import {
  associateAccount,
  createTenant,
  listTenants,
  listUnassignedAccounts,
  removeMember,
  removeTenant
} from "../services/tenant.service";
import type { AuthenticatedRequest } from "../types/auth";

export const tenantRouter = Router();

tenantRouter.get(
  "/:boardingHouseId",
  requireAuth,
  requireMembership,
  asyncRoute(async (req, res) => {
    res.json({ tenants: await listTenants(req.params.boardingHouseId as string) });
  })
);

tenantRouter.post(
  "/:boardingHouseId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req, res) => {
    const body = z.object({
      fullName: z.string().trim().min(1).max(150),
      email: z.string().email().optional(),
      phone: z.string().trim().max(40).optional()
    }).parse(req.body);

    res.status(201).json(
      await createTenant(
        req.params.boardingHouseId as string,
        body.fullName,
        body.email,
        body.phone
      )
    );
  })
);

tenantRouter.get(
  "/:boardingHouseId/unassigned",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req, res) => {
    res.json({
      accounts: await listUnassignedAccounts(req.params.boardingHouseId as string)
    });
  })
);

tenantRouter.post(
  "/:boardingHouseId/associations",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z.object({
      tenantId: z.string().uuid(),
      userId: z.string().uuid(),
      roomId: z.string().uuid().optional()
    }).parse(req.body);

    await associateAccount(
      req.params.boardingHouseId as string,
      body.tenantId,
      body.userId,
      req.authUser!.id,
      body.roomId
    );

    res.status(204).send();
  })
);

tenantRouter.delete(
  "/:boardingHouseId/members/:userId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const removed = await removeMember(
      req.params.boardingHouseId as string,
      req.params.userId as string,
      req.authUser!.id
    );

    if (!removed) {
      res.status(404).json({ error: "MEMBER_NOT_FOUND" });
      return;
    }

    res.status(204).send();
  })
);

tenantRouter.delete(
  "/:boardingHouseId/tenants/:tenantId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const removed = await removeTenant(
      req.params.boardingHouseId as string,
      req.params.tenantId as string,
      req.authUser!.id
    );

    if (!removed) {
      res.status(404).json({ error: "TENANT_NOT_FOUND" });
      return;
    }

    res.status(204).send();
  })
);

