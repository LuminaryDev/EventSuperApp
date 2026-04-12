# Database field reference — platform extensions (003)

Applies when you run `database/migrations/003_platform_extensions.sql` and `004_platform_security.sql`.  
Base MVP tables remain in `docs/DATABASE_FIELD_REFERENCE.md`.

---

## tags

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| slug | VARCHAR(120) | NOT NULL, UNIQUE |
| name | VARCHAR(160) | NOT NULL |
| created_at | TIMESTAMPTZ | NOT NULL |

---

## event_tags

| Column | Type | Notes |
|--------|------|--------|
| event_id | BIGINT | PK, FK events(id) CASCADE |
| tag_id | BIGINT | PK, FK tags(id) CASCADE |
| created_at | TIMESTAMPTZ | NOT NULL |

**Index:** (tag_id)

---

## promo_codes

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| public_id | UUID | UNIQUE, default gen_random_uuid() |
| organization_id | BIGINT | FK organizations(id) CASCADE, nullable (platform-wide) |
| event_id | BIGINT | FK events(id) CASCADE, nullable |
| code | CITEXT | NOT NULL, UNIQUE (case-insensitive) |
| discount_kind | VARCHAR(20) | percent_bp \| fixed_minor |
| percent_basis_points | INTEGER | 1–10000 when kind = percent_bp |
| fixed_amount_minor | BIGINT | >= 0 when kind = fixed_minor |
| currency | CHAR(3) | default ETB |
| max_redemptions | INTEGER | nullable, > 0 if set |
| redemptions_count | INTEGER | NOT NULL, default 0 |
| per_user_limit | INTEGER | NOT NULL, default 1, >= 1 |
| min_order_minor | BIGINT | NOT NULL, default 0 |
| starts_at, ends_at | TIMESTAMPTZ | |
| active | BOOLEAN | NOT NULL, default true |
| created_at, updated_at | TIMESTAMPTZ | trigger |

**CHECK:** discount shape (percent vs fixed); `event_id IS NULL OR organization_id IS NOT NULL`

**Indexes:** (organization_id), (event_id), (active, starts_at, ends_at)

---

## order_promo_applications

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| order_id | BIGINT | FK orders(id) RESTRICT |
| promo_code_id | BIGINT | FK promo_codes(id) RESTRICT |
| discount_minor | BIGINT | NOT NULL, >= 0 |
| created_at | TIMESTAMPTZ | NOT NULL |

**UNIQUE:** (order_id, promo_code_id)

**Indexes:** (order_id), (promo_code_id)

---

## waitlist_entries

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| public_id | UUID | UNIQUE |
| user_id | BIGINT | FK users(id) CASCADE |
| event_id | BIGINT | FK events(id) CASCADE |
| ticket_type_id | BIGINT | FK ticket_types(id) CASCADE, nullable |
| status | VARCHAR(20) | waiting \| offered \| fulfilled \| expired \| cancelled |
| position_hint | INTEGER | |
| offered_at | TIMESTAMPTZ | |
| fulfilled_order_id | BIGINT | FK orders(id) SET NULL |
| notes_internal | TEXT | |
| created_at, updated_at | TIMESTAMPTZ | trigger |

**Partial UNIQUE:** (user_id, event_id) WHERE ticket_type_id IS NULL; (user_id, event_id, ticket_type_id) WHERE ticket_type_id IS NOT NULL

**Index:** (event_id, status)

---

## organizer_payout_profiles

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| organization_id | BIGINT | NOT NULL, UNIQUE, FK organizations(id) CASCADE |
| payout_provider | VARCHAR(50) | NOT NULL, default manual |
| provider_account_id | VARCHAR(255) | |
| default_currency | CHAR(3) | default ETB |
| payout_metadata | JSONB | NOT NULL, default {} |
| verified_at | TIMESTAMPTZ | |
| created_at, updated_at | TIMESTAMPTZ | trigger |

---

## payout_batches

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| public_id | UUID | UNIQUE |
| organization_id | BIGINT | FK organizations(id) RESTRICT |
| period_start, period_end | TIMESTAMPTZ | period_end > period_start |
| status | VARCHAR(20) | draft \| submitted \| processing \| paid \| failed \| cancelled |
| gross_minor | BIGINT | >= 0 |
| platform_fee_minor | BIGINT | >= 0 |
| net_to_org_minor | BIGINT | >= 0 |
| currency | CHAR(3) | default ETB |
| provider_payout_id | VARCHAR(255) | |
| notes | TEXT | |
| created_at, updated_at | TIMESTAMPTZ | trigger |

