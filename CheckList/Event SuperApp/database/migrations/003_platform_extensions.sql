-- =============================================================================
-- Event SuperApp — platform extensions (promos, waitlist, payouts, comms, etc.)
-- Run AFTER 001_initial_schema.sql and 002_security_grants_rls.sql
-- Then run 004_platform_security.sql
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Discovery: tags
-- -----------------------------------------------------------------------------
CREATE TABLE tags (
  id                  BIGSERIAL PRIMARY KEY,
  slug                VARCHAR(120) NOT NULL UNIQUE,
  name                VARCHAR(160) NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE event_tags (
  event_id            BIGINT NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  tag_id              BIGINT NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, tag_id)
);

CREATE INDEX idx_event_tags_tag ON event_tags (tag_id);

-- -----------------------------------------------------------------------------
-- Promotions
-- -----------------------------------------------------------------------------
CREATE TABLE promo_codes (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  organization_id     BIGINT REFERENCES organizations (id) ON DELETE CASCADE,
  event_id            BIGINT REFERENCES events (id) ON DELETE CASCADE,

  code                CITEXT NOT NULL UNIQUE,

  discount_kind       VARCHAR(20) NOT NULL
                      CHECK (discount_kind IN ('percent_bp', 'fixed_minor')),
  percent_basis_points INTEGER
                      CHECK (percent_basis_points IS NULL OR (percent_basis_points > 0 AND percent_basis_points <= 10000)),
  fixed_amount_minor  BIGINT
                      CHECK (fixed_amount_minor IS NULL OR fixed_amount_minor >= 0),

  currency            CHAR(3) NOT NULL DEFAULT 'ETB',

  max_redemptions     INTEGER CHECK (max_redemptions IS NULL OR max_redemptions > 0),
  redemptions_count   INTEGER NOT NULL DEFAULT 0 CHECK (redemptions_count >= 0),

  per_user_limit      INTEGER NOT NULL DEFAULT 1 CHECK (per_user_limit >= 1),
  min_order_minor     BIGINT NOT NULL DEFAULT 0 CHECK (min_order_minor >= 0),

  starts_at           TIMESTAMPTZ,
  ends_at             TIMESTAMPTZ,

  active              BOOLEAN NOT NULL DEFAULT true,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT promo_discount_shape CHECK (
    (discount_kind = 'percent_bp' AND percent_basis_points IS NOT NULL AND fixed_amount_minor IS NULL)
    OR
    (discount_kind = 'fixed_minor' AND fixed_amount_minor IS NOT NULL AND percent_basis_points IS NULL)
  ),
  CONSTRAINT promo_event_requires_org CHECK (event_id IS NULL OR organization_id IS NOT NULL)
);

CREATE TRIGGER tr_promo_codes_updated_at
  BEFORE UPDATE ON promo_codes
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_promo_codes_org ON promo_codes (organization_id);
CREATE INDEX idx_promo_codes_event ON promo_codes (event_id);
CREATE INDEX idx_promo_codes_active ON promo_codes (active, starts_at, ends_at);

CREATE TABLE order_promo_applications (
  id                  BIGSERIAL PRIMARY KEY,

  order_id            BIGINT NOT NULL REFERENCES orders (id) ON DELETE RESTRICT,
  promo_code_id       BIGINT NOT NULL REFERENCES promo_codes (id) ON DELETE RESTRICT,

  discount_minor      BIGINT NOT NULL CHECK (discount_minor >= 0),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (order_id, promo_code_id)
);

CREATE INDEX idx_order_promo_order ON order_promo_applications (order_id);
CREATE INDEX idx_order_promo_promo ON order_promo_applications (promo_code_id);

