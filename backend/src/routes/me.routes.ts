import { Router } from "express";
import { requireAuth } from "../middleware/auth";
import { asyncRoute } from "../utils/async-route";
import { listMyBoardingHouses, listRemovedBoardingHouses } from "../services/boarding-house.service";
import { query } from "../config/db";
import type { AuthenticatedRequest } from "../types/auth";

export const meRouter = Router();

meRouter.get(
  "/",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const user = req.authUser!;
    const houses = await listMyBoardingHouses(user.id);
    const removedHouses = await listRemovedBoardingHouses(user.id);

    res.json({
      user,
      boardingHouses: houses,
      removedBoardingHouses: removedHouses
    });
  })
);

meRouter.post(
  "/dismiss-removal/:boardingHouseId",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    await query(
      `
      DELETE FROM boarding_house_memberships
      WHERE user_id = $1
        AND boarding_house_id = $2
        AND status = 'removed'
      `,
      [req.authUser!.id, req.params.boardingHouseId]
    );
    res.json({ ok: true });
  })
);

meRouter.get(
  "/profile",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const result = await query(
      `
      SELECT
        id,
        email,
        display_name AS "displayName",
        avatar_url AS "avatarUrl",
        created_at AS "createdAt"
      FROM users
      WHERE id = $1
      `,
      [req.authUser!.id]
    );

    res.json(result.rows[0]);
  })
);
