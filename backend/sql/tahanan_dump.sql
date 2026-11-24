--
-- PostgreSQL database dump
--

\restrict OOcNGHU061e5gmmQOjpCYUQglg2vjMLXQwYT3MXfxzIVcCe2qM4qUyrdQ0cXhlb

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: announcement_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.announcement_status AS ENUM (
    'draft',
    'published',
    'archived'
);


--
-- Name: concern_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.concern_category AS ENUM (
    'maintenance',
    'utilities',
    'cleanliness',
    'security',
    'noise',
    'other'
);


--
-- Name: concern_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.concern_status AS ENUM (
    'unread',
    'pending',
    'resolved'
);


--
-- Name: membership_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.membership_role AS ENUM (
    'owner',
    'tenant'
);


--
-- Name: membership_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.membership_status AS ENUM (
    'active',
    'removed'
);


--
-- Name: monthly_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.monthly_status AS ENUM (
    'paid',
    'partial',
    'unpaid'
);


--
-- Name: room_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.room_status AS ENUM (
    'active',
    'archived'
);


--
-- Name: prevent_auth_events_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_auth_events_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'auth_events is append-only';
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;


--
-- Name: validate_monthly_status_house(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_monthly_status_house() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: validate_owner_membership(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_owner_membership() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: validate_room_capacity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_room_capacity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: validate_tenant_account_association(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_tenant_account_association() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: validate_tenant_room_assignment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_tenant_room_assignment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: academic_years; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.academic_years (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    boarding_house_id uuid NOT NULL,
    name text NOT NULL,
    starts_on date NOT NULL,
    ends_on date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_academic_year_dates CHECK ((ends_on > starts_on)),
    CONSTRAINT chk_academic_year_name CHECK (((length(TRIM(BOTH FROM name)) >= 4) AND (length(TRIM(BOTH FROM name)) <= 30)))
);


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    boarding_house_id uuid NOT NULL,
    author_user_id uuid NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    status public.announcement_status DEFAULT 'published'::public.announcement_status NOT NULL,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_announcement_message CHECK (((length(TRIM(BOTH FROM message)) >= 1) AND (length(TRIM(BOTH FROM message)) <= 10000))),
    CONSTRAINT chk_announcement_publish_state CHECK ((((status = 'published'::public.announcement_status) AND (published_at IS NOT NULL)) OR (status = ANY (ARRAY['draft'::public.announcement_status, 'archived'::public.announcement_status])))),
    CONSTRAINT chk_announcement_title CHECK (((length(TRIM(BOTH FROM title)) >= 1) AND (length(TRIM(BOTH FROM title)) <= 200)))
);


--
-- Name: auth_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_events (
    id bigint NOT NULL,
    event_type text NOT NULL,
    user_id uuid,
    email text,
    ip_address text,
    user_agent text,
    details jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    username_typed text
);


--
-- Name: auth_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_events_id_seq OWNED BY public.auth_events.id;


--
-- Name: auth_refresh_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_refresh_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    device_name text,
    ip_address text,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone
);


--
-- Name: boarding_house_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.boarding_house_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    boarding_house_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role public.membership_role NOT NULL,
    status public.membership_status DEFAULT 'active'::public.membership_status NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    removed_at timestamp with time zone,
    removed_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_membership_removed CHECK ((((status = 'active'::public.membership_status) AND (removed_at IS NULL)) OR ((status = 'removed'::public.membership_status) AND (removed_at IS NOT NULL))))
);


--
-- Name: boarding_houses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.boarding_houses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_user_id uuid NOT NULL,
    name text NOT NULL,
    domain text NOT NULL,
    join_key text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_bh_domain CHECK ((domain ~ '^[a-z0-9][a-z0-9-]{2,59}$'::text)),
    CONSTRAINT chk_bh_join_key CHECK (((length(TRIM(BOTH FROM join_key)) >= 6) AND (length(TRIM(BOTH FROM join_key)) <= 64))),
    CONSTRAINT chk_bh_name CHECK (((length(TRIM(BOTH FROM name)) >= 2) AND (length(TRIM(BOTH FROM name)) <= 120)))
);


--
-- Name: concern_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concern_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    concern_id uuid NOT NULL,
    storage_path text NOT NULL,
    public_url text,
    mime_type text,
    file_name text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_attachment_path CHECK ((length(TRIM(BOTH FROM storage_path)) > 0))
);


--
-- Name: concerns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concerns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    boarding_house_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    reported_room_id uuid,
    category public.concern_category NOT NULL,
    subject text NOT NULL,
    details text NOT NULL,
    status public.concern_status DEFAULT 'unread'::public.concern_status NOT NULL,
    owner_response text,
    responded_by uuid,
    responded_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    rating smallint,
    CONSTRAINT chk_concern_details CHECK (((length(TRIM(BOTH FROM details)) >= 1) AND (length(TRIM(BOTH FROM details)) <= 20000))),
    CONSTRAINT chk_concern_rating CHECK (((rating IS NULL) OR ((rating >= 0) AND (rating <= 5)))),
    CONSTRAINT chk_concern_response CHECK ((((owner_response IS NULL) AND (responded_at IS NULL)) OR ((owner_response IS NOT NULL) AND (responded_at IS NOT NULL)))),
    CONSTRAINT chk_concern_subject CHECK (((length(TRIM(BOTH FROM subject)) >= 1) AND (length(TRIM(BOTH FROM subject)) <= 200))),
    CONSTRAINT concerns_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: ip_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ip_blocks (
    ip_address text NOT NULL,
    blocked_until timestamp with time zone NOT NULL,
    reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: login_otps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.login_otps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    code_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    used boolean DEFAULT false NOT NULL,
    resend_count integer DEFAULT 0 NOT NULL,
    last_sent_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    ip_address text,
    user_agent text,
    purpose text DEFAULT 'login'::text NOT NULL
);


--
-- Name: login_remember_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.login_remember_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: password_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_history (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: password_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.password_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: password_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.password_history_id_seq OWNED BY public.password_history.id;


--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_reset_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: rooms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rooms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    boarding_house_id uuid NOT NULL,
    room_number text NOT NULL,
    capacity integer NOT NULL,
    status public.room_status DEFAULT 'active'::public.room_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_room_capacity CHECK (((capacity >= 1) AND (capacity <= 100))),
    CONSTRAINT chk_room_number CHECK ((length(TRIM(BOTH FROM room_number)) > 0))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version text NOT NULL,
    checksum text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: security_answers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security_answers (
    user_id uuid NOT NULL,
    question_key text NOT NULL,
    answer_hash text NOT NULL
);


--
-- Name: security_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security_flags (
    id bigint NOT NULL,
    pattern text NOT NULL,
    target text NOT NULL,
    severity text NOT NULL,
    details text NOT NULL,
    flag_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: security_flags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.security_flags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: security_flags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.security_flags_id_seq OWNED BY public.security_flags.id;


--
-- Name: tenant_account_associations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_account_associations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    boarding_house_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    associated_by uuid NOT NULL,
    associated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tenant_monthly_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_monthly_statuses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    boarding_house_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    academic_year_id uuid NOT NULL,
    month_start date NOT NULL,
    status public.monthly_status NOT NULL,
    updated_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_month_first_day CHECK ((month_start = (date_trunc('month'::text, (month_start)::timestamp with time zone))::date))
);


--
-- Name: tenant_room_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_room_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    room_id uuid NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    ended_at timestamp with time zone,
    assigned_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_assignment_dates CHECK (((ended_at IS NULL) OR (ended_at > assigned_at)))
);


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    boarding_house_id uuid NOT NULL,
    full_name text NOT NULL,
    email text,
    phone text,
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_tenant_name CHECK (((length(TRIM(BOTH FROM full_name)) >= 1) AND (length(TRIM(BOTH FROM full_name)) <= 150)))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auth_provider text DEFAULT 'google'::text NOT NULL,
    auth_provider_uid text NOT NULL,
    email text NOT NULL,
    display_name text NOT NULL,
    avatar_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    password_hash text,
    failed_login_count integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    last_login_at timestamp with time zone,
    password_changed_at timestamp with time zone,
    token_version integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    privacy_consent_at timestamp with time zone,
    username text,
    id_number text,
    first_name text,
    middle_name text,
    family_name text,
    name_extension text,
    birthdate date,
    age integer,
    address_purok text,
    address_barangay text,
    address_city text,
    address_province text,
    address_country text,
    address_zip text,
    government_id_ciphertext text,
    government_id_iv text,
    government_id_tag text,
    government_id_lookup text,
    move_in_date date,
    room_type text,
    emergency_contact text,
    tenancy_notes text,
    is_admin boolean DEFAULT false NOT NULL,
    email_verified_at timestamp with time zone,
    last_activity_at timestamp with time zone,
    CONSTRAINT chk_user_email CHECK ((length(TRIM(BOTH FROM email)) > 3)),
    CONSTRAINT chk_user_name CHECK ((length(TRIM(BOTH FROM display_name)) > 0))
);


--
-- Name: v_room_occupancy; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_room_occupancy AS
SELECT
    NULL::uuid AS room_id,
    NULL::uuid AS boarding_house_id,
    NULL::text AS room_number,
    NULL::integer AS capacity,
    NULL::integer AS occupied_slots,
    NULL::integer AS available_slots,
    NULL::text AS occupancy_status;


--
-- Name: v_unassigned_accounts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_unassigned_accounts AS
 SELECT m.id AS membership_id,
    m.boarding_house_id,
    m.user_id,
    u.email,
    u.display_name,
    u.avatar_url,
    m.joined_at
   FROM ((public.boarding_house_memberships m
     JOIN public.users u ON ((u.id = m.user_id)))
     LEFT JOIN public.tenant_account_associations taa ON (((taa.boarding_house_id = m.boarding_house_id) AND (taa.user_id = m.user_id))))
  WHERE ((m.role = 'tenant'::public.membership_role) AND (m.status = 'active'::public.membership_status) AND (taa.id IS NULL));


--
-- Name: v_boarding_house_dashboard; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_boarding_house_dashboard AS
 SELECT id AS boarding_house_id,
    name,
    domain,
    join_key,
    (( SELECT count(*) AS count
           FROM public.rooms r
          WHERE ((r.boarding_house_id = bh.id) AND (r.status = 'active'::public.room_status))))::integer AS total_rooms,
    (( SELECT count(*) AS count
           FROM public.tenants t
          WHERE ((t.boarding_house_id = bh.id) AND t.is_active)))::integer AS total_tenants,
    (( SELECT COALESCE(sum(ro.available_slots), (0)::bigint) AS "coalesce"
           FROM public.v_room_occupancy ro
          WHERE (ro.boarding_house_id = bh.id)))::integer AS open_slots,
    (( SELECT count(*) AS count
           FROM public.concerns c
          WHERE ((c.boarding_house_id = bh.id) AND (c.status = ANY (ARRAY['unread'::public.concern_status, 'pending'::public.concern_status])))))::integer AS active_concerns,
    (( SELECT count(*) AS count
           FROM public.v_unassigned_accounts ua
          WHERE (ua.boarding_house_id = bh.id)))::integer AS unassigned_accounts
   FROM public.boarding_houses bh;


--
-- Name: v_published_announcements; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_published_announcements AS
 SELECT a.id,
    a.boarding_house_id,
    a.title,
    a.message,
    a.author_user_id,
    u.display_name AS author_name,
    a.published_at
   FROM (public.announcements a
     JOIN public.users u ON ((u.id = a.author_user_id)))
  WHERE (a.status = 'published'::public.announcement_status);


--
-- Name: v_tenant_current_assignment; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_tenant_current_assignment AS
 SELECT t.id AS tenant_id,
    t.boarding_house_id,
    t.full_name,
    t.email,
    tra.room_id,
    r.room_number,
    r.capacity
   FROM ((public.tenants t
     LEFT JOIN public.tenant_room_assignments tra ON (((tra.tenant_id = t.id) AND (tra.ended_at IS NULL))))
     LEFT JOIN public.rooms r ON ((r.id = tra.room_id)));


--
-- Name: auth_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_events ALTER COLUMN id SET DEFAULT nextval('public.auth_events_id_seq'::regclass);


--
-- Name: password_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_history ALTER COLUMN id SET DEFAULT nextval('public.password_history_id_seq'::regclass);


--
-- Name: security_flags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_flags ALTER COLUMN id SET DEFAULT nextval('public.security_flags_id_seq'::regclass);


--
-- Data for Name: academic_years; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.academic_years (id, boarding_house_id, name, starts_on, ends_on, is_active, created_at) FROM stdin;
b3eefe68-b808-4a4c-b09f-cfdf43910bd6	f664b487-71d5-4241-89e4-4a77fab02519	2026-2027	2026-06-01	2027-06-01	t	2026-11-10 21:23:20.206406+08
2ed46d7e-dd84-41ce-9be7-5dd3f9c8975e	dfbc5a44-d183-4d99-9e4b-e30fe06ccca6	2026-2027	2026-06-01	2027-06-01	t	2026-11-11 13:17:07.873762+08
\.


--
-- Data for Name: announcements; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.announcements (id, boarding_house_id, author_user_id, title, message, status, published_at, created_at, updated_at) FROM stdin;
9190c572-d15b-43a3-9838-5ed911b0c743	f664b487-71d5-4241-89e4-4a77fab02519	35abeb06-cba5-4a42-a757-2f5eca443dcd	niggas	whattup pussies	published	2026-11-10 23:42:33.009203+08	2026-11-10 23:42:33.009203+08	2026-11-10 23:42:33.009203+08
\.


