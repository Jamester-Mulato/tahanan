-- 005_handout_core.sql
-- Everything the IT 107 handout requires inside the Tahanan system itself.

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
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question_key TEXT NOT NULL,
    answer_hash TEXT NOT NULL,
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

-- The student's own account administers the security dashboard.
UPDATE users SET is_admin = TRUE
 WHERE lower(email) = 'jamestermulato@gmail.com';
