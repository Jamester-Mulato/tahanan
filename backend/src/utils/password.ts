import crypto from "node:crypto";

// scrypt ships with Node, so password auth needs no native build step.
const KEY_LENGTH = 64;
const DEFAULT_OPTIONS = { N: 16384, r: 8, p: 1 } as const;

function derive(
  password: string,
  salt: Buffer,
  keyLength: number,
  options: { N: number; r: number; p: number }
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, keyLength, options, (error, derivedKey) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(derivedKey);
    });
  });
}

/** Returns `scrypt$N$r$p$salt$hash`, all base64 except the parameters. */
export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.randomBytes(16);
  const derived = await derive(password, salt, KEY_LENGTH, DEFAULT_OPTIONS);
  return [
    "scrypt",
    DEFAULT_OPTIONS.N,
    DEFAULT_OPTIONS.r,
    DEFAULT_OPTIONS.p,
    salt.toString("base64"),
    derived.toString("base64")
  ].join("$");
}

export async function verifyPassword(
  password: string,
  stored: string | null | undefined
): Promise<boolean> {
  if (!stored) return false;

  const parts = stored.split("$");
  if (parts.length !== 6 || parts[0] !== "scrypt") return false;

  const N = Number(parts[1]);
  const r = Number(parts[2]);
  const p = Number(parts[3]);
  if (!Number.isInteger(N) || !Number.isInteger(r) || !Number.isInteger(p)) {
    return false;
  }

  const salt = Buffer.from(parts[4], "base64");
  const expected = Buffer.from(parts[5], "base64");
  if (salt.length === 0 || expected.length === 0) return false;

  const derived = await derive(password, salt, expected.length, { N, r, p });
  return (
    derived.length === expected.length &&
    crypto.timingSafeEqual(derived, expected)
  );
}
