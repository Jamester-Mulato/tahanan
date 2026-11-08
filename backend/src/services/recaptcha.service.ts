import { env } from "../config/env";

/**
 * Real Google reCAPTCHA v2 verification.
 *
 * Both keys are created at https://www.google.com/recaptcha/admin and are
 * required for this mode. When they are absent the portal falls back to the
 * server-issued challenge so the app keeps working during setup.
 */
export function recaptchaEnabled(): boolean {
  return (
    env.RECAPTCHA_ENABLED &&
    Boolean(env.RECAPTCHA_SITE_KEY && env.RECAPTCHA_SECRET_KEY)
  );
}

export async function verifyRecaptcha(
  token: string,
  remoteIp?: string
): Promise<boolean> {
  if (!recaptchaEnabled()) return false;

  const body = new URLSearchParams({
    secret: env.RECAPTCHA_SECRET_KEY,
    response: token
  });

  if (remoteIp) body.set("remoteip", remoteIp);

  const response = await fetch(
    "https://www.google.com/recaptcha/api/siteverify",
    {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body
    }
  );

  if (!response.ok) return false;

  const data = (await response.json()) as { success?: boolean };
  return data.success === true;
}
