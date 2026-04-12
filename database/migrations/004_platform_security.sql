-- =============================================================================
-- Event SuperApp — security for 003_platform_extensions (run AFTER 003)
-- Reassigns ownership, grants, enables RLS + policies on new tables.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Ownership
-- -----------------------------------------------------------------------------
ALTER TABLE tags OWNER TO eventapp_migrator;
ALTER TABLE event_tags OWNER TO eventapp_migrator;
ALTER TABLE promo_codes OWNER TO eventapp_migrator;
ALTER TABLE order_promo_applications OWNER TO eventapp_migrator;
ALTER TABLE waitlist_entries OWNER TO eventapp_migrator;
ALTER TABLE organizer_payout_profiles OWNER TO eventapp_migrator;
ALTER TABLE payout_batches OWNER TO eventapp_migrator;
ALTER TABLE payout_batch_items OWNER TO eventapp_migrator;
ALTER TABLE notification_templates OWNER TO eventapp_migrator;
ALTER TABLE notification_jobs OWNER TO eventapp_migrator;
ALTER TABLE file_assets OWNER TO eventapp_migrator;
ALTER TABLE feature_flags OWNER TO eventapp_migrator;
ALTER TABLE audit_admin_events OWNER TO eventapp_migrator;
ALTER TABLE data_subject_export_requests OWNER TO eventapp_migrator;
ALTER TABLE analytics_events OWNER TO eventapp_migrator;
ALTER TABLE user_event_favorites OWNER TO eventapp_migrator;
ALTER TABLE cart_sessions OWNER TO eventapp_migrator;
ALTER TABLE cart_lines OWNER TO eventapp_migrator;
ALTER TABLE referral_codes OWNER TO eventapp_migrator;
ALTER TABLE referral_attributions OWNER TO eventapp_migrator;
ALTER TABLE user_security_tokens OWNER TO eventapp_migrator;
ALTER TABLE user_marketing_preferences OWNER TO eventapp_migrator;

ALTER SEQUENCE tags_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE promo_codes_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE order_promo_applications_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE waitlist_entries_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE organizer_payout_profiles_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE payout_batches_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE payout_batch_items_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE notification_templates_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE notification_jobs_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE file_assets_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE feature_flags_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE audit_admin_events_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE data_subject_export_requests_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE analytics_events_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE cart_sessions_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE cart_lines_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE referral_codes_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE referral_attributions_id_seq OWNER TO eventapp_migrator;
ALTER SEQUENCE user_security_tokens_id_seq OWNER TO eventapp_migrator;

-- -----------------------------------------------------------------------------
-- Grants (003 objects were not included in 002’s ALL TABLES snapshot)
-- -----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON tags, event_tags, promo_codes, order_promo_applications,
  waitlist_entries, organizer_payout_profiles, payout_batches, payout_batch_items,
  notification_templates, notification_jobs, file_assets, feature_flags, audit_admin_events,
  data_subject_export_requests, analytics_events, user_event_favorites, cart_sessions, cart_lines,
  referral_codes, referral_attributions, user_security_tokens, user_marketing_preferences
  TO eventapp_web, eventapp_worker;

GRANT USAGE, SELECT ON SEQUENCE
  tags_id_seq, promo_codes_id_seq, order_promo_applications_id_seq, waitlist_entries_id_seq,
  organizer_payout_profiles_id_seq, payout_batches_id_seq, payout_batch_items_id_seq,
  notification_templates_id_seq, notification_jobs_id_seq, file_assets_id_seq, feature_flags_id_seq,
  audit_admin_events_id_seq, data_subject_export_requests_id_seq, analytics_events_id_seq,
  cart_sessions_id_seq, cart_lines_id_seq, referral_codes_id_seq, referral_attributions_id_seq,
  user_security_tokens_id_seq
  TO eventapp_web, eventapp_worker;

-- Sensitive: templates mutated by ops; admin audit + raw tokens + analytics pipeline
REVOKE INSERT, UPDATE, DELETE ON notification_templates FROM eventapp_web;
REVOKE ALL ON audit_admin_events FROM eventapp_web;
REVOKE ALL ON user_security_tokens FROM eventapp_web;
REVOKE ALL ON analytics_events FROM eventapp_web;

-- Promo validation at checkout should use worker or staff; staff still needs CRUD
-- (handled via RLS below; web retains INSERT for creating org-scoped promos where policy allows)

-- -----------------------------------------------------------------------------
-- RLS + FORCE
-- -----------------------------------------------------------------------------
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags FORCE ROW LEVEL SECURITY;

ALTER TABLE event_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_tags FORCE ROW LEVEL SECURITY;

ALTER TABLE promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE promo_codes FORCE ROW LEVEL SECURITY;

ALTER TABLE order_promo_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_promo_applications FORCE ROW LEVEL SECURITY;

ALTER TABLE waitlist_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE waitlist_entries FORCE ROW LEVEL SECURITY;

ALTER TABLE organizer_payout_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizer_payout_profiles FORCE ROW LEVEL SECURITY;