--
-- Data for Name: auth_events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_events (id, event_type, user_id, email, ip_address, user_agent, details, created_at, username_typed) FROM stdin;
18	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-10 23:05:01.022717+08	\N
19	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-10 23:06:07.80727+08	\N
20	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-10 23:09:51.630784+08	\N
21	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-10 23:10:28.533358+08	\N
22	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-10 23:20:02.078173+08	\N
23	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-10 23:33:59.995936+08	\N
24	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-10 23:37:29.918395+08	\N
25	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-11 00:00:08.164901+08	\N
26	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-11 11:58:41.866885+08	\N
27	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-11 12:03:11.379081+08	\N
34	PASSWORD_RESET_REQUESTED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	{"knownUser": true}	2026-11-11 12:44:36.254931+08	\N
35	PASSWORD_RESET_EMAIL_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-11 12:44:47.524865+08	\N
36	PASSWORD_RESET_REQUESTED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	{"knownUser": true}	2026-11-11 12:45:25.763894+08	\N
37	PASSWORD_RESET_EMAIL_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-11 12:45:28.467901+08	\N
38	PASSWORD_RESET_COMPLETED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-11 12:45:45.522178+08	\N
39	LOGIN_FAILED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	{"reason": "wrong_password", "lockedFor": 0}	2026-11-11 12:46:14.038329+08	\N
40	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-11 12:46:32.424078+08	\N
41	LOGIN_FAILED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	{"reason": "wrong_password", "lockedFor": 0}	2026-11-11 13:16:18.850159+08	\N
42	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-11 13:16:47.300257+08	\N
43	LOGIN_FAILED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	{"reason": "wrong_password", "lockedFor": 0}	2026-11-11 13:20:49.725716+08	\N
44	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-11 13:21:19.068112+08	\N
45	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-11 13:51:22.710757+08	\N
46	PASSWORD_RESET_REQUESTED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.26100.9711	{"knownUser": true}	2026-11-11 15:11:13.058063+08	\N
47	PASSWORD_RESET_EMAIL_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.26100.9711	\N	2026-11-11 15:11:23.240079+08	\N
95	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	curl/8.22.0	{"purpose": "login"}	2026-11-13 18:29:15.840515+08	\N
96	LOGIN_FAILED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamester123	::ffff:127.0.0.1	Dart/3.13 (dart:io)	{"reason": "wrong_password", "lockedFor": 0}	2026-11-13 19:12:10.516582+08	\N
97	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-13 19:12:25.16534+08	\N
98	LOGIN_SUCCEEDED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-13 19:12:51.632032+08	\N
141	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-16 22:05:40.544768+08	jamestermulato@gmail.com
142	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-16 22:06:01.92371+08	jamestermulato@gmail.com
144	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-16 22:07:12.132312+08	jamestermulato@gmail.com
145	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::ffff:127.0.0.1	Dart/3.13 (dart:io)	\N	2026-11-16 22:07:36.942607+08	jamestermulato@gmail.com
146	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-17 20:51:24.726638+08	jamestermulato@gmail.com
147	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-17 20:51:56.831664+08	jamestermulato@gmail.com
148	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-17 20:59:09.335921+08	jamestermulato@gmail.com
149	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-17 21:01:42.750907+08	\N
150	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-17 21:02:10.439853+08	jamestermulato@gmail.com
151	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-17 21:03:07.363349+08	jamestermulato@gmail.com
152	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-18 12:08:50.964845+08	jamestermulato@gmail.com
153	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-18 12:09:05.494844+08	jamestermulato@gmail.com
154	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-18 12:09:15.652489+08	jamestermulato@gmail.com
155	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-18 12:10:28.495403+08	\N
159	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-18 21:23:40.781423+08	jamestermulato@gmail.com
160	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-18 21:23:58.830274+08	jamestermulato@gmail.com
161	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	{"purpose": "login"}	2026-11-18 21:31:56.830307+08	jamestermulato@gmail.com
162	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	\N	2026-11-18 21:32:07.513506+08	jamestermulato@gmail.com
163	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	\N	2026-11-18 21:33:21.813512+08	jamestermulato@gmail.com
164	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-18 21:37:18.263425+08	jamestermulato@gmail.com
165	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-18 21:37:24.016788+08	jamestermulato@gmail.com
166	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-18 21:37:27.749996+08	jamestermulato@gmail.com
167	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	\N	2026-11-18 21:40:57.378915+08	\N
168	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	{"purpose": "login"}	2026-11-18 21:42:06.968194+08	jamestermulato@gmail.com
169	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	\N	2026-11-18 21:42:33.136309+08	jamestermulato@gmail.com
170	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	{"purpose": "login"}	2026-11-18 22:12:12.147854+08	jamestermulato@gmail.com
171	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	\N	2026-11-18 22:12:59.76851+08	jamestermulato@gmail.com
172	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	\N	2026-11-18 22:14:43.151097+08	jamestermulato@gmail.com
173	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	{"purpose": "login"}	2026-11-18 22:51:58.328552+08	jamestermulato@gmail.com
174	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	\N	2026-11-18 22:52:31.262087+08	jamestermulato@gmail.com
175	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	{"purpose": "login"}	2026-11-18 23:19:27.192867+08	jamestermulato@gmail.com
176	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	\N	2026-11-18 23:19:42.709954+08	jamestermulato@gmail.com
177	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	\N	2026-11-18 23:19:49.045254+08	jamestermulato@gmail.com
178	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	{"purpose": "login"}	2026-11-19 00:28:36.611497+08	jamestermulato@gmail.com
179	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	\N	2026-11-19 00:28:50.429375+08	jamestermulato@gmail.com
180	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	{"purpose": "login"}	2026-11-19 01:06:58.001859+08	jamestermulato@gmail.com
181	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	\N	2026-11-19 01:07:16.384071+08	jamestermulato@gmail.com
182	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	{"purpose": "login"}	2026-11-19 15:41:10.150162+08	jamestermulato@gmail.com
183	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-19 15:41:31.593193+08	jamestermulato@gmail.com
184	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	{"purpose": "login"}	2026-11-19 15:42:50.053596+08	jamestermulato@gmail.com
185	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	\N	2026-11-19 15:43:08.127536+08	jamestermulato@gmail.com
186	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	{"purpose": "login"}	2026-11-19 16:37:10.884869+08	jamestermulato@gmail.com
187	OTP_FAILED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	{"reason": "wrong_code", "purpose": "login"}	2026-11-19 16:37:28.3592+08	jamestermulato@gmail.com
188	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-19 16:37:42.065268+08	jamestermulato@gmail.com
189	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 17:42:40.24162+08	jamestermulato@gmail.com
190	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 17:42:54.796719+08	jamestermulato@gmail.com
191	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 17:44:19.476036+08	jamestermulato@gmail.com
192	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 18:27:47.069564+08	jamestermulato@gmail.com
193	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 18:28:02.205385+08	jamestermulato@gmail.com
194	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 18:30:06.838227+08	\N
195	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 18:30:32.920597+08	jamestermulato@gmail.com
196	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 18:30:49.53679+08	jamestermulato@gmail.com
197	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	{"purpose": "login"}	2026-11-19 18:48:36.658185+08	jamestermulato@gmail.com
199	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	{"purpose": "login"}	2026-11-19 18:50:33.992324+08	jamestermulato@gmail.com
200	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-19 18:50:46.104343+08	jamestermulato@gmail.com
201	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 18:51:34.908099+08	\N
202	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 18:57:58.952764+08	jamestermulato@gmail.com
203	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 18:58:17.608163+08	jamestermulato@gmail.com
204	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 19:28:15.308511+08	jamestermulato@gmail.com
205	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 19:28:29.041158+08	jamestermulato@gmail.com
206	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 19:49:55.816159+08	jamestermulato@gmail.com
207	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 19:50:14.854561+08	jamestermulato@gmail.com
208	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 20:04:15.023894+08	jamestermulato@gmail.com
209	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 20:04:36.798233+08	jamestermulato@gmail.com
210	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 20:14:14.022777+08	jamestermulato@gmail.com
211	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 20:14:30.178663+08	jamestermulato@gmail.com
212	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 20:27:44.747523+08	jamestermulato@gmail.com
213	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 20:28:01.600317+08	jamestermulato@gmail.com
214	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 20:35:12.412601+08	\N
215	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 20:36:25.24362+08	jamestermulato@gmail.com
216	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 20:36:37.594428+08	jamestermulato@gmail.com
217	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 20:55:20.867217+08	jamestermulato@gmail.com
218	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 20:55:41.847646+08	jamestermulato@gmail.com
219	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 21:17:27.094813+08	\N
220	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 21:18:07.454635+08	jamestermulato@gmail.com
221	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 21:18:42.068761+08	jamestermulato@gmail.com
222	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 21:18:52.492787+08	jamestermulato@gmail.com
223	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 21:20:12.486916+08	\N
224	RESET_REQUESTED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	\N	\N	{"identifier": "jamester123"}	2026-11-19 21:20:27.211555+08	jamestermulato@gmail.com
225	LOCKOUT_TIER_1	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 16, "attempts": 3}	2026-11-19 21:20:52.908356+08	jamester123
226	LOCKOUT_TIER_2	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 32, "attempts": 6}	2026-11-19 21:21:07.973672+08	jamester123
227	LOCKOUT_TIER_3	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 64, "attempts": 9}	2026-11-19 21:21:09.754968+08	jamester123
228	LOCKOUT_TIER_3	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 64, "attempts": 10}	2026-11-19 21:21:10.009054+08	jamester123
229	LOCKOUT_TIER_3	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 64, "attempts": 11}	2026-11-19 21:21:10.185528+08	jamester123
230	LOCKOUT_TIER_3	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 64, "attempts": 12}	2026-11-19 21:21:10.371462+08	jamester123
231	LOCKOUT_TIER_3	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 64, "attempts": 13}	2026-11-19 21:21:10.585246+08	jamester123
232	LOCKOUT_TIER_3	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 64, "attempts": 14}	2026-11-19 21:21:10.768099+08	jamester123
233	LOCKOUT_TIER_3	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 64, "attempts": 15}	2026-11-19 21:21:10.965575+08	jamester123
234	LOCKOUT_TIER_3	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 64, "attempts": 16}	2026-11-19 21:21:11.137076+08	jamester123
235	LOCKOUT_TIER_3	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 64, "attempts": 17}	2026-11-19 21:21:11.329237+08	jamester123
236	LOGIN_BLOCKED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamester123	100.84.208.58	Dart/3.13 (dart:io)	{"seconds": 46}	2026-11-19 21:21:29.561467+08	jamester123
238	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-19 21:22:44.043991+08	jamestermulato@gmail.com
239	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 21:23:00.579705+08	jamestermulato@gmail.com
240	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-19 21:23:16.842255+08	\N
241	RESET_REQUESTED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	\N	\N	{"identifier": "jamester123"}	2026-11-19 21:23:49.164938+08	jamestermulato@gmail.com
242	LOCKOUT_TIER_1	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"source": "reset", "seconds": 16, "attempts": 3}	2026-11-19 21:24:09.845215+08	jamester123
243	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-20 17:10:48.804681+08	jamestermulato@gmail.com
244	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-20 17:11:01.892844+08	jamestermulato@gmail.com
245	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-20 18:00:15.87147+08	jamestermulato@gmail.com
246	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-20 18:00:26.675347+08	jamestermulato@gmail.com
247	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-23 09:11:36.321445+08	jamestermulato@gmail.com
248	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-23 09:11:52.318042+08	jamestermulato@gmail.com
249	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-23 09:14:28.24178+08	\N
258	LOGIN_FAILED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamester123	100.84.208.58	Dart/3.13 (dart:io)	{"reason": "wrong_password", "lockedFor": 0}	2026-11-23 09:21:17.773461+08	jamester123
259	LOGIN_FAILED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamester123	100.84.208.58	Dart/3.13 (dart:io)	{"reason": "wrong_password", "lockedFor": 0}	2026-11-23 09:21:27.533375+08	jamester123
260	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-23 09:21:47.957482+08	jamestermulato@gmail.com
261	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-23 09:22:02.493637+08	jamestermulato@gmail.com
262	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-23 09:22:09.788075+08	\N
268	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	node	{"purpose": "login"}	2026-11-23 09:28:40.167769+08	jamestermulato@gmail.com
272	RESET_REQUESTED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	\N	\N	{"identifier": "jamester123"}	2026-11-23 09:28:43.862696+08	jamestermulato@gmail.com
275	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	node	{"purpose": "reset"}	2026-11-23 09:36:38.773943+08	jamestermulato@gmail.com
280	LOGIN_FAILED	\N	jamestrer123	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.7977.167 Safari/537.36	{"reason": "unknown_or_passwordless"}	2026-11-24 23:56:51.941987+08	jamestrer123
281	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.7977.167 Safari/537.36	{"purpose": "login"}	2026-11-24 23:57:47.737903+08	jamestermulato@gmail.com
282	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.7977.167 Safari/537.36	\N	2026-11-24 23:58:04.596982+08	jamestermulato@gmail.com
283	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	{"purpose": "login"}	2026-11-24 23:59:24.30252+08	jamestermulato@gmail.com
361	ALERT_EMAIL_SENT	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"kind": "lockout", "seconds": 16, "attempts": 3}	2026-11-25 12:52:53.53439+08	jamestermulato+h2372@gmail.com
362	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 16}	2026-11-25 12:52:53.545095+08	hand2372
363	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:52:53.688296+08	hand2372
367	ALERT_EMAIL_SENT	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"kind": "lockout", "seconds": 16, "attempts": 3}	2026-11-25 12:53:37.254522+08	jamestermulato+h2372@gmail.com
368	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 16}	2026-11-25 12:53:37.259687+08	hand2372
369	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:53:37.380679+08	hand2372
370	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:53:37.496793+08	hand2372
371	LOCKOUT_TIER_2	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"seconds": 32, "attempts": 6}	2026-11-25 12:53:37.613048+08	jamestermulato+h2372@gmail.com
372	ALERT_EMAIL_SENT	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"kind": "lockout", "seconds": 32, "attempts": 6}	2026-11-25 12:53:41.042298+08	jamestermulato+h2372@gmail.com
373	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 32}	2026-11-25 12:53:41.050201+08	hand2372
374	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:53:41.189386+08	hand2372
375	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:53:41.296749+08	hand2372
376	LOCKOUT_TIER_3	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"seconds": 64, "attempts": 9}	2026-11-25 12:53:41.403724+08	jamestermulato+h2372@gmail.com
377	ALERT_EMAIL_SENT	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"kind": "lockout", "seconds": 64, "attempts": 9}	2026-11-25 12:53:44.520625+08	jamestermulato+h2372@gmail.com
378	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 64}	2026-11-25 12:53:44.522873+08	hand2372
284	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-24 23:59:34.550208+08	jamestermulato@gmail.com
285	LOGGED_OUT_ALL	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-25 00:02:24.305852+08	\N
286	RESET_REQUESTED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	\N	\N	{"identifier": "jamester123"}	2026-11-25 00:02:40.917934+08	jamestermulato@gmail.com
287	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	node	{"purpose": "reset"}	2026-11-25 00:09:41.972672+08	jamestermulato@gmail.com
288	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	::1	node	{"purpose": "login"}	2026-11-25 00:09:45.433664+08	jamestermulato@gmail.com
289	RESET_REQUESTED	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	\N	\N	{"identifier": "jamester123"}	2026-11-25 00:26:25.064075+08	jamestermulato@gmail.com
290	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "reset"}	2026-11-25 00:26:36.172979+08	jamestermulato@gmail.com
291	RESET_TOKEN_ISSUED	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	{"minutes": 10}	2026-11-25 00:27:10.866112+08	\N
292	ALERT_EMAIL_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"kind": "password_changed"}	2026-11-25 00:27:13.414301+08	jamestermulato@gmail.com
293	PASSWORD_CHANGED	35abeb06-cba5-4a42-a757-2f5eca443dcd	\N	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-25 00:27:13.418354+08	\N
294	OTP_SENT	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	{"purpose": "login"}	2026-11-25 00:27:22.214463+08	jamestermulato@gmail.com
295	LOGIN_SUCCESS	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-25 00:27:51.263904+08	jamestermulato@gmail.com
296	ADMIN_VIEWED_DASHBOARD	35abeb06-cba5-4a42-a757-2f5eca443dcd	jamestermulato@gmail.com	100.84.208.58	Dart/3.13 (dart:io)	\N	2026-11-25 00:27:58.591054+08	jamestermulato@gmail.com
299	REGISTERED	41f0f5bc-3783-4a85-b7de-d35013a3e53c	caloymulato@gmail.com	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	{"username": "israel123"}	2026-11-25 00:49:35.629398+08	caloymulato@gmail.com
300	OTP_SENT	41f0f5bc-3783-4a85-b7de-d35013a3e53c	caloymulato@gmail.com	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	{"purpose": "register"}	2026-11-25 00:49:39.050167+08	caloymulato@gmail.com
301	ACCOUNT_VERIFIED	41f0f5bc-3783-4a85-b7de-d35013a3e53c	\N	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-25 00:50:05.205105+08	\N
302	LOGIN_SUCCESS	41f0f5bc-3783-4a85-b7de-d35013a3e53c	caloymulato@gmail.com	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-25 00:50:05.209229+08	caloymulato@gmail.com
303	LOGGED_OUT_ALL	41f0f5bc-3783-4a85-b7de-d35013a3e53c	\N	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	\N	2026-11-25 00:55:44.567426+08	\N
304	LOGIN_FAILED	\N	+probe0@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:03:54.884086+08	probe0
305	LOGIN_FAILED	\N	+probe1@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:04:54.973424+08	probe1
306	LOGIN_FAILED	\N	+probe2@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:05:54.976106+08	probe2
307	LOGIN_FAILED	\N	+probe3@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:06:54.978363+08	probe3
308	LOGIN_FAILED	\N	+probe4@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:07:54.98059+08	probe4
309	LOGIN_FAILED	\N	+probe5@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:08:55.063511+08	probe5
310	LOGIN_FAILED	\N	+probe6@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:09:55.150285+08	probe6
311	LOGIN_FAILED	\N	+probe7@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:10:55.159608+08	probe7
312	LOGIN_FAILED	\N	+probe8@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:11:55.165417+08	probe8
313	LOGIN_FAILED	\N	+probe9@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:12:55.173396+08	probe9
314	LOGIN_FAILED	\N	+probe10@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:13:55.178565+08	probe10
315	LOGIN_FAILED	\N	+probe11@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:14:55.183163+08	probe11
316	LOGIN_FAILED	\N	+probe12@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:15:55.191311+08	probe12
317	LOGIN_FAILED	\N	+probe13@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:16:55.196427+08	probe13
318	LOGIN_FAILED	\N	+probe14@example.com	203.0.113.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 12:17:55.201222+08	probe14
319	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.11	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 11:48:55.208111+08	hand2372
320	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.11	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 11:47:55.29818+08	hand2372
321	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 11:45:55.380805+08	hand2372
365	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:53:32.781237+08	hand2372
366	LOCKOUT_TIER_1	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"seconds": 16, "attempts": 3}	2026-11-25 12:53:32.900652+08	jamestermulato+h2372@gmail.com
322	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 11:44:55.465164+08	hand2372
323	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.13	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 11:42:55.551836+08	hand2372
324	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.13	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"reason": "wrong_password", "source": "demo-seed"}	2026-11-25 11:41:55.559822+08	hand2372
325	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:21:55.564594+08	hand2372
326	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:22:55.56806+08	hand2372
327	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:23:55.573332+08	hand2372
328	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:24:55.578279+08	hand2372
329	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:25:55.581986+08	hand2372
330	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:26:55.585707+08	hand2372
331	LOGIN_SUCCESS	e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	jamestermulato+device@gmail.com	203.0.113.13	Tahanan/1.0 (Android 14; SM-A155F)	{"note": "off-hours sample", "source": "demo-seed"}	2026-11-25 02:15:00+08	devicetest
332	LOGIN_SUCCESS	e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	jamestermulato+device@gmail.com	203.0.113.13	Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0 Safari/537.36	{"source": "demo-seed", "provider": "password"}	2026-11-25 10:33:55.696729+08	devicetest
333	LOGIN_SUCCESS	e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	jamestermulato+device@gmail.com	203.0.113.13	Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0 Safari/537.36	{"source": "demo-seed", "provider": "password"}	2026-11-25 08:58:55.699964+08	devicetest
334	LOGIN_SUCCESS	e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	jamestermulato+device@gmail.com	203.0.113.13	Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0 Safari/537.36	{"source": "demo-seed", "provider": "password"}	2026-11-25 07:23:55.704771+08	devicetest
335	LOGIN_SUCCESS	e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	jamestermulato+device@gmail.com	203.0.113.13	Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0 Safari/537.36	{"source": "demo-seed", "provider": "password"}	2026-11-25 05:48:55.793457+08	devicetest
336	LOGIN_SUCCESS	e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	jamestermulato+device@gmail.com	203.0.113.13	Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0 Safari/537.36	{"source": "demo-seed", "provider": "password"}	2026-11-25 04:13:55.878138+08	devicetest
337	LOGIN_SUCCESS	e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	jamestermulato+device@gmail.com	203.0.113.13	Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0 Safari/537.36	{"source": "demo-seed", "provider": "password"}	2026-11-25 02:38:55.962644+08	devicetest
338	ADMIN_VIEWED_DASHBOARD	4acbcb7b-a2d2-46bb-85bb-ab4169ebd287	jamestermulato+admin@gmail.com	203.0.113.14	Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0 Safari/537.36	{"source": "demo-seed"}	2026-11-25 12:28:56.045069+08	\N
339	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:31:02.717261+08	hand2372
340	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:30:02.726128+08	hand2372
341	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:29:02.72793+08	hand2372
342	OTP_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	203.0.113.12	curl/8.7.1	{"source": "demo-seed", "purpose": "login"}	2026-11-25 12:28:02.73003+08	hand2372
343	ADMIN_ACCESS_DENIED	41f0f5bc-3783-4a85-b7de-d35013a3e53c	caloymulato@gmail.com	::1	node	{"path": "/api/admin/security"}	2026-11-25 12:38:28.655768+08	caloymulato@gmail.com
344	LOGIN_SUCCESS	41f0f5bc-3783-4a85-b7de-d35013a3e53c	caloymulato@gmail.com	\N	\N	\N	2026-11-25 12:38:29.8833+08	caloymulato@gmail.com
345	CSRF_REJECTED	\N	\N	::1	node	{"path": "/api/auth/logout-all", "method": "POST", "origin": "https://evil.example"}	2026-11-25 12:38:30.016917+08	\N
346	HONEYPOT_TRIGGERED	\N	\N	::ffff:127.0.0.1	Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.26100.9818	{"path": "/register"}	2026-11-25 12:49:16.386094+08	\N
347	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:52:08.756915+08	hand2372
348	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:52:08.844222+08	hand2372
349	LOCKOUT_TIER_1	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"seconds": 16, "attempts": 3}	2026-11-25 12:52:08.916141+08	jamestermulato+h2372@gmail.com
350	ALERT_EMAIL_SENT	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"kind": "lockout", "seconds": 16, "attempts": 3}	2026-11-25 12:52:13.815444+08	jamestermulato+h2372@gmail.com
351	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 16}	2026-11-25 12:52:13.825146+08	hand2372
352	LOGIN_BLOCKED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"seconds": 12}	2026-11-25 12:52:13.839065+08	hand2372
353	LOGIN_BLOCKED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"seconds": 12}	2026-11-25 12:52:13.849474+08	hand2372
354	LOGIN_BLOCKED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"seconds": 12}	2026-11-25 12:52:13.861739+08	hand2372
355	LOGIN_BLOCKED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"seconds": 12}	2026-11-25 12:52:13.873181+08	hand2372
356	LOGIN_BLOCKED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"seconds": 12}	2026-11-25 12:52:13.882164+08	hand2372
357	LOGIN_BLOCKED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"seconds": 12}	2026-11-25 12:52:13.911162+08	hand2372
358	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:52:49.626936+08	hand2372
359	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:52:49.743686+08	hand2372
360	LOCKOUT_TIER_1	07b41a06-dc31-4a61-8a15-cd3149a95c76	jamestermulato+h2372@gmail.com	\N	\N	{"seconds": 16, "attempts": 3}	2026-11-25 12:52:49.862379+08	jamestermulato+h2372@gmail.com
364	LOGIN_FAILED	07b41a06-dc31-4a61-8a15-cd3149a95c76	hand2372	\N	\N	{"reason": "wrong_password", "lockedFor": 0}	2026-11-25 12:53:32.666524+08	hand2372
\.


