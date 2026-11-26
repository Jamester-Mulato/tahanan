import fs from "node:fs";
import path from "node:path";
import nodemailer, { type Transporter } from "nodemailer";
import { env } from "../config/env";

/** Philippine time stamp so each code email is its own thread and the newest
 *  message is obvious in Gmail. */
function phtStamp(): string {
  return new Date().toLocaleTimeString("en-PH", {
    timeZone: "Asia/Manila",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  });
}

/** Full date and time in Philippine time, for security alerts. */
function phtDateTime(): string {
  return new Date().toLocaleString("en-PH", {
    timeZone: "Asia/Manila",
    year: "numeric",
    month: "short",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: true
  });
}

let cached: Transporter | null | undefined;

function transporter(): Transporter | null {
  if (cached !== undefined) return cached;

  if (!env.SMTP_HOST || !env.SMTP_USER || !env.SMTP_PASS) {
    cached = null;
    return null;
  }

  cached = nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_SECURE,
    auth: { user: env.SMTP_USER, pass: env.SMTP_PASS },
    // Render (and many hosts) silently drop SMTP packets; fail fast instead
    // of hanging the request for two minutes.
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 15000
  });

  return cached;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function logoSettings() {
  const logoPath = path.resolve(process.cwd(), "assets", "tahanan_logo.png");
  if (!fs.existsSync(logoPath)) return { logoPath: null, attachments: [] };

  return {
    logoPath,
    attachments: [
      {
        filename: "tahanan-logo.png",
        path: logoPath,
        cid: "tahanan-logo"
      }
    ]
  };
}

function emailShell(input: {
  preheader: string;
  heading: string;
  body: string;
  hasLogo: boolean;
}): string {
  const logo = input.hasLogo
    ? `<img src="cid:tahanan-logo" width="64" height="64" alt="Tahanan"
         style="display:block; width:64px; height:64px; border-radius:18px; margin:0 auto 10px;">`
    : "";

  return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${escapeHtml(input.heading)}</title>
  </head>
  <body style="margin:0; padding:0; background:#f4faf6; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">
    <div style="display:none; max-height:0; overflow:hidden; opacity:0;">${escapeHtml(input.preheader)}</div>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4faf6; padding:28px 14px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:540px; background:#ffffff; border:1px solid #d8eee2; border-radius:20px; overflow:hidden;">
            <tr>
              <td style="background:#06301d; padding:24px 24px 20px; text-align:center;">
                ${logo}
                <div style="color:#ffffff; font-size:18px; font-weight:700; letter-spacing:-0.3px;">Tahanan Secure</div>
                <div style="color:#a9c9b8; font-size:10px; font-weight:600; letter-spacing:1.4px; margin-top:4px;">BOARDING HOUSE PORTAL</div>
              </td>
            </tr>
            <tr>
              <td style="padding:26px 26px 8px;">
                <h1 style="margin:0 0 14px; color:#0b1f14; font-size:20px; line-height:1.25; letter-spacing:-0.4px;">${escapeHtml(input.heading)}</h1>
                <div style="color:#33463c; font-size:14px; line-height:1.65;">
                  ${input.body}
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 26px 22px;">
                <div style="height:1px; background:#e4efe8; margin-bottom:14px;"></div>
                <p style="margin:0; color:#7a9486; font-size:11px; line-height:1.5;">
                  Tahanan Secure · Boarding house tenant &amp; rent portal<br>
                  This is an automated message. Please do not reply.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

/** "Tahanan Secure <name@example.com>" -> Brevo sender identity. */
function senderIdentity(): { name: string; email: string } {
  const raw = (env.SMTP_FROM || env.SMTP_USER || "").trim();
  const match = raw.match(/^(.*?)\s*<([^>]+)>\s*$/);
  if (match) {
    return {
      name: match[1].trim() || "Tahanan Secure",
      email: match[2].trim()
    };
  }
  return { name: "Tahanan Secure", email: raw };
}

/**
 * Brevo (https://brevo.com) delivers over HTTPS, which is the only option on
 * hosts that block outbound SMTP ports (Render's free plan blocks 25/465/587).
 */
async function sendViaBrevo(input: {
  to: string;
  subject: string;
  text: string;
  html: string;
}): Promise<void> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": env.BREVO_API_KEY,
        "content-type": "application/json",
        accept: "application/json"
      },
      body: JSON.stringify({
        sender: senderIdentity(),
        to: [{ email: input.to }],
        subject: input.subject,
        htmlContent: input.html,
        textContent: input.text
      }),
      signal: controller.signal
    });

    if (!response.ok) {
      const detail = await response.text().catch(() => "");
      throw new Error(
        `Brevo rejected the message (${response.status}): ${detail.slice(0, 300)}`
      );
    }
  } finally {
    clearTimeout(timer);
  }
}

