import type { Request } from "express";
import { query } from "../config/db";
import { encryptField, lookupHash } from "../security/crypto";
import { SEEDED_KEYS } from "../security/questions";
import {
  ageFromBirthdate,
  type RegistrationInput
} from "../security/registration";
import { hashPassword } from "../utils/password";
import { HttpError } from "../utils/http-error";
import { logAuthEvent } from "./auth-events.service";
import { recordPasswordHistory } from "./auth.service";

function extensionValue(input: RegistrationInput): string | null {
  if (input.name_extension === "Other") {
    return input.name_extension_other.trim().toUpperCase();
  }
  return input.name_extension || null;
}

/**
 * Creates an unverified account with every handout field, the encrypted
 * Government ID, and the three seeded security answers.
 */
export async function registerAccount(input: RegistrationInput, req?: Request) {
  const duplicateId = await query("SELECT 1 FROM users WHERE id_number = $1", [input.id_number]);
  if (duplicateId.rowCount) {
    throw new HttpError(409, "ID_IN_USE", "This ID Number is already registered.");
  }

  const duplicateUsername = await query(
    "SELECT 1 FROM users WHERE lower(username) = lower($1)",
    [input.username]
  );
  if (duplicateUsername.rowCount) {
    throw new HttpError(409, "USERNAME_TAKEN", "That username is already taken.");
  }

  const duplicateEmail = await query(
    "SELECT 1 FROM users WHERE lower(email) = lower($1)",
    [input.email]
  );
  if (duplicateEmail.rowCount) {
    throw new HttpError(409, "EMAIL_IN_USE", "This email is already registered.");
  }

  const governmentLookup = lookupHash(input.government_id);
  const duplicateGovernment = await query(
    "SELECT 1 FROM users WHERE government_id_lookup = $1",
    [governmentLookup]
  );
  if (duplicateGovernment.rowCount) {
    throw new HttpError(
      409,
      "GOVERNMENT_ID_IN_USE",
      "This Government ID Number is already registered."
    );
  }

  const passwordHash = await hashPassword(input.password);
  const government = encryptField(input.government_id);
  const age = ageFromBirthdate(input.birthdate) ?? 0;
  const extension = extensionValue(input);
  const displayName = [
    input.first_name,
    input.middle_name,
    input.family_name,
    extension
  ]
    .filter(Boolean)
    .join(" ");

  const inserted = await query<{ id: string; email: string; display_name: string }>(
    `INSERT INTO users (
        auth_provider, auth_provider_uid, email, display_name, username,
        password_hash, password_changed_at, privacy_consent_at,
        status, email_verified_at,
        id_number, first_name, middle_name, family_name, name_extension,
        birthdate, age,
        address_purok, address_barangay, address_city, address_province,
        address_country, address_zip,
        government_id_ciphertext, government_id_iv, government_id_tag,
        government_id_lookup,
        move_in_date, room_type, emergency_contact, tenancy_notes, is_admin
     ) VALUES (
        'password', $1, $2, $3, $4,
        $5, now(), now(),
        'pending', NULL,
        $6, $7, $8, $9, $10,
        $11, $12,
        $13, $14, $15, $16,
        $17, $18,
        $19, $20, $21,
        $22,
        $23, $24, $25, $26, FALSE
     )
     RETURNING id, email, display_name`,
    [
      input.email,
      input.email,
      displayName,
      input.username,
      passwordHash,
      input.id_number,
      input.first_name,
      input.middle_name || null,
      input.family_name,
      extension,
      input.birthdate,
      age,
      input.address_purok,
      input.address_barangay,
      input.address_city,
      input.address_province,
      input.address_country,
      input.address_zip,
      government.ciphertext,
      government.iv,
      government.tag,
      governmentLookup,
      input.move_in_date,
      input.room_type,
      input.emergency_contact,
      input.tenancy_notes || null
    ]
  );

  const user = inserted.rows[0];

  const answers: Record<(typeof SEEDED_KEYS)[number], string> = {
    Q6: input.answer_a,
    Q1: input.answer_b,
    Q3: input.answer_c
  };

  for (const key of SEEDED_KEYS) {
    const answerHash = await hashPassword(answers[key].trim().toLowerCase());
    await query(
      `INSERT INTO security_answers (user_id, question_key, answer_hash)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, question_key) DO UPDATE SET answer_hash = EXCLUDED.answer_hash`,
      [user.id, key, answerHash]
    );
  }

  await recordPasswordHistory(user.id, passwordHash);
  await logAuthEvent({
    eventType: "REGISTERED",
    userId: user.id,
    email: user.email,
    req,
    details: { username: input.username }
  });

  return user;
}

export async function activateAccount(userId: string, req?: Request) {
  await query(
    `UPDATE users
        SET status = 'active',
            email_verified_at = COALESCE(email_verified_at, now()),
            updated_at = now()
      WHERE id = $1`,
    [userId]
  );
  await logAuthEvent({
    eventType: "ACCOUNT_VERIFIED",
    userId,
    req
  });
}
