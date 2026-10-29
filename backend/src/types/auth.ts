import type { Request } from "express";

export interface AuthUser {
  id: string;
  email: string;
  displayName: string;
  isAdmin: boolean;
}

export interface AuthenticatedRequest extends Request {
  authUser?: AuthUser;
}
