-- 008_baseline_handout.sql
--
-- Brings a database created from sql/001_schema.sql (the original base
-- schema) up to the current handout schema. 001 is kept byte-for-byte stable
-- because existing databases verify its checksum at boot; everything the
-- handout added afterwards lives here instead.
--
-- Every statement is idempotent: running this on an up-to-date database
-- (including the original development database) changes nothing.

BEGIN;

-- ============================================================
-- 003_refinement: concern statuses + rating
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM pg_type t
      JOIN pg_enum e ON e.enumtypid = t.oid
     WHERE t.typname = 'concern_status'
       AND e.enumlabel = 'open'
  ) THEN
    DROP VIEW IF EXISTS v_boarding_house_dashboard;
    ALTER TABLE concerns ALTER COLUMN status DROP DEFAULT;
    ALTER TABLE concerns ALTER COLUMN status TYPE TEXT;
    UPDATE concerns SET status = 'unread' WHERE status = 'open';
    UPDATE concerns SET status = 'pending' WHERE status = 'in_progress';
    DROP TYPE concern_status;
    CREATE TYPE concern_status AS ENUM ('unread', 'pending', 'resolved');
    ALTER TABLE concerns ALTER COLUMN status TYPE concern_status
      USING status::concern_status;
    ALTER TABLE concerns ALTER COLUMN status SET DEFAULT 'unread';
  END IF;
END $$;

ALTER TABLE concerns ADD COLUMN IF NOT EXISTS rating INTEGER;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_concern_rating'
  ) THEN
    ALTER TABLE concerns ADD CONSTRAINT chk_concern_rating
      CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5));
  END IF;
END $$;

CREATE OR REPLACE VIEW v_boarding_house_dashboard AS
SELECT
    bh.id AS boarding_house_id,
    bh.name,
    bh.domain,
    bh.join_key,
    (SELECT COUNT(*) FROM rooms r WHERE r.boarding_house_id = bh.id AND r.status = 'active')::INTEGER AS total_rooms,
    (SELECT COUNT(*) FROM tenants t WHERE t.boarding_house_id = bh.id AND t.is_active)::INTEGER AS total_tenants,
    (SELECT COALESCE(SUM(ro.available_slots), 0) FROM v_room_occupancy ro WHERE ro.boarding_house_id = bh.id)::INTEGER AS open_slots,
    (SELECT COUNT(*) FROM concerns c WHERE c.boarding_house_id = bh.id AND c.status IN ('unread','pending'))::INTEGER AS active_concerns,
    (SELECT COUNT(*) FROM v_unassigned_accounts ua WHERE ua.boarding_house_id = bh.id)::INTEGER AS unassigned_accounts
FROM boarding_houses bh;

-- ============================================================
-- 004_login_otp: username + email OTP challenges
-- ============================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS username TEXT;

UPDATE users SET username = 'jamestermulato'
 WHERE lower(email) = 'jamestermulato@gmail.com' AND username IS NULL;
UPDATE users SET username = 'jamester'
 WHERE lower(email) = 'jamester.mulato@csucc.edu.ph' AND username IS NULL;
UPDATE users SET username = 'joritomulato'
 WHERE lower(email) = 'joritomulato@gmail.com' AND username IS NULL;

UPDATE users
   SET username = 'u' || substr(md5(id::text), 1, 9)
 WHERE username IS NULL OR username ~ '^u[0-9a-f]{9}$';

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_username_ci ON users (lower(username));

CREATE TABLE IF NOT EXISTS login_otps (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash       TEXT NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    attempts        INTEGER NOT NULL DEFAULT 0,
    used            BOOLEAN NOT NULL DEFAULT FALSE,
    resend_count    INTEGER NOT NULL DEFAULT 0,
    last_sent_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_address      TEXT,
    user_agent      TEXT
);

CREATE INDEX IF NOT EXISTS idx_login_otps_user
    ON login_otps (user_id, created_at DESC);

