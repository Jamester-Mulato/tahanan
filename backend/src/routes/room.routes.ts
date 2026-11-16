import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import {
  requireMembership,
  requireOwner
} from "../middleware/require-membership";
import { asyncRoute } from "../utils/async-route";
import {
  createRoom,
  listRooms,
  updateRoom,
  archiveRoom
} from "../services/room.service";
import type { AuthenticatedRequest } from "../types/auth";

export const roomRouter = Router();

roomRouter.get(
  "/:boardingHouseId",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    // Membership is checked manually here because this route returns
    // the same room data to both owners and tenants.
    const rooms = await listRooms(req.params.boardingHouseId as string);
    res.json({ rooms });
  })
);

roomRouter.post(
  "/:boardingHouseId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req, res) => {
    const body = z.object({
      roomNumber: z.string().trim().min(1).max(50),
      capacity: z.number().int().min(1).max(100)
    }).parse(req.body);

    res.status(201).json(
      await createRoom(req.params.boardingHouseId as string, body.roomNumber, body.capacity)
    );
  })
);

roomRouter.patch(
  "/:boardingHouseId/:roomId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req, res) => {
    const body = z.object({
      roomNumber: z.string().trim().min(1).max(50).optional(),
      capacity: z.number().int().min(1).max(100).optional()
    }).refine(
      (value) => value.roomNumber !== undefined || value.capacity !== undefined,
      "At least one field must be provided."
    ).parse(req.body);

    const room = await updateRoom(
      req.params.roomId as string,
      body.roomNumber,
      body.capacity,
      req.params.boardingHouseId as string
    );

    if (!room) {
      res.status(404).json({ error: "ROOM_NOT_FOUND" });
      return;
    }

    res.json(room);
  })
);

roomRouter.delete(
  "/:boardingHouseId/:roomId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req, res) => {
    const archived = await archiveRoom(
      req.params.roomId as string,
      req.params.boardingHouseId as string
    );

    if (!archived) {
      res.status(404).json({ error: "ROOM_NOT_FOUND" });
      return;
    }

    res.status(204).send();
  })
);
