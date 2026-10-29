import crypto from "node:crypto";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export function generateJoinKey(): string {
  let value = "";
  for (let i = 0; i < 12; i += 1) {
    value += ALPHABET[crypto.randomInt(0, ALPHABET.length)];
  }
  return `${value.slice(0, 4)}-${value.slice(4, 8)}-${value.slice(8, 12)}`;
}

export function slugifyDomain(name: string): string {
  const base = name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 52);

  return base || "boarding-house";
}