**Index:** (organization_id, status)

---

## payout_batch_items

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| payout_batch_id | BIGINT | FK payout_batches(id) CASCADE |
| order_id | BIGINT | FK orders(id) RESTRICT |
| gross_minor | BIGINT | >= 0 |
| platform_fee_minor | BIGINT | >= 0 |
| net_to_org_minor | BIGINT | >= 0 |
| currency | CHAR(3) | NOT NULL |
| created_at | TIMESTAMPTZ | NOT NULL |

**UNIQUE:** (payout_batch_id, order_id)

**Index:** (order_id)

---

## notification_templates

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| template_key | VARCHAR(100) | NOT NULL |
| channel | VARCHAR(20) | email \| sms \| push \| in_app |
| locale | VARCHAR(10) | NOT NULL, default en |
| subject_template | TEXT | |
| body_template | TEXT | NOT NULL |
| active | BOOLEAN | NOT NULL, default true |
| created_at, updated_at | TIMESTAMPTZ | trigger |

**UNIQUE:** (template_key, channel, locale)

---

## notification_jobs

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| public_id | UUID | UNIQUE |
| template_id | BIGINT | FK notification_templates(id) SET NULL |
| user_id | BIGINT | FK users(id) SET NULL |
| channel | VARCHAR(20) | email \| sms \| push \| in_app |
| to_address | TEXT | NOT NULL |
| payload | JSONB | NOT NULL, default {} |
| status | VARCHAR(20) | pending \| queued \| sending \| sent \| failed \| cancelled |
| attempts | INTEGER | >= 0 |
| next_attempt_at | TIMESTAMPTZ | |
| sent_at | TIMESTAMPTZ | |
| last_error | TEXT | |
| correlation_id | UUID | |
| created_at, updated_at | TIMESTAMPTZ | trigger |

**Indexes:** (status, next_attempt_at); (user_id, created_at DESC)

---

## file_assets

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| public_id | UUID | UNIQUE |
| storage_provider | VARCHAR(50) | NOT NULL |
| bucket | VARCHAR(255) | NOT NULL |
| object_key | TEXT | NOT NULL |
| mime_type | VARCHAR(120) | NOT NULL |
| byte_size | BIGINT | >= 0 |
| checksum_sha256 | VARCHAR(64) | |
| uploaded_by_user_id | BIGINT | FK users(id) SET NULL |
| organization_id | BIGINT | FK organizations(id) SET NULL |
| event_id | BIGINT | FK events(id) SET NULL |
| purpose | VARCHAR(50) | general \| event_cover \| event_gallery \| user_avatar \| org_logo \| export_archive \| other |
| created_at | TIMESTAMPTZ | NOT NULL |

**UNIQUE:** (storage_provider, bucket, object_key)

**Indexes:** (event_id), (organization_id)

---

## feature_flags

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| flag_key | VARCHAR(100) | NOT NULL, UNIQUE |
| enabled | BOOLEAN | NOT NULL, default false |
| rollout_percent | INTEGER | 0–100 |
| metadata | JSONB | NOT NULL, default {} |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

---

## audit_admin_events

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| actor_user_id | BIGINT | FK users(id) SET NULL |
| action | VARCHAR(120) | NOT NULL |
| entity_table | VARCHAR(100) | |
| entity_id | BIGINT | |
| impersonated_user_id | BIGINT | FK users(id) SET NULL |
| ip_address | INET | |
| user_agent | VARCHAR(512) | |
| payload | JSONB | NOT NULL, default {} |
| created_at | TIMESTAMPTZ | NOT NULL |

**Indexes:** (actor_user_id, created_at DESC); (created_at DESC)

**Security:** `eventapp_web` has no privileges (004).

---

