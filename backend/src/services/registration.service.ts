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
  const governmentLookup = lookupHash(input.government_id);
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

  const values = [
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
  ];

  // An unverified account with these details is the same person retrying.
  // Refresh it and issue a new code instead of saying everything is taken.
  const existing = await query<{ id: string; status: string }>(
    `SELECT id, status FROM users
      WHERE lower(email) = lower($1)
         OR id_number = $2
         OR lower(username) = lower($3)
         OR government_id_lookup = $4
      LIMIT 1`,
    [input.email, input.id_number, input.username, governmentLookup]
  );

  let user: { id: string; email: string; display_name: string };
  let resumed = false;

  if (existing.rows[0]?.status === "pending") {
    const id = existing.rows[0].id;
    const conflict = await query(
      `SELECT 1 FROM users
        WHERE id <> $1
          AND (lower(email) = lower($2)
            OR id_number = $3
            OR lower(username) = lower($4)
            OR government_id_lookup = $5)
        LIMIT 1`,
      [id, input.email, input.id_number, input.username, governmentLookup]
    );
    if (conflict.rowCount) {
      throw new HttpError(
        409,
        "DETAILS_IN_USE",
        "One of these details is already registered to another account."
      );
    }

    await query(
      `UPDATE users SET
          email = $2, display_name = $3, username = $4,
          password_hash = $5, password_changed_at = now(),
          privacy_consent_at = now(),
          status = 'pending', email_verified_at = NULL,
          id_number = $6, first_name = $7, middle_name = $8,
          family_name = $9, name_extension = $10,
          birthdate = $11, age = $12,
          address_purok = $13, address_barangay = $14, address_city = $15,
          address_province = $16, address_country = $17, address_zip = $18,
          government_id_ciphertext = $19, government_id_iv = $20,
          government_id_tag = $21, government_id_lookup = $22,
          move_in_date = $23, room_type = $24, emergency_contact = $25,
          tenancy_notes = $26,
          failed_login_count = 0, locked_until = NULL,
          token_version = token_version + 1, updated_at = now()
        WHERE id = $1`,
      [id, ...values.slice(1)]
    );

    user = { id, email: input.email, display_name: displayName };
    resumed = true;
  } else {
    const duplicateId = await query(
      "SELECT 1 FROM users WHERE id_number = $1",
      [input.id_number]
    );
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
      values
    );
    user = inserted.rows[0];
  }

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
    eventType: resumed ? "REGISTRATION_RESUMED" : "REGISTERED",
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
