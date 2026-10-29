import type { NextFunction, Response } from "express";
import type { AuthenticatedRequest } from "../types/auth";
import { query } from "../config/db";

export type MembershipRole = "owner" | "tenant";

export interface MembershipContext {
  boardingHouseId: string;
  role: MembershipRole;
}

export async function requireMembership(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authUser = req.authUser;
    const boardingHouseId = req.params.boardingHouseId;

    if (!authUser) {
      res.status(401).json({ error: "UNAUTHENTICATED" });
      return;
    }

    if (!boardingHouseId) {
      res.status(400).json({ error: "BOARDING_HOUSE_ID_REQUIRED" });
      return;
    }

    const result = await query<MembershipContext>(
      `
      SELECT
        boarding_house_id AS "boardingHouseId",
        role::text AS role
      FROM boarding_house_memberships
      WHERE boarding_house_id = $1
        AND user_id = $2
        AND status = 'active'
      LIMIT 1
      `,
      [boardingHouseId, authUser.id]
    );

    const membership = result.rows[0];

    if (!membership) {
      res.status(403).json({
        error: "FORBIDDEN",
        message: "You are not an active member of this boarding house."
      });
      return;
    }

    res.locals.membership = membership;
    next();
  } catch (error) {
    next(error);
  }
}

export function requireOwner(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): void {
  const membership = res.locals.membership as MembershipContext | undefined;

  if (membership?.role !== "owner") {
    res.status(403).json({
      error: "OWNER_ONLY",
      message: "This action requires an owner membership."
    });
    return;
  }

  next();
}

export function requireTenant(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): void {
  const membership = res.locals.membership as MembershipContext | undefined;

  if (membership?.role !== "tenant") {
    res.status(403).json({
      error: "TENANT_ONLY",
      message: "This action requires a tenant membership."
    });
    return;
  }

  next();
}
