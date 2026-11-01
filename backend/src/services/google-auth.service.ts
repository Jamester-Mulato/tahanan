import { OAuth2Client } from "google-auth-library";
import { googleClientIds } from "../config/env";

const client = new OAuth2Client();

export interface GoogleIdentity {
  subject: string;
  email: string;
  displayName: string;
  avatarUrl?: string;
}

export async function verifyGoogleIdToken(
  idToken: string
): Promise<GoogleIdentity> {
  const ticket = await client.verifyIdToken({
    idToken,
    audience: googleClientIds
  });

  const payload = ticket.getPayload();

  if (!payload?.sub || !payload.email) {
    throw new Error(
      "Google token does not contain the required identity claims."
    );
  }

  if (payload.email_verified === false) {
    throw new Error("Google email is not verified.");
  }

  return {
    subject: payload.sub,
    email: payload.email,
    displayName: payload.name ?? payload.email,
    avatarUrl: payload.picture
  };
}

interface TokenInfo {
  aud?: string;
  sub?: string;
  email?: string;
  email_verified?: string | boolean;
  name?: string;
  picture?: string;
}

/**
 * The web Google button can return an OAuth access token instead of an ID
 * token. Verify it with Google's tokeninfo endpoint and enforce the same
 * audience list used for ID tokens.
 */
export async function verifyGoogleAccessToken(
  accessToken: string
): Promise<GoogleIdentity> {
  const response = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?access_token=${encodeURIComponent(
      accessToken
    )}`
  );

  if (!response.ok) {
    throw new Error("Google access token is not valid.");
  }

  const payload = (await response.json()) as TokenInfo;

  if (!payload.sub || !payload.email) {
    throw new Error(
      "Google token does not contain the required identity claims."
    );
  }

  if (payload.aud && !googleClientIds.includes(payload.aud)) {
    throw new Error("Google token audience is not allowed.");
  }

  if (String(payload.email_verified) === "false") {
    throw new Error("Google email is not verified.");
  }

  return {
    subject: payload.sub,
    email: payload.email,
    displayName: payload.name ?? payload.email,
    avatarUrl: payload.picture
  };
}
