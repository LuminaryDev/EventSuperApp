-- =============================================================================
-- Event SuperApp — PostgreSQL initial schema (MVP: ticketing + transport)
-- Run as a superuser or role with CREATEDB / CREATE privileges on the database.
-- Apply 002_security_grants_rls.sql after this file (same DB).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Extensions (security-relevant: use documented, maintained extensions only)
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), digest()
CREATE EXTENSION IF NOT EXISTS citext;     -- case-insensitive email

-- -----------------------------------------------------------------------------
-- Enumerated labels (CHECK constraints — easier to evolve than PG ENUM types)
-- -----------------------------------------------------------------------------
-- user_status: active | suspended | deleted
-- org_status: active | inactive
-- member_role: owner | admin | staff
-- event_status: draft | published | cancelled | completed
-- order_status: pending_payment | paid | cancelled | refunded | partially_refunded
-- ticket_status: valid | cancelled | refunded
-- payment_status: pending | processing | succeeded | failed | refunded
-- refund_status: pending | succeeded | failed
-- webhook_processing_status: received | processed | failed | ignored
-- transport_direction: to_event | from_event | both
-- transport_request_status: requested | assigned | completed | cancelled
-- transport_group_status: planned | dispatched | completed | cancelled

-- -----------------------------------------------------------------------------
-- Helper: updated_at maintenance
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- =============================================================================
-- USERS — authentication identity (PII: protect in app + backups)
-- =============================================================================
CREATE TABLE users (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  email               CITEXT UNIQUE,
  phone_e164          VARCHAR(32) UNIQUE,

  password_hash       TEXT,
  display_name        VARCHAR(200) NOT NULL DEFAULT '',

  status              VARCHAR(20) NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active', 'suspended', 'deleted')),

  email_verified_at   TIMESTAMPTZ,
  phone_verified_at   TIMESTAMPTZ,
  last_login_at       TIMESTAMPTZ,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at          TIMESTAMPTZ,

  CONSTRAINT users_email_or_phone CHECK (email IS NOT NULL OR phone_e164 IS NOT NULL)
);

CREATE TRIGGER tr_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

COMMENT ON TABLE users IS 'Login identity; never expose id — use public_id in APIs.';
COMMENT ON COLUMN users.password_hash IS 'Argon2id/bcrypt hash; NULL if OAuth-only.';
COMMENT ON COLUMN users.phone_e164 IS 'E.164; prefer app-layer encryption for extra PII control.';

