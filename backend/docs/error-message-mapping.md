# Error message mapping

Every validation rule in registration and account management, with the exact
message the user sees. The server is the authority; the app shows the same text.

## Core fields

| Field | Rule | Exact message |
|---|---|---|
| ID Number | required | ID Number is required. |
| ID Number | `xxxx-xxxx` | ID Number must follow the format xxxx-xxxx. |
| ID Number | unique | This ID Number is already registered. |
| First Name | required | First Name is required. |
| First / Middle / Family Name | 2–25 characters | {First Name} must be 2 to 25 characters. |
| First / Middle / Family Name | no digits | Numbers are not allowed in {First Name}. |
| First / Middle / Family Name | no special characters | Special characters are not allowed in {First Name}. |
| First / Middle / Family Name | no double space | Double space is not allowed. |
| First / Middle / Family Name | not all capitals | Do not use all capital letters. |
| First / Middle / Family Name | no three identical letters | Three consecutive identical letters are not allowed. |
| First / Middle / Family Name | Title Case | First letter of your name must be capital. |
| Name Extension | dropdown value | Please select a valid name extension. |
| Name Extension = Other | custom value | Choose I, II, III, IV, IX or X for Other. |
| Birthdate | required / real date | Enter a valid birthdate. |
| Birthdate | not future | A birthdate in the future is not allowed. |
| Birthdate | 18 or older | You must be at least 18 years old to register. |
| Purok / Street | required | Purok / Street is required. |
| Purok / Street | 3–50 letters, digits, spaces | Purok / Street must be 3 to 50 letters, digits and spaces, without double spaces. |
| Barangay / City / Province / Country | required | {Barangay} is required. |
| Barangay / City / Province / Country | 2–50 letters, Title Case | {Barangay} must be 2 to 50 letters in Title Case. |
| ZIP Code | exactly 4 digits | ZIP Code must be exactly 4 digits. |
| Email | required / format / ≤100 | Please enter a valid email address. |
| Email | unique | This email is already registered. |
| Username | 7–16 characters | Username must be at least 7 characters. / Username must be at most 16 characters. |
| Username | starts with a letter, letters and digits | Username must start with a letter and use letters and digits only. |
| Username | unique | That username is already taken. |
| Username | live check | Username is available. / That username is already taken. |
| Password | minimum 9 | Password must be at least 9 characters. |
| Password | maximum 64 | Password must be at most 64 characters. |
| Password | uppercase + digit | Password must include an uppercase letter and a number. |
| Password | Weak | A weak password cannot be submitted. |
| Re-enter Password | must match | Passwords do not match. |
| Security answer A/B/C | 2–50 letters/spaces | Answer A must be 2 to 50 characters. / Answer A may contain letters and spaces only. |
| Privacy consent | must be ticked | You must agree to the Privacy Notice to register. |
| CAPTCHA | required | Complete the Google reCAPTCHA verification. / Enter the CAPTCHA answer. |

## System fields

| Field | Rule | Exact message |
|---|---|---|
| Government ID Number | `xxxx-xxxx-xxxx` | Government ID Number must follow the format xxxx-xxxx-xxxx. |
| Government ID Number | unique | This Government ID Number is already registered. |
| Move-in Date | required, 2000-01-01 … today | Move-in Date is required. / Move-in Date must be a valid date between 2000-01-01 and today. |
| Room Type | allowed dropdown values | Please select a valid room type. |
| Emergency Contact | 11 digits starting 09 | Contact number must be 11 digits and start with 09. |
| Tenancy Notes | optional, ≤200 | Tenancy Notes may contain letters, digits, commas, periods and spaces only, up to 200 characters. |

## Sign-in, OTP and password management

| Situation | Exact message |
|---|---|
| Wrong username or password | Invalid username or password. |
| Account locked | Too many attempts. Try again in N seconds. |
| IP blocked | Too many failed attempts. Try again in N seconds. |
| Wrong OTP | That code is wrong. N tries left. |
| 3 wrong OTPs | Too many wrong codes. Request a new one. |
| Expired OTP | That code has expired. Request a new one. |
| Already-used OTP | That code was already used. Request a new one. |
| Resend too soon | Wait N seconds before requesting another code. |
| Too many resends | Too many codes requested. Start again later. |
| Wrong security answer | One of those details is incorrect. |
| Answers do not match | Answers do not match. |
| Change Password mismatch | Mismatch Password |
| Current password wrong | Current password is incorrect. |
| Password reuse | You cannot reuse a recent password. |
| Change Password success | Successfully Change Password |
| Dashboard denial | Access denied. |
| CSRF refusal | This request did not come from the Tahanan app. |
| Idle timeout | Your session expired after inactivity. Please sign in again. |