-- ============================================================
-- 005_handout_core: registration fields, security answers, flags, IP blocks
-- ============================================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS id_number TEXT,
  ADD COLUMN IF NOT EXISTS first_name TEXT,
  ADD COLUMN IF NOT EXISTS middle_name TEXT,
  ADD COLUMN IF NOT EXISTS family_name TEXT,
  ADD COLUMN IF NOT EXISTS name_extension TEXT,
  ADD COLUMN IF NOT EXISTS birthdate DATE,
  ADD COLUMN IF NOT EXISTS age INTEGER,
  ADD COLUMN IF NOT EXISTS address_purok TEXT,
  ADD COLUMN IF NOT EXISTS address_barangay TEXT,
  ADD COLUMN IF NOT EXISTS address_city TEXT,
  ADD COLUMN IF NOT EXISTS address_province TEXT,
  ADD COLUMN IF NOT EXISTS address_country TEXT,
  ADD COLUMN IF NOT EXISTS address_zip TEXT,
  ADD COLUMN IF NOT EXISTS government_id_ciphertext TEXT,
  ADD COLUMN IF NOT EXISTS government_id_iv TEXT,
  ADD COLUMN IF NOT EXISTS government_id_tag TEXT,
  ADD COLUMN IF NOT EXISTS government_id_lookup TEXT,
  ADD COLUMN IF NOT EXISTS move_in_date DATE,
  ADD COLUMN IF NOT EXISTS room_type TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact TEXT,
  ADD COLUMN IF NOT EXISTS tenancy_notes TEXT,
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_id_number
  ON users (id_number) WHERE id_number IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_gov_id_lookup
  ON users (government_id_lookup) WHERE government_id_lookup IS NOT NULL;

CREATE TABLE IF NOT EXISTS security_answers (
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question_key TEXT NOT NULL,
    answer_hash  TEXT NOT NULL,
    PRIMARY KEY (user_id, question_key)
);

ALTER TABLE login_otps
  ADD COLUMN IF NOT EXISTS purpose TEXT NOT NULL DEFAULT 'login';

CREATE INDEX IF NOT EXISTS idx_login_otps_purpose
  ON login_otps (user_id, purpose, created_at DESC);

CREATE TABLE IF NOT EXISTS security_flags (
    id          BIGSERIAL PRIMARY KEY,
    pattern     TEXT NOT NULL,
    target      TEXT NOT NULL,
    severity    TEXT NOT NULL,
    details     TEXT NOT NULL,
    flag_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (pattern, target, flag_date)
);

CREATE TABLE IF NOT EXISTS ip_blocks (
    ip_address    TEXT PRIMARY KEY,
    blocked_until TIMESTAMPTZ NOT NULL,
    reason        TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- auth_events (created at runtime by server.ts on old databases)
-- ============================================================
CREATE TABLE IF NOT EXISTS auth_events (
    id          BIGSERIAL PRIMARY KEY,
    event_type  TEXT NOT NULL,
    user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
    email       TEXT,
    ip_address  TEXT,
    user_agent  TEXT,
    details     JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_events_created
  ON auth_events (created_at DESC);

-- Protection 9 / S11: the activity log can only be appended to.
CREATE OR REPLACE FUNCTION prevent_auth_events_change() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'auth_events is append-only';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS auth_events_no_change ON auth_events;
CREATE TRIGGER auth_events_no_change
    BEFORE UPDATE OR DELETE ON auth_events
    FOR EACH ROW EXECUTE FUNCTION prevent_auth_events_change();

-- ============================================================
-- 006_handout_final: idle session timeout
-- ============================================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_last_activity
  ON users (last_activity_at);

-- ============================================================
-- 007_activity_log_username
-- ============================================================
ALTER TABLE auth_events ADD COLUMN IF NOT EXISTS username_typed TEXT;

CREATE INDEX IF NOT EXISTS idx_auth_events_username_typed
  ON auth_events (lower(username_typed));

-- The student's own account administers the security dashboard. Only bootstrap
-- it when the database has no administrator at all, so restarting the server
-- never silently undoes an operator revoking that privilege.
UPDATE users SET is_admin = TRUE
 WHERE lower(email) = 'jamestermulato@gmail.com'
   AND NOT EXISTS (SELECT 1 FROM users WHERE is_admin);

COMMIT;
