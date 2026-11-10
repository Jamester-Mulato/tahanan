import { Router, type Request } from "express";
import { z } from "zod";
import {
  authenticatePassword,
  changePassword,
  completeLogin,
  loginWithGoogle,
  logoutAll,
  refreshSession,
  registerWithGoogle,
  usernameAvailable
} from "../services/auth.service";
import {
  activateAccount,
  registerAccount
} from "../services/registration.service";
import {
  normalizeRegistration,
  validateRegistration
} from "../security/registration";
import {
  createResetToken,
  questionsFor,
  resetPasswordWithToken,
  verifySecurityAnswer
} from "../services/password-reset-flow.service";
import { createCaptcha, verifyCaptcha } from "../services/captcha.service";
import {
  createRememberToken,
  revokeRememberToken
} from "../services/remember.service";
import {
  recaptchaEnabled,
  verifyRecaptcha
} from "../services/recaptcha.service";
import {
  listRefreshSessions,
  revokeRefreshSession,
  revokeRefreshToken
} from "../services/refresh-token.service";
import { logAuthEvent } from "../services/auth-events.service";
import {
  resendLoginOtp,
  resendOtp,
  startLoginOtp,
  startOtp,
  verifyLoginOtp,
  verifyOtp
} from "../services/login-otp.service";
import { ipBlockSeconds, recordIpFailure } from "../services/throttle.service";
import { requireAuth } from "../middleware/auth";
import { HttpError } from "../utils/http-error";
import { env } from "../config/env";
import type { AuthenticatedRequest } from "../types/auth";
import { asyncRoute } from "../utils/async-route";

export const authRouter = Router();

const emailSchema = z
  .string()
  .trim()
  .min(3)
  .max(254)
  .regex(/^[^\s@]+@[^\s@]+\.[^\s@]+$/, "Enter a valid email address.");

const passwordSchema = z
  .string()
  .min(8, "Password must be at least 8 characters.")
  .max(128, "Password must be at most 128 characters.")
  .refine(
    (value) => /[A-Za-z]/.test(value) && /\d/.test(value),
    "Password must include a letter and a number."
  );

// Handout 4.9: letters and digits, starts with a letter, 7–16 characters.
const usernameSchema = z
  .string()
  .trim()
  .min(7, "Username must be at least 7 characters.")
  .max(16, "Username must be at most 16 characters.")
  .regex(
    /^[A-Za-z][A-Za-z0-9]*$/,
    "Username must start with a letter and use letters and digits only."
  );

const humanSchema = z.object({
  captchaId: z.string().trim().min(1).max(128).optional(),
  captchaAnswer: z.string().trim().min(1).max(16).optional(),
  recaptchaToken: z.string().trim().min(1).max(8192).optional()
});

const credentialSchema = z
  .object({
    idToken: z.string().min(1).optional(),
    accessToken: z.string().min(1).optional()
  })
  .refine((value) => Boolean(value.idToken || value.accessToken), {
    message: "A Google credential is required."
  });

function requireCaptcha(input: { captchaId?: string; captchaAnswer?: string }) {
  if (!input.captchaId || !input.captchaAnswer) {
    throw new HttpError(
      400,
      "CAPTCHA_REQUIRED",
      "Complete the CAPTCHA to continue."
    );
  }

  if (!verifyCaptcha(input.captchaId, input.captchaAnswer)) {
    throw new HttpError(
      400,
      "CAPTCHA_FAILED",
      "That CAPTCHA answer is wrong or expired. Try a new challenge."
    );
  }
}