-- -----------------------------------------------------------------------------
-- Waitlist
-- -----------------------------------------------------------------------------
CREATE TABLE waitlist_entries (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  user_id             BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  event_id            BIGINT NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  ticket_type_id      BIGINT REFERENCES ticket_types (id) ON DELETE CASCADE,

  status              VARCHAR(20) NOT NULL DEFAULT 'waiting'
                      CHECK (status IN ('waiting', 'offered', 'fulfilled', 'expired', 'cancelled')),

  position_hint       INTEGER,
  offered_at          TIMESTAMPTZ,
  fulfilled_order_id  BIGINT REFERENCES orders (id) ON DELETE SET NULL,

  notes_internal      TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_waitlist_entries_updated_at
  BEFORE UPDATE ON waitlist_entries
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE UNIQUE INDEX waitlist_user_event_any_type ON waitlist_entries (user_id, event_id)
  WHERE ticket_type_id IS NULL;

CREATE UNIQUE INDEX waitlist_user_event_ticket_type ON waitlist_entries (user_id, event_id, ticket_type_id)
  WHERE ticket_type_id IS NOT NULL;

CREATE INDEX idx_waitlist_event_status ON waitlist_entries (event_id, status);

-- -----------------------------------------------------------------------------
-- Organizer payouts & settlements
-- -----------------------------------------------------------------------------
CREATE TABLE organizer_payout_profiles (
  id                  BIGSERIAL PRIMARY KEY,
  organization_id     BIGINT NOT NULL UNIQUE REFERENCES organizations (id) ON DELETE CASCADE,

  payout_provider     VARCHAR(50) NOT NULL DEFAULT 'manual',
  provider_account_id VARCHAR(255),

  default_currency    CHAR(3) NOT NULL DEFAULT 'ETB',

  payout_metadata     JSONB NOT NULL DEFAULT '{}',

  verified_at         TIMESTAMPTZ,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_organizer_payout_profiles_updated_at
  BEFORE UPDATE ON organizer_payout_profiles
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE TABLE payout_batches (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  organization_id     BIGINT NOT NULL REFERENCES organizations (id) ON DELETE RESTRICT,

  period_start        TIMESTAMPTZ NOT NULL,
  period_end          TIMESTAMPTZ NOT NULL,

  status              VARCHAR(20) NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'submitted', 'processing', 'paid', 'failed', 'cancelled')),

  gross_minor         BIGINT NOT NULL DEFAULT 0 CHECK (gross_minor >= 0),
  platform_fee_minor  BIGINT NOT NULL DEFAULT 0 CHECK (platform_fee_minor >= 0),
  net_to_org_minor    BIGINT NOT NULL DEFAULT 0 CHECK (net_to_org_minor >= 0),
  currency            CHAR(3) NOT NULL DEFAULT 'ETB',

  provider_payout_id  VARCHAR(255),
  notes               TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT payout_batch_period CHECK (period_end > period_start)
);

CREATE TRIGGER tr_payout_batches_updated_at
  BEFORE UPDATE ON payout_batches
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_payout_batches_org ON payout_batches (organization_id, status);

CREATE TABLE payout_batch_items (
  id                  BIGSERIAL PRIMARY KEY,

  payout_batch_id     BIGINT NOT NULL REFERENCES payout_batches (id) ON DELETE CASCADE,
  order_id            BIGINT NOT NULL REFERENCES orders (id) ON DELETE RESTRICT,

  gross_minor         BIGINT NOT NULL CHECK (gross_minor >= 0),
  platform_fee_minor  BIGINT NOT NULL CHECK (platform_fee_minor >= 0),
  net_to_org_minor    BIGINT NOT NULL CHECK (net_to_org_minor >= 0),
  currency            CHAR(3) NOT NULL,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (payout_batch_id, order_id)
);

CREATE INDEX idx_payout_batch_items_order ON payout_batch_items (order_id);

-- -----------------------------------------------------------------------------
-- Notifications (template + outbox)
-- -----------------------------------------------------------------------------
CREATE TABLE notification_templates (
  id                  BIGSERIAL PRIMARY KEY,

  template_key        VARCHAR(100) NOT NULL,
  channel             VARCHAR(20) NOT NULL
                      CHECK (channel IN ('email', 'sms', 'push', 'in_app')),

  locale              VARCHAR(10) NOT NULL DEFAULT 'en',

  subject_template    TEXT,
  body_template       TEXT NOT NULL,

  active              BOOLEAN NOT NULL DEFAULT true,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (template_key, channel, locale)
);

CREATE TRIGGER tr_notification_templates_updated_at
  BEFORE UPDATE ON notification_templates
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE TABLE notification_jobs (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  template_id         BIGINT REFERENCES notification_templates (id) ON DELETE SET NULL,

  user_id             BIGINT REFERENCES users (id) ON DELETE SET NULL,

  channel             VARCHAR(20) NOT NULL
                      CHECK (channel IN ('email', 'sms', 'push', 'in_app')),

  to_address          TEXT NOT NULL,
  payload             JSONB NOT NULL DEFAULT '{}',

  status              VARCHAR(20) NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'queued', 'sending', 'sent', 'failed', 'cancelled')),

  attempts            INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at     TIMESTAMPTZ,
  sent_at             TIMESTAMPTZ,
  last_error          TEXT,

  correlation_id      UUID,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_notification_jobs_updated_at
  BEFORE UPDATE ON notification_jobs
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_notification_jobs_status_next ON notification_jobs (status, next_attempt_at);
CREATE INDEX idx_notification_jobs_user ON notification_jobs (user_id, created_at DESC);

