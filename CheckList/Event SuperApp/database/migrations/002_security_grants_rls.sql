-- =============================================================================
-- Event SuperApp — roles, least privilege, RLS (run AFTER 001_initial_schema.sql)
-- Requires: superuser or role with CREATEROLE + ownership on objects from 001.
--
-- BEFORE PRODUCTION: set strong passwords and store only in secrets manager:
--   ALTER ROLE eventapp_web PASSWORD '...';
--   ALTER ROLE eventapp_worker PASSWORD '...';
--
-- Application usage:
--   • eventapp_web: end-user API pool. Per request: SET LOCAL app.user_id = '<bigint>';
--   • eventapp_worker: payment webhooks, ticket issuance, admin batch jobs (BYPASSRLS).
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS app;

-- -----------------------------------------------------------------------------
-- Session context (no SECURITY DEFINER — reads request-scoped GUC)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.session_user_id()
RETURNS BIGINT
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN current_setting('app.user_id', true) IS NULL THEN NULL
    WHEN btrim(current_setting('app.user_id', true)) = '' THEN NULL
    ELSE btrim(current_setting('app.user_id', true))::BIGINT
  END;
$$;

REVOKE ALL ON FUNCTION app.session_user_id() FROM PUBLIC;

-- -----------------------------------------------------------------------------
-- Roles (no passwords in repo — set manually)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'eventapp_migrator') THEN
    CREATE ROLE eventapp_migrator NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'eventapp_web') THEN
    CREATE ROLE eventapp_web LOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'eventapp_worker') THEN
    CREATE ROLE eventapp_worker LOGIN BYPASSRLS;
  END IF;
END
$$;

ALTER ROLE eventapp_web SET search_path = public, pg_temp;
ALTER ROLE eventapp_worker SET search_path = public, pg_temp;

COMMENT ON ROLE eventapp_migrator IS 'Owns schema objects; used for migrations only.';
COMMENT ON ROLE eventapp_web IS 'Pool user for HTTP API; must SET LOCAL app.user_id per transaction.';
COMMENT ON ROLE eventapp_worker IS 'Workers/webhooks; BYPASSRLS — protect with network + secrets.';

-- -----------------------------------------------------------------------------
-- Ownership (locks DDL away from runtime roles)
-- -----------------------------------------------------------------------------
ALTER FUNCTION public.app_set_updated_at() OWNER TO eventapp_migrator;
ALTER FUNCTION public.app_prevent_order_events_mutation() OWNER TO eventapp_migrator;
ALTER FUNCTION app.session_user_id() OWNER TO eventapp_migrator;

ALTER TABLE users OWNER TO eventapp_migrator;
ALTER TABLE organizations OWNER TO eventapp_migrator;
ALTER TABLE organization_members OWNER TO eventapp_migrator;
ALTER TABLE venues OWNER TO eventapp_migrator;
ALTER TABLE events OWNER TO eventapp_migrator;
ALTER TABLE ticket_types OWNER TO eventapp_migrator;
ALTER TABLE orders OWNER TO eventapp_migrator;
ALTER TABLE order_items OWNER TO eventapp_migrator;
ALTER TABLE tickets OWNER TO eventapp_migrator;
ALTER TABLE payments OWNER TO eventapp_migrator;
ALTER TABLE payment_webhook_events OWNER TO eventapp_migrator;
ALTER TABLE refunds OWNER TO eventapp_migrator;
ALTER TABLE order_events OWNER TO eventapp_migrator;
ALTER TABLE transport_requests OWNER TO eventapp_migrator;
ALTER TABLE transport_groups OWNER TO eventapp_migrator;
ALTER TABLE transport_assignments OWNER TO eventapp_migrator;

-- Sequences (BIGSERIAL)
ALTER SEQUENCE users_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE organizations_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE organization_members_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE venues_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE events_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE ticket_types_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE orders_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE order_items_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE tickets_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE payments_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE payment_webhook_events_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE refunds_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE order_events_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE transport_requests_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE transport_groups_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE transport_assignments_id_seq OWNER TO eventapp_migrator;

-- -----------------------------------------------------------------------------
-- Revoke public defaults (new objects still need default privileges below)
-- -----------------------------------------------------------------------------
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO eventapp_web, eventapp_worker;
GRANT USAGE ON SCHEMA app TO eventapp_web, eventapp_worker;

-- -----------------------------------------------------------------------------
-- Table privileges: web (RLS-enforced) vs worker (bypass + webhooks)
-- -----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO eventapp_web;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO eventapp_web;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO eventapp_worker;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO eventapp_worker;

-- Webhook inbox: only worker should touch (optional hardening — revoke from web)
REVOKE ALL ON TABLE payment_webhook_events FROM eventapp_web;

