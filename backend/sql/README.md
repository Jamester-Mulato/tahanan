# Schema pipeline

The authoritative order is the manifest in `src/utils/db-init.ts`:

| Version | File | Notes |
|---|---|---|
| 001 | `001_schema.sql` | Structural base. Checksum is verified strictly. |
| 008 | `008_baseline_handout.sql` | Everything the handout added. Idempotent. |
| 009 | `009_admin_console.sql` | `admin_audit`, `client_error_logs`. |
| 010 | `010_runtime_settings.sql` | `app_settings`. |
| 011 | `011_auth_tables.sql` | Sessions, OTP, password history, remember-me. |

Each applied file is recorded in `schema_migrations(version, checksum)`.
A version is applied once; a changed file is re-applied once and re-recorded.
A plain restart applies nothing.

`002`–`007` are historical and already folded into `008`. They are kept only
because older documentation points at `002_seed.sql` for a manual seed.
`tahanan_dump.sql` is a data snapshot, not a schema source.
