import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import {
  requireMembership,
  requireOwner
} from "../middleware/require-membership";
import { asyncRoute } from "../utils/async-route";
import {
  createAnnouncement,
  listAnnouncements,
  updateAnnouncement,
  deleteAnnouncement
} from "../services/announcement.service";
import type { AuthenticatedRequest } from "../types/auth";

export const announcementRouter = Router();

announcementRouter.get(
  "/:boardingHouseId",
  requireAuth,
  requireMembership,
  asyncRoute(async (req, res) => {
    res.json({
      announcements: await listAnnouncements(req.params.boardingHouseId as string)
    });
  })
);

announcementRouter.post(
  "/:boardingHouseId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z.object({
      title: z.string().trim().min(1).max(200),
      message: z.string().trim().min(1).max(10000)
    }).parse(req.body);

    res.status(201).json(
      await createAnnouncement(
        req.params.boardingHouseId as string,
        req.authUser!.id,
        body.title,
        body.message
      )
    );
  })
);

announcementRouter.patch(
  "/:boardingHouseId/:announcementId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req, res) => {
    const body = z.object({
      title: z.string().trim().min(1).max(200),
      message: z.string().trim().min(1).max(10000)
    }).parse(req.body);

    const updated = await updateAnnouncement(
      req.params.announcementId as string,
      req.params.boardingHouseId as string,
      body.title,
      body.message
    );

    if (!updated) {
      res.status(404).json({ error: "ANNOUNCEMENT_NOT_FOUND" });
      return;
    }

    res.json(updated);
  })
);

announcementRouter.delete(
  "/:boardingHouseId/:announcementId",
  requireAuth,
  requireMembership,
  requireOwner,
  asyncRoute(async (req, res) => {
    const deleted = await deleteAnnouncement(
      req.params.announcementId as string,
      req.params.boardingHouseId as string
    );

    if (!deleted) {
      res.status(404).json({ error: "ANNOUNCEMENT_NOT_FOUND" });
      return;
    }

    res.status(204).send();
  })
);