async function send(input: {
  to: string;
  subject: string;
  text: string;
  html: string;
}): Promise<boolean> {
  if (env.BREVO_API_KEY) {
    await sendViaBrevo(input);
    return true;
  }

  const client = transporter();
  const logo = logoSettings();

  if (!client) {
    console.log(
      `[dev-mail] to=${input.to} subject=${input.subject}\n${input.text}`
    );
    return false;
  }

  await client.sendMail({
    from: env.SMTP_FROM || `Tahanan Secure <${env.SMTP_USER}>`,
    to: input.to,
    subject: input.subject,
    text: input.text,
    html: input.html,
    attachments: logo.attachments
  });
  return true;
}

export async function sendPasswordResetCode(input: {
  to: string;
  name: string;
  code: string;
  expiresMinutes: number;
}): Promise<boolean> {
  const logo = logoSettings();
  const name = escapeHtml(input.name);
  const code = escapeHtml(input.code);

  return send({
    to: input.to,
    subject: `Tahanan Secure - your password reset code (${phtStamp()})`,
    text: [
      "Tahanan Secure",
      "",
      `Hello ${input.name},`,
      "",
      `Your password reset code is: ${input.code}`,
      `It expires in ${input.expiresMinutes} minutes.`,
      "",
      "If you did not request this code, ignore this email and consider changing your password."
    ].join("\n"),
    html: emailShell({
      preheader: `Your Tahanan Secure reset code is ${input.code}`,
      heading: "Reset your password",
      hasLogo: Boolean(logo.logoPath),
      body: `
        <p style="margin:0 0 14px;">Hello ${name},</p>
        <p style="margin:0 0 18px;">Use this code to choose a new password:</p>
        <div style="background:#f4faf6; border:1px solid #d8eee2; border-radius:14px; padding:18px; text-align:center; margin-bottom:18px;">
          <div style="font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:32px; font-weight:800; letter-spacing:9px; color:#0f7a44;">${code}</div>
        </div>
        <p style="margin:0 0 8px;">The code expires in <strong>${input.expiresMinutes} minutes</strong> and can be used once.</p>
        <p style="margin:0; color:#7a9486; font-size:12px;">If you did not request this code, ignore this email and consider changing your password.</p>
      `
    })
  });
}