async function requireHuman(
  input: {
    captchaId?: string;
    captchaAnswer?: string;
    recaptchaToken?: string;
    email?: string;
  },
  req: Request
) {
  // A Google token is verified with Google when one is supplied.
  if (input.recaptchaToken) {
    const ok = await verifyRecaptcha(input.recaptchaToken, req.ip);
    if (!ok) {
      const seconds = await recordIpFailure(req.ip);
      await logAuthEvent({
        eventType: "RECAPTCHA_FAILED",
        email: input.email,
        req
      });
      if (seconds > 0) {
        await logAuthEvent({
          eventType: "IP_BLOCKED",
          email: input.email,
          usernameTyped: input.email,
          req,
          details: { seconds, source: "recaptcha" }
        });
      }
      throw new HttpError(
        400,
        "RECAPTCHA_FAILED",
        "The Google reCAPTCHA verification failed. Please try again."
      );
    }
    return;
  }

  // Otherwise the server-issued challenge is the CAPTCHA. This keeps the app
  // usable on platforms where the Google widget cannot be embedded.
  try {
    requireCaptcha(input);
  } catch (error) {
    const seconds = await recordIpFailure(req.ip);
    await logAuthEvent({
      eventType: "CAPTCHA_FAILED",
      email: input.email,
      req,
      details: { kind: "challenge" }
    });
    if (seconds > 0) {
      await logAuthEvent({
        eventType: "IP_BLOCKED",
        email: input.email,
        usernameTyped: input.email,
        req,
        details: { seconds, source: "captcha" }
      });
    }
    throw error;
  }
}

// Tells the app which human-verification mode this server is using.
authRouter.get("/recaptcha", (_req, res) => {
  res.json({
    enabled: recaptchaEnabled(),
    siteKey: env.RECAPTCHA_SITE_KEY
  });
});

// A fresh fallback challenge. The answer stays on the server.
authRouter.get("/captcha", (_req, res) => {
  res.json(createCaptcha());
});

// ---------------------------------------------------------------
// SIGN-UP
// ---------------------------------------------------------------
authRouter.post(
  "/register",
  asyncRoute(async (req, res) => {
    const raw = (req.body ?? {}) as Record<string, unknown>;

    // Protection 8: a hidden field humans never fill.
    if (typeof raw.website === "string" && raw.website.trim() !== "") {
      await logAuthEvent({
        eventType: "HONEYPOT_TRIGGERED",
        req,
        details: { path: "/register" }
      });
      res.status(201).json({ ok: true, otpRequired: false });
      return;
    }

    const input = normalizeRegistration(raw);
    const errors = validateRegistration(input);
    if (Object.keys(errors).length > 0) {
      res.status(422).json({
        error: "VALIDATION_ERROR",
        message: "Please fix the highlighted fields.",
        details: errors
      });
      return;
    }

    const human = z
      .object({})
      .and(humanSchema)
      .parse(raw);
    await requireHuman({ ...human, email: input.email }, req);

    const user = await registerAccount(input, req);
    const challenge = await startOtp({
      userId: user.id,
      email: user.email,
      name: user.display_name,
      purpose: "register",
      req
    });

    res.status(201).json({ otpRequired: true, ...challenge });
  })
);

authRouter.post(
  "/register/verify-otp",
  asyncRoute(async (req, res) => {
    const body = z
      .object({
        challengeId: z.string().uuid("The verification session is invalid."),
        code: z.string().trim().regex(/^\d{6}$/, "Enter the 6-digit code.")
      })
      .parse(req.body);

    const verified = await verifyOtp({
      challengeId: body.challengeId,
      code: body.code,
      purpose: "register",
      req
    });

    await activateAccount(verified.userId, req);
    const result = await completeLogin(verified.userId, req);
    res.json(result);
  })
);

authRouter.post(
  "/register/resend-otp",
  asyncRoute(async (req, res) => {
    const body = z
      .object({ challengeId: z.string().uuid("The verification session is invalid.") })
      .parse(req.body);

    const challenge = await resendOtp({
      challengeId: body.challengeId,
      purpose: "register",
      req
    });

    res.json({ otpRequired: true, ...challenge });
  })
);