ALTER TABLE payout_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_batches FORCE ROW LEVEL SECURITY;

ALTER TABLE payout_batch_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_batch_items FORCE ROW LEVEL SECURITY;

ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_templates FORCE ROW LEVEL SECURITY;

ALTER TABLE notification_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_jobs FORCE ROW LEVEL SECURITY;

ALTER TABLE file_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE file_assets FORCE ROW LEVEL SECURITY;

ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flags FORCE ROW LEVEL SECURITY;

ALTER TABLE data_subject_export_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_subject_export_requests FORCE ROW LEVEL SECURITY;

ALTER TABLE user_event_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_event_favorites FORCE ROW LEVEL SECURITY;

ALTER TABLE cart_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_sessions FORCE ROW LEVEL SECURITY;

ALTER TABLE cart_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_lines FORCE ROW LEVEL SECURITY;

ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_codes FORCE ROW LEVEL SECURITY;

ALTER TABLE referral_attributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_attributions FORCE ROW LEVEL SECURITY;

ALTER TABLE user_marketing_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_marketing_preferences FORCE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Policies (eventapp_web). eventapp_worker BYPASSRLS.
-- -----------------------------------------------------------------------------

CREATE POLICY tags_select_all ON tags FOR SELECT TO eventapp_web USING (true);

CREATE POLICY event_tags_select_visible ON event_tags FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM events e
      WHERE e.id = event_tags.event_id
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

CREATE POLICY event_tags_staff_write ON event_tags FOR ALL TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = event_tags.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = event_tags.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

CREATE POLICY promo_select_staff ON promo_codes FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
        AND (
          (promo_codes.organization_id IS NOT NULL AND promo_codes.organization_id = m.organization_id)
          OR EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = promo_codes.event_id
              AND e.organization_id = m.organization_id
          )
        )
    )
  );

CREATE POLICY promo_staff_write ON promo_codes FOR INSERT TO eventapp_web
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
        AND (
          (promo_codes.organization_id = m.organization_id)
          OR EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = promo_codes.event_id
              AND e.organization_id = m.organization_id
          )
        )
    )
  );

CREATE POLICY promo_staff_update ON promo_codes FOR UPDATE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
        AND (
          (promo_codes.organization_id = m.organization_id)
          OR EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = promo_codes.event_id
              AND e.organization_id = m.organization_id
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
        AND (
          (promo_codes.organization_id = m.organization_id)
          OR EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = promo_codes.event_id
              AND e.organization_id = m.organization_id
          )
        )
    )
  );

CREATE POLICY promo_staff_delete ON promo_codes FOR DELETE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
        AND (
          (promo_codes.organization_id = m.organization_id)
          OR EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = promo_codes.event_id
              AND e.organization_id = m.organization_id
          )
        )
    )
  );

CREATE POLICY order_promo_select_own ON order_promo_applications FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_promo_applications.order_id
        AND o.user_id = app.session_user_id()
    )
  );

CREATE POLICY order_promo_staff_select ON order_promo_applications FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      JOIN events e ON e.id = o.event_id
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE o.id = order_promo_applications.order_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

CREATE POLICY order_promo_insert_own ON order_promo_applications FOR INSERT TO eventapp_web
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_promo_applications.order_id
        AND o.user_id = app.session_user_id()
    )
  );

CREATE POLICY waitlist_select_self ON waitlist_entries FOR SELECT TO eventapp_web
  USING (user_id = app.session_user_id());

CREATE POLICY waitlist_staff_select ON waitlist_entries FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = waitlist_entries.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

CREATE POLICY waitlist_insert_self ON waitlist_entries FOR INSERT TO eventapp_web
  WITH CHECK (user_id = app.session_user_id());

CREATE POLICY waitlist_update_self ON waitlist_entries FOR UPDATE TO eventapp_web
  USING (user_id = app.session_user_id())
  WITH CHECK (user_id = app.session_user_id());

CREATE POLICY waitlist_delete_self ON waitlist_entries FOR DELETE TO eventapp_web
  USING (user_id = app.session_user_id());

CREATE POLICY waitlist_staff_update ON waitlist_entries FOR UPDATE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = waitlist_entries.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events e
      JOIN organization_members m ON m.organization_id = e.organization_id
      WHERE e.id = waitlist_entries.event_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
  );

CREATE POLICY payout_profile_select_admin ON organizer_payout_profiles FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = organizer_payout_profiles.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  );

CREATE POLICY payout_profile_write_admin ON organizer_payout_profiles FOR ALL TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = organizer_payout_profiles.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = organizer_payout_profiles.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  );

CREATE POLICY payout_batches_admin ON payout_batches FOR ALL TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = payout_batches.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = payout_batches.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  );

CREATE POLICY payout_items_admin_select ON payout_batch_items FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM payout_batches pb
      JOIN organization_members m ON m.organization_id = pb.organization_id
      WHERE pb.id = payout_batch_items.payout_batch_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  );

