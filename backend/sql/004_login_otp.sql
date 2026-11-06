-- 004_login_otp.sql
-- Adds the handout's second factor to the Tahanan app backend:
--   * a unique username per account (the app now signs in by username)
--   * a login_otps table for 6-digit email codes (5 min, 3 tries, single use)

ALTER TABLE users ADD COLUMN IF NOT EXISTS username TEXT;

-- Readable usernames for the three real password accounts.
UPDATE users SET username = 'jamestermulato'
 WHERE lower(email) = 'jamestermulato@gmail.com' AND username IS NULL;
UPDATE users SET username = 'jamester'
 WHERE lower(email) = 'jamester.mulato@csucc.edu.ph' AND username IS NULL;
UPDATE users SET username = 'joritomulato'
 WHERE lower(email) = 'joritomulato@gmail.com' AND username IS NULL;

-- Every other (Google-only) account gets a unique placeholder username.
-- md5 keeps it unique even for seeded rows that share a zero UUID.
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