--
-- Data for Name: auth_refresh_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_refresh_tokens (id, user_id, token_hash, device_name, ip_address, user_agent, created_at, last_used_at, expires_at, revoked_at) FROM stdin;
d48b2075-bf5b-4fac-968a-ea79baba312a	41f0f5bc-3783-4a85-b7de-d35013a3e53c	abec5347d3fbc9fa61c9716355ccb5dbe920a2bb18194b9192d6e65b3c4b1fe0	Windows	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	2026-11-25 00:50:05.224748+08	\N	2026-12-25 00:50:05.223+08	2026-11-25 00:55:44.55498+08
244fff4a-4a4a-42b4-abae-d6338b0860d4	41f0f5bc-3783-4a85-b7de-d35013a3e53c	bc36449c2dbbf93f246fc139e6ce044a6b12c84c971eb50b4c58e2bccc0b3bba	\N	\N	\N	2026-11-25 12:38:29.887424+08	\N	2026-12-25 12:38:29.883+08	\N
096f0c16-012d-4c6d-aa76-fa22f9157404	35abeb06-cba5-4a42-a757-2f5eca443dcd	97d543b8005f9502278017749e79c5fbb69ec79047f9b36a281397d9515e2821	Dart/3.13 (dart:io)	100.84.208.58	Dart/3.13 (dart:io)	2026-11-25 00:27:51.273968+08	\N	2026-12-25 00:27:51.272+08	\N
\.


--
-- Data for Name: boarding_house_memberships; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.boarding_house_memberships (id, boarding_house_id, user_id, role, status, joined_at, removed_at, removed_by, updated_at) FROM stdin;
1323f937-3c14-4a7b-ab14-aab0fb8ba850	f664b487-71d5-4241-89e4-4a77fab02519	35abeb06-cba5-4a42-a757-2f5eca443dcd	owner	active	2026-11-10 21:23:20.206406+08	\N	\N	2026-11-10 21:23:20.206406+08
e17eb1fa-db89-44c8-bbaf-b651cbbc959c	dfbc5a44-d183-4d99-9e4b-e30fe06ccca6	35abeb06-cba5-4a42-a757-2f5eca443dcd	owner	active	2026-11-11 13:17:07.873762+08	\N	\N	2026-11-11 13:17:07.873762+08
7e8ce8ac-cccc-458e-970e-d1554985c2da	f664b487-71d5-4241-89e4-4a77fab02519	41f0f5bc-3783-4a85-b7de-d35013a3e53c	tenant	active	2026-11-25 00:51:02.089474+08	\N	\N	2026-11-25 00:51:02.089474+08
\.


--
-- Data for Name: boarding_houses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.boarding_houses (id, owner_user_id, name, domain, join_key, is_active, created_at, updated_at) FROM stdin;
f664b487-71d5-4241-89e4-4a77fab02519	35abeb06-cba5-4a42-a757-2f5eca443dcd	Green Haven Boarding House	green-haven-boarding-house-2	3CVA-5GPX-H7X8	t	2026-11-10 21:23:20.206406+08	2026-11-10 21:23:20.206406+08
dfbc5a44-d183-4d99-9e4b-e30fe06ccca6	35abeb06-cba5-4a42-a757-2f5eca443dcd	Green Haven Boarding House	green-haven-boarding-house-3	5WX7-YZSY-Z2BB	t	2026-11-11 13:17:07.873762+08	2026-11-11 13:17:07.873762+08
\.


--
-- Data for Name: concern_attachments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.concern_attachments (id, concern_id, storage_path, public_url, mime_type, file_name, created_at) FROM stdin;
036c580a-6116-454a-8e81-ee9bfac633a0	2fb13e31-5551-4258-97cf-df56ed3acb95	C:\\Users\\caloy\\StudioProjects\\Tahanan\\backend\\uploads\\att_1794317272142_45673804_scaled_1000021493.png	/uploads/att_1794317272142_45673804_scaled_1000021493.png	image/jpeg	scaled_1000021493.png	2026-11-10 21:27:52.150292+08
\.


--
-- Data for Name: concerns; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.concerns (id, boarding_house_id, tenant_id, reported_room_id, category, subject, details, status, owner_response, responded_by, responded_at, created_at, updated_at, rating) FROM stdin;
2fb13e31-5551-4258-97cf-df56ed3acb95	f664b487-71d5-4241-89e4-4a77fab02519	a87f2d39-b3f9-4f73-b66b-305d7f22b6da	\N	maintenance	hsshh	Haha	resolved	nigga	35abeb06-cba5-4a42-a757-2f5eca443dcd	2026-11-11 00:00:56.52887+08	2026-11-10 21:27:52.135979+08	2026-11-11 00:00:56.52887+08	\N
\.


--
-- Data for Name: ip_blocks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ip_blocks (ip_address, blocked_until, reason, created_at) FROM stdin;
203.0.113.10	2026-11-25 12:43:56.128212+08	15 failures in 10 minutes [demo-seed]	2026-11-25 12:33:56.128212+08
203.0.113.11	2026-11-25 12:43:56.22821+08	6 failures in 10 minutes [demo-seed]	2026-11-25 12:33:56.22821+08
203.0.113.12	2026-11-25 12:40:56.312616+08	6 wrong OTP codes in 10 minutes [demo-seed]	2026-11-25 12:33:56.312616+08
203.0.113.13	2026-11-25 12:32:26.396916+08	13 failures in 10 minutes (expired sample) [demo-seed]	2026-11-25 12:33:56.396916+08
203.0.113.14	2026-11-25 12:09:56.400426+08	13 failures in 10 minutes (expired sample) [demo-seed]	2026-11-25 12:33:56.400426+08
\.