## data_subject_export_requests

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| public_id | UUID | UNIQUE |
| user_id | BIGINT | FK users(id) CASCADE |
| status | VARCHAR(20) | pending \| processing \| ready \| expired \| failed |
| file_asset_id | BIGINT | FK file_assets(id) SET NULL |
| requested_at | TIMESTAMPTZ | NOT NULL |
| ready_at | TIMESTAMPTZ | |
| expires_at | TIMESTAMPTZ | |
| error | TEXT | |

**Index:** (user_id, requested_at DESC)

---

## analytics_events

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| occurred_at | TIMESTAMPTZ | NOT NULL, default now() |
| user_id | BIGINT | FK users(id) SET NULL |
| anon_id | UUID | |
| session_id | UUID | |
| event_name | VARCHAR(120) | NOT NULL |
| properties | JSONB | NOT NULL, default {} |

**CHECK:** user_id IS NOT NULL OR anon_id IS NOT NULL

**Indexes:** (occurred_at DESC); (event_name, occurred_at DESC); (user_id, occurred_at DESC)

**Security:** `eventapp_web` has no privileges; ingest with `eventapp_worker`.

---

## user_event_favorites

| Column | Type | Notes |
|--------|------|--------|
| user_id | BIGINT | PK, FK users(id) CASCADE |
| event_id | BIGINT | PK, FK events(id) CASCADE |
| created_at | TIMESTAMPTZ | NOT NULL |

**Index:** (event_id)

---

## cart_sessions

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| public_id | UUID | UNIQUE |
| user_id | BIGINT | FK users(id) CASCADE, nullable (RLS targets logged-in only) |
| label | VARCHAR(120) | |
| expires_at | TIMESTAMPTZ | NOT NULL |
| created_at, updated_at | TIMESTAMPTZ | trigger |

**Indexes:** (user_id); (expires_at)

---

## cart_lines

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| cart_id | BIGINT | FK cart_sessions(id) CASCADE |
| event_id | BIGINT | FK events(id) CASCADE |
| ticket_type_id | BIGINT | FK ticket_types(id) CASCADE |
| quantity | INTEGER | NOT NULL, >= 1 |
| created_at, updated_at | TIMESTAMPTZ | trigger |

**UNIQUE:** (cart_id, ticket_type_id)

**Indexes:** (cart_id); (event_id)

---

## referral_codes

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| public_id | UUID | UNIQUE |
| user_id | BIGINT | FK users(id) CASCADE |
| code | CITEXT | NOT NULL, UNIQUE |
| max_uses | INTEGER | nullable, > 0 |
| uses_count | INTEGER | NOT NULL, >= 0 |
| active | BOOLEAN | NOT NULL, default true |
| created_at, updated_at | TIMESTAMPTZ | trigger |

**Index:** (user_id)

---

## referral_attributions

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| referral_code_id | BIGINT | FK referral_codes(id) RESTRICT |
| referred_user_id | BIGINT | FK users(id) CASCADE, UNIQUE |
| first_order_id | BIGINT | FK orders(id) SET NULL |
| created_at | TIMESTAMPTZ | NOT NULL |

**Index:** (referral_code_id)

---

## user_security_tokens

| Column | Type | Notes |
|--------|------|--------|
| id | BIGSERIAL | PK |
| user_id | BIGINT | FK users(id) CASCADE |
| purpose | VARCHAR(32) | email_verify \| password_reset \| magic_link \| phone_verify |
| token_hash | BYTEA | NOT NULL |
| expires_at | TIMESTAMPTZ | NOT NULL |
| consumed_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | NOT NULL |

**UNIQUE:** (user_id, purpose, token_hash)

**Indexes:** (user_id, purpose); (expires_at)

**Security:** `eventapp_web` has no privileges.

---

## user_marketing_preferences

| Column | Type | Notes |
|--------|------|--------|
| user_id | BIGINT | PK, FK users(id) CASCADE |
| email_opt_in | BOOLEAN | NOT NULL, default false |
| sms_opt_in | BOOLEAN | NOT NULL, default false |
| push_opt_in | BOOLEAN | NOT NULL, default false |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

---

## Still not modeled (add when you need them)

- Seat maps / reserved seating geometry
- In-app messaging threads
- Chargeback / dispute case management
- Multi-tenant “platform operator” staff table (beyond RLS + worker)
- Subscription billing (SaaS for organizers)
- Per-country tax rule engine tables

These can be new migrations that reference existing `orders`, `events`, and `organizations`.
