-- 010_runtime_settings.sql
-- Small key/value store for settings the admin can change without a redeploy.

BEGIN;

CREATE TABLE IF NOT EXISTS app_settings (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;