--
-- Data for Name: login_otps; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.login_otps (id, user_id, code_hash, expires_at, attempts, used, resend_count, last_sent_at, created_at, ip_address, user_agent, purpose) FROM stdin;
20ca0b5c-8129-42eb-a714-9f7293a94d2e	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$oLRhsGDIbileI1Oz1zFYZA==$IkIc4CBXmrKm0H2yxHNQINyaRn+71ywdsL81XIhXMkfalw8Durzk13AD2j2UHqnhQ/5NxFawshuKYp/4jviWOg==	2026-11-23 09:33:36.564445+08	0	t	0	2026-11-23 09:28:36.564445+08	2026-11-23 09:28:36.467376+08	::1	node	login
5e50edcd-15e0-47fe-9656-e633a85a9c8c	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$Cm3hOGKVewBEO1JKCeYcEw==$tkVTFp2IjHeEf8Q2zJJmGxqSq/zmbH+RX2IxLLjgXUu1glb+JawXG5V5FCQCJtmar+KYnIycJ5oLWzrjwHxVUg==	2026-11-13 18:34:12.597852+08	0	t	0	2026-11-13 18:29:12.597852+08	2026-11-13 18:29:12.541711+08	::1	curl/8.22.0	login
26f2ed41-9d32-4b37-9afc-78c2a2c6a20c	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$3pAgTdBwnabCNoTr2yEOzw==$eAGM+JcGno5K7TxklRueoLJVivBXTwlDVfJLuNBGABx5yHDz6LjoIrjL2Vi+P1qK1T5EQ/m6HZWiPACR8NrcTQ==	2026-11-18 21:46:57.045875+08	0	t	0	2026-11-18 21:41:57.045875+08	2026-11-18 21:41:56.822454+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	login
84b61f34-b2c9-4548-a508-8c3cb02ee43f	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$5te2dmGC6PO85pABiLb3fg==$Toz0mBjS31VNw5xZz2jYTCxsWZiyV+cnGd4woahcByq3NOnGU1uormtWuoZKYM2+hKINZqpfDuHmf51cvVwI1A==	2026-11-13 19:17:21.295646+08	0	t	0	2026-11-13 19:12:21.295646+08	2026-11-13 19:12:21.199623+08	::ffff:127.0.0.1	Dart/3.13 (dart:io)	login
f9d85f66-c573-4619-8dbf-04eb4bc50289	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$M/0/qXrvrI1bAEt7rSSLwQ==$asZuixaEcOllYdLlemnCo3KxuZ/617w+qZFEuDsA0GiE3Y9hjg4t7XBvVMhCk281N11lyAV5Iv7O0bjAjGtXTw==	2026-11-18 12:13:41.088728+08	0	t	0	2026-11-18 12:08:41.088728+08	2026-11-18 12:08:41.009881+08	100.84.208.58	Dart/3.13 (dart:io)	login
da559c39-6781-448e-a16f-34c72ecd1c7a	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$QMVYfrkOaIQ6h3zxZ/3Eqw==$bJ5nJaS4S46XgdLk+B9M6E0jhuruHhhKLtTnBE6IVZxB91ERhZ4y67XI+aSQfg0vIuliCPEM7BrJcZSSNNo0UA==	2026-11-16 22:10:29.000719+08	0	t	0	2026-11-16 22:05:29.000719+08	2026-11-16 22:05:28.898347+08	::ffff:127.0.0.1	Dart/3.13 (dart:io)	login
3551bea8-d844-4ac7-8084-74afa62444c6	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$YNgfiQvTcAijmKM4gwOXAg==$o7xQCNq9AwWrGn4ZSio+5f5B4zaPqUQFpehHHY8a3v3i6So+wpqRv4NecNIalvS6sMRX0aS69lzu2ewBabt6dg==	2026-11-16 22:12:08.809938+08	0	t	0	2026-11-16 22:07:08.809938+08	2026-11-16 22:07:08.758338+08	::ffff:127.0.0.1	Dart/3.13 (dart:io)	login
5b243533-e7d2-4194-b9a8-5818b60e5e84	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$farYhwvReWiiAXv8/eujVw==$z+Eshs8PQ/KYoB1wlxHmpCcu6pGHH+nwfqE5JeOsfcQzFlcBjmeuXn9ovJuSnmHPjql6XAEkFdRxpcjEfbCNKw==	2026-11-17 20:56:15.19045+08	0	t	0	2026-11-17 20:51:15.19045+08	2026-11-17 20:51:15.134667+08	100.84.208.58	Dart/3.13 (dart:io)	login
fd3ffd04-7ce8-4891-af99-8d2daa89a639	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$VR2jIjX+UmlnhdBG4CGx/w==$lFEIdbPyo5p8LJRCB/wRmRGla3FDmgUkSW1aqQgGdxkhAoDz6xpkL0DnMIXzZ1LrGN+HxfvSlqeHlmsvQ4QBmQ==	2026-11-18 21:28:32.337183+08	0	t	0	2026-11-18 21:23:32.337183+08	2026-11-18 21:23:32.268366+08	100.84.208.58	Dart/3.13 (dart:io)	login
cd807acc-8580-4861-bbae-ac4c9e44a0b9	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$O0ypsVfD0nKajvb2wI8JbA==$il67zEzO5DU3VMY5GZUpxGeAaN9dnr6g3sxCOloZRYSCYybvPpjswmXfwxOJzHbI3bBpgATIsjTreB8TEamxLQ==	2026-11-17 21:07:01.369464+08	0	t	0	2026-11-17 21:02:01.369464+08	2026-11-17 21:02:01.315109+08	100.84.208.58	Dart/3.13 (dart:io)	login
2952af3f-d88a-43fb-86b7-7d3d64bf7487	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$j75yHyu5f9sph2ZRCnoN0Q==$g25AeQg4qy6nZmrTolvjmlrSSthKjUhUa1OaUyNJaecIMJrk4fBr+S3X3goQCWfcM7vSeonieL2RbsEOclKKwA==	2026-11-18 21:36:46.643552+08	0	t	0	2026-11-18 21:31:46.643552+08	2026-11-18 21:31:46.545331+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	login
4f8bdd41-b8f9-41ca-93f1-5279f347fe36	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$d56uqV13RBjTeo3zd49ATA==$WfAnw+XZ7TubhRU7eGkn6tniHUEoJCGal2UCQQfvkukyF69GzsuXa7mebcpzzr7dPKsBc7MNZ+xmE/oxTj6/YA==	2026-11-18 22:56:49.117277+08	0	t	0	2026-11-18 22:51:49.117277+08	2026-11-18 22:51:49.039749+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	login
3e7a0de6-d495-4672-842a-13d14f6710b1	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$qEy5OhzfRPnSsdEdrx948g==$c2HaLXKSltPwoIsubhtVJuZGv6dbur4NR4OMht+dTFDzVUkYnzQBp4V1MJnw8rrdVPri6jT1l5lcKmPxKpFlWQ==	2026-11-18 22:17:02.344192+08	0	t	0	2026-11-18 22:12:02.344192+08	2026-11-18 22:12:02.204381+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	login
6c178592-4e4e-4068-96d2-f095d718d90d	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$iSfEgf39pnjFXuoNliHttw==$eYjEPuPB9OUQAgkOLwH88J3PDQTlDfVjsSxc49afGoRYHaeaAPcKuEgu0fZ4p/InH5U6Oz96yceYOsI+hnVXBw==	2026-11-18 23:24:17.849541+08	0	t	0	2026-11-18 23:19:17.849541+08	2026-11-18 23:19:17.721593+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	login
52c1b8ec-70b9-4292-bf1f-8db336c42f6c	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$Rd0qzhT8Nglt4IFWB9CKGA==$89axSQ+WnkGofigEXP1H1lkWIeTISlvrO84gA6jw+ol8FRj201y78ildhITTlrPMehQVhJvoibwc3guL7I/O0Q==	2026-11-19 00:33:27.284939+08	0	t	0	2026-11-19 00:28:27.284939+08	2026-11-19 00:28:27.21673+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	login
881eebc5-74bf-4a2a-9af9-5b0355fc6c0f	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$dmPxhjVsWPsaaU2vbBxcIg==$njv3OydFnSjMTC4mp6NBfB1p0DBEvI4l2i7mvPmuhjuC8LSA2MhXdGK2zIFlAe9T1orrrI/4SV7v5cH/2wJA0Q==	2026-11-19 01:11:48.546657+08	0	t	0	2026-11-19 01:06:48.546657+08	2026-11-19 01:06:48.473434+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36 Edg/157.0.0.0	login
9de3dad6-fe6d-4708-a627-46e004931e93	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$OPXdJUZdwvOy8jpsilYewQ==$uyFDwjVbSWmqoYVp+UslVwaCzR5VHwkXgjGU8OKmGAv1sYfu2haodE5Q5t47y05mRShL+z7lWkFt56/J8OTcUg==	2026-11-19 18:55:30.263147+08	0	t	0	2026-11-19 18:50:30.263147+08	2026-11-19 18:50:30.03707+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	login
2aef7f68-5ead-4224-8e8e-eaa37806ea6d	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$uO9mH7HtLGjc8l4nDpxPeA==$ppwLYHVLP0JwUUyY1LSVX74uT+DTflClc9hA5XUbSehP4F4dS//vID+c+z30Oc210g8RM5rLbrD1SYvfzCUcJA==	2026-11-19 15:46:00.720916+08	0	t	0	2026-11-19 15:41:00.720916+08	2026-11-19 15:41:00.613306+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	login
5360cd35-a97f-4026-9be9-6c45018b23c9	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$rxsNFyiiy6XUVyffnb3Rlw==$SlonUDbM1tW6DKn0K4aC9oDpTqDjSqz9IfEnV9azqAK1W3ES4kY2pZKgKjunNXnWG63r3jIKCO09V1rGId3q+A==	2026-11-19 15:47:47.398562+08	0	t	0	2026-11-19 15:42:47.398562+08	2026-11-19 15:42:47.298061+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) OpenCode/2.3.0 Chrome/152.0.7977.167 Electron/44.9.1 Safari/537.36	login
631ac15a-d242-41b7-b84a-94d00ef64773	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$pqwKt9A4/r5hQNhttvSvlA==$uglHRxMTj5fJCI3lNwZEPVKJhkgivxubaAVOKIWJ9vbAANQ6C2d9npsOVj714lyz6Of7gtWXvSmoOzzocmJWIw==	2026-11-19 20:32:36.972737+08	0	t	0	2026-11-19 20:27:36.972737+08	2026-11-19 20:27:36.892149+08	100.84.208.58	Dart/3.13 (dart:io)	login
2fc09b89-51e1-4265-81d0-8c6568733b57	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$vJvjlvlun/v+x4yV6z/vBA==$YHW119XiBefVIvv3yt1v/FF/JdBuY2ULJ6xSQLU1vaS34IhhReYcFJI7MztT+hHgxfEGkH4FiKbKJN4KFvHf2g==	2026-11-19 19:02:49.974802+08	0	t	0	2026-11-19 18:57:49.974802+08	2026-11-19 18:57:49.881386+08	100.84.208.58	Dart/3.13 (dart:io)	login
69233d6d-51ee-4346-b85b-012b20f4d9b4	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$O9ejqMmh8T/9G8GqYPUJ9g==$4oiE4pF98JEKMMzSfjBBTKYfrLNI60Qs7D3yAjtzdjYlXVqcodTU+Hz5NOFFy8YDDNsSp3du+b9eRBQLm+dhcw==	2026-11-19 16:42:06.476625+08	1	t	0	2026-11-19 16:37:06.476625+08	2026-11-19 16:37:06.294105+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	login
d52bc2d4-d659-487b-a568-d345648a2aa4	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$AtZL/j36g1IH2gh0NR7Leg==$aAE16DHT9k4AoLDah7YHwcgkh0kPI9/hYJmV0Gbq4DV7Dp5uHrhCfBRnyyJdfklPaZY4ZaviV8o2hb8I3OzcGA==	2026-11-19 17:47:36.211399+08	0	t	0	2026-11-19 17:42:36.211399+08	2026-11-19 17:42:36.101236+08	100.84.208.58	Dart/3.13 (dart:io)	login
943fdc30-1452-4c3a-ac34-958c0c36de95	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$j8+RSx5A7UcfYVLjC0UHdw==$JmiQiT4l1H2Wo1vfknFoCMl5JdXOEbOoWISxx0MCLiAMEC/gXe+lWHpS53NZKxH/lP2tM5nu9S+jVicvvuLf6w==	2026-11-19 18:32:37.291384+08	0	t	0	2026-11-19 18:27:37.291384+08	2026-11-19 18:27:37.142025+08	100.84.208.58	Dart/3.13 (dart:io)	login
43af359f-8757-430a-b03f-e20c59a8a720	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$//sj0N6rIPvESHTnBXNx0A==$6a5VRGUb4eYVOBCb6sGss4uYiD9YCkMEaqKAh4+Nb1D7R0K3Z5mHBxItWe071Pan4FqZ+j0+ffu4YcBiRcUyYw==	2026-11-19 19:33:06.679953+08	0	t	0	2026-11-19 19:28:06.679953+08	2026-11-19 19:28:06.593205+08	100.84.208.58	Dart/3.13 (dart:io)	login
8989413d-1fe3-445d-bf67-6e97d10ad2d6	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$hp1Ckg2ugxSSFFXkbZ9wpA==$myxI+ISGjmWkgJX7hOWhpQiePipPD+lGz56kKbqDUDpaKEeXPEd5gDtgsIdB38fdXW9NE2hPQa2QBUP2JHZxFA==	2026-11-19 18:35:29.106219+08	0	t	0	2026-11-19 18:30:29.106219+08	2026-11-19 18:30:28.941175+08	100.84.208.58	Dart/3.13 (dart:io)	login
2d613b43-a95a-4ad2-bc58-663cdbbc8dd3	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$cQIMIdsVOZ1NzNWxmu9kdQ==$qRYdVB9CeTSWms3xJnmVHN0iUQUvQU/ywxhU6XblW+2pw15L3bhFb7DyFGdtGK4bb80pO6Be0RBFmqxo9IH1yQ==	2026-11-19 18:53:27.867909+08	0	t	0	2026-11-19 18:48:27.867909+08	2026-11-19 18:48:27.663626+08	::1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	login
074117f2-f190-425d-9cb8-f2a8a91322d5	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$4pwVm3WVPmV9PmR4aJJDkw==$dL7ey4TxgzjBlvMZQ9Tyt+ImapDujOGzZH5NdmuKgcPtV+gfbzcWDL6ytLXhFiWJcde1dwyNUtgwNssiQNInsA==	2026-11-19 21:23:39.344805+08	0	t	0	2026-11-19 21:18:39.344805+08	2026-11-19 21:18:39.294615+08	100.84.208.58	Dart/3.13 (dart:io)	login
441b338c-7100-4d09-9aff-fe960d6428ff	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$CYbecVW0huOO/mI2tntZNg==$oW+Z2BG4dYoVKddlEvzrYdnGOE7bzGwfuegTs/3QQ9rkVAqLo8FZf2cVVDVpZQrSUQy4W+TdLPvqYmvolsu5Kg==	2026-11-19 20:41:16.287981+08	0	t	0	2026-11-19 20:36:16.287981+08	2026-11-19 20:36:16.072785+08	100.84.208.58	Dart/3.13 (dart:io)	login
8792b861-0cc4-4cce-85d4-2d30de44bc59	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$77KUoUpeMqaNhqQ3Bo2RFQ==$/35/CGJYjxdg2Uj892kL+sLgmYBCE5uXjKzSyrqDq2wt8CmDJg4EOHQZx6sqqCZalU8sFVQMevUvAWn4GepWJg==	2026-11-19 19:54:52.355335+08	0	t	0	2026-11-19 19:49:52.355335+08	2026-11-19 19:49:52.279877+08	100.84.208.58	Dart/3.13 (dart:io)	login
3c0aa10c-0292-4cc7-a873-ad7b0242caea	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$qUKtw1Pxiy+rXbd3dXQbFA==$Asvk8Msa4VBlCX/kiTmVGyK9YPRsyttLHelrS3ALXikTQ2U2qaVTHSDD6rkRM1oXKPgfZHj6kR8Hjs1kvIJOTA==	2026-11-19 20:09:04.79752+08	0	t	0	2026-11-19 20:04:04.79752+08	2026-11-19 20:04:04.695976+08	100.84.208.58	Dart/3.13 (dart:io)	login
f9357436-065e-4e69-bd9f-5f4d9a78bca5	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$fg/M7o7WvFzI0MzbWSNbfQ==$eyERGgQNvUcMGj30X4K7tjLuImHeDlQWkXiWMBaL/JfVIOg99LpHzVmQhvv2QwfVplXKwddjd4TF9+Wbty0cWw==	2026-11-19 20:19:06.669577+08	0	t	0	2026-11-19 20:14:06.669577+08	2026-11-19 20:14:06.436457+08	100.84.208.58	Dart/3.13 (dart:io)	login
dcec063c-528a-44d9-84fc-e16bca3b1d1e	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$XsQA2YwtSQTh596itRXtkw==$CtzB3Hq0tuFOZNwsX7wi5uQi5gQ9GCBV3I7UT67wZmJeUsxTH6ikdMJSKM2C9uO9xsgseGxpo8vE8wL2GBjE5g==	2026-11-19 21:00:11.454713+08	0	t	0	2026-11-19 20:55:11.454713+08	2026-11-19 20:55:11.360349+08	100.84.208.58	Dart/3.13 (dart:io)	login
ebebceab-c7c0-45d8-89f3-1b23be2174c8	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$RbOM3C/1Q9DL36AW0HffpA==$WXBPTjctEIXMT6kjdOkRDKKpc+zwZWpRZHml5EkAiwxmYbc0LEL8xWRxfVyIp21YxFNLY3CMpHTTR9EYsmKJww==	2026-11-19 21:27:41.801089+08	0	t	0	2026-11-19 21:22:41.801089+08	2026-11-19 21:22:41.727661+08	100.84.208.58	Dart/3.13 (dart:io)	login
3ed4d336-d220-415a-a9b1-2a0135034c34	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$03FDvycKq4AXqSqVjk5NgA==$wX9Zz3+ryirQ0pEMvB/CRs2A1aWJQhefsUcsTkwvKlbXCt4j8EhD4p6STkYKBVpRg/al/gMqyvaSjOTxxxtdjg==	2026-11-19 21:22:58.035673+08	0	t	0	2026-11-19 21:17:58.035673+08	2026-11-19 21:17:57.960828+08	100.84.208.58	Dart/3.13 (dart:io)	login
9a831c30-0031-461d-9cb3-7973c7024c76	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$jfkDJJTj7qU7uwtd1vyqaw==$0A19PyRC8pHwKhZmwqhX3ewLV7fzJdV88vvNXzmjG3QFIB9PsNNDJ6x93oaaqB3XaY13GaTSWJLQpV8P9Y0GJg==	2026-11-23 09:16:31.792988+08	0	t	0	2026-11-23 09:11:31.792988+08	2026-11-23 09:11:31.683618+08	100.84.208.58	Dart/3.13 (dart:io)	login
05515ce2-a1cc-45c2-82e8-77602df1dc67	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$eZl5jetz/O3H0uG1xYvGWw==$deqmUwquNKfb9xGF9BUpeFcsYBrNiJ7zrJ1hhRrVhLJMQj2WNfonm7WEanDj2HbCF8ieN+K2ufUziOJ58tGpEg==	2026-11-20 18:05:05.822581+08	0	t	0	2026-11-20 18:00:05.822581+08	2026-11-20 18:00:05.755273+08	100.84.208.58	Dart/3.13 (dart:io)	login
67296fee-1580-4ca4-8e8d-8ce452680154	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$fs6L1ks4D6XOxszU6sp5+Q==$v6YypGZNiYlzXYy1lWyrj6JoQrup3PY7JVcCHNVPJ6hr1rx40sS4q4yTQl0Cor2AweAeqoETjUF4jJCfgzTryw==	2026-11-20 17:15:44.396475+08	0	t	0	2026-11-20 17:10:44.396475+08	2026-11-20 17:10:44.34129+08	100.84.208.58	Dart/3.13 (dart:io)	login
069ffadc-f6c8-4222-b336-6f70ec8df5ad	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$tbMRPGiIMXuewMOeaZIXqw==$MbWmQ0GlaX7gapeL0U2IYTq9pTZdACxHSEkQ0J5LZ/16ET/Lotr5Km+SRyWV0oh4onftG+qChDq0hsfOspWzJA==	2026-11-23 09:26:44.85349+08	0	t	0	2026-11-23 09:21:44.85349+08	2026-11-23 09:21:44.757668+08	100.84.208.58	Dart/3.13 (dart:io)	login
c0079c98-6e35-41da-a4c5-769d88d119e7	41f0f5bc-3783-4a85-b7de-d35013a3e53c	scrypt$16384$8$1$BCbQYJErql5oaMYppHi2lg==$8qgUGJVC3/UE1Au8bMz45QO+zYOUn1qZdp/UOav7NVZkZoDEA20zJwEn8O4xytZ4bh6aa/LzuWutq2c3d2Rc3A==	2026-11-25 00:54:35.777623+08	0	t	0	2026-11-25 00:49:35.777623+08	2026-11-25 00:49:35.662552+08	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	register
64559858-eb48-4290-b86e-5ff3e100d0c6	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$3TZGblMaWW/e4Iz5E7Esjw==$kdq8i9oWIIxNgyZSebAOC1QWk+70v2xvOZCdWoMU8sxJOQel7BKNKz7BRii2frwtrzpx8AVdkZ44JfhwwhkbPw==	2026-11-25 00:02:43.628474+08	0	t	0	2026-11-24 23:57:43.628474+08	2026-11-24 23:57:43.452943+08	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.7977.167 Safari/537.36	login
af6a5120-33c0-4e60-b914-f747f26e1682	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$8fEcxxF0R696NOiFcgMqGw==$qYpWNVte1uqBOGch1g6YUMOiVcVhKD+/WwV11PayuFwupARFA8P8cVKXbs1jHvhRqF0KLsV2l8e6Lfp3M+NRYw==	2026-11-25 00:04:19.473284+08	0	t	0	2026-11-24 23:59:19.473284+08	2026-11-24 23:59:19.340901+08	100.68.121.7	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/157.0.0.0 Safari/537.36	login
20972bb1-8a74-45f4-baa5-cb7ea3535bb0	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$C+7YveoRm4888eIo+pCsJA==$GfcCL6hXpYcIG2UQXf780jY3Y7asiyhpAEbn+VLZZ4bk/lRrrYhXEYU1MgffOsuAC4/gBbYyWFAYrxvNNLwoug==	2026-11-23 09:41:35.092412+08	0	t	0	2026-11-23 09:36:35.092412+08	2026-11-23 09:36:34.997408+08	::1	node	reset
b099141f-f25f-48ab-b861-3371927dcd1d	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$7siOVPn/CNmk1nJ4mohN8w==$8S+ttGTOgWws/ec8MooBqhk/UteAgaCXMwIWLvdgIpb+k3MjOMQcpDooA31pwMaZ2yMwYo3hXElh2PF3Y550dg==	2026-11-25 00:14:34.82648+08	0	t	0	2026-11-25 00:09:34.82648+08	2026-11-25 00:09:34.543103+08	::1	node	reset
5626469e-45b9-4e60-9128-e63c0c65fe86	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$s7GJDptNR7lJ13NaZ/USZw==$wKB4CqocjLyVEK+ImfFqMuBxMSkiW4sO3qsAyfzh+uV6O7wqlPCgiJb7PMo0AVncN0qTxq1NSaNozXPXCS3+WA==	2026-11-25 00:31:32.724667+08	0	t	0	2026-11-25 00:26:32.724667+08	2026-11-25 00:26:32.656106+08	100.84.208.58	Dart/3.13 (dart:io)	reset
75889ab8-0e96-4ef4-92c2-2a98d2adbc3e	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$zIEiMuAMVRTQQnmS9nLWsg==$51JMlSs61Ai8FDE28dogpchFCHYeISik4/KyIsaJsGu9FvkYhfDFGFAFbEZ3gKynOMq955DP/dOv7+S+bYk6Tg==	2026-11-25 00:14:42.472756+08	0	t	0	2026-11-25 00:09:42.472756+08	2026-11-25 00:09:42.330416+08	::1	node	login
ac6eb9a9-3c0b-4691-9051-63292662e2ff	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$1xTK5p7MTG14aavtsHSX/g==$JdQoHE6uiNryzKa4t7Y/wsP8GGA0RNCjorLmXxa3NxEsts8FngtByoR2sRzmHo3aBmCancorlQiLzyQJIxorYw==	2026-11-25 00:32:19.298366+08	0	t	0	2026-11-25 00:27:19.298366+08	2026-11-25 00:27:19.233662+08	100.84.208.58	Dart/3.13 (dart:io)	login
\.


