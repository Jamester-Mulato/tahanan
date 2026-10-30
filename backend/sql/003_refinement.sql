-- Migration to refine Tahanan features:
-- 1. Standardize concern statuses to unread, pending, resolved.
-- 2. Add rating to concerns.
-- 3. Update related views.

BEGIN;

-- Drop dependent view
DROP VIEW IF EXISTS v_boarding_house_dashboard;

-- 1. Update concern_status ENUM
-- Remove default before changing type
ALTER TABLE concerns ALTER COLUMN status DROP DEFAULT;
ALTER TABLE concerns ALTER COLUMN status TYPE TEXT;

UPDATE concerns SET status = 'unread' WHERE status = 'open';
UPDATE concerns SET status = 'pending' WHERE status = 'in_progress';
-- 'resolved' stays 'resolved'

DROP TYPE concern_status;
CREATE TYPE concern_status AS ENUM ('unread', 'pending', 'resolved');

ALTER TABLE concerns ALTER COLUMN status TYPE concern_status USING status::concern_status;
ALTER TABLE concerns ALTER COLUMN status SET DEFAULT 'unread';

-- 2. Add rating to concerns
ALTER TABLE concerns ADD COLUMN rating INTEGER;
ALTER TABLE concerns ADD CONSTRAINT chk_concern_rating CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5));

-- 3. Recreate v_boarding_house_dashboard view with new status names
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

COMMIT;
