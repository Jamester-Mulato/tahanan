import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import { asyncRoute } from "../utils/async-route";
import {
  createBoardingHouse,
  joinBoardingHouse,
  listMyBoardingHouses
} from "../services/boarding-house.service";
import { query } from "../config/db";
import type { AuthenticatedRequest } from "../types/auth";

export const boardingHouseRouter = Router();

const roomSchema = z.object({
  roomNumber: z.string().trim().min(1).max(50),
  capacity: z.number().int().min(1).max(100)
});

boardingHouseRouter.get(
  "/mine",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    res.json({
      boardingHouses: await listMyBoardingHouses(req.authUser!.id)
    });
  })
);

boardingHouseRouter.post(
  "/",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z.object({
      name: z.string().trim().min(2).max(120),
      rooms: z.array(roomSchema).min(1).max(100),
      academicYear: z.object({
        name: z.string().trim().min(4).max(30),
        startsOn: z.string(),
        endsOn: z.string()
      }).optional()
    }).parse(req.body);

    const result = await createBoardingHouse(req.authUser!.id, body);
    res.status(201).json(result);
  })
);

boardingHouseRouter.post(
  "/join",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z.object({
      keyOrDomain: z.string().trim().min(3).max(64)
    }).parse(req.body);

    const result = await joinBoardingHouse(req.authUser!.id, body.keyOrDomain);

    if (!result) {
      res.status(404).json({
        error: "BOARDING_HOUSE_NOT_FOUND",
        message: "No active boarding house matches that key or domain."
      });
      return;
    }

    res.status(201).json(result);
  })
);

boardingHouseRouter.get(
  "/:boardingHouseId",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const result = await query(
      `
      SELECT
        bh.id,
        bh.name,
        bh.domain,
        bh.join_key AS "joinKey",
        bh.created_at AS "createdAt"
      FROM boarding_houses bh
      JOIN boarding_house_memberships m
        ON m.boarding_house_id = bh.id
       AND m.user_id = $2
       AND m.status = 'active'
      WHERE bh.id = $1
        AND bh.is_active = TRUE
      `,
      [req.params.boardingHouseId as string, req.authUser!.id]
    );

    if ((result.rowCount ?? 0) === 0) {
      res.status(404).json({ error: "BOARDING_HOUSE_NOT_FOUND" });
      return;
    }

    res.json(result.rows[0]);
  })
);
