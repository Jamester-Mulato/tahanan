-- ============================================================
-- TAHANAN - PostgreSQL Database Schema
-- Flutter Android + PostgreSQL backend
--
-- KEY RULE:
-- A user's role is PER BOARDING HOUSE, not global.
-- The same user can be OWNER of one BH and TENANT of another.
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, checksum TEXT NOT NULL, applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW());

-- -------------------------
-- ENUMS
-- -------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'membership_role') THEN
        CREATE TYPE membership_role AS ENUM ('owner', 'tenant');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'membership_status') THEN
        CREATE TYPE membership_status AS ENUM ('active', 'removed');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'room_status') THEN
        CREATE TYPE room_status AS ENUM ('active', 'archived');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'monthly_status') THEN
        CREATE TYPE monthly_status AS ENUM ('paid', 'partial', 'unpaid');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'announcement_status') THEN
        CREATE TYPE announcement_status AS ENUM ('draft', 'published', 'archived');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'concern_category') THEN
        CREATE TYPE concern_category AS ENUM ('maintenance','utilities','cleanliness','security','noise','other');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'concern_status') THEN
        CREATE TYPE concern_status AS ENUM ('open','in_progress','resolved');
    END IF;
END $$;

-- -------------------------
-- USERS
-- Authentication may be handled by Google/Firebase/Auth0/etc.
-- This table stores the application's user identity/profile.
-- No global OWNER/TENANT role here.
-- -------------------------
CREATE TABLE IF NOT EXISTS users (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_provider       TEXT NOT NULL DEFAULT 'google',
    auth_provider_uid   TEXT NOT NULL,
    email               TEXT NOT NULL,
    display_name        TEXT NOT NULL,
    avatar_url          TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_provider_uid UNIQUE (auth_provider, auth_provider_uid),
    CONSTRAINT chk_user_email CHECK (length(trim(email)) > 3),
    CONSTRAINT chk_user_name CHECK (length(trim(display_name)) > 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_email_ci ON users (lower(email));

-- -------------------------
-- BOARDING HOUSES
-- domain: human-readable BH identifier (e.g. greenhaven)
-- join_key: actual key/code tenants use to join
-- -------------------------
CREATE TABLE IF NOT EXISTS boarding_houses (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id       UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name                TEXT NOT NULL,
    domain              TEXT NOT NULL,
    join_key             TEXT NOT NULL,
    is_active            BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_bh_domain UNIQUE (domain),
    CONSTRAINT uq_bh_join_key UNIQUE (join_key),
    CONSTRAINT chk_bh_name CHECK (length(trim(name)) BETWEEN 2 AND 120),
    CONSTRAINT chk_bh_domain CHECK (domain ~ '^[a-z0-9][a-z0-9-]{2,59}$'),
    CONSTRAINT chk_bh_join_key CHECK (length(trim(join_key)) BETWEEN 6 AND 64)
);
CREATE INDEX IF NOT EXISTS idx_bh_owner ON boarding_houses(owner_user_id);

-- -------------------------
-- MEMBERSHIPS
-- THIS is where the OWNER/TENANT role lives.
-- A user may own multiple BHs and tenant in multiple BHs.
-- -------------------------
CREATE TABLE IF NOT EXISTS boarding_house_memberships (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boarding_house_id   UUID NOT NULL REFERENCES boarding_houses(id) ON DELETE CASCADE,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role                membership_role NOT NULL,
    status              membership_status NOT NULL DEFAULT 'active',
    joined_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    removed_at          TIMESTAMPTZ,
    removed_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_membership_house_user UNIQUE (boarding_house_id, user_id),
    CONSTRAINT chk_membership_removed CHECK (
        (status = 'active' AND removed_at IS NULL)
        OR
        (status = 'removed' AND removed_at IS NOT NULL)
    )
);
CREATE INDEX IF NOT EXISTS idx_membership_user ON boarding_house_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_membership_house_role ON boarding_house_memberships(boarding_house_id, role, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_active_owner_per_bh
    ON boarding_house_memberships(boarding_house_id)
    WHERE role = 'owner' AND status = 'active';

-- -------------------------
-- ROOMS
-- Capacity belongs to each room.
-- -------------------------
CREATE TABLE IF NOT EXISTS rooms (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boarding_house_id   UUID NOT NULL REFERENCES boarding_houses(id) ON DELETE CASCADE,
    room_number         TEXT NOT NULL,
    capacity            INTEGER NOT NULL,
    status              room_status NOT NULL DEFAULT 'active',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_room_per_bh UNIQUE (boarding_house_id, room_number),
    CONSTRAINT chk_room_capacity CHECK (capacity BETWEEN 1 AND 100),
    CONSTRAINT chk_room_number CHECK (length(trim(room_number)) > 0)
);
CREATE INDEX IF NOT EXISTS idx_rooms_bh ON rooms(boarding_house_id);

-- -------------------------
-- TENANT RECORDS
-- Separate from Google accounts.
-- -------------------------
CREATE TABLE IF NOT EXISTS tenants (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boarding_house_id   UUID NOT NULL REFERENCES boarding_houses(id) ON DELETE CASCADE,
    full_name           TEXT NOT NULL,
    email               TEXT,
    phone               TEXT,
    notes               TEXT,
    is_active            BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_tenant_name CHECK (length(trim(full_name)) BETWEEN 1 AND 150)
);
CREATE INDEX IF NOT EXISTS idx_tenants_bh ON tenants(boarding_house_id);
CREATE INDEX IF NOT EXISTS idx_tenants_name ON tenants(boarding_house_id, lower(full_name));

-- -------------------------
-- GOOGLE ACCOUNT <-> TENANT ASSOCIATION
-- A user can be associated with at most one tenant record per BH.
-- A tenant can have at most one associated user per BH.
-- -------------------------
CREATE TABLE IF NOT EXISTS tenant_account_associations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boarding_house_id   UUID NOT NULL REFERENCES boarding_houses(id) ON DELETE CASCADE,
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    associated_by       UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    associated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_assoc_tenant UNIQUE (boarding_house_id, tenant_id),
    CONSTRAINT uq_tenant_assoc_user UNIQUE (boarding_house_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_tenant_assoc_user ON tenant_account_associations(user_id);
CREATE INDEX IF NOT EXISTS idx_tenant_assoc_tenant ON tenant_account_associations(tenant_id);

-- -------------------------
-- ROOM ASSIGNMENTS
-- Separate from Google-account association.
-- Supports room move history.
-- Only one active room assignment per tenant.
-- -------------------------
CREATE TABLE IF NOT EXISTS tenant_room_assignments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    room_id             UUID NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
    assigned_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at            TIMESTAMPTZ,
    assigned_by         UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_assignment_dates CHECK (ended_at IS NULL OR ended_at > assigned_at)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_tenant_assignment
    ON tenant_room_assignments(tenant_id)
    WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_active_assignments_room
    ON tenant_room_assignments(room_id)
    WHERE ended_at IS NULL;

-- -------------------------
-- ACADEMIC YEARS
-- Example: 2026-2027 = 2026-06-01 through 2027-06-01.
-- -------------------------
CREATE TABLE IF NOT EXISTS academic_years (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boarding_house_id   UUID NOT NULL REFERENCES boarding_houses(id) ON DELETE CASCADE,
    name                TEXT NOT NULL,
    starts_on           DATE NOT NULL,
    ends_on             DATE NOT NULL,
    is_active            BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_academic_year_house_name UNIQUE (boarding_house_id, name),
    CONSTRAINT chk_academic_year_dates CHECK (ends_on > starts_on),
    CONSTRAINT chk_academic_year_name CHECK (length(trim(name)) BETWEEN 4 AND 30)
);
CREATE INDEX IF NOT EXISTS idx_academic_years_bh ON academic_years(boarding_house_id);

-- -------------------------
-- MONTHLY TENANT STATUS
-- One row = one tenant + academic year + month.
-- -------------------------
CREATE TABLE IF NOT EXISTS tenant_monthly_statuses (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boarding_house_id   UUID NOT NULL REFERENCES boarding_houses(id) ON DELETE CASCADE,
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    academic_year_id    UUID NOT NULL REFERENCES academic_years(id) ON DELETE CASCADE,
    month_start         DATE NOT NULL,
    status              monthly_status NOT NULL,
    updated_by          UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_month_status UNIQUE (tenant_id, academic_year_id, month_start),
    CONSTRAINT chk_month_first_day CHECK (month_start = date_trunc('month', month_start)::date)
);
CREATE INDEX IF NOT EXISTS idx_month_status_tenant_year
    ON tenant_monthly_statuses(tenant_id, academic_year_id, month_start);

-- -------------------------
-- ANNOUNCEMENTS
-- -------------------------
CREATE TABLE IF NOT EXISTS announcements (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boarding_house_id   UUID NOT NULL REFERENCES boarding_houses(id) ON DELETE CASCADE,
    author_user_id      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    title               TEXT NOT NULL,
    message             TEXT NOT NULL,
    status              announcement_status NOT NULL DEFAULT 'published',
    published_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_announcement_title CHECK (length(trim(title)) BETWEEN 1 AND 200),
    CONSTRAINT chk_announcement_message CHECK (length(trim(message)) BETWEEN 1 AND 10000),
    CONSTRAINT chk_announcement_publish_state CHECK (
        (status = 'published' AND published_at IS NOT NULL)
        OR status IN ('draft','archived')
    )
);
CREATE INDEX IF NOT EXISTS idx_announcements_feed
    ON announcements(boarding_house_id, published_at DESC);

-- -------------------------
-- CONCERNS
-- reported_room_id is kept as a historical/context reference.
-- -------------------------
CREATE TABLE IF NOT EXISTS concerns (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boarding_house_id   UUID NOT NULL REFERENCES boarding_houses(id) ON DELETE CASCADE,
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    reported_room_id    UUID REFERENCES rooms(id) ON DELETE SET NULL,
    category            concern_category NOT NULL,
    subject             TEXT NOT NULL,
    details             TEXT NOT NULL,
    status              concern_status NOT NULL DEFAULT 'open',
    owner_response      TEXT,
    responded_by        UUID REFERENCES users(id) ON DELETE SET NULL,
    responded_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_concern_subject CHECK (length(trim(subject)) BETWEEN 1 AND 200),
    CONSTRAINT chk_concern_details CHECK (length(trim(details)) BETWEEN 1 AND 20000),
    CONSTRAINT chk_concern_response CHECK (
        (owner_response IS NULL AND responded_at IS NULL)
        OR (owner_response IS NOT NULL AND responded_at IS NOT NULL)
    )
);
CREATE INDEX IF NOT EXISTS idx_concerns_bh_status
    ON concerns(boarding_house_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_concerns_tenant
    ON concerns(tenant_id, created_at DESC);

-- -------------------------
-- CONCERN ATTACHMENTS
-- Actual image bytes live in object storage.
-- -------------------------
CREATE TABLE IF NOT EXISTS concern_attachments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    concern_id          UUID NOT NULL REFERENCES concerns(id) ON DELETE CASCADE,
    storage_path        TEXT NOT NULL,
    public_url          TEXT,
    mime_type           TEXT,
    file_name           TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_attachment_path CHECK (length(trim(storage_path)) > 0)
);
CREATE INDEX IF NOT EXISTS idx_concern_attachments ON concern_attachments(concern_id);

-- ============================================================
-- TIMESTAMP TRIGGERS
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS trg_bh_updated_at ON boarding_houses;
CREATE TRIGGER trg_bh_updated_at BEFORE UPDATE ON boarding_houses FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS trg_membership_updated_at ON boarding_house_memberships;
CREATE TRIGGER trg_membership_updated_at BEFORE UPDATE ON boarding_house_memberships FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS trg_rooms_updated_at ON rooms;
CREATE TRIGGER trg_rooms_updated_at BEFORE UPDATE ON rooms FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS trg_tenants_updated_at ON tenants;
CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS trg_announcements_updated_at ON announcements;
CREATE TRIGGER trg_announcements_updated_at BEFORE UPDATE ON announcements FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS trg_concerns_updated_at ON concerns;
CREATE TRIGGER trg_concerns_updated_at BEFORE UPDATE ON concerns FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- VALIDATION FUNCTIONS
-- ============================================================

-- Room assignment must use a room in the same BH and respect capacity.
CREATE OR REPLACE FUNCTION validate_tenant_room_assignment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    tenant_house UUID;
    room_house UUID;
    room_capacity INTEGER;
    active_count INTEGER;
BEGIN
    SELECT boarding_house_id INTO tenant_house FROM tenants WHERE id = NEW.tenant_id;
    SELECT boarding_house_id, capacity INTO room_house, room_capacity
      FROM rooms
     WHERE id = NEW.room_id AND status = 'active'
     FOR UPDATE;

    IF tenant_house IS NULL THEN
        RAISE EXCEPTION 'Tenant % does not exist', NEW.tenant_id;
    END IF;
    IF room_house IS NULL THEN
        RAISE EXCEPTION 'Room % does not exist or is archived', NEW.room_id;
    END IF;
    IF tenant_house <> room_house THEN
        RAISE EXCEPTION 'Tenant and room belong to different boarding houses';
    END IF;

    IF NEW.ended_at IS NULL THEN
        SELECT COUNT(*) INTO active_count
          FROM tenant_room_assignments tra
         WHERE tra.room_id = NEW.room_id
           AND tra.ended_at IS NULL
           AND tra.id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

        IF active_count >= room_capacity THEN
            RAISE EXCEPTION 'Room % is full (%/% capacity)', NEW.room_id, active_count, room_capacity;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validate_tenant_room_assignment ON tenant_room_assignments;
CREATE TRIGGER trg_validate_tenant_room_assignment
BEFORE INSERT OR UPDATE OF tenant_id, room_id, ended_at
ON tenant_room_assignments
FOR EACH ROW EXECUTE FUNCTION validate_tenant_room_assignment();

-- Prevent lowering a room's capacity below current occupancy.
CREATE OR REPLACE FUNCTION validate_room_capacity_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    occupied INTEGER;
BEGIN
    IF NEW.capacity < OLD.capacity THEN
        SELECT COUNT(*) INTO occupied
          FROM tenant_room_assignments
         WHERE room_id = NEW.id AND ended_at IS NULL;
        IF occupied > NEW.capacity THEN
            RAISE EXCEPTION 'Cannot set capacity to %: room currently has % tenants', NEW.capacity, occupied;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validate_room_capacity_change ON rooms;
CREATE TRIGGER trg_validate_room_capacity_change
BEFORE UPDATE OF capacity ON rooms
FOR EACH ROW EXECUTE FUNCTION validate_room_capacity_change();

-- Account association must use a tenant and an active tenant membership in the same BH.
CREATE OR REPLACE FUNCTION validate_tenant_account_association()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    tenant_house UUID;
    member_ok BOOLEAN;
BEGIN
    SELECT boarding_house_id INTO tenant_house FROM tenants WHERE id = NEW.tenant_id;
    IF tenant_house IS NULL OR tenant_house <> NEW.boarding_house_id THEN
        RAISE EXCEPTION 'Tenant association must stay inside one boarding house';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM boarding_house_memberships m
         WHERE m.boarding_house_id = NEW.boarding_house_id
           AND m.user_id = NEW.user_id
           AND m.role = 'tenant'
           AND m.status = 'active'
    ) INTO member_ok;

    IF NOT member_ok THEN
        RAISE EXCEPTION 'Google account must be an active tenant member before association';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validate_tenant_account_association ON tenant_account_associations;
CREATE TRIGGER trg_validate_tenant_account_association
BEFORE INSERT OR UPDATE ON tenant_account_associations
FOR EACH ROW EXECUTE FUNCTION validate_tenant_account_association();

-- Monthly status must reference a tenant/year in the same BH.
CREATE OR REPLACE FUNCTION validate_monthly_status_house()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    tenant_house UUID;
    year_house UUID;
BEGIN
    SELECT boarding_house_id INTO tenant_house FROM tenants WHERE id = NEW.tenant_id;
    SELECT boarding_house_id INTO year_house FROM academic_years WHERE id = NEW.academic_year_id;
    IF tenant_house IS NULL OR year_house IS NULL
       OR tenant_house <> NEW.boarding_house_id
       OR year_house <> NEW.boarding_house_id THEN
        RAISE EXCEPTION 'Monthly status references different boarding houses';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validate_monthly_status_house ON tenant_monthly_statuses;
CREATE TRIGGER trg_validate_monthly_status_house
BEFORE INSERT OR UPDATE ON tenant_monthly_statuses
FOR EACH ROW EXECUTE FUNCTION validate_monthly_status_house();

-- Only the canonical BH owner may be an owner membership.
CREATE OR REPLACE FUNCTION validate_owner_membership()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    canonical_owner UUID;
BEGIN
    IF NEW.role = 'owner' THEN
        SELECT owner_user_id INTO canonical_owner FROM boarding_houses WHERE id = NEW.boarding_house_id;
        IF canonical_owner IS NULL OR canonical_owner <> NEW.user_id THEN
            RAISE EXCEPTION 'Only the boarding house owner can have owner membership';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validate_owner_membership ON boarding_house_memberships;
CREATE TRIGGER trg_validate_owner_membership
BEFORE INSERT OR UPDATE ON boarding_house_memberships
FOR EACH ROW EXECUTE FUNCTION validate_owner_membership();

-- ============================================================
-- VIEWS FOR FLUTTER/API
-- ============================================================

-- Room occupancy is derived from assignments; no tenant_count column.
CREATE OR REPLACE VIEW v_room_occupancy AS
SELECT
    r.id AS room_id,
    r.boarding_house_id,
    r.room_number,
    r.capacity,
    COUNT(tra.id)::INTEGER AS occupied_slots,
    GREATEST(r.capacity - COUNT(tra.id)::INTEGER, 0) AS available_slots,
    CASE
        WHEN COUNT(tra.id) = 0 THEN 'empty'
        WHEN COUNT(tra.id) >= r.capacity THEN 'full'
        ELSE 'available'
    END AS occupancy_status
FROM rooms r
LEFT JOIN tenant_room_assignments tra
  ON tra.room_id = r.id AND tra.ended_at IS NULL
WHERE r.status = 'active'
GROUP BY r.id;

CREATE OR REPLACE VIEW v_tenant_current_assignment AS
SELECT
    t.id AS tenant_id,
    t.boarding_house_id,
    t.full_name,
    t.email,
    tra.room_id,
    r.room_number,
    r.capacity
FROM tenants t
LEFT JOIN tenant_room_assignments tra
  ON tra.tenant_id = t.id AND tra.ended_at IS NULL
LEFT JOIN rooms r ON r.id = tra.room_id;

-- Google users who joined a BH but have no tenant-record association.
CREATE OR REPLACE VIEW v_unassigned_accounts AS
SELECT
    m.id AS membership_id,
    m.boarding_house_id,
    m.user_id,
    u.email,
    u.display_name,
    u.avatar_url,
    m.joined_at
FROM boarding_house_memberships m
JOIN users u ON u.id = m.user_id
LEFT JOIN tenant_account_associations taa
  ON taa.boarding_house_id = m.boarding_house_id
 AND taa.user_id = m.user_id
WHERE m.role = 'tenant'
  AND m.status = 'active'
  AND taa.id IS NULL;

-- Dashboard summary without aggregate multiplication.
CREATE OR REPLACE VIEW v_boarding_house_dashboard AS
SELECT
    bh.id AS boarding_house_id,
    bh.name,
    bh.domain,
    bh.join_key,
    (SELECT COUNT(*) FROM rooms r WHERE r.boarding_house_id = bh.id AND r.status = 'active')::INTEGER AS total_rooms,
    (SELECT COUNT(*) FROM tenants t WHERE t.boarding_house_id = bh.id AND t.is_active)::INTEGER AS total_tenants,
    (SELECT COALESCE(SUM(ro.available_slots), 0) FROM v_room_occupancy ro WHERE ro.boarding_house_id = bh.id)::INTEGER AS open_slots,
    (SELECT COUNT(*) FROM concerns c WHERE c.boarding_house_id = bh.id AND c.status IN ('open','in_progress'))::INTEGER AS active_concerns,
    (SELECT COUNT(*) FROM v_unassigned_accounts ua WHERE ua.boarding_house_id = bh.id)::INTEGER AS unassigned_accounts
FROM boarding_houses bh;

CREATE OR REPLACE VIEW v_published_announcements AS
SELECT
    a.id,
    a.boarding_house_id,
    a.title,
    a.message,
    a.author_user_id,
    u.display_name AS author_name,
    a.published_at
FROM announcements a
JOIN users u ON u.id = a.author_user_id
WHERE a.status = 'published';

COMMIT;

-- ============================================================
-- IMPLEMENTATION NOTES
-- ============================================================
--
-- 1. LOGIN / ROLE
--    Do not store a global role on users.
--    After Google login, load active boarding_house_memberships.
--    A user can see multiple BHs and their role in each.
--
--    Example:
--      User A -> BH Alpha -> owner
--      User A -> BH Beta  -> tenant
--
-- 2. CREATE BH
--    Transaction:
--      insert boarding_houses with owner_user_id
--      insert owner membership
--      insert rooms
--      optionally insert academic year
--
-- 3. JOIN BH
--    Find BH by join_key (or domain if the UI supports it).
--    Create/reactivate tenant membership.
--    Do NOT automatically create a tenant record.
--
-- 4. UNASSIGNED ACCOUNT
--    v_unassigned_accounts detects an active tenant membership with no
--    tenant_account_associations row.
--
-- 5. ASSOCIATE ACCOUNT
--    Insert into tenant_account_associations, then create/update the
--    tenant_room_assignments row if a room is selected.
--
-- 6. REMOVE OUTSIDER
--    Set membership status='removed', removed_at=now(), removed_by=<owner>.
--    This removes BH access; it does not delete the Google account.
--
-- 7. ROOM CAPACITY
--    Room occupancy is derived from tenant_room_assignments.
--    Capacity is enforced in PostgreSQL triggers.
--
-- 8. MONTHLY STATUS
--    Use tenant_monthly_statuses; do not put Paid/Partial/Unpaid on tenants.
--
-- 9. IMAGES
--    Store concern photos in object storage; store only references here.
--
-- 10. MOBILE SECURITY
--    Do NOT ship PostgreSQL credentials in the Flutter APK.
--    Flutter should call a secured backend/API that authenticates the user
--    and enforces membership/owner checks.
