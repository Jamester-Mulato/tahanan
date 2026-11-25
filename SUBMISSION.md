# IT 107 Final Laboratory Project — Submission

**System:** Tahanan — Boarding House Tenant & Rent System
**Student:** Jamester C. Mulato (241-00315, D1 = 1, D2 = 5)
**Repository:** https://github.com/Jamester-Mulato/tahanan

## What is in this repository

| Requirement | Where |
|---|---|
| Written documentation (.docx) | [`docs/submission/IT107_Tahanan_Final_Project_Documentation.docx`](docs/submission/IT107_Tahanan_Final_Project_Documentation.docx) |
| System Proposal (Appendix A) | Document section 2 |
| Seed table (section 2.2) | Document page 1 |
| Threat Model (Appendix B) | Document section 3 |
| Design Decisions (every "Your call") | Document section 4 |
| Privacy Note (RA 10173) | Document section 5 |
| Error Message Mapping | Document section 6 |
| Development Journal (Appendix C) | Document section 7 |
| Test accounts | Document section 8 |
| SQL dump | [`backend/sql/tahanan_dump.sql`](backend/sql/tahanan_dump.sql) |
| Monitoring script | [`backend/scripts/monitor.ts`](backend/scripts/monitor.ts) |
| Demo-account seeder | [`backend/scripts/seed-test-accounts.ts`](backend/scripts/seed-test-accounts.ts) |
| Repeatable test records | [`backend/scripts/seed-demo-evidence.ts`](backend/scripts/seed-demo-evidence.ts) |

The Word file is generated from [`docs/build_submission_docx.py`](docs/build_submission_docx.py)
so the document and the code cannot drift apart:

```powershell
py docs/build_submission_docx.py
```

## Test accounts

| Role | Username | Password | Inbox |
|---|---|---|---|
| Admin | `tahananadmin` | `Admin#24100315` | jamestermulato+admin@gmail.com |
| User 1 | `devicetest` | `AppTest2026` | jamestermulato+device@gmail.com |
| User 2 | `hand2372` | `Handout#2027` | jamestermulato+h2372@gmail.com |

All three deliver OTPs and alerts to `jamestermulato@gmail.com` through
plus-addressing. Security answers: Q6 `Bahay Kubo`, Q1 `Bantay`, Q3 `Mrs Cruz`.

Re-seed at any time (idempotent, safe before a demo):

```powershell
cd backend
npx tsx scripts/seed-test-accounts.ts
npx tsx scripts/seed-demo-evidence.ts
npx tsx scripts/monitor.ts
```

These are deliberate demo credentials for a school project. No real
deployment uses them.

## Run

```powershell
# API
cd backend
npm install
copy .env.example .env   # then fill in the values
npm run dev

# Flutter app (web)
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Secrets live in `backend/.env`, which is git-ignored. `backend/.env.example`
contains placeholders only.

## Verification

```powershell
cd backend
npx tsx scripts/verify-handout.ts   # admin access, idle timeout, CSRF, headers
npx tsx scripts/monitor.ts          # four-pattern detection
```

## Still requires the student

- Signature and date on Appendix A (instructor, Checkpoint 1).
- The live demo and the on-the-spot requirement.
- The commit history is the real one; it was not rewritten to look older.
