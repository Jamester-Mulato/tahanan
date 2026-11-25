-- 009_admin_console.sql
-- Admin console data: an audit trail for privileged actions and a place for
-- client-side errors reported by the apps.

BEGIN;

CREATE TABLE IF NOT EXISTS admin_audit (
    id            BIGSERIAL PRIMARY KEY,
    admin_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action        TEXT NOT NULL,
    target        TEXT,
    details       JSONB,
    ip_address    TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_created
    ON admin_audit (created_at DESC);

CREATE TABLE IF NOT EXISTS client_error_logs (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
    username    TEXT,
    platform    TEXT,
    app_version TEXT,
    message     TEXT NOT NULL,
    stack       TEXT,
    screen      TEXT,
    extra       JSONB,
    ip_address  TEXT,
    user_agent  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_errors_created
    ON client_error_logs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_client_errors_user
    ON client_error_logs (user_id);

COMMIT;