--
-- Data for Name: login_remember_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.login_remember_tokens (id, user_id, token_hash, expires_at, created_at) FROM stdin;
4459c154-dae8-427e-9e23-630fb9ccc181	35abeb06-cba5-4a42-a757-2f5eca443dcd	23762d1889744ea1b505da8bc22968c7889a5d21d4a4204245a00d617e8a6836	2026-11-25 12:09:05.511+08	2026-11-18 12:09:05.51988+08
e011d56e-de07-424a-92ac-c0364387decd	35abeb06-cba5-4a42-a757-2f5eca443dcd	2f35d6683087f4d20645ab69d80872346e4a04d01c4a555542c71cc5f12b1cb6	2026-11-25 21:23:58.844+08	2026-11-18 21:23:58.853858+08
2b98238b-3c8e-4493-9a2b-ae654423d704	35abeb06-cba5-4a42-a757-2f5eca443dcd	f7fc8ab492731467febfd342687fed76e3c9a90b84c2ff21ce72ee08e26a0429	2026-11-25 21:32:07.532+08	2026-11-18 21:32:07.540726+08
b0038aeb-ccad-4c38-b376-2aed6cdcdae6	35abeb06-cba5-4a42-a757-2f5eca443dcd	d322a78cffa9583d703167c3f288310c505bd1f03c2df83f6af2c1eaef73cf3a	2026-11-25 21:42:33.153+08	2026-11-18 21:42:33.164736+08
6836c4a3-cfb9-4308-ad7b-64582e431513	35abeb06-cba5-4a42-a757-2f5eca443dcd	705ff402b0e0b9801a7048c9387ca764fc965ef0542a20011fe5c2d553f0ceee	2026-11-25 22:12:59.82+08	2026-11-18 22:12:59.827302+08
91724ef1-f913-47ea-8833-81252e0d392f	35abeb06-cba5-4a42-a757-2f5eca443dcd	457998a648132feda08bc46e288be7a625eea5d22b8aa107ba7677d608cfc821	2026-11-25 22:52:31.282+08	2026-11-18 22:52:31.288659+08
07780472-5d4e-43b9-b8d7-cc6704096fc3	35abeb06-cba5-4a42-a757-2f5eca443dcd	eb1db08f251fde41db22b1fc845c063cd493b4061ed1b1955fa70079c2ae65a9	2026-11-25 23:19:42.997+08	2026-11-18 23:19:43.099924+08
f004bdce-b6b1-425d-827d-d0d1bdd21178	35abeb06-cba5-4a42-a757-2f5eca443dcd	76db1adaf353a69dfba1138a366e8c34f23d428bb82a9e008ca05699e1a5b9db	2026-11-26 00:28:50.443+08	2026-11-19 00:28:50.452095+08
535df8b3-5c91-49ea-b6e8-28b3882cd048	35abeb06-cba5-4a42-a757-2f5eca443dcd	49768d4fb82713343b0508963f9da5babfbe86e5225dd2c39d5ef03578dda6e9	2026-11-26 01:07:16.468+08	2026-11-19 01:07:16.491517+08
fd408f84-d8bf-485e-95c9-a77d4c1b58f4	35abeb06-cba5-4a42-a757-2f5eca443dcd	7c3ee06967514f6922cfbb46f418bbcf76fbb440e853c01ffd80ef208b14b944	2026-11-26 15:41:31.634+08	2026-11-19 15:41:31.648532+08
efc26d70-0e8d-47d4-bf80-fbba5e2bf4b3	35abeb06-cba5-4a42-a757-2f5eca443dcd	12560d2ad4a5342c5cfb7080dec98da9e05bfafd559589fab30351e32f6af021	2026-11-26 15:43:08.142+08	2026-11-19 15:43:08.152053+08
1f64a364-318e-44a2-9993-f6263a7d88a0	35abeb06-cba5-4a42-a757-2f5eca443dcd	86a8a209feb7294fb25e126702b537f0d05de01e75024ec737cb17d58b271c66	2026-11-26 16:37:42.08+08	2026-11-19 16:37:42.085648+08
28b1695b-7141-421e-8dba-c8ba418f5948	35abeb06-cba5-4a42-a757-2f5eca443dcd	35bae7606654daf05054dfd32f097fe56373fb6f2019dbd70a241fcb8e1f5583	2026-11-26 17:42:54.83+08	2026-11-19 17:42:54.839964+08
ab3cbe5e-2db2-43e7-8f73-e6730b86a3a3	35abeb06-cba5-4a42-a757-2f5eca443dcd	c10845e956aa6e4c58893f8fb8138abba3d760e0d12b4e3f199823c0f952b074	2026-11-26 18:28:02.242+08	2026-11-19 18:28:02.268825+08
46f6d153-9aa6-4342-aad1-8c195912f114	35abeb06-cba5-4a42-a757-2f5eca443dcd	060639206201ec6c7de54cc64b6ed333b466b422718fdc49caa8d034935cffea	2026-11-26 18:30:49.541+08	2026-11-19 18:30:49.544598+08
8e963540-cfb5-4e68-ac4b-df65f94f2803	35abeb06-cba5-4a42-a757-2f5eca443dcd	c3521e13476b38f13c60898d4a18825d854bbc13aa4272a17704019d0bb38f15	2026-11-26 18:50:46.119+08	2026-11-19 18:50:46.126515+08
fc444573-9928-423e-aa2b-9982444dafba	35abeb06-cba5-4a42-a757-2f5eca443dcd	c4ae3c6d1443cb72fc5d03baafb529640c2954c6ad8e2de47d9d90da42b5f473	2026-11-26 18:58:17.64+08	2026-11-19 18:58:17.666193+08
d39bcd1a-3a1c-4776-9a59-6bae59142a19	35abeb06-cba5-4a42-a757-2f5eca443dcd	1b5c9af1eec3857b4ae7630e66a39bc285a55c26c0c0f952c123a246cc3d2f2a	2026-11-26 19:28:29.046+08	2026-11-19 19:28:29.053413+08
76f80d9b-14fc-43d2-8feb-ce923c00d159	35abeb06-cba5-4a42-a757-2f5eca443dcd	80c3add92c76267de6e37eb2eadb26d6661ec21345e915684d17b8aabb782294	2026-11-26 19:50:14.867+08	2026-11-19 19:50:14.872305+08
f0fd0d43-53bd-47b5-ba4d-7da4f32ab591	35abeb06-cba5-4a42-a757-2f5eca443dcd	fa153cd34d126121d69f0aee49c861f4176848e907debb468d6100c16e443610	2026-11-26 20:04:36.815+08	2026-11-19 20:04:36.820761+08
3b2884da-20ae-4788-9c50-b68be3b6dce0	35abeb06-cba5-4a42-a757-2f5eca443dcd	4a85ed6fc5e653887dd61fba027862cd96c7367a72a17009a62ce91aaa3426a5	2026-11-26 20:14:30.19+08	2026-11-19 20:14:30.201153+08
ef25d70b-1420-4282-8540-ada1f313090d	35abeb06-cba5-4a42-a757-2f5eca443dcd	bb5eed13b06202168a7873fdc549e69e426b755b896c6527dd29d2afd93f190d	2026-11-26 20:28:01.617+08	2026-11-19 20:28:01.623386+08
136da689-62f5-4e34-bfdf-f842618ed051	35abeb06-cba5-4a42-a757-2f5eca443dcd	354f7e4ab8aab398763cea6fb946ac9a41f987d00bc417290202e92f0c9e1753	2026-11-26 20:36:37.731+08	2026-11-19 20:36:37.739324+08
cefcb42e-065e-464e-9be1-b0485c7abfdc	35abeb06-cba5-4a42-a757-2f5eca443dcd	cfac0b082519cdb17b0e608330d9143fe675ae90a91f847c500d79799f4b0fe7	2026-11-26 20:55:41.863+08	2026-11-19 20:55:41.868895+08
0493b936-9d0a-4274-a7ea-e8b8b8eea5e3	35abeb06-cba5-4a42-a757-2f5eca443dcd	f2e2c71958bff89884375c298695225b3afde88ac72e260c03bc2c0e8e3db339	2026-11-26 21:18:52.582+08	2026-11-19 21:18:52.62672+08
6eb75cfd-d50f-4635-88bb-74867ac1ff81	35abeb06-cba5-4a42-a757-2f5eca443dcd	6450c355a6b94bd91f46b3359f4a75b4bf22a2f8d6f85616e0e322dca612ba74	2026-11-26 21:23:00.585+08	2026-11-19 21:23:00.589182+08
580eeb4b-ebb8-4732-a71d-6f5d469ddee3	35abeb06-cba5-4a42-a757-2f5eca443dcd	fa72ea1474c2cb22c1474621cfa79a085b7ee454984e6228ea054bc22146fb93	2026-11-27 17:11:01.923+08	2026-11-20 17:11:01.931247+08
e3d8a9b3-f28e-4958-b323-e8ecbed031c1	35abeb06-cba5-4a42-a757-2f5eca443dcd	0d7fbc2cc32b50a220933920e3bccfcd77bb96517358863ad1fef3ba81b34700	2026-11-27 18:00:26.691+08	2026-11-20 18:00:26.694948+08
e6700d20-cf2f-4ca1-8fd4-a3aad496e655	35abeb06-cba5-4a42-a757-2f5eca443dcd	7711b379ecf60818119250fd87a4fea83317a1b371a11e6601ee16f4c4b12a01	2026-11-30 09:11:52.342+08	2026-11-23 09:11:52.350836+08
d502eb80-5ad9-4326-a335-dc6b34b5c01c	35abeb06-cba5-4a42-a757-2f5eca443dcd	23da21b1bca053fadacd9f43f1f273b60494c86d4d5a80b1c3effbbfa89de6af	2026-11-30 09:22:02.503+08	2026-11-23 09:22:02.506889+08
ac59a4e7-3187-432e-815f-3719bc150a9f	35abeb06-cba5-4a42-a757-2f5eca443dcd	43d6c968a3447d1fcb61efc96cc1b56e1b15aaa6fb618a3b8d6d33c0faa570ed	2026-12-01 23:58:04.659+08	2026-11-24 23:58:04.689197+08
0af2792b-17c3-4df0-b0b2-83a4378d78a3	35abeb06-cba5-4a42-a757-2f5eca443dcd	08a29e1e7dcbf9e37fc4a2d6d033694f7de95b8cb59abf20a86d2eb99a994d46	2026-12-01 23:59:34.597+08	2026-11-24 23:59:34.605195+08
099d928f-ec4d-4673-9469-23217cdcce3b	35abeb06-cba5-4a42-a757-2f5eca443dcd	514c14a2b72ba0474a633e2513603aaa5dbfda8c0f728a3ad43f8c0617942224	2026-12-02 00:27:51.283+08	2026-11-25 00:27:51.287715+08
\.


