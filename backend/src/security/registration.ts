/**
 * Server-side registration rules for the Tahanan system.
 * Every rule here is repeated on the client, but the server is the authority.
 * Credential rules themselves live in services/credential-policy so the
 * request layer, this validator and the domain layer cannot drift.
 */
import {
  PASSWORD_MAX_LENGTH,
  PASSWORD_MIN_LENGTH,
  USERNAME_MAX_LENGTH,
  USERNAME_MIN_LENGTH,
  passwordProblem as passwordPolicyProblem,
  usernameProblem as usernamePolicyProblem
} from "../services/credential-policy";

export const MIN_USERNAME = USERNAME_MIN_LENGTH;
export const MAX_USERNAME = USERNAME_MAX_LENGTH;
export const MIN_PASSWORD = PASSWORD_MIN_LENGTH;
export const MAX_PASSWORD = PASSWORD_MAX_LENGTH;
export const MAX_NAME = 25;
export const ROOM_TYPES = ["Single", "Shared", "Bedspacer", "Studio"] as const;
export const EXTENSION_OPTIONS = ["", "Jr.", "Sr.", "Other"] as const;
export const EXTENSION_CUSTOM = ["I", "II", "III", "IV", "IX", "X"] as const;

export interface RegistrationInput {
  id_number: string;
  first_name: string;
  middle_name: string;
  family_name: string;
  name_extension: string;
  name_extension_other: string;
  birthdate: string;
  age: string;
  address_purok: string;
  address_barangay: string;
  address_city: string;
  address_province: string;
  address_country: string;
  address_zip: string;
  email: string;
  username: string;
  password: string;
  repassword: string;
  government_id: string;
  move_in_date: string;
  room_type: string;
  emergency_contact: string;
  tenancy_notes: string;
  answer_a: string;
  answer_b: string;
  answer_c: string;
  consent: boolean;
  website?: string;
}

const str = (value: unknown) => (typeof value === "string" ? value.trim() : "");
const hasDoubleSpace = (value: string) => /\s{2,}/.test(value);

function titleCaseWords(value: string): boolean {
  return value
    .split(" ")
    .every((word) => word === "" || /^[A-Z][a-z]*$/.test(word));
}

export function ageFromBirthdate(birthdate: string): number | null {
  const date = new Date(`${birthdate}T00:00:00`);
  if (Number.isNaN(date.getTime())) return null;
  const today = new Date();
  let age = today.getFullYear() - date.getFullYear();
  const month = today.getMonth() - date.getMonth();
  if (month < 0 || (month === 0 && today.getDate() < date.getDate())) age--;
  return age;
}

function validateName(
  value: string,
  label: string,
  required: boolean
): string | null {
  if (!value) return required ? `${label} is required.` : null;
  if (value.length < 2 || value.length > MAX_NAME) {
    return `${label} must be 2 to ${MAX_NAME} characters.`;
  }
  if (/\d/.test(value)) return `Numbers are not allowed in ${label}.`;
  if (/[^A-Za-z ]/.test(value)) {
    return `Special characters are not allowed in ${label}.`;
  }
  if (hasDoubleSpace(value)) return "Double space is not allowed.";
  if (value === value.toUpperCase() && /[A-Z]/.test(value)) {
    return "Do not use all capital letters.";
  }
  if (/([A-Za-z])\1\1/.test(value)) {
    return "Three consecutive identical letters are not allowed.";
  }
  if (!titleCaseWords(value)) {
    return `First letter of your name must be capital.`;
  }
  return null;
}

export function normalizeRegistration(body: Record<string, unknown>): RegistrationInput {
  return {
    id_number: str(body.id_number),
    first_name: str(body.first_name),
    middle_name: str(body.middle_name),
    family_name: str(body.family_name),
    name_extension: str(body.name_extension),
    name_extension_other: str(body.name_extension_other),
    birthdate: str(body.birthdate),
    age: str(body.age),
    address_purok: str(body.address_purok),
    address_barangay: str(body.address_barangay),
    address_city: str(body.address_city),
    address_province: str(body.address_province),
    address_country: str(body.address_country),
    address_zip: str(body.address_zip),
    email: str(body.email).toLowerCase(),
    username: str(body.username),
    password: typeof body.password === "string" ? body.password : "",
    repassword: typeof body.repassword === "string" ? body.repassword : "",
    government_id: str(body.government_id),
    move_in_date: str(body.move_in_date),
    room_type: str(body.room_type),
    emergency_contact: str(body.emergency_contact),
    tenancy_notes: str(body.tenancy_notes),
    answer_a: str(body.answer_a),
    answer_b: str(body.answer_b),
    answer_c: str(body.answer_c),
    consent: body.consent === true || body.consent === "on" || body.consent === "true",
    website: str(body.website)
  };
}

