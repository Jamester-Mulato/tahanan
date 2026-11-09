import crypto from "node:crypto";
import { env } from "../config/env";

function key(): Buffer {
  const decoded = Buffer.from(env.ENCRYPTION_KEY, "base64");
  if (decoded.length !== 32) {
    throw new Error("ENCRYPTION_KEY must be 32 bytes, base64 encoded.");
  }
  return decoded;
}

export interface EncryptedField {
  ciphertext: string;
  iv: string;
  tag: string;
}

/** AES-256-GCM with a random IV per value (protection 13 / S2). */
export function encryptField(plain: string): EncryptedField {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key(), iv);
  const ciphertext = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  return {
    ciphertext: ciphertext.toString("base64"),
    iv: iv.toString("base64"),
    tag: cipher.getAuthTag().toString("base64")
  };
}

export function decryptField(input: EncryptedField): string {
  const decipher = crypto.createDecipheriv(
    "aes-256-gcm",
    key(),
    Buffer.from(input.iv, "base64")
  );
  decipher.setAuthTag(Buffer.from(input.tag, "base64"));
  const plain = Buffer.concat([
    decipher.update(Buffer.from(input.ciphertext, "base64")),
    decipher.final()
  ]);
  return plain.toString("utf8");
}

/** Deterministic lookup so a unique index still works on encrypted data. */
export function lookupHash(value: string): string {
  return crypto.createHmac("sha256", key()).update(value.trim().toLowerCase()).digest("hex");
}
