# Test accounts

All three accounts use the real OTP mailbox
**jamestermulato@gmail.com** (plus-addressing: the `+tag` still lands in the
same inbox), so every code and alert can be opened on demo day.

| Role | Username | Password | Email | Notes |
|---|---|---|---|---|
| Admin | `tahananadmin` | `Admin#24100315` | jamestermulato+admin@gmail.com | Created directly in the database; `is_admin = true`; sees the Security monitoring tile in More |
| User 1 | `devicetest` | `AppTest2026` | jamestermulato+device@gmail.com | Owns a boarding house and rooms |
| User 2 | `hand2372` | `Handout#2027` | jamestermulato+h2372@gmail.com | ID Number 2027-2372 |
| Backup admin | `jamester123` | (student's own) | jamestermulato@gmail.com | Existing owner account, `is_admin = true` |

Security-question answers for all three demo accounts:

| Question | Answer |
|---|---|
| Q6 first song learned by heart | `Bahay Kubo` |
| Q1 first pet | `Bantay` |
| Q3 favorite high-school teacher | `Mrs Cruz` |

Reset or re-create them at any time:

```powershell
cd backend
npx tsx scripts/seed-test-accounts.ts
```

The script verifies each documented password first and only rewrites a hash
when it does not match, so it is safe to re-run before a demo.

**Security note:** these are deliberate demo credentials for a school project.
They are not used by any real deployment.