--
-- Data for Name: password_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.password_history (id, user_id, password_hash, created_at) FROM stdin;
5	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$Asg6qmvNZ3BqFDgehslwOQ==$wprGrTZqB3+Wp4eBIcFRuqnBnOHY8jqZPG5P0j6dxGSxgwsptOVjV7UU23nIFH74anaJFOryZDE+YMcyI+Hc5g==	2026-11-11 12:45:45.477624+08
13	35abeb06-cba5-4a42-a757-2f5eca443dcd	scrypt$16384$8$1$1BU0H/kxvcNYqOAWT0VugQ==$Xjg+JkOT9MsJwRD1YkqbJC2H/h0fMYAXNVlJvmFUAhtWp8ic6d76+9NKS/9wQdjEwTaMlsAt6GFKmVJti5QfDg==	2026-11-25 00:27:11.09366+08
15	41f0f5bc-3783-4a85-b7de-d35013a3e53c	scrypt$16384$8$1$0BhYfmUznYrXDD1HkyZ1JQ==$0DnrrZLN19cW8TWWCbdVrVfgIvyu4ZxpAxRz9itabC/+dJFkynKYasH4E9H+BOnws4SohkmxT3DWWqIINSuJfg==	2026-11-25 00:49:35.595707+08
16	07b41a06-dc31-4a61-8a15-cd3149a95c76	scrypt$16384$8$1$cdsYkCgErcHgRcDG2JiqZQ==$+LULUUdguuBG2NwyfBDQZ+Wt2IGhXwMvlxIl3uR+L4sbamO+ghHP3d4pp//fjtVt4RUuaRyLyaPKLr86jGTAVg==	2026-10-26 12:33:56.557856+08
17	07b41a06-dc31-4a61-8a15-cd3149a95c76	scrypt$16384$8$1$agP/dHubHDY9n768teFZ2A==$8eeuTi8Sku+zqpgNHie6+yIO+V6n8n2kLsBOjb3h0mqNu/IMTDGwV1svDY1Vs68LBZUZwUWUctwZ0N50jxadDQ==	2026-10-06 12:33:56.684081+08
18	07b41a06-dc31-4a61-8a15-cd3149a95c76	scrypt$16384$8$1$62q6tDtumVyH4xkt3mWP2A==$eGqr0lFhLbBJkjlW4nW8pdMhUNYRh8JMQvgqZagBv+yT87WaSJgfzw7PRmrVFb/oqwd+7KNM5oqtoBIfbdzYYw==	2026-09-16 12:33:56.808627+08
19	07b41a06-dc31-4a61-8a15-cd3149a95c76	scrypt$16384$8$1$3xXoG2QH+5kLK3K8xkITZQ==$BBAq7QesJUNgTnBfou3fM7aXFByYU5kxHvdO6HqJq2aVgQjjtYNTkzayw0XiYOtsLnfdge8P647+afAs1rYODg==	2026-08-27 12:33:56.9157+08
20	07b41a06-dc31-4a61-8a15-cd3149a95c76	scrypt$16384$8$1$k9fnTvhF9XDLYjO4C112+w==$bBg8As+hL7ruZfTqxEjCUGCVOmZbPDf9JJMffUDghTc5bk6gr/DUDLfLCC7/9+7DUhEB3hD9kyDlJVxa95epzg==	2026-08-07 12:33:57.04442+08
\.


--
-- Data for Name: password_reset_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.password_reset_tokens (id, user_id, token_hash, expires_at, used_at, created_at) FROM stdin;
ae7d9846-a1a3-4db3-93d1-32ce3cc28cc4	35abeb06-cba5-4a42-a757-2f5eca443dcd	101346375ec736612db816d78c27c1b39a06ca4af3f2b6c830fe0c546d08eaad	2026-11-11 12:54:36.269+08	2026-11-11 12:45:25.808724+08	2026-11-11 12:44:36.294394+08
ec14d995-59a5-4cd1-bcc8-6a3f27cb8a9d	35abeb06-cba5-4a42-a757-2f5eca443dcd	a924386088a04960799ff20dc4c3d56783edb128075ae15dd03d36b44191e879	2026-11-11 12:55:25.767+08	2026-11-11 12:45:45.330366+08	2026-11-11 12:45:25.823808+08
384188ea-2d66-4dc5-a4d5-204f0f22f029	35abeb06-cba5-4a42-a757-2f5eca443dcd	54fe4c4b16f2736d3ace2042876c33c3ae117b5d491b690e925c4580a5cf4272	2026-11-25 00:37:10.847452+08	2026-11-25 00:27:11.083944+08	2026-11-25 00:27:10.847452+08
a770a29e-3564-4351-8666-209891fd8fea	35abeb06-cba5-4a42-a757-2f5eca443dcd	633471fbfd8e7351117bb1ae4a57ea14a3e4291478ca34fecfac994168b64238	2026-11-11 15:21:13.084+08	2026-11-25 00:27:11.084903+08	2026-11-11 15:11:13.100526+08
\.


--
-- Data for Name: rooms; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rooms (id, boarding_house_id, room_number, capacity, status, created_at, updated_at) FROM stdin;
b6ac716b-ab2d-4769-bfd5-1fdf4df48cff	f664b487-71d5-4241-89e4-4a77fab02519	101	3	active	2026-11-10 21:23:20.206406+08	2026-11-10 21:23:20.206406+08
70327a3d-d877-4d22-8beb-470269ae61da	f664b487-71d5-4241-89e4-4a77fab02519	102	3	active	2026-11-10 21:23:20.206406+08	2026-11-10 21:23:20.206406+08
22f4a15a-51dc-421a-827d-c51d1246d66e	f664b487-71d5-4241-89e4-4a77fab02519	103	3	active	2026-11-10 21:23:20.206406+08	2026-11-10 21:23:20.206406+08
cc6cec56-5178-4fe6-b625-f31efc487533	f664b487-71d5-4241-89e4-4a77fab02519	104	3	active	2026-11-10 21:23:20.206406+08	2026-11-10 21:23:20.206406+08
beb1e9a4-1304-4731-8f48-1a1a05b1f776	f664b487-71d5-4241-89e4-4a77fab02519	105	3	active	2026-11-10 21:23:20.206406+08	2026-11-10 21:23:20.206406+08
194dc366-a1e4-4f2e-b7ac-45885013aeec	f664b487-71d5-4241-89e4-4a77fab02519	106	3	active	2026-11-10 21:23:20.206406+08	2026-11-10 21:23:20.206406+08
fa06cb68-94b3-42b9-9f8e-9707febb750d	dfbc5a44-d183-4d99-9e4b-e30fe06ccca6	102	3	active	2026-11-11 13:17:07.873762+08	2026-11-11 13:17:07.873762+08
f49af80a-4586-4295-b247-463ef77ba719	dfbc5a44-d183-4d99-9e4b-e30fe06ccca6	103	3	active	2026-11-11 13:17:07.873762+08	2026-11-11 13:17:07.873762+08
0a2ecc13-6a46-4b52-a767-070fdfcb5786	dfbc5a44-d183-4d99-9e4b-e30fe06ccca6	104	3	active	2026-11-11 13:17:07.873762+08	2026-11-11 13:17:07.873762+08
a2374fd2-599e-43ce-abe3-f62abe6fa804	dfbc5a44-d183-4d99-9e4b-e30fe06ccca6	105	3	active	2026-11-11 13:17:07.873762+08	2026-11-11 13:17:07.873762+08
6dfc3cc2-db82-40f4-996c-4080bf1040b3	dfbc5a44-d183-4d99-9e4b-e30fe06ccca6	106	3	active	2026-11-11 13:17:07.873762+08	2026-11-11 13:17:07.873762+08
391ae4a0-b698-45d2-a782-c400914b9005	dfbc5a44-d183-4d99-9e4b-e30fe06ccca6	101	3	active	2026-11-11 13:17:07.873762+08	2026-11-25 00:01:19.547928+08
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schema_migrations (version, checksum, applied_at) FROM stdin;
001	a89b61052c03b714af6bafb38041a314d2c5f6ba0181ea2a3e0dbcbae2e468ae	2026-11-09 22:42:26.851529+08
\.