// ---------------------------------------------------------------
// LOG-IN — password + CAPTCHA, then a 6-digit email code (handout 8)
// ---------------------------------------------------------------
authRouter.get(
  "/username-available",
  asyncRoute(async (req, res) => {
    const username = String(req.query.username ?? "").trim();
    res.json({ username, available: await usernameAvailable(username) });
  })
);

authRouter.post(
  "/login",
  asyncRoute(async (req, res) => {
    const body = z
      .object({
        username: z.string().trim().min(1, "Enter your username.").max(64),
        password: z.string().min(1).max(128),
        rememberMe: z.boolean().optional().default(false)
      })
      .and(humanSchema)
      .parse(req.body);

    const blocked = await ipBlockSeconds(req.ip);
    if (blocked > 0) {
      throw new HttpError(
        429,
        "IP_BLOCKED",
        `Too many failed attempts. Try again in ${blocked} seconds.`,
        { retryAfter: blocked }
      );
    }

    await requireHuman(body, req);

    // Credentials only. No session exists until the code is correct.
    const user = await authenticatePassword(
      { identifier: body.username, password: body.password },
      req
    );

    if (user.status !== "active") {
      throw new HttpError(
        403,
        "EMAIL_NOT_VERIFIED",
        "Verify your email address before logging in."
      );
    }

    const challenge = await startLoginOtp({
      userId: user.id,
      email: user.email,
      name: user.displayName,
      req
    });

    res.json({ otpRequired: true, ...challenge });
  })
);

authRouter.post(
  "/login/verify-otp",
  asyncRoute(async (req, res) => {
    const body = z
      .object({
        challengeId: z.string().uuid("The log-in challenge is invalid."),
        code: z.string().trim().regex(/^\d{6}$/, "Enter the 6-digit code."),
        rememberMe: z.boolean().optional().default(false)
      })
      .parse(req.body);

    const verified = await verifyLoginOtp({
      challengeId: body.challengeId,
      code: body.code,
      req
    });

    const result = await completeLogin(verified.userId, req);

    if (body.rememberMe) {
      const remember = await createRememberToken(result.user.id);
      res.json({ ...result, ...remember });
      return;
    }

    res.json(result);
  })
);

authRouter.post(
  "/login/resend-otp",
  asyncRoute(async (req, res) => {
    const body = z
      .object({ challengeId: z.string().uuid("The log-in challenge is invalid.") })
      .parse(req.body);

    const challenge = await resendLoginOtp({
      challengeId: body.challengeId,
      req
    });

    res.json({ otpRequired: true, ...challenge });
  })
);

// ---------------------------------------------------------------
// TOKENS / SESSIONS
// ---------------------------------------------------------------
authRouter.post(
  "/refresh",
  asyncRoute(async (req, res) => {
    const body = z
      .object({ refreshToken: z.string().trim().min(1).max(256) })
      .parse(req.body);

    const result = await refreshSession(body.refreshToken, req);
    res.json(result);
  })
);

authRouter.post(
  "/logout",
  asyncRoute(async (req, res) => {
    const body = z
      .object({
        refreshToken: z.string().trim().min(1).max(256).optional(),
        rememberToken: z.string().trim().min(1).max(256).optional()
      })
      .parse(req.body ?? {});

    if (body.refreshToken) await revokeRefreshToken(body.refreshToken);
    if (body.rememberToken) await revokeRememberToken(body.rememberToken);

    await logAuthEvent({ eventType: "LOGGED_OUT", req });
    res.json({ ok: true });
  })
);

authRouter.post(
  "/logout-all",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    await logoutAll(req.authUser!.id, req);
    res.json({ ok: true });
  })
);

authRouter.get(
  "/sessions",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const sessions = await listRefreshSessions(req.authUser!.id);
    res.json({ sessions });
  })
);