-- -----------------------------------------------------------------------------
-- Media / file metadata (object lives in S3, R2, etc.)
-- -----------------------------------------------------------------------------
CREATE TABLE file_assets (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  storage_provider    VARCHAR(50) NOT NULL,
  bucket              VARCHAR(255) NOT NULL,
  object_key          TEXT NOT NULL,

  mime_type           VARCHAR(120) NOT NULL,
  byte_size           BIGINT NOT NULL CHECK (byte_size >= 0),
  checksum_sha256     VARCHAR(64),

  uploaded_by_user_id BIGINT REFERENCES users (id) ON DELETE SET NULL,
  organization_id     BIGINT REFERENCES organizations (id) ON DELETE SET NULL,
  event_id            BIGINT REFERENCES events (id) ON DELETE SET NULL,

  purpose             VARCHAR(50) NOT NULL DEFAULT 'general'
                      CHECK (purpose IN (
                        'general', 'event_cover', 'event_gallery', 'user_avatar',
                        'org_logo', 'export_archive', 'other'
                      )),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (storage_provider, bucket, object_key)
);

CREATE INDEX idx_file_assets_event ON file_assets (event_id);
CREATE INDEX idx_file_assets_org ON file_assets (organization_id);

-- -----------------------------------------------------------------------------
-- Feature flags
-- -----------------------------------------------------------------------------
CREATE TABLE feature_flags (
  id                  BIGSERIAL PRIMARY KEY,

  flag_key            VARCHAR(100) NOT NULL UNIQUE,
  enabled             BOOLEAN NOT NULL DEFAULT false,
  rollout_percent     INTEGER NOT NULL DEFAULT 0 CHECK (rollout_percent >= 0 AND rollout_percent <= 100),

  metadata            JSONB NOT NULL DEFAULT '{}',

  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_feature_flags_updated_at
  BEFORE UPDATE ON feature_flags
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

-- -----------------------------------------------------------------------------
-- Admin / support audit (impersonation, sensitive actions)
-- -----------------------------------------------------------------------------
CREATE TABLE audit_admin_events (
  id                  BIGSERIAL PRIMARY KEY,

  actor_user_id       BIGINT REFERENCES users (id) ON DELETE SET NULL,

  action              VARCHAR(120) NOT NULL,

  entity_table        VARCHAR(100),
  entity_id           BIGINT,

  impersonated_user_id BIGINT REFERENCES users (id) ON DELETE SET NULL,

  ip_address          INET,
  user_agent          VARCHAR(512),

  payload             JSONB NOT NULL DEFAULT '{}',

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_admin_actor ON audit_admin_events (actor_user_id, created_at DESC);
CREATE INDEX idx_audit_admin_created ON audit_admin_events (created_at DESC);

-- -----------------------------------------------------------------------------
-- GDPR / data subject exports
-- -----------------------------------------------------------------------------
CREATE TABLE data_subject_export_requests (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  user_id             BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  status              VARCHAR(20) NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'processing', 'ready', 'expired', 'failed')),

  file_asset_id       BIGINT REFERENCES file_assets (id) ON DELETE SET NULL,

  requested_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  ready_at            TIMESTAMPTZ,
  expires_at          TIMESTAMPTZ,

  error               TEXT
);

CREATE INDEX idx_data_export_user ON data_subject_export_requests (user_id, requested_at DESC);

-- -----------------------------------------------------------------------------
-- Product analytics (append-only; partition in ops when volume explodes)
-- -----------------------------------------------------------------------------
CREATE TABLE analytics_events (
  id                  BIGSERIAL PRIMARY KEY,

  occurred_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

  user_id             BIGINT REFERENCES users (id) ON DELETE SET NULL,
  anon_id             UUID,

  session_id          UUID,
  event_name          VARCHAR(120) NOT NULL,
  properties          JSONB NOT NULL DEFAULT '{}',

  CONSTRAINT analytics_actor CHECK (user_id IS NOT NULL OR anon_id IS NOT NULL)
);

CREATE INDEX idx_analytics_occurred ON analytics_events (occurred_at DESC);
CREATE INDEX idx_analytics_name_time ON analytics_events (event_name, occurred_at DESC);
CREATE INDEX idx_analytics_user_time ON analytics_events (user_id, occurred_at DESC);

