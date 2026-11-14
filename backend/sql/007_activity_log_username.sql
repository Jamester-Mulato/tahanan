-- 007_activity_log_username.sql
-- Handout 13.4: the activity log keeps the identifier exactly as typed
-- ("username_typed"), separate from the resolved account email.

ALTER TABLE auth_events
  ADD COLUMN IF NOT EXISTS username_typed TEXT;

CREATE INDEX IF NOT EXISTS idx_auth_events_username_typed
  ON auth_events (lower(username_typed));