-- Issuance & money writes should run as eventapp_worker (webhooks / trusted jobs).
REVOKE INSERT ON TABLE tickets FROM eventapp_web;
REVOKE INSERT ON TABLE payments FROM eventapp_web;
REVOKE INSERT ON TABLE refunds FROM eventapp_web;

GRANT EXECUTE ON FUNCTION app.session_user_id() TO eventapp_web, eventapp_worker;

-- Future objects created by migrator during later migrations
ALTER DEFAULT PRIVILEGES FOR ROLE eventapp_migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO eventapp_web, eventapp_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE eventapp_migrator IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO eventapp_web, eventapp_worker;

-- -----------------------------------------------------------------------------
-- Row Level Security + FORCE (table owner no longer bypasses)
-- -----------------------------------------------------------------------------
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations FORCE ROW LEVEL SECURITY;

ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members FORCE ROW LEVEL SECURITY;

ALTER TABLE venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE venues FORCE ROW LEVEL SECURITY;

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE events FORCE ROW LEVEL SECURITY;

ALTER TABLE ticket_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_types FORCE ROW LEVEL SECURITY;

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders FORCE ROW LEVEL SECURITY;

ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items FORCE ROW LEVEL SECURITY;

ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets FORCE ROW LEVEL SECURITY;

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments FORCE ROW LEVEL SECURITY;

ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds FORCE ROW LEVEL SECURITY;

ALTER TABLE order_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_events FORCE ROW LEVEL SECURITY;

ALTER TABLE transport_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_requests FORCE ROW LEVEL SECURITY;

ALTER TABLE transport_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_groups FORCE ROW LEVEL SECURITY;

ALTER TABLE transport_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_assignments FORCE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Policies: eventapp_web (eventapp_worker bypasses all RLS)
-- -----------------------------------------------------------------------------

-- USERS: own profile only; signup/imports use eventapp_worker.
CREATE POLICY users_select_self ON users
  FOR SELECT TO eventapp_web
  USING (id = app.session_user_id());

CREATE POLICY users_update_self ON users
  FOR UPDATE TO eventapp_web
  USING (id = app.session_user_id())
  WITH CHECK (id = app.session_user_id());

-- ORGANIZATIONS: members can read; writes should go through worker or add owner policies later.
CREATE POLICY organizations_select_member ON organizations
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = organizations.id
        AND m.user_id = app.session_user_id()
    )
  );

-- ORGANIZATION_MEMBERS: see your own memberships.
CREATE POLICY org_members_select_self ON organization_members
  FOR SELECT TO eventapp_web
  USING (user_id = app.session_user_id());

-- VENUES: visible if used by a published event OR you manage the org (via any event).
CREATE POLICY venues_select_policy ON venues
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM events e
      WHERE e.venue_id = venues.id
        AND e.status = 'published'
    )
    OR EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.venue_id = venues.id
        AND m.user_id = app.session_user_id()
    )
  );

CREATE POLICY venues_staff_insert ON venues
  FOR INSERT TO eventapp_web
  WITH CHECK (
    organization_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = venues.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

CREATE POLICY venues_staff_update ON venues
  FOR UPDATE TO eventapp_web
  USING (
    organization_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = venues.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = venues.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

-- EVENTS: published catalog OR org team.
CREATE POLICY events_select_policy ON events
  FOR SELECT TO eventapp_web
  USING (
    status = 'published'
    OR EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = events.organization_id
        AND m.user_id = app.session_user_id()
    )
  );

CREATE POLICY events_staff_insert ON events
  FOR INSERT TO eventapp_web
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = events.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  );

CREATE POLICY events_staff_update ON events
  FOR UPDATE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = events.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = events.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

CREATE POLICY events_staff_delete ON events
  FOR DELETE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = events.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  );

-- TICKET_TYPES: mirror event visibility.
CREATE POLICY ticket_types_select_policy ON ticket_types
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM events e
      WHERE e.id = ticket_types.event_id
        AND (
          e.status = 'published'
          OR EXISTS (
            SELECT 1 FROM organization_members m
            WHERE m.organization_id = e.organization_id
              AND m.user_id = app.session_user_id()
          )
        )
    )
  );

CREATE POLICY ticket_types_staff_manage ON ticket_types
  FOR ALL TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = ticket_types.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = ticket_types.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

-- ORDERS: buyer only.
CREATE POLICY orders_select_own ON orders
  FOR SELECT TO eventapp_web
  USING (user_id = app.session_user_id());

CREATE POLICY orders_insert_own ON orders
  FOR INSERT TO eventapp_web
  WITH CHECK (user_id = app.session_user_id());

