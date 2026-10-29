import jwt from "jsonwebtoken";
import { env } from "../config/env";

export interface TokenUser {
  id: string;
  email: string;
  displayName: string;
  tokenVersion: number;
}

export function signAccessToken(user: TokenUser): string {
  return jwt.sign(
    {
      sub: user.id,
      email: user.email,
      displayName: user.displayName,
      tv: user.tokenVersion
    },
    env.JWT_SECRET,
    { expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions["expiresIn"] }
  );
}