CREATE POLICY payout_items_admin_write ON payout_batch_items FOR INSERT TO eventapp_web
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM payout_batches pb
      JOIN organization_members m ON m.organization_id = pb.organization_id
      WHERE pb.id = payout_batch_items.payout_batch_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  );

CREATE POLICY payout_items_admin_update ON payout_batch_items FOR UPDATE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM payout_batches pb
      JOIN organization_members m ON m.organization_id = pb.organization_id
      WHERE pb.id = payout_batch_items.payout_batch_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM payout_batches pb
      JOIN organization_members m ON m.organization_id = pb.organization_id
      WHERE pb.id = payout_batch_items.payout_batch_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  );

CREATE POLICY payout_items_admin_delete ON payout_batch_items FOR DELETE TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM payout_batches pb
      JOIN organization_members m ON m.organization_id = pb.organization_id
      WHERE pb.id = payout_batch_items.payout_batch_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin')
    )
  );

CREATE POLICY notification_templates_select ON notification_templates FOR SELECT TO eventapp_web
  USING (true);

CREATE POLICY notification_jobs_select_own ON notification_jobs FOR SELECT TO eventapp_web
  USING (user_id = app.session_user_id());

CREATE POLICY notification_jobs_insert_own ON notification_jobs FOR INSERT TO eventapp_web
  WITH CHECK (user_id = app.session_user_id());

CREATE POLICY file_assets_select ON file_assets FOR SELECT TO eventapp_web
  USING (
    uploaded_by_user_id = app.session_user_id()
    OR EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = file_assets.organization_id
        AND m.user_id = app.session_user_id()
    )
    OR (
      file_assets.event_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM events e
        WHERE e.id = file_assets.event_id
          AND (
            e.status = 'published'
            OR EXISTS (
              SELECT 1 FROM organization_members m
              WHERE m.organization_id = e.organization_id
                AND m.user_id = app.session_user_id()
            )
          )
      )
    )
  );

CREATE POLICY file_assets_insert ON file_assets FOR INSERT TO eventapp_web
  WITH CHECK (
    uploaded_by_user_id = app.session_user_id()
    OR EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = file_assets.organization_id
        AND m.user_id = app.session_user_id()
        AND m.role IN ('owner', 'admin', 'staff')
    )
    OR (
      file_assets.event_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM events e
        JOIN organization_members m ON m.organization_id = e.organization_id
        WHERE e.id = file_assets.event_id
          AND m.user_id = app.session_user_id()
          AND m.role IN ('owner', 'admin', 'staff')
      )
    )
  );

CREATE POLICY feature_flags_select ON feature_flags FOR SELECT TO eventapp_web USING (true);

CREATE POLICY data_export_select_own ON data_subject_export_requests FOR SELECT TO eventapp_web
  USING (user_id = app.session_user_id());

CREATE POLICY data_export_insert_own ON data_subject_export_requests FOR INSERT TO eventapp_web
  WITH CHECK (user_id = app.session_user_id());

CREATE POLICY data_export_update_own ON data_subject_export_requests FOR UPDATE TO eventapp_web
  USING (user_id = app.session_user_id())
  WITH CHECK (user_id = app.session_user_id());

CREATE POLICY favorites_all_own ON user_event_favorites FOR ALL TO eventapp_web
  USING (user_id = app.session_user_id())
  WITH CHECK (user_id = app.session_user_id());

CREATE POLICY cart_session_own ON cart_sessions FOR ALL TO eventapp_web
  USING (user_id = app.session_user_id() AND user_id IS NOT NULL)
  WITH CHECK (user_id = app.session_user_id() AND user_id IS NOT NULL);

CREATE POLICY cart_lines_via_cart ON cart_lines FOR ALL TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM cart_sessions c
      WHERE c.id = cart_lines.cart_id
        AND c.user_id = app.session_user_id()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM cart_sessions c
      WHERE c.id = cart_lines.cart_id
        AND c.user_id = app.session_user_id()
    )
  );

CREATE POLICY referral_codes_own ON referral_codes FOR ALL TO eventapp_web
  USING (user_id = app.session_user_id())
  WITH CHECK (user_id = app.session_user_id());

CREATE POLICY referral_attr_select_referred ON referral_attributions FOR SELECT TO eventapp_web
  USING (referred_user_id = app.session_user_id());

CREATE POLICY referral_attr_select_referrer ON referral_attributions FOR SELECT TO eventapp_web
  USING (
    EXISTS (
      SELECT 1 FROM referral_codes rc
      WHERE rc.id = referral_attributions.referral_code_id
        AND rc.user_id = app.session_user_id()
    )
  );

CREATE POLICY referral_attr_insert_self ON referral_attributions FOR INSERT TO eventapp_web
  WITH CHECK (referred_user_id = app.session_user_id());

CREATE POLICY marketing_prefs_own ON user_marketing_preferences FOR ALL TO eventapp_web
  USING (user_id = app.session_user_id())
  WITH CHECK (user_id = app.session_user_id());

COMMIT;
