# Privacy note (RA 10173)

**System:** Tahanan — Boarding House Tenant & Rent System
**Personal information controller:** the boarding-house owner / system
administrator (Jamester C. Mulato, jamestermulato@gmail.com).
**Complaints:** National Privacy Commission — privacy.gov.ph.

## What is collected, and why each field is needed

| Field | Classification | Why it is needed |
|---|---|---|
| ID Number (`xxxx-xxxx`) | Personal information | Unique identity inside the boarding house; prevents duplicate tenant records. |
| First / Middle / Family Name, Name Extension | Personal information | Identifies the tenant on the lease, room list and receipts. |
| Birthdate and computed Age | Personal information | Confirms the tenant is at least 18; age is derived, never typed. |
| Purok/Street, Barangay, City, Province, Country, ZIP | Personal information | Contact address for emergencies and for the tenancy record. |
| Email address | Personal information | Account identifier and the only channel for OTPs and security alerts. |
| Username | Personal information | Sign-in identifier. |
| Password | Secret, **hashed with scrypt** | Account protection; the plain value is never stored or logged. |
| Three security answers | Secret, **hashed with scrypt** | Account recovery when the password is forgotten. |
| Government ID Number | **Sensitive personal information**, encrypted with AES-256-GCM | Required by the owner before move-in to verify identity; shown only to its owner and the owner of the house. |
| Move-in Date | Personal information | Rent start date. |
| Room Type, tenancy notes | Personal information | Room assignment and billing; notes are optional. |
| Emergency contact number | Personal information | Contact if the tenant is unreachable in an emergency. |
| Privacy consent timestamp | Personal information | Proof that consent was given under RA 10173. |
| Activity log: event, typed identifier, IP address, browser/device, time | Personal information | Security monitoring, lockout and incident investigation. |
| One-time codes | Secret, **hashed**; short expiry | Prove the person controls the email inbox. |

Nothing else is collected. There are no analytics, advertising or tracking SDKs,
and the Government ID is the only field that is encrypted rather than hashed.

## How the data is protected

- Passwords, security answers and OTP codes are stored as one-way scrypt hashes.
- The Government ID is AES-256-GCM encrypted with a random IV; the database
  shows unreadable ciphertext.
- Access is authorised on the server on every request with a signed JWT.
- Sign-in is rate-limited (3/6/9 lockout, 13 failures per IP in 10 minutes), and
  an idle session ends after six minutes.
- Security events are written to an append-only activity log.
- Secrets live in `backend/.env`, which is git-ignored and never served.

## How long it is kept

Tenant data is kept while the tenancy is active and for **one year** after it
ends, then the personal fields are erased. Security logs are kept for one year.
Backups follow the same retention.

## Rights of the data subject

Under RA 10173 the tenant may ask to see, correct, or erase their data, object to
processing, or file a complaint with the National Privacy Commission. Requests
go to the administrator at the contact above; the app already lets a tenant
change their own password and view their stored profile.

## Consent

Registration shows this notice through a “Read the Privacy Notice” link and
requires an unchecked-by-default checkbox with the exact text:

> I have read the Privacy Notice and agree to the collection and processing of
> my personal data in accordance with the Data Privacy Act of 2012 (RA 10173).

Registration is refused until the box is ticked, and the server stores the date
and time in `users.privacy_consent_at`.
