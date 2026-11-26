import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(8080),
  DATABASE_HOST: z.string().default("127.0.0.1"),
  DATABASE_PORT: z.coerce.number().int().positive().default(5432),
  DATABASE_NAME: z.string().min(1).default("tahanan"),
  DATABASE_USER: z.string().min(1).default("postgres"),
  /**
   * Only used for a local/discrete connection. Managed Postgres passes the
   * credentials inside DATABASE_URL, so this may be absent there.
   */
  DATABASE_PASSWORD: z.string().default(""),
  DATABASE_ADMIN_DATABASE: z.string().default("postgres"),
  /**
   * Managed Postgres (Neon, Render Postgres, Supabase) hands out one
   * connection string instead of discrete fields. When present it wins over
   * DATABASE_HOST/PORT/NAME/USER/PASSWORD.
   */
  DATABASE_URL: z.string().optional(),
  /** Force TLS on/off. Unset = on whenever DATABASE_URL is used. */
  DATABASE_SSL: z
    .string()
    .default("")
    .transform((value) => (value === "" ? undefined : value === "true")),
  DB_AUTO_CREATE: z.string().default("true").transform(v => v === "true"),
  DB_AUTO_INIT_SCHEMA: z.string().default("true").transform(v => v === "true"),
  DB_VERIFY_SCHEMA: z.string().default("true").transform(v => v === "true"),
  GOOGLE_CLIENT_IDS: z.string().min(1),
  JWT_SECRET: z.string().min(32),
  JWT_EXPIRES_IN: z.string().default("7d"),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
  IDLE_TIMEOUT_SECONDS: z.coerce.number().int().positive().default(360),
  LOCKOUT_TIER1_SECONDS: z.coerce.number().int().positive().default(16),
  LOCKOUT_TIER2_SECONDS: z.coerce.number().int().positive().default(32),
  LOCKOUT_TIER3_SECONDS: z.coerce.number().int().positive().default(64),
  IP_BLOCK_THRESHOLD: z.coerce.number().int().positive().default(13),
  IP_BLOCK_SECONDS: z.coerce.number().int().positive().default(600),
  ENCRYPTION_KEY: z
    .string()
    .min(44)
    .default("dGFoYW5hbi1kZXYtb25seS0zMi1ieXRlLWtleSEhISE="),
  CORS_ORIGINS: z.string().default("*"),
  APP_PUBLIC_URL: z.string().default("http://localhost:5173"),
  RECAPTCHA_SITE_KEY: z.string().default(""),
  RECAPTCHA_SECRET_KEY: z.string().default(""),
  RECAPTCHA_ENABLED: z
    .string()
    .default("true")
    .transform((value) => value !== "false"),
  SMTP_HOST: z.string().default(""),
  SMTP_PORT: z.coerce.number().int().positive().default(587),
  SMTP_SECURE: z
    .string()
    .default("false")
    .transform((value) => value === "true"),
  SMTP_USER: z.string().default(""),
  SMTP_PASS: z.string().default(""),
  SMTP_FROM: z.string().default(""),
  /**
   * Render's free plan blocks outbound SMTP (ports 25/465/587), so deployed
   * instances send mail through Brevo's HTTPS API instead. When this key is
   * present it takes precedence over SMTP.
   */
  BREVO_API_KEY: z.string().default(""),
  /**
   * Off by default: a one-time code is a credential and must never reach the
   * logs. Set to "true" only on a local demo box where SMTP is unavailable and
   * the operator needs to read the code from the console.
   */
  OTP_DEBUG_CODES: z
    .string()
    .default("false")
    .transform((value) => value === "true")
});

export const env = envSchema.parse(process.env);
export const googleClientIds = env.GOOGLE_CLIENT_IDS.split(",").map(v => v.trim()).filter(Boolean);
export const corsOrigins = env.CORS_ORIGINS === "*" ? "*" : env.CORS_ORIGINS.split(",").map(v => v.trim()).filter(Boolean);