--
-- Data for Name: security_answers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.security_answers (user_id, question_key, answer_hash) FROM stdin;
41f0f5bc-3783-4a85-b7de-d35013a3e53c	Q6	scrypt$16384$8$1$yKfAAP2kmAdVmvvI3PXBYQ==$vuosbpdWqSQDYI7l0jdpwl/40NdYO08/CLFKq9jG1kAMpAZtpU1sQ5K91xut22K6QHFX4n2BPbo8rPZPCVl5vQ==
41f0f5bc-3783-4a85-b7de-d35013a3e53c	Q1	scrypt$16384$8$1$nlhP8YawmnA6jVgol7sgQQ==$PVtv7zx7VU874+sR/h+sNGRyskPOrddJ1rNBn0CoAM4DuBoo4iYCACplAWDWv4sJwqRD4ZJmq1Yt6WM1+UeoOg==
41f0f5bc-3783-4a85-b7de-d35013a3e53c	Q3	scrypt$16384$8$1$7Ib912OI7pSqZIscU7cwXg==$spsmW2c5MtW3z7+d2Vce89MFFxAjC2Ov2c/NB2dPKAXqam0H8Op9rKvcSJW8CCv0enxH8XjRcoHuwmaiqpY2WA==
4acbcb7b-a2d2-46bb-85bb-ab4169ebd287	Q6	scrypt$16384$8$1$yqUHoflPmj8XH4oae86EYg==$XcQsA/sC1P9/i1bdXlR6gloZSXcq3G66nxf//sF68FVNQubHpH3smAGkObRWWj525ia/WWiof6x7zNRSk9uONA==
4acbcb7b-a2d2-46bb-85bb-ab4169ebd287	Q1	scrypt$16384$8$1$I1h50oflGeSKfVKWsRs6Tg==$n1cp2CZBfDzcAk9LRQ0uFlyOFarD0JchnDrc9ybWvde8DyxCT0/55/NSyWIwdG20CrHEkx6Vi1rQ2+w7iI08zg==
4acbcb7b-a2d2-46bb-85bb-ab4169ebd287	Q3	scrypt$16384$8$1$/xUXfyCUtIyjj/Aa8NaZ5A==$J4BSGQAYrlpTpjdTKr1T/pyMc88rFTyZNsYFz9MpvKFfboTSHiG81p+athk5e5phGVAaIK/wMF6UvinZIIa4Dw==
e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	Q6	scrypt$16384$8$1$JhkYJ3rXqnASt6dIikkDyw==$t62wb2XJ85eqGAstd58eNoKH4s+SMJ4KhrwrkavLdJ1XKB3p6eLt29xHInnwiRF3i4lYoMuVJtcUggBlQLnaew==
e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	Q1	scrypt$16384$8$1$FA9e9xNwungxm4KIBQmE/w==$2tuEKDIMBc6/GDfsIKmP6qGx2OEVXIyz3VY9L+G0mwvDxmRlHpL0dnYddIL7TlhQcT2IQ5usmWkAXUV4SYhuZw==
e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	Q3	scrypt$16384$8$1$CjjPB5vnncsDhIUZqpMlUw==$s47ELj1VPWOux4fSxhuW+ZxsBfMTvhjiD+bxODgzSUHNjgP3KF9Jk3As2ROJiwMhZ7JfaX57XuPdqtTj/lh/4w==
07b41a06-dc31-4a61-8a15-cd3149a95c76	Q6	scrypt$16384$8$1$RzohfiKF2htV5DbKeb/9aQ==$9FCaJ7IiVCWiS/2osIOwysu+v/XRPhbULMoa7F6c8dwz5hi5bkHUUCzhtdI1dsFIiycUaPfaPzYqTGT9Pa+pyA==
07b41a06-dc31-4a61-8a15-cd3149a95c76	Q1	scrypt$16384$8$1$b2fLJkbXH7jRkhpwR0cDHQ==$briY1RbuVMPDxsQxWG+1XXTpukJa37tEWsCXsYWCpfGHC0Yo8+6d+3l8susmTUcY2MfUMnuVa5deSnYyfwUCFw==
07b41a06-dc31-4a61-8a15-cd3149a95c76	Q3	scrypt$16384$8$1$01tvjtgevRlIaktcfRsw8Q==$kjc83VJCJo9D558OTshsuFEu52TtaNyq75+jFxBNa2Xq3HQATCSlHJj9ESH8ZVMdPgXb/s+GWOqyM41KpTSStg==
35abeb06-cba5-4a42-a757-2f5eca443dcd	Q6	scrypt$16384$8$1$0fgOmK1E/e4d4K/PvK25jA==$qf10NroRSuVHhh8YyYdxkem56WNWfDxqrY8N5f01dMWaqLr3oIiV41EgY0O1cR8ID67agw67MPRXSnX04DAvFg==
35abeb06-cba5-4a42-a757-2f5eca443dcd	Q1	scrypt$16384$8$1$VtVvYgWcSjy6J8RnxyTLlg==$Hynrx4mDSFVyT8VaO3k1Cp6fb11SGElcknzZImN48WILkEr3pRZulhqwv0yTdBsMYHoJdj+IDyp2MrSVcf47gw==
35abeb06-cba5-4a42-a757-2f5eca443dcd	Q3	scrypt$16384$8$1$oVvUpQ2iRqIfQ5FKeyQ68g==$NU5dwUmhhmeQ2EWLRTSS1JkC190iT+aHiBKXpJ6W505ji16Xv5QivdL2C9U/WsT5YjRuYCh4lEOlS/xy/0UA/w==
\.


--
-- Data for Name: security_flags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.security_flags (id, pattern, target, severity, details, flag_date, created_at) FROM stdin;
2	IP_OVER_THRESHOLD	203.0.113.10	HIGH	15 failures, 15 usernames	2026-11-25	2026-11-25 12:34:12.704772+08
3	ACCOUNT_TARGETED	jamestermulato+h2372@gmail.com	MED	failures from 3 IPs (6 attempts)	2026-11-25	2026-11-25 12:34:12.717457+08
4	OFF_HOURS_LOGIN	jamestermulato@gmail.com	MED	successful login at Wed Nov 25 2026 00:27:51 GMT+0800 (Singapore Standard Time)	2026-11-25	2026-11-25 12:34:12.720246+08
5	OFF_HOURS_LOGIN	caloymulato@gmail.com	MED	successful login at Wed Nov 25 2026 00:50:05 GMT+0800 (Singapore Standard Time)	2026-11-25	2026-11-25 12:34:12.722695+08
6	OFF_HOURS_LOGIN	jamestermulato+device@gmail.com	MED	successful login at Wed Nov 25 2026 02:15:00 GMT+0800 (Singapore Standard Time)	2026-11-25	2026-11-25 12:34:12.725276+08
18	OTP_GUESSING	jamestermulato+h2372@gmail.com	MED	6 wrong OTPs in 10 minutes	2026-11-25	2026-11-25 12:35:08.62589+08
\.


--
-- Data for Name: tenant_account_associations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tenant_account_associations (id, boarding_house_id, tenant_id, user_id, associated_by, associated_at) FROM stdin;
\.


--
-- Data for Name: tenant_monthly_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tenant_monthly_statuses (id, boarding_house_id, tenant_id, academic_year_id, month_start, status, updated_by, updated_at) FROM stdin;
81ca35b0-6fa3-4489-9b3f-2c6bb3cf41da	f664b487-71d5-4241-89e4-4a77fab02519	a87f2d39-b3f9-4f73-b66b-305d7f22b6da	b3eefe68-b808-4a4c-b09f-cfdf43910bd6	2025-12-01	partial	35abeb06-cba5-4a42-a757-2f5eca443dcd	2026-11-11 00:00:43.642729+08
988975d8-2b51-4191-8fb8-b23359c5579e	f664b487-71d5-4241-89e4-4a77fab02519	a87f2d39-b3f9-4f73-b66b-305d7f22b6da	b3eefe68-b808-4a4c-b09f-cfdf43910bd6	2025-11-01	paid	35abeb06-cba5-4a42-a757-2f5eca443dcd	2026-11-11 12:04:00.275739+08
\.


--
-- Data for Name: tenant_room_assignments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tenant_room_assignments (id, tenant_id, room_id, assigned_at, ended_at, assigned_by, created_at) FROM stdin;
25ecbe18-affe-4ff3-849f-2010c8ad83ad	a87f2d39-b3f9-4f73-b66b-305d7f22b6da	b6ac716b-ab2d-4769-bfd5-1fdf4df48cff	2026-11-10 21:27:07.892989+08	\N	35abeb06-cba5-4a42-a757-2f5eca443dcd	2026-11-10 21:27:07.892989+08
\.


--
-- Data for Name: tenants; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tenants (id, boarding_house_id, full_name, email, phone, notes, is_active, created_at, updated_at) FROM stdin;
a87f2d39-b3f9-4f73-b66b-305d7f22b6da	f664b487-71d5-4241-89e4-4a77fab02519	mulato	joritomulato@gmail.com	\N	\N	t	2026-11-10 21:27:07.416806+08	2026-11-10 21:27:07.416806+08
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, auth_provider, auth_provider_uid, email, display_name, avatar_url, created_at, updated_at, password_hash, failed_login_count, locked_until, last_login_at, password_changed_at, token_version, status, privacy_consent_at, username, id_number, first_name, middle_name, family_name, name_extension, birthdate, age, address_purok, address_barangay, address_city, address_province, address_country, address_zip, government_id_ciphertext, government_id_iv, government_id_tag, government_id_lookup, move_in_date, room_type, emergency_contact, tenancy_notes, is_admin, email_verified_at, last_activity_at) FROM stdin;
4acbcb7b-a2d2-46bb-85bb-ab4169ebd287	password	jamestermulato+admin@gmail.com	jamestermulato+admin@gmail.com	Tahanan Admin	\N	2026-11-25 12:28:16.182634+08	2026-11-25 12:28:16.182634+08	scrypt$16384$8$1$XfdJApZBbZjoK+yyoRpRNw==$Zy6rm+lLiRO3dg1N4i+Crw/S/DZP/BmqQFQkHfQqQjfJH92p1OFG59Q8s3/mjFsv5uocAagLNTebKn4S+ezI/w==	0	\N	\N	2026-11-25 12:28:16.182634+08	0	active	2026-11-25 12:28:16.182634+08	tahananadmin	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	2026-11-25 12:28:16.182634+08	\N
e5def9b7-8de0-49a0-a9dc-7d43f2f9cfb5	password	jamestermulato+device@gmail.com	jamestermulato+device@gmail.com	Device Test	\N	2026-11-25 12:28:16.578467+08	2026-11-25 12:28:16.578467+08	scrypt$16384$8$1$J+UcM6LWkJ5V7aKYYC30hA==$bsYpQIn68q2P7emaxWz8CgOGNwHRT6f+iy+na4LboVkfW7UULJYHERESnH/ayHRI/b3M3KK4zPD2mCa2b2ejlQ==	0	\N	\N	2026-11-25 12:28:16.578467+08	0	active	2026-11-25 12:28:16.578467+08	devicetest	2026-0001	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	2026-11-25 12:28:16.578467+08	\N
41f0f5bc-3783-4a85-b7de-d35013a3e53c	password	caloymulato@gmail.com	caloymulato@gmail.com	Israel Panamogan	\N	2026-11-25 00:49:35.25398+08	2026-11-25 12:38:29.906136+08	scrypt$16384$8$1$0BhYfmUznYrXDD1HkyZ1JQ==$0DnrrZLN19cW8TWWCbdVrVfgIvyu4ZxpAxRz9itabC/+dJFkynKYasH4E9H+BOnws4SohkmxT3DWWqIINSuJfg==	0	\N	\N	2026-11-25 00:49:35.25398+08	1	active	2026-11-25 00:49:35.25398+08	israel123	2024-0032	Israel	\N	Panamogan	\N	1998-01-01	28	Purok 3	San Jose	Butuan City	Agusan Del Norte	Philippines	8600	E7AGltjun125LnA12pA=	N96fXgKvxDUb8Nc5	Ld1ofUFQEb5R6OgQXOJu2A==	2fcc5d67805689ee2cf48a80375121b4cc0951d62cbf3d1417f3b8af48cebf84	2026-11-25	Single	09123456789	\N	f	2026-11-25 00:50:05.170376+08	2026-11-25 12:38:29.906136+08
35abeb06-cba5-4a42-a757-2f5eca443dcd	password	jamestermulato@gmail.com	jamestermulato@gmail.com	Jamester Mulato	\N	2026-11-10 21:22:58.545081+08	2026-11-25 12:49:15.519961+08	scrypt$16384$8$1$1BU0H/kxvcNYqOAWT0VugQ==$Xjg+JkOT9MsJwRD1YkqbJC2H/h0fMYAXNVlJvmFUAhtWp8ic6d76+9NKS/9wQdjEwTaMlsAt6GFKmVJti5QfDg==	0	\N	2026-11-25 00:27:19.228227+08	2026-11-25 00:27:11.056149+08	15	active	\N	jamester123	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	2026-11-13 18:28:59.414826+08	2026-11-25 12:38:28.709585+08
07b41a06-dc31-4a61-8a15-cd3149a95c76	password	jamestermulato+h2372@gmail.com	jamestermulato+h2372@gmail.com	Hand Test	\N	2026-11-25 12:28:16.921064+08	2026-11-25 12:53:44.534518+08	scrypt$16384$8$1$VfD0YL/JUyxN+4QwpncTFg==$t7E2T9nlIzOZgQDFC2WYnOCHevvo2kBsgZbyWaL1AZBcs+quVyfUFCvitmhcZ+Iko62RZoIoElRV9frqiAfvBA==	0	\N	\N	2026-11-25 12:28:16.921064+08	0	active	2026-11-25 12:28:16.921064+08	hand2372	2027-2372	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	x2I9b9qsJUN6fKHXYWA=	DFuZg9G+tEfKo6xR	A7zD3Uwr2Zn2+B3PtBmA4g==	17bb9495b0d3f882cbccd04f428f7803b497c417bdc8799a3ee08f0dc8691930	\N	\N	\N	\N	f	2026-11-25 12:28:16.921064+08	\N
\.


--
-- Name: auth_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_events_id_seq', 378, true);


--
-- Name: password_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.password_history_id_seq', 20, true);


--
-- Name: security_flags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.security_flags_id_seq', 23, true);