CREATE POLICY orders_update_own ON orders
  FOR UPDATE TO eventapp_web
  USING (user_id = app.session_user_id())
  WITH CHECK (user_id = app.session_user_id());

-- ORDER_ITEMS: via parent order.
CREATE POLICY order_items_select_own ON order_items
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_items.order_id
        AND o.user_id = app.session_user_id()
    )
  );

CREATE POLICY order_items_insert_own ON order_items
  FOR INSERT TO eventapp_web
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_items.order_id
        AND o.user_id = app.session_user_id()
    )
  );

CREATE POLICY order_items_update_own ON order_items
  FOR UPDATE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_items.order_id
        AND o.user_id = app.session_user_id()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_items.order_id
        AND o.user_id = app.session_user_id()
    )
  );

-- TICKETS: via order ownership.
CREATE POLICY tickets_select_own ON tickets
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      WHERE oi.id = tickets.order_item_id
        AND o.user_id = app.session_user_id()
    )
  );

CREATE POLICY tickets_update_own ON tickets
  FOR UPDATE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      WHERE oi.id = tickets.order_item_id
        AND o.user_id = app.session_user_id()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      WHERE oi.id = tickets.order_item_id
        AND o.user_id = app.session_user_id()
    )
  );

CREATE POLICY tickets_staff_checkin ON tickets
  FOR UPDATE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = tickets.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = tickets.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

-- PAYMENTS: via order.
CREATE POLICY payments_select_own ON payments
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = payments.order_id
        AND o.user_id = app.session_user_id()
    )
  );

-- REFUNDS: via order.
CREATE POLICY refunds_select_own ON refunds
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = refunds.order_id
        AND o.user_id = app.session_user_id()
    )
  );

-- ORDER_EVENTS: audit stream for own orders.
CREATE POLICY order_events_select_own ON order_events
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_events.order_id
        AND o.user_id = app.session_user_id()
    )
  );

CREATE POLICY order_events_insert_own ON order_events
  FOR INSERT TO eventapp_web
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_events.order_id
        AND o.user_id = app.session_user_id()
    )
  );

-- TRANSPORT_REQUESTS: via order.
CREATE POLICY transport_req_select_own ON transport_requests
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = transport_requests.order_id
        AND o.user_id = app.session_user_id()
    )
  );

CREATE POLICY transport_req_insert_own ON transport_requests
  FOR INSERT TO eventapp_web
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = transport_requests.order_id
        AND o.user_id = app.session_user_id()
    )
  );

CREATE POLICY transport_req_update_own ON transport_requests
  FOR UPDATE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = transport_requests.order_id
        AND o.user_id = app.session_user_id()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = transport_requests.order_id
        AND o.user_id = app.session_user_id()
    )
  );

-- TRANSPORT_GROUPS: org staff for the event.
CREATE POLICY transport_groups_staff_all ON transport_groups
  FOR ALL TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = transport_groups.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = transport_groups.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

-- TRANSPORT_ASSIGNMENTS: staff (same as groups) OR attendee sees own assignment.
CREATE POLICY transport_assign_select ON transport_assignments
  FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM transport_requests tr
      JOIN orders o ON o.id = tr.order_id
      WHERE tr.id = transport_assignments.transport_request_id
        AND o.user_id = app.session_user_id()
    )
    OR EXISTS (
      SELECT 1 FROM transport_groups tg
      JOIN events e ON e.id = tg.event_id
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE tg.id = transport_assignments.transport_group_id
        AND m.user_id = app.session_user_id()
    )
  );

CREATE POLICY transport_assign_staff_write ON transport_assignments
  FOR INSERT TO eventapp_web
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM transport_groups tg
      JOIN events e ON e.id = tg.event_id
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE tg.id = transport_assignments.transport_group_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

CREATE POLICY transport_assign_staff_update ON transport_assignments
  FOR UPDATE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM transport_groups tg
      JOIN events e ON e.id = tg.event_id
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE tg.id = transport_assignments.transport_group_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM transport_groups tg
      JOIN events e ON e.id = tg.event_id
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE tg.id = transport_assignments.transport_group_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

CREATE POLICY transport_assign_staff_delete ON transport_assignments
  FOR DELETE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM transport_groups tg
      JOIN events e ON e.id = tg.event_id
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE tg.id = transport_assignments.transport_group_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

-- -----------------------------------------------------------------------------
-- Database connection hardening (optional; requires superuser)
-- -----------------------------------------------------------------------------
DO $sec$
BEGIN
  EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', current_database());
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END
$sec$;

DO $sec$
BEGIN
  EXECUTE format(
    'GRANT CONNECT ON DATABASE %I TO eventapp_web, eventapp_worker',
    current_database()
  );
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END
$sec$;

COMMIT;
