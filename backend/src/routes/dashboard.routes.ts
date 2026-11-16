import { Router } from "express";
import { requireAuth } from "../middleware/auth";
import { requireMembership } from "../middleware/require-membership";
import { asyncRoute } from "../utils/async-route";
import { query } from "../config/db";

export const dashboardRouter = Router();

dashboardRouter.get(
  "/:boardingHouseId",
  requireAuth,
  requireMembership,
  asyncRoute(async (req, res) => {
    const result = await query(
      `
      SELECT
        boarding_house_id AS "boardingHouseId",
        name,
        domain,
        join_key AS "joinKey",
        total_rooms AS "totalRooms",
        total_tenants AS "totalTenants",
        open_slots AS "openSlots",
        active_concerns AS "activeConcerns",
        unassigned_accounts AS "unassignedAccounts"
      FROM v_boarding_house_dashboard
      WHERE boarding_house_id = $1
      `,
      [req.params.boardingHouseId as string]
    );

    if ((result.rowCount ?? 0) === 0) {
      res.status(404).json({ error: "BOARDING_HOUSE_NOT_FOUND" });
      return;
    }

    res.json(result.rows[0]);
  })
);