--
-- Name: academic_years academic_years_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_years
    ADD CONSTRAINT academic_years_pkey PRIMARY KEY (id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: auth_events auth_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_events
    ADD CONSTRAINT auth_events_pkey PRIMARY KEY (id);


--
-- Name: auth_refresh_tokens auth_refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_refresh_tokens
    ADD CONSTRAINT auth_refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: auth_refresh_tokens auth_refresh_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_refresh_tokens
    ADD CONSTRAINT auth_refresh_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: boarding_house_memberships boarding_house_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boarding_house_memberships
    ADD CONSTRAINT boarding_house_memberships_pkey PRIMARY KEY (id);


--
-- Name: boarding_houses boarding_houses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boarding_houses
    ADD CONSTRAINT boarding_houses_pkey PRIMARY KEY (id);


--
-- Name: concern_attachments concern_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concern_attachments
    ADD CONSTRAINT concern_attachments_pkey PRIMARY KEY (id);


--
-- Name: concerns concerns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concerns
    ADD CONSTRAINT concerns_pkey PRIMARY KEY (id);


--
-- Name: ip_blocks ip_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_blocks
    ADD CONSTRAINT ip_blocks_pkey PRIMARY KEY (ip_address);


--
-- Name: login_otps login_otps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_otps
    ADD CONSTRAINT login_otps_pkey PRIMARY KEY (id);


--
-- Name: login_remember_tokens login_remember_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_remember_tokens
    ADD CONSTRAINT login_remember_tokens_pkey PRIMARY KEY (id);


--
-- Name: password_history password_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_history
    ADD CONSTRAINT password_history_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: security_answers security_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_answers
    ADD CONSTRAINT security_answers_pkey PRIMARY KEY (user_id, question_key);


--
-- Name: security_flags security_flags_pattern_target_flag_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_flags
    ADD CONSTRAINT security_flags_pattern_target_flag_date_key UNIQUE (pattern, target, flag_date);


--
-- Name: security_flags security_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_flags
    ADD CONSTRAINT security_flags_pkey PRIMARY KEY (id);


--
-- Name: tenant_account_associations tenant_account_associations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_account_associations
    ADD CONSTRAINT tenant_account_associations_pkey PRIMARY KEY (id);


--
-- Name: tenant_monthly_statuses tenant_monthly_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_monthly_statuses
    ADD CONSTRAINT tenant_monthly_statuses_pkey PRIMARY KEY (id);


--
-- Name: tenant_room_assignments tenant_room_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_room_assignments
    ADD CONSTRAINT tenant_room_assignments_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: academic_years uq_academic_year_house_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_years
    ADD CONSTRAINT uq_academic_year_house_name UNIQUE (boarding_house_id, name);


--
-- Name: boarding_houses uq_bh_domain; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boarding_houses
    ADD CONSTRAINT uq_bh_domain UNIQUE (domain);


--
-- Name: boarding_houses uq_bh_join_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boarding_houses
    ADD CONSTRAINT uq_bh_join_key UNIQUE (join_key);


--
-- Name: boarding_house_memberships uq_membership_house_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boarding_house_memberships
    ADD CONSTRAINT uq_membership_house_user UNIQUE (boarding_house_id, user_id);


--
-- Name: rooms uq_room_per_bh; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT uq_room_per_bh UNIQUE (boarding_house_id, room_number);


--
-- Name: tenant_account_associations uq_tenant_assoc_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_account_associations
    ADD CONSTRAINT uq_tenant_assoc_tenant UNIQUE (boarding_house_id, tenant_id);


--
-- Name: tenant_account_associations uq_tenant_assoc_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_account_associations
    ADD CONSTRAINT uq_tenant_assoc_user UNIQUE (boarding_house_id, user_id);


--
-- Name: tenant_monthly_statuses uq_tenant_month_status; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_monthly_statuses
    ADD CONSTRAINT uq_tenant_month_status UNIQUE (tenant_id, academic_year_id, month_start);


--
-- Name: users uq_user_provider_uid; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT uq_user_provider_uid UNIQUE (auth_provider, auth_provider_uid);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_academic_years_bh; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_academic_years_bh ON public.academic_years USING btree (boarding_house_id);


--
-- Name: idx_active_assignments_room; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_active_assignments_room ON public.tenant_room_assignments USING btree (room_id) WHERE (ended_at IS NULL);


--
-- Name: idx_announcements_feed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_announcements_feed ON public.announcements USING btree (boarding_house_id, published_at DESC);


--
-- Name: idx_auth_events_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auth_events_created ON public.auth_events USING btree (created_at DESC);


--
-- Name: idx_auth_events_username_typed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auth_events_username_typed ON public.auth_events USING btree (lower(username_typed));


--
-- Name: idx_bh_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bh_owner ON public.boarding_houses USING btree (owner_user_id);


--
-- Name: idx_concern_attachments; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_concern_attachments ON public.concern_attachments USING btree (concern_id);


--
-- Name: idx_concerns_bh_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_concerns_bh_status ON public.concerns USING btree (boarding_house_id, status, created_at DESC);


--
-- Name: idx_concerns_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_concerns_tenant ON public.concerns USING btree (tenant_id, created_at DESC);


--
-- Name: idx_login_otps_purpose; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_login_otps_purpose ON public.login_otps USING btree (user_id, purpose, created_at DESC);


--
-- Name: idx_login_otps_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_login_otps_user ON public.login_otps USING btree (user_id, created_at DESC);


--
-- Name: idx_membership_house_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membership_house_role ON public.boarding_house_memberships USING btree (boarding_house_id, role, status);


--
-- Name: idx_membership_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membership_user ON public.boarding_house_memberships USING btree (user_id);


--
-- Name: idx_month_status_tenant_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_month_status_tenant_year ON public.tenant_monthly_statuses USING btree (tenant_id, academic_year_id, month_start);


--
-- Name: idx_password_history_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_password_history_user ON public.password_history USING btree (user_id);


--
-- Name: idx_password_reset_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_password_reset_user ON public.password_reset_tokens USING btree (user_id);


--
-- Name: idx_refresh_tokens_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_tokens_user ON public.auth_refresh_tokens USING btree (user_id);


--
-- Name: idx_remember_tokens_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_remember_tokens_user ON public.login_remember_tokens USING btree (user_id);


--
-- Name: idx_rooms_bh; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rooms_bh ON public.rooms USING btree (boarding_house_id);


--
-- Name: idx_tenant_assoc_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tenant_assoc_tenant ON public.tenant_account_associations USING btree (tenant_id);


--
-- Name: idx_tenant_assoc_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tenant_assoc_user ON public.tenant_account_associations USING btree (user_id);


--
-- Name: idx_tenants_bh; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tenants_bh ON public.tenants USING btree (boarding_house_id);


--
-- Name: idx_tenants_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tenants_name ON public.tenants USING btree (boarding_house_id, lower(full_name));


--
-- Name: idx_users_last_activity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_last_activity ON public.users USING btree (last_activity_at);


--
-- Name: uq_active_tenant_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_active_tenant_assignment ON public.tenant_room_assignments USING btree (tenant_id) WHERE (ended_at IS NULL);


--
-- Name: uq_one_active_owner_per_bh; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_one_active_owner_per_bh ON public.boarding_house_memberships USING btree (boarding_house_id) WHERE ((role = 'owner'::public.membership_role) AND (status = 'active'::public.membership_status));


--
-- Name: uq_user_email_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_user_email_ci ON public.users USING btree (lower(email));


--
-- Name: uq_user_gov_id_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_user_gov_id_lookup ON public.users USING btree (government_id_lookup) WHERE (government_id_lookup IS NOT NULL);


--
-- Name: uq_user_id_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_user_id_number ON public.users USING btree (id_number) WHERE (id_number IS NOT NULL);


--
-- Name: uq_user_username_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_user_username_ci ON public.users USING btree (lower(username));


--
-- Name: v_room_occupancy _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.v_room_occupancy AS
 SELECT r.id AS room_id,
    r.boarding_house_id,
    r.room_number,
    r.capacity,
    (count(tra.id))::integer AS occupied_slots,
    GREATEST((r.capacity - (count(tra.id))::integer), 0) AS available_slots,
        CASE
            WHEN (count(tra.id) = 0) THEN 'empty'::text
            WHEN (count(tra.id) >= r.capacity) THEN 'full'::text
            ELSE 'available'::text
        END AS occupancy_status
   FROM (public.rooms r
     LEFT JOIN public.tenant_room_assignments tra ON (((tra.room_id = r.id) AND (tra.ended_at IS NULL))))
  WHERE (r.status = 'active'::public.room_status)
  GROUP BY r.id;


--
-- Name: auth_events auth_events_no_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER auth_events_no_change BEFORE DELETE OR UPDATE ON public.auth_events FOR EACH ROW EXECUTE FUNCTION public.prevent_auth_events_change();


--
-- Name: announcements trg_announcements_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_announcements_updated_at BEFORE UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: boarding_houses trg_bh_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_bh_updated_at BEFORE UPDATE ON public.boarding_houses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: concerns trg_concerns_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_concerns_updated_at BEFORE UPDATE ON public.concerns FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: boarding_house_memberships trg_membership_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_membership_updated_at BEFORE UPDATE ON public.boarding_house_memberships FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: rooms trg_rooms_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rooms_updated_at BEFORE UPDATE ON public.rooms FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: tenants trg_tenants_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: users trg_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: tenant_monthly_statuses trg_validate_monthly_status_house; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validate_monthly_status_house BEFORE INSERT OR UPDATE ON public.tenant_monthly_statuses FOR EACH ROW EXECUTE FUNCTION public.validate_monthly_status_house();


--
-- Name: boarding_house_memberships trg_validate_owner_membership; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validate_owner_membership BEFORE INSERT OR UPDATE ON public.boarding_house_memberships FOR EACH ROW EXECUTE FUNCTION public.validate_owner_membership();


--
-- Name: rooms trg_validate_room_capacity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validate_room_capacity_change BEFORE UPDATE OF capacity ON public.rooms FOR EACH ROW EXECUTE FUNCTION public.validate_room_capacity_change();


--
-- Name: tenant_account_associations trg_validate_tenant_account_association; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validate_tenant_account_association BEFORE INSERT OR UPDATE ON public.tenant_account_associations FOR EACH ROW EXECUTE FUNCTION public.validate_tenant_account_association();


--
-- Name: tenant_room_assignments trg_validate_tenant_room_assignment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validate_tenant_room_assignment BEFORE INSERT OR UPDATE OF tenant_id, room_id, ended_at ON public.tenant_room_assignments FOR EACH ROW EXECUTE FUNCTION public.validate_tenant_room_assignment();


--
-- Name: academic_years academic_years_boarding_house_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_years
    ADD CONSTRAINT academic_years_boarding_house_id_fkey FOREIGN KEY (boarding_house_id) REFERENCES public.boarding_houses(id) ON DELETE CASCADE;


--
-- Name: announcements announcements_author_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: announcements announcements_boarding_house_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_boarding_house_id_fkey FOREIGN KEY (boarding_house_id) REFERENCES public.boarding_houses(id) ON DELETE CASCADE;


--
-- Name: auth_events auth_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_events
    ADD CONSTRAINT auth_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: auth_refresh_tokens auth_refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_refresh_tokens
    ADD CONSTRAINT auth_refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: boarding_house_memberships boarding_house_memberships_boarding_house_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boarding_house_memberships
    ADD CONSTRAINT boarding_house_memberships_boarding_house_id_fkey FOREIGN KEY (boarding_house_id) REFERENCES public.boarding_houses(id) ON DELETE CASCADE;


--
-- Name: boarding_house_memberships boarding_house_memberships_removed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boarding_house_memberships
    ADD CONSTRAINT boarding_house_memberships_removed_by_fkey FOREIGN KEY (removed_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: boarding_house_memberships boarding_house_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boarding_house_memberships
    ADD CONSTRAINT boarding_house_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: boarding_houses boarding_houses_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boarding_houses
    ADD CONSTRAINT boarding_houses_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: concern_attachments concern_attachments_concern_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concern_attachments
    ADD CONSTRAINT concern_attachments_concern_id_fkey FOREIGN KEY (concern_id) REFERENCES public.concerns(id) ON DELETE CASCADE;


--
-- Name: concerns concerns_boarding_house_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concerns
    ADD CONSTRAINT concerns_boarding_house_id_fkey FOREIGN KEY (boarding_house_id) REFERENCES public.boarding_houses(id) ON DELETE CASCADE;


--
-- Name: concerns concerns_reported_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concerns
    ADD CONSTRAINT concerns_reported_room_id_fkey FOREIGN KEY (reported_room_id) REFERENCES public.rooms(id) ON DELETE SET NULL;


--
-- Name: concerns concerns_responded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concerns
    ADD CONSTRAINT concerns_responded_by_fkey FOREIGN KEY (responded_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: concerns concerns_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concerns
    ADD CONSTRAINT concerns_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE RESTRICT;


--
-- Name: login_otps login_otps_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_otps
    ADD CONSTRAINT login_otps_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: login_remember_tokens login_remember_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_remember_tokens
    ADD CONSTRAINT login_remember_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: password_history password_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_history
    ADD CONSTRAINT password_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: password_reset_tokens password_reset_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: rooms rooms_boarding_house_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_boarding_house_id_fkey FOREIGN KEY (boarding_house_id) REFERENCES public.boarding_houses(id) ON DELETE CASCADE;


--
-- Name: security_answers security_answers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_answers
    ADD CONSTRAINT security_answers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tenant_account_associations tenant_account_associations_associated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_account_associations
    ADD CONSTRAINT tenant_account_associations_associated_by_fkey FOREIGN KEY (associated_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: tenant_account_associations tenant_account_associations_boarding_house_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_account_associations
    ADD CONSTRAINT tenant_account_associations_boarding_house_id_fkey FOREIGN KEY (boarding_house_id) REFERENCES public.boarding_houses(id) ON DELETE CASCADE;


--
-- Name: tenant_account_associations tenant_account_associations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_account_associations
    ADD CONSTRAINT tenant_account_associations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_account_associations tenant_account_associations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_account_associations
    ADD CONSTRAINT tenant_account_associations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tenant_monthly_statuses tenant_monthly_statuses_academic_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_monthly_statuses
    ADD CONSTRAINT tenant_monthly_statuses_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES public.academic_years(id) ON DELETE CASCADE;


--
-- Name: tenant_monthly_statuses tenant_monthly_statuses_boarding_house_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_monthly_statuses
    ADD CONSTRAINT tenant_monthly_statuses_boarding_house_id_fkey FOREIGN KEY (boarding_house_id) REFERENCES public.boarding_houses(id) ON DELETE CASCADE;


--
-- Name: tenant_monthly_statuses tenant_monthly_statuses_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_monthly_statuses
    ADD CONSTRAINT tenant_monthly_statuses_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_monthly_statuses tenant_monthly_statuses_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_monthly_statuses
    ADD CONSTRAINT tenant_monthly_statuses_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: tenant_room_assignments tenant_room_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_room_assignments
    ADD CONSTRAINT tenant_room_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: tenant_room_assignments tenant_room_assignments_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_room_assignments
    ADD CONSTRAINT tenant_room_assignments_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE RESTRICT;


--
-- Name: tenant_room_assignments tenant_room_assignments_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_room_assignments
    ADD CONSTRAINT tenant_room_assignments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenants tenants_boarding_house_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_boarding_house_id_fkey FOREIGN KEY (boarding_house_id) REFERENCES public.boarding_houses(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict OOcNGHU061e5gmmQOjpCYUQglg2vjMLXQwYT3MXfxzIVcCe2qM4qUyrdQ0cXhlb

