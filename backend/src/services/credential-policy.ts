import { env } from "../config/env";

/**
 * The one place that decides whether a credential is acceptable and how long
 * a failure streak locks an account. Both the request layer (Zod) and the
 * domain layer call these functions, so they cannot drift apart.
 */

export const PASSWORD_MIN_LENGTH = 9;
export const PASSWORD_MAX_LENGTH = 64;
export const USERNAME_MIN_LENGTH = 7;
export const USERNAME_MAX_LENGTH = 16;
export const USERNAME_PATTERN = /^[A-Za-z][A-Za-z0-9]*$/;

export function passwordProblem(password: string): string | null {
  if (password.length < PASSWORD_MIN_LENGTH) {
    return `Password must be at least ${PASSWORD_MIN_LENGTH} characters.`;
  }
  if (password.length > PASSWORD_MAX_LENGTH) {
    return `Password must be at most ${PASSWORD_MAX_LENGTH} characters.`;
  }
  if (!/[A-Z]/.test(password)) {
    return "Password must include an uppercase letter.";
  }
  if (!/\d/.test(password)) {
    return "Password must include a number.";
  }
  return null;
}

export function usernameProblem(username: string): string | null {
  if (username.length < USERNAME_MIN_LENGTH) {
    return `Username must be at least ${USERNAME_MIN_LENGTH} characters.`;
  }
  if (username.length > USERNAME_MAX_LENGTH) {
    return `Username must be at most ${USERNAME_MAX_LENGTH} characters.`;
  }
  if (!USERNAME_PATTERN.test(username)) {
    return "Username must start with a letter and use letters and digits only.";
  }
  return null;
}

export type LockoutEventType =
  | "LOCKOUT_TIER_1"
  | "LOCKOUT_TIER_2"
  | "LOCKOUT_TIER_3";

export interface Lockout {
  attempts: number;
  seconds: number;
  event: LockoutEventType;
  tier: 1 | 2 | 3;
}

/**
 * Handout tiers: the 3rd, 6th and every 9th-plus consecutive failure lock the
 * account. Any other count returns null and does not interrupt the attempt.
 */
export function lockoutFor(attempts: number): Lockout | null {
  if (attempts === 3) {
    return {
      attempts,
      seconds: env.LOCKOUT_TIER1_SECONDS,
      event: "LOCKOUT_TIER_1",
      tier: 1
    };
  }
  if (attempts === 6) {
    return {
      attempts,
      seconds: env.LOCKOUT_TIER2_SECONDS,
      event: "LOCKOUT_TIER_2",
      tier: 2
    };
  }
  if (attempts >= 9) {
    return {
      attempts,
      seconds: env.LOCKOUT_TIER3_SECONDS,
      event: "LOCKOUT_TIER_3",
      tier: 3
    };
  }
  return null;
}