COMMENT ON TABLE analytics_events IS 'High-volume; consider time partitioning + BRIN(occurred_at) in production.';

-- -----------------------------------------------------------------------------
-- Engagement
-- -----------------------------------------------------------------------------
CREATE TABLE user_event_favorites (
  user_id             BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  event_id            BIGINT NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, event_id)
);

CREATE INDEX idx_favorites_event ON user_event_favorites (event_id);

-- -----------------------------------------------------------------------------
-- Shopping carts (multi-event; checkout still creates per-event orders in MVP)
-- -----------------------------------------------------------------------------
CREATE TABLE cart_sessions (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  user_id             BIGINT REFERENCES users (id) ON DELETE CASCADE,

  label               VARCHAR(120),

  expires_at          TIMESTAMPTZ NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_cart_sessions_updated_at
  BEFORE UPDATE ON cart_sessions
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_cart_sessions_user ON cart_sessions (user_id);
CREATE INDEX idx_cart_sessions_expires ON cart_sessions (expires_at);

CREATE TABLE cart_lines (
  id                  BIGSERIAL PRIMARY KEY,

  cart_id             BIGINT NOT NULL REFERENCES cart_sessions (id) ON DELETE CASCADE,
  event_id            BIGINT NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  ticket_type_id      BIGINT NOT NULL REFERENCES ticket_types (id) ON DELETE CASCADE,

  quantity            INTEGER NOT NULL CHECK (quantity >= 1),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (cart_id, ticket_type_id)
);

CREATE TRIGGER tr_cart_lines_updated_at
  BEFORE UPDATE ON cart_lines
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_cart_lines_cart ON cart_lines (cart_id);
CREATE INDEX idx_cart_lines_event ON cart_lines (event_id);

-- -----------------------------------------------------------------------------
-- Referrals (lightweight)
-- -----------------------------------------------------------------------------
CREATE TABLE referral_codes (
  id                  BIGSERIAL PRIMARY KEY,
  public_id           UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  user_id             BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  code                CITEXT NOT NULL UNIQUE,

  max_uses            INTEGER CHECK (max_uses IS NULL OR max_uses > 0),
  uses_count          INTEGER NOT NULL DEFAULT 0 CHECK (uses_count >= 0),

  active              BOOLEAN NOT NULL DEFAULT true,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_referral_codes_updated_at
  BEFORE UPDATE ON referral_codes
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

CREATE INDEX idx_referral_codes_user ON referral_codes (user_id);

CREATE TABLE referral_attributions (
  id                  BIGSERIAL PRIMARY KEY,

  referral_code_id    BIGINT NOT NULL REFERENCES referral_codes (id) ON DELETE RESTRICT,
  referred_user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  first_order_id      BIGINT REFERENCES orders (id) ON DELETE SET NULL,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (referred_user_id)
);

CREATE INDEX idx_referral_attr_code ON referral_attributions (referral_code_id);

-- -----------------------------------------------------------------------------
-- Auth challenge tokens (hashed; worker validates)
-- -----------------------------------------------------------------------------
CREATE TABLE user_security_tokens (
  id                  BIGSERIAL PRIMARY KEY,

  user_id             BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  purpose             VARCHAR(32) NOT NULL
                      CHECK (purpose IN ('email_verify', 'password_reset', 'magic_link', 'phone_verify')),

  token_hash          BYTEA NOT NULL,
  expires_at          TIMESTAMPTZ NOT NULL,
  consumed_at         TIMESTAMPTZ,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (user_id, purpose, token_hash)
);

CREATE INDEX idx_user_security_tokens_user_purpose ON user_security_tokens (user_id, purpose);
CREATE INDEX idx_user_security_tokens_expires ON user_security_tokens (expires_at);

-- -----------------------------------------------------------------------------
-- Marketing consent
-- -----------------------------------------------------------------------------
CREATE TABLE user_marketing_preferences (
  user_id             BIGINT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,

  email_opt_in        BOOLEAN NOT NULL DEFAULT false,
  sms_opt_in          BOOLEAN NOT NULL DEFAULT false,
  push_opt_in         BOOLEAN NOT NULL DEFAULT false,

  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER tr_user_marketing_preferences_updated_at
  BEFORE UPDATE ON user_marketing_preferences
  FOR EACH ROW EXECUTE PROCEDURE app_set_updated_at();

COMMIT;