authRouter.delete(
  "/sessions/:id",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const id = z.string().uuid().parse(req.params.id);
    const revoked = await revokeRefreshSession(req.authUser!.id, id);

    if (!revoked) {
      throw new HttpError(404, "SESSION_NOT_FOUND", "Session not found.");
    }

    res.json({ ok: true });
  })
);

// ---------------------------------------------------------------
// PASSWORD
// ---------------------------------------------------------------
authRouter.post(
  "/password",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z
      .object({
        currentPassword: z.string().min(1).max(128),
        newPassword: passwordSchema
      })
      .parse(req.body);

    await changePassword(
      req.authUser!.id,
      body.currentPassword,
      body.newPassword,
      req
    );

    res.json({
      ok: true,
      message: "Password changed. Please sign in again."
    });
  })
);

authRouter.post(
  "/forgot-password",
  asyncRoute(async (req, res) => {
    const body = z
      .object({
        username: z.string().trim().min(1, "Enter your username.").max(254)
      })
      .and(humanSchema)
      .parse(req.body);

    await requireHuman({ ...body, email: body.username }, req);

    const { questions } = await questionsFor(body.username);
    res.json({ questions });
  })
);

authRouter.post(
  "/forgot-password/answer",
  asyncRoute(async (req, res) => {
    const body = z
      .object({
        username: z.string().trim().min(1).max(254),
        question: z.enum(["Q6", "Q1", "Q3"]),
        answer: z.string().trim().min(2).max(50),
        reanswer: z.string().trim().min(2).max(50)
      })
      .parse(req.body);

    const user = await verifySecurityAnswer({
      identifier: body.username,
      question: body.question,
      answer: body.answer,
      reanswer: body.reanswer,
      req
    });

    const challenge = await startOtp({
      userId: user.id,
      email: user.email,
      name: user.display_name,
      purpose: "reset",
      req
    });

    res.json({ otpRequired: true, ...challenge });
  })
);

authRouter.post(
  "/forgot-password/verify-otp",
  asyncRoute(async (req, res) => {
    const body = z
      .object({
        challengeId: z.string().uuid("The reset session is invalid."),
        code: z.string().trim().regex(/^\d{6}$/, "Enter the 6-digit code.")
      })
      .parse(req.body);

    const verified = await verifyOtp({
      challengeId: body.challengeId,
      code: body.code,
      purpose: "reset",
      req
    });

    const grant = await createResetToken(verified.userId, req);
    res.json({ resetToken: grant.token, expiresIn: grant.expiresIn });
  })
);

authRouter.post(
  "/forgot-password/resend-otp",
  asyncRoute(async (req, res) => {
    const body = z
      .object({ challengeId: z.string().uuid("The reset session is invalid.") })
      .parse(req.body);

    const challenge = await resendOtp({
      challengeId: body.challengeId,
      purpose: "reset",
      req
    });

    res.json({ otpRequired: true, ...challenge });
  })
);

authRouter.post(
  "/reset-password",
  asyncRoute(async (req, res) => {
    const body = z
      .object({
        token: z.string().trim().min(10).max(128),
        password: z.string().min(9, "Password must be at least 9 characters.").max(64)
      })
      .parse(req.body);

    await resetPasswordWithToken({
      token: body.token,
      password: body.password,
      req
    });
    res.json({ ok: true, message: "Password changed. Please log in." });
  })
);

// ---------------------------------------------------------------
// OPTIONAL GOOGLE-NATIVE ENDPOINTS
// ---------------------------------------------------------------
authRouter.post(
  "/register/google",
  asyncRoute(async (req, res) => {
    const body = credentialSchema
      .and(z.object({ password: passwordSchema }))
      .parse(req.body);

    const result = await registerWithGoogle(body, req);
    res.status(201).json(result);
  })
);

authRouter.post(
  "/google",
  asyncRoute(async (req, res) => {
    const body = credentialSchema.parse(req.body);
    const result = await loginWithGoogle(body, req);
    res.json(result);
  })
);