export async function sendRegistrationOtp(input: {
  to: string;
  name: string;
  code: string;
  expiresMinutes: number;
}): Promise<boolean> {
  const logo = logoSettings();
  const name = escapeHtml(input.name);
  const code = escapeHtml(input.code);

  return send({
    to: input.to,
    subject: `Tahanan Secure - verify your account (${phtStamp()})`,
    text: [
      "Tahanan Secure",
      "",
      `Hello ${input.name},`,
      "",
      `Your verification code is: ${input.code}`,
      `It expires in ${input.expiresMinutes} minutes and can be used once.`,
      "",
      "If you did not request this code, ignore this email and consider changing your password."
    ].join("\n"),
    html: emailShell({
      preheader: `Your Tahanan Secure verification code is ${input.code}`,
      heading: "Verify your account",
      hasLogo: Boolean(logo.logoPath),
      body: `
        <p style="margin:0 0 14px;">Hello ${name},</p>
        <p style="margin:0 0 18px;">Enter this code to activate your account:</p>
        <div style="background:#f4faf6; border:1px solid #d8eee2; border-radius:14px; padding:18px; text-align:center; margin-bottom:18px;">
          <div style="font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:32px; font-weight:800; letter-spacing:9px; color:#0f7a44;">${code}</div>
        </div>
        <p style="margin:0 0 8px;">The code expires in <strong>${input.expiresMinutes} minutes</strong> and can be used once.</p>
        <p style="margin:0; color:#7a9486; font-size:12px;">If you did not request this code, ignore this email and consider changing your password.</p>
      `
    })
  });
}

export async function sendLoginOtp(input: {
  to: string;
  name: string;
  code: string;
  expiresMinutes: number;
}): Promise<boolean> {
  const logo = logoSettings();
  const name = escapeHtml(input.name);
  const code = escapeHtml(input.code);

  return send({
    to: input.to,
    subject: `Tahanan Secure - your log-in code (${phtStamp()})`,
    text: [
      "Tahanan Secure",
      "",
      `Hello ${input.name},`,
      "",
      `Your log-in code is: ${input.code}`,
      `It expires in ${input.expiresMinutes} minutes and can be used once.`,
      "",
      "If you did not request this code, ignore this email and consider",
      "changing your password."
    ].join("\n"),
    html: emailShell({
      preheader: `Your Tahanan Secure log-in code is ${input.code}`,
      heading: "Your log-in code",
      hasLogo: Boolean(logo.logoPath),
      body: `
        <p style="margin:0 0 14px;">Hello ${name},</p>
        <p style="margin:0 0 18px;">Enter this code to finish signing in:</p>
        <div style="background:#f4faf6; border:1px solid #d8eee2; border-radius:14px; padding:18px; text-align:center; margin-bottom:18px;">
          <div style="font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:32px; font-weight:800; letter-spacing:9px; color:#0f7a44;">${code}</div>
        </div>
        <p style="margin:0 0 8px;">The code expires in <strong>${input.expiresMinutes} minutes</strong> and can be used once.</p>
        <p style="margin:0; color:#7a9486; font-size:12px;">If you did not request this code, ignore this email and consider changing your password.</p>
      `
    })
  });
}