-- =============================================================================
-- ORGANIZATIONS — organizers / legal entity
-- =============================================================================
CREATE TABLE organizations (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  name                VARCHAR(255) NOT NULL,
  slug                VARCHAR(100) NOT NULL UNIQUE,
  legal_name          VARCHAR(255),
  tax_id              VARCHAR(64),

  status              VARCHAR(20) NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active', 'inactive')),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_organizations_updated_at
  BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

-- =============================================================================
-- ORGANIZATION_MEMBERS — RBAC: who can act for an organization
-- =============================================================================
CREATE TABLE organization_members (
  id                  BIGSERIAL PRIMARY KEY,
  organization_id     BIGINT NOT NULL REFERENCES organizations (id) ON DELETE CASCADE,
  user_id             BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  role                VARCHAR(20) NOT NULL
                      CHECK (role IN ('owner', 'admin', 'staff')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (organization_id, user_id)
);

CREATE INDEX idx_org_members_user ON organization_members (user_id);
CREATE INDEX idx_org_members_org ON organization_members (organization_id);

-- =============================================================================
-- VENUES — physical locations (reusable)
-- =============================================================================
CREATE TABLE venues (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  organization_id     BIGINT REFERENCES organizations (id) ON DELETE SET NULL,

  name                VARCHAR(255) NOT NULL,
  line1               VARCHAR(255),
  line2               VARCHAR(255),
  city                VARCHAR(120),
  region              VARCHAR(120),
  postal_code         VARCHAR(32),
  country             CHAR(2) NOT NULL DEFAULT 'ET',

  latitude            DOUBLE PRECISION,
  longitude           DOUBLE PRECISION,

  timezone            VARCHAR(64) NOT NULL DEFAULT 'Africa/Addis_Ababa',

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_venues_updated_at
  BEFORE UPDATE ON venues
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_venues_org ON venues (organization_id);

-- =============================================================================
-- EVENTS — sellable event (single organization, single venue per MVP)
-- =============================================================================
CREATE TABLE events (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  organization_id     BIGINT NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,
  venue_id            BIGINT NOT NULL REFERENCES venues (id) ON DELETE RESTRICT,

  title               VARCHAR(500) NOT NULL,
  slug                VARCHAR(160) NOT NULL,
  description         TEXT,

  starts_at           TIMESTAMPTZ NOT NULL,
  ends_at             TIMESTAMPTZ NOT NULL,
  timezone            VARCHAR(64) NOT NULL,

  status              VARCHAR(20) NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'published', 'cancelled', 'completed')),

  published_at        TIMESTAMPTZ,
  sales_starts_at     TIMESTAMPTZ,
  sales_ends_at       TIMESTAMPTZ,

  max_attendees       INTEGER CHECK (max_attendees IS NULL OR max_attendees > 0),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (organization_id, slug),
  CONSTRAINT events_time_order CHECK (ends_at > starts_at)
);

CREATE TRIGGER tr_events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_events_org_status_starts ON events (organization_id, status, starts_at);
CREATE INDEX idx_events_published_starts ON events (status, starts_at)
  WHERE status = 'published';

-- =============================================================================
-- TICKET_TYPES — inventory + price (atomic sold counter — update with care)
-- =============================================================================
CREATE TABLE ticket_types (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  event_id            BIGINT NOT NULL REFERENCES events (id) ON DELETE RESTRICT,

  name                VARCHAR(120) NOT NULL,
  description         TEXT,

  price_amount_minor  BIGINT NOT NULL CHECK (price_amount_minor >= 0),
  currency            CHAR(3) NOT NULL DEFAULT 'ETB',

  quantity_total      INTEGER NOT NULL CHECK (quantity_total >= 0),
  quantity_sold       INTEGER NOT NULL DEFAULT 0 CHECK (quantity_sold >= 0),

  max_per_order       INTEGER NOT NULL DEFAULT 10 CHECK (max_per_order >= 1),
  sort_order          INTEGER NOT NULL DEFAULT 0,
  active              BOOLEAN NOT NULL DEFAULT true,

  sales_starts_at     TIMESTAMPTZ,
  sales_ends_at       TIMESTAMPTZ,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ticket_types_sold_vs_total CHECK (quantity_sold <= quantity_total)
);

CREATE TRIGGER tr_ticket_types_updated_at
  BEFORE UPDATE ON ticket_types
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_ticket_types_event ON ticket_types (event_id, active);

-- =============================================================================
-- ORDERS — one checkout per payment intent; single event per MVP order
-- =============================================================================
CREATE TABLE orders (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  user_id             BIGINT NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  event_id            BIGINT NOT NULL REFERENCES events (id) ON DELETE RESTRICT,

  status              VARCHAR(30) NOT NULL DEFAULT 'pending_payment'
                      CHECK (status IN (
                        'pending_payment', 'paid', 'cancelled', 'refunded', 'partially_refunded'
                      )),

  currency            CHAR(3) NOT NULL DEFAULT 'ETB',

  subtotal_minor      BIGINT NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
  fees_minor          BIGINT NOT NULL DEFAULT 0 CHECK (fees_minor >= 0),
  tax_minor           BIGINT NOT NULL DEFAULT 0 CHECK (tax_minor >= 0),
  discount_minor      BIGINT NOT NULL DEFAULT 0 CHECK (discount_minor >= 0),
  total_minor         BIGINT NOT NULL DEFAULT 0 CHECK (total_minor >= 0),

  idempotency_key     VARCHAR(128) NOT NULL UNIQUE,

  placed_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at             TIMESTAMPTZ,
  cancelled_at        TIMESTAMPTZ,

  notes               TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_orders_user_placed ON orders (user_id, placed_at DESC);
CREATE INDEX idx_orders_event_status ON orders (event_id, status);

-- =============================================================================
-- ORDER_ITEMS — line items (tickets to issue)
-- =============================================================================
CREATE TABLE order_items (
  id                  BIGSERIAL PRIMARY KEY,

  order_id            BIGINT NOT NULL REFERENCES orders (id) ON DELETE RESTRICT,
  ticket_type_id      BIGINT NOT NULL REFERENCES ticket_types (id) ON DELETE RESTRICT,

  quantity            INTEGER NOT NULL CHECK (quantity >= 1),
  unit_price_minor    BIGINT NOT NULL CHECK (unit_price_minor >= 0),
  line_total_minor    BIGINT NOT NULL CHECK (line_total_minor >= 0),
  currency            CHAR(3) NOT NULL,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (order_id, ticket_type_id)
);

CREATE INDEX idx_order_items_order ON order_items (order_id);
CREATE INDEX idx_order_items_ticket_type ON order_items (ticket_type_id);

-- =============================================================================
-- TICKETS — one row per issued ticket (check-in, QR, refunds)
-- =============================================================================
CREATE TABLE tickets (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  order_item_id       BIGINT NOT NULL REFERENCES order_items (id) ON DELETE RESTRICT,
  event_id            BIGINT NOT NULL REFERENCES events (id) ON DELETE RESTRICT,
  ticket_type_id      BIGINT NOT NULL REFERENCES ticket_types (id) ON DELETE RESTRICT,

  holder_name         VARCHAR(200),

  status              VARCHAR(20) NOT NULL DEFAULT 'valid'
                      CHECK (status IN ('valid', 'cancelled', 'refunded')),

  -- Store only a peppered hash; API verifies scan tokens by hashing input (never store raw codes).
  redemption_code_hash BYTEA NOT NULL UNIQUE,

  checked_in_at       TIMESTAMPTZ,
  checked_in_by_user_id BIGINT REFERENCES users (id) ON DELETE SET NULL,

  voided_at           TIMESTAMPTZ,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tickets_event_status ON tickets (event_id, status);
CREATE INDEX idx_tickets_order_item ON tickets (order_item_id);

COMMENT ON COLUMN tickets.redemption_code_hash IS 'digest(concat(code, server_pepper), sha256) from pgcrypto; compute in app on issue/check-in.';

-- =============================================================================
-- PAYMENTS — provider ledger
-- =============================================================================
CREATE TABLE payments (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  order_id            BIGINT NOT NULL REFERENCES orders (id) ON DELETE RESTRICT,

  provider            VARCHAR(50) NOT NULL,
  provider_payment_id VARCHAR(255) NOT NULL,

  amount_minor        BIGINT NOT NULL CHECK (amount_minor >= 0),
  currency            CHAR(3) NOT NULL,

  status              VARCHAR(20) NOT NULL
                      CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'refunded')),

  provider_fee_minor  BIGINT CHECK (provider_fee_minor IS NULL OR provider_fee_minor >= 0),

  raw_metadata        JSONB,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (provider, provider_payment_id)
);

CREATE TRIGGER tr_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_payments_order ON payments (order_id);

-- =============================================================================
-- PAYMENT_WEBHOOK_EVENTS — idempotent webhook processing
-- =============================================================================
CREATE TABLE payment_webhook_events (
  id                  BIGSERIAL PRIMARY KEY,

  provider            VARCHAR(50) NOT NULL,
  provider_event_id   VARCHAR(255) NOT NULL,

  payload_digest      VARCHAR(64) NOT NULL,
  payload_json        JSONB,

  processing_status   VARCHAR(20) NOT NULL DEFAULT 'received'
                      CHECK (processing_status IN ('received', 'processed', 'failed', 'ignored')),
  processing_error    TEXT,
  processed_at        TIMESTAMPTZ,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (provider, provider_event_id)
);

CREATE INDEX idx_webhook_events_created ON payment_webhook_events (created_at DESC);

-- =============================================================================
-- REFUNDS — financial corrections (manual or provider-driven)
-- =============================================================================
CREATE TABLE refunds (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  order_id            BIGINT NOT NULL REFERENCES orders (id) ON DELETE RESTRICT,
  payment_id          BIGINT REFERENCES payments (id) ON DELETE SET NULL,

  amount_minor        BIGINT NOT NULL CHECK (amount_minor > 0),
  currency            CHAR(3) NOT NULL,

  reason              TEXT,
  provider_refund_id  VARCHAR(255),

  status              VARCHAR(20) NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'succeeded', 'failed')),

  created_by_user_id  BIGINT REFERENCES users (id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_refunds_order ON refunds (order_id);

-- =============================================================================
-- ORDER_EVENTS — append-only audit trail for order lifecycle
-- =============================================================================
CREATE TABLE order_events (
  id                  BIGSERIAL PRIMARY KEY,

  order_id            BIGINT NOT NULL REFERENCES orders (id) ON DELETE CASCADE,

  event_type          VARCHAR(64) NOT NULL,
  actor_user_id       BIGINT REFERENCES users (id) ON DELETE SET NULL,
  payload             JSONB NOT NULL DEFAULT '{}',

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_order_events_order_created ON order_events (order_id, created_at DESC);

COMMENT ON TABLE order_events IS 'Append-only; do not UPDATE/DELETE except GDPR/legal holds.';

-- =============================================================================
-- TRANSPORT — MVP: one request per order; manual grouping in ops
-- =============================================================================
CREATE TABLE transport_requests (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  order_id            BIGINT NOT NULL UNIQUE REFERENCES orders (id) ON DELETE RESTRICT,

  direction           VARCHAR(20) NOT NULL
                      CHECK (direction IN ('to_event', 'from_event', 'both')),

  pickup_note         TEXT,
  pickup_lat          DOUBLE PRECISION,
  pickup_lng          DOUBLE PRECISION,

  contact_phone       VARCHAR(32) NOT NULL,

  status              VARCHAR(20) NOT NULL DEFAULT 'requested'
                      CHECK (status IN ('requested', 'assigned', 'completed', 'cancelled')),

  internal_notes      TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_transport_requests_updated_at
  BEFORE UPDATE ON transport_requests
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

-- =============================================================================
-- TRANSPORT_GROUPS — manual route/vehicle grouping per event
-- =============================================================================
CREATE TABLE transport_groups (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  event_id            BIGINT NOT NULL REFERENCES events (id) ON DELETE CASCADE,

  label               VARCHAR(120) NOT NULL,
  pickup_landmark     TEXT,
  scheduled_pickup_at TIMESTAMPTZ,

  vehicle_description VARCHAR(255),
  driver_phone        VARCHAR(32),

  status              VARCHAR(20) NOT NULL DEFAULT 'planned'
                      CHECK (status IN ('planned', 'dispatched', 'completed', 'cancelled')),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_transport_groups_updated_at
  BEFORE UPDATE ON transport_groups
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_transport_groups_event ON transport_groups (event_id);

-- =============================================================================
-- TRANSPORT_ASSIGNMENTS — link request → group
-- =============================================================================
CREATE TABLE transport_assignments (
  id                  BIGSERIAL PRIMARY KEY,

  transport_request_id BIGINT NOT NULL REFERENCES transport_requests (id) ON DELETE CASCADE,
  transport_group_id   BIGINT NOT NULL REFERENCES transport_groups (id) ON DELETE CASCADE,

  assigned_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  assigned_by_user_id BIGINT REFERENCES users (id) ON DELETE SET NULL,

  UNIQUE (transport_request_id)
);

CREATE INDEX idx_transport_assignments_group ON transport_assignments (transport_group_id);

-- =============================================================================
-- Optional: prevent destructive tampering on audit table (superuser can still bypass)
-- =============================================================================
CREATE OR REPLACE FUNCTION app_prevent_order_events_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'order_events is append-only';
END;
$$;

CREATE TRIGGER tr_order_events_no_update
  BEFORE UPDATE ON order_events
  FOR EACH ROW EXECUTE PROCEDURE app_prevent_order_events_mutation();

CREATE TRIGGER tr_order_events_no_delete
  BEFORE DELETE ON order_events
  FOR EACH ROW EXECUTE PROCEDURE app_prevent_order_events_mutation();

COMMIT;
