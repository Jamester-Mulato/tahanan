-- 006_handout_final.sql
-- Server-enforced idle session timeout (seed: 6 minutes for student 241-00315).

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_last_activity
  ON users (last_activity_at);