export function validateRegistration(input: RegistrationInput): Record<string, string> {
  const errors: Record<string, string> = {};

  if (!input.id_number) {
    errors.id_number = "ID Number is required.";
  } else if (!/^\d{4}-\d{4}$/.test(input.id_number)) {
    errors.id_number = "ID Number must follow the format xxxx-xxxx.";
  }

  const first = validateName(input.first_name, "First Name", true);
  if (first) errors.first_name = first;
  const middle = validateName(input.middle_name, "Middle Name", false);
  if (middle) errors.middle_name = middle;
  const family = validateName(input.family_name, "Family Name", true);
  if (family) errors.family_name = family;

  if (input.name_extension && !EXTENSION_OPTIONS.includes(input.name_extension as never)) {
    errors.name_extension = "Please select a valid name extension.";
  }
  if (input.name_extension === "Other") {
    const other = input.name_extension_other.toUpperCase();
    if (!EXTENSION_CUSTOM.includes(other as never)) {
      errors.name_extension = "Choose I, II, III, IV, IX or X for Other.";
    }
  }

  const birthdate = new Date(`${input.birthdate}T00:00:00`);
  if (!input.birthdate || Number.isNaN(birthdate.getTime())) {
    errors.birthdate = "Enter a valid birthdate.";
  } else if (birthdate > new Date()) {
    errors.birthdate = "A birthdate in the future is not allowed.";
  } else if ((ageFromBirthdate(input.birthdate) ?? 0) < 18) {
    errors.birthdate = "You must be at least 18 years old to register.";
  }

  if (!input.address_purok) {
    errors.address_purok = "Purok / Street is required.";
  } else if (
    input.address_purok.length < 3 ||
    input.address_purok.length > 50 ||
    !/^[A-Za-z0-9 ]+$/.test(input.address_purok) ||
    hasDoubleSpace(input.address_purok)
  ) {
    errors.address_purok =
      "Purok / Street must be 3 to 50 letters, digits and spaces, without double spaces.";
  }

  for (const [key, label] of [
    ["address_barangay", "Barangay"],
    ["address_city", "Municipality / City"],
    ["address_province", "Province"],
    ["address_country", "Country"]
  ] as const) {
    const value = input[key];
    if (!value) {
      errors[key] = `${label} is required.`;
    } else if (
      value.length < 2 ||
      value.length > 50 ||
      !/^[A-Za-z ]+$/.test(value) ||
      !titleCaseWords(value)
    ) {
      errors[key] = `${label} must be 2 to 50 letters in Title Case.`;
    }
  }

  if (!/^\d{4}$/.test(input.address_zip)) {
    errors.address_zip = "ZIP Code must be exactly 4 digits.";
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email) || input.email.length > 100) {
    errors.email = "Please enter a valid email address.";
  }

  const usernameIssue = usernamePolicyProblem(input.username);
  if (usernameIssue) errors.username = usernameIssue;

  const passwordIssue = passwordPolicyProblem(input.password);
  if (passwordIssue) errors.password = passwordIssue;
  if (input.password !== input.repassword) {
    errors.repassword = "Passwords do not match.";
  }

  if (!/^\d{4}-\d{4}-\d{4}$/.test(input.government_id)) {
    errors.government_id =
      "Government ID Number must follow the format xxxx-xxxx-xxxx.";
  }

  const moveIn = new Date(`${input.move_in_date}T00:00:00`);
  if (!input.move_in_date || Number.isNaN(moveIn.getTime())) {
    errors.move_in_date = "Move-in Date is required.";
  } else if (moveIn < new Date("2000-01-01T00:00:00") || moveIn > new Date()) {
    errors.move_in_date =
      "Move-in Date must be a valid date between 2000-01-01 and today.";
  }

  if (!ROOM_TYPES.includes(input.room_type as never)) {
    errors.room_type = "Please select a valid room type.";
  }

  if (!/^09\d{9}$/.test(input.emergency_contact)) {
    errors.emergency_contact =
      "Contact number must be 11 digits and start with 09.";
  }

  if (input.tenancy_notes) {
    if (
      input.tenancy_notes.length > 200 ||
      !/^[A-Za-z0-9,.\s]+$/.test(input.tenancy_notes) ||
      hasDoubleSpace(input.tenancy_notes)
    ) {
      errors.tenancy_notes =
        "Tenancy Notes may contain letters, digits, commas, periods and spaces only, up to 200 characters.";
    }
  }

  for (const [key, label] of [
    ["answer_a", "A"],
    ["answer_b", "B"],
    ["answer_c", "C"]
  ] as const) {
    const value = input[key];
    if (value.length < 2 || value.length > 50) {
      errors[key] = `Answer ${label} must be 2 to 50 characters.`;
    } else if (!/^[A-Za-z ]+$/.test(value) || hasDoubleSpace(value)) {
      errors[key] = `Answer ${label} may contain letters and spaces only.`;
    }
  }

  if (!input.consent) {
    errors.consent = "You must agree to the Privacy Notice to register.";
  }

  return errors;
}