export async function sendFailedLoginAlert(input: {
  to: string;
  name: string;
  attempts: number;
  seconds?: number;
  ip?: string;
  userAgent?: string;
}): Promise<boolean> {
  const logo = logoSettings();
  const name = escapeHtml(input.name);
  const ip = escapeHtml(input.ip || "unknown");
  const agent = escapeHtml(input.userAgent || "unknown");
  const when = phtDateTime();
  const resetLink = `${env.APP_PUBLIC_URL.replace(/\/+$/, "")}/?forgot=1`;
  const locked = input.seconds && input.seconds > 0;
  const lockLine = locked
    ? `For your protection the account is locked for ${input.seconds} seconds.`
    : "If the attempts continue, the account will be temporarily locked.";

  return send({
    to: input.to,
    subject: `Failed sign-in attempt on your account (${phtStamp()})`,
    text: [
      "Tahanan Secure",
      "",
      `Hello ${input.name},`,
      "",
      `A sign-in attempt on your account failed (attempt ${input.attempts}).`,
      lockLine,
      "",
      `Date and time (PHT): ${when}`,
      `IP address: ${input.ip || "unknown"}`,
      `Browser/device: ${input.userAgent || "unknown"}`,
      "",
      "If this was you, you can ignore this message. If it was not, reset your password now:",
      resetLink
    ].join("\n"),
    html: emailShell({
      preheader: "A sign-in attempt on your Tahanan Secure account failed",
      heading: "Failed sign-in attempt",
      hasLogo: Boolean(logo.logoPath),
      body: `
        <p style="margin:0 0 14px;">Hello ${name},</p>
        <p style="margin:0 0 16px;">A sign-in attempt on your account failed
        (attempt <strong>${input.attempts}</strong>). ${escapeHtml(lockLine)}</p>
        <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%; background:#f4faf6; border:1px solid #d8eee2; border-radius:14px; padding:14px; margin-bottom:16px;">
          <tr><td style="padding:4px 12px; color:#7a9486; font-size:11px;">DATE AND TIME (PHT)</td><td style="padding:4px 12px; color:#0b1f14; font-size:12px;">${when}</td></tr>
          <tr><td style="padding:4px 12px; color:#7a9486; font-size:11px;">IP ADDRESS</td><td style="padding:4px 12px; color:#0b1f14; font-size:12px; font-family:ui-monospace,monospace;">${ip}</td></tr>
          <tr><td style="padding:4px 12px; color:#7a9486; font-size:11px;">DEVICE</td><td style="padding:4px 12px; color:#0b1f14; font-size:12px;">${agent}</td></tr>
        </table>
        <p style="margin:0;">If this was not you, <a href="${escapeHtml(resetLink)}" style="color:#0f7a44; font-weight:700;">reset your password now</a>.</p>
      `
    })
  });
}

export async function sendPasswordChangedAlert(input: {
  to: string;
  name: string;
  ip?: string;
  userAgent?: string;
}): Promise<boolean> {
  const logo = logoSettings();
  const name = escapeHtml(input.name);
  const ip = escapeHtml(input.ip || "unknown");
  const agent = escapeHtml(input.userAgent || "unknown");
  const when = phtDateTime();
  const resetLink = `${env.APP_PUBLIC_URL.replace(/\/+$/, "")}/?forgot=1`;

  return send({
    to: input.to,
    subject: "Your password was changed",
    text: [
      "Tahanan Secure",
      "",
      `Hello ${input.name},`,
      "",
      "Your password was changed and every other session was signed out.",
      "",
      `Date and time (PHT): ${when}`,
      `IP address: ${input.ip || "unknown"}`,
      `Browser/device: ${input.userAgent || "unknown"}`,
      "",
      "If this was not you, reset your password now:",
      resetLink
    ].join("\n"),
    html: emailShell({
      preheader: "Your Tahanan Secure password was changed",
      heading: "Your password was changed",
      hasLogo: Boolean(logo.logoPath),
      body: `
        <p style="margin:0 0 14px;">Hello ${name},</p>
        <p style="margin:0 0 16px;">Your password was changed and every other session was signed out.</p>
        <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%; background:#f4faf6; border:1px solid #d8eee2; border-radius:14px; padding:14px; margin-bottom:16px;">
          <tr><td style="padding:4px 12px; color:#7a9486; font-size:11px;">DATE AND TIME (PHT)</td><td style="padding:4px 12px; color:#0b1f14; font-size:12px;">${when}</td></tr>
          <tr><td style="padding:4px 12px; color:#7a9486; font-size:11px;">IP ADDRESS</td><td style="padding:4px 12px; color:#0b1f14; font-size:12px; font-family:ui-monospace,monospace;">${ip}</td></tr>
          <tr><td style="padding:4px 12px; color:#7a9486; font-size:11px;">DEVICE</td><td style="padding:4px 12px; color:#0b1f14; font-size:12px;">${agent}</td></tr>
        </table>
        <p style="margin:0;">If this was not you, <a href="${escapeHtml(resetLink)}" style="color:#0f7a44; font-weight:700;">reset your password now</a>.</p>
      `
    })
  });
}

export function mailConfigured(): boolean {
  if (env.BREVO_API_KEY) return true;
  return Boolean(env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASS);
}
