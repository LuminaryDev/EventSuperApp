# Database field reference (001)

Every table and column from `database/migrations/001_initial_schema.sql`.  
Enum-like values are enforced with `CHECK` (see comments at top of 001).

**Platform add-on (003):** `docs/DATABASE_FIELD_REFERENCE_PLATFORM.md` (promos, waitlist, payouts, comms, carts, referrals, analytics, etc.).

---

## users

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE, default gen_random_uuid() |
| email | CITEXT | UNIQUE, nullable |
| phone_e164 | VARCHAR(32) | UNIQUE, nullable |
| password_hash | TEXT | nullable |
| display_name | VARCHAR(200) | NOT NULL, default '' |
| status | VARCHAR(20) | active \| suspended \| deleted |
| email_verified_at | TIMESTAMPTZ | |
| phone_verified_at | TIMESTAMPTZ | |
| last_login_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |
| deleted_at | TIMESTAMPTZ | soft delete |

**CHECK:** `email IS NOT NULL OR phone_e164 IS NOT NULL`

---

## organizations

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| name | VARCHAR(255) | NOT NULL |
| slug | VARCHAR(100) | NOT NULL, UNIQUE |
| legal_name | VARCHAR(255) | |
| tax_id | VARCHAR(64) | |
| status | VARCHAR(20) | active \| inactive |
| created_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

---

## organization_members

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| organization_id | BIGINT | NOT NULL, FK organizations(id) ON DELETE CASCADE |
| user_id | BIGINT | NOT NULL, FK users(id) ON DELETE CASCADE |
| role | VARCHAR(20) | owner \| admin \| staff |
| created_at | TIMESTAMPTZ | NOT NULL |

**UNIQUE:** (organization_id, user_id)

**Indexes:** (user_id), (organization_id)

---

## venues

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| organization_id | BIGINT | FK organizations(id) ON DELETE SET NULL |
| name | VARCHAR(255) | NOT NULL |
| line1 | VARCHAR(255) | |
| line2 | VARCHAR(255) | |
| city | VARCHAR(120) | |
| region | VARCHAR(120) | |
| postal_code | VARCHAR(32) | |
| country | CHAR(2) | NOT NULL, default ET |
| latitude | DOUBLE PRECISION | |
| longitude | DOUBLE PRECISION | |
| timezone | VARCHAR(64) | NOT NULL, default Africa/Addis_Ababa |
| created_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

**Index:** (organization_id)

---

## events

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| organization_id | BIGINT | NOT NULL, FK organizations(id) ON DELETE RESTRICT |
| venue_id | BIGINT | NOT NULL, FK venues(id) ON DELETE RESTRICT |
| title | VARCHAR(500) | NOT NULL |
| slug | VARCHAR(160) | NOT NULL |
| description | TEXT | |
| starts_at | TIMESTAMPTZ | NOT NULL |
| ends_at | TIMESTAMPTZ | NOT NULL |
| timezone | VARCHAR(64) | NOT NULL |
| status | VARCHAR(20) | draft \| published \| cancelled \| completed |
| published_at | TIMESTAMPTZ | |
| sales_starts_at | TIMESTAMPTZ | |
| sales_ends_at | TIMESTAMPTZ | |
| max_attendees | INTEGER | nullable, > 0 if set |
| created_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

**UNIQUE:** (organization_id, slug)  
**CHECK:** ends_at \> starts_at

**Indexes:** (organization_id, status, starts_at); partial (status, starts_at) WHERE status = published

---

## ticket_types

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| event_id | BIGINT | NOT NULL, FK events(id) ON DELETE RESTRICT |
| name | VARCHAR(120) | NOT NULL |
| description | TEXT | |
| price_amount_minor | BIGINT | NOT NULL, >= 0 |
| currency | CHAR(3) | NOT NULL, default ETB |
| quantity_total | INTEGER | NOT NULL, >= 0 |
| quantity_sold | INTEGER | NOT NULL, default 0, >= 0 |
| max_per_order | INTEGER | NOT NULL, default 10, >= 1 |
| sort_order | INTEGER | NOT NULL, default 0 |
| active | BOOLEAN | NOT NULL, default true |
| sales_starts_at | TIMESTAMPTZ | |
| sales_ends_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

**CHECK:** quantity_sold <= quantity_total

**Index:** (event_id, active)

---

## orders

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| user_id | BIGINT | NOT NULL, FK users(id) ON DELETE RESTRICT |
| event_id | BIGINT | NOT NULL, FK events(id) ON DELETE RESTRICT |
| status | VARCHAR(30) | pending_payment \| paid \| cancelled \| refunded \| partially_refunded |
| currency | CHAR(3) | NOT NULL, default ETB |
| subtotal_minor | BIGINT | NOT NULL, default 0, >= 0 |
| fees_minor | BIGINT | NOT NULL, default 0, >= 0 |
| tax_minor | BIGINT | NOT NULL, default 0, >= 0 |
| discount_minor | BIGINT | NOT NULL, default 0, >= 0 |
| total_minor | BIGINT | NOT NULL, default 0, >= 0 |
| idempotency_key | VARCHAR(128) | NOT NULL, UNIQUE |
| placed_at | TIMESTAMPTZ | NOT NULL |
| paid_at | TIMESTAMPTZ | |
| cancelled_at | TIMESTAMPTZ | |
| notes | TEXT | |
| created_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

**Indexes:** (user_id, placed_at DESC); (event_id, status)

---

## order_items

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| order_id | BIGINT | NOT NULL, FK orders(id) ON DELETE RESTRICT |
| ticket_type_id | BIGINT | NOT NULL, FK ticket_types(id) ON DELETE RESTRICT |
| quantity | INTEGER | NOT NULL, >= 1 |
| unit_price_minor | BIGINT | NOT NULL, >= 0 |
| line_total_minor | BIGINT | NOT NULL, >= 0 |
| currency | CHAR(3) | NOT NULL |
| created_at | TIMESTAMPTZ | NOT NULL |

**UNIQUE:** (order_id, ticket_type_id)

**Indexes:** (order_id); (ticket_type_id)

---

## tickets

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| order_item_id | BIGINT | NOT NULL, FK order_items(id) ON DELETE RESTRICT |
| event_id | BIGINT | NOT NULL, FK events(id) ON DELETE RESTRICT |
| ticket_type_id | BIGINT | NOT NULL, FK ticket_types(id) ON DELETE RESTRICT |
| holder_name | VARCHAR(200) | |
| status | VARCHAR(20) | valid \| cancelled \| refunded |
| redemption_code_hash | BYTEA | NOT NULL, UNIQUE |
| checked_in_at | TIMESTAMPTZ | |
| checked_in_by_user_id | BIGINT | FK users(id) ON DELETE SET NULL |
| voided_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | NOT NULL |

**Indexes:** (event_id, status); (order_item_id)

---

## payments

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| order_id | BIGINT | NOT NULL, FK orders(id) ON DELETE RESTRICT |
| provider | VARCHAR(50) | NOT NULL |
| provider_payment_id | VARCHAR(255) | NOT NULL |
| amount_minor | BIGINT | NOT NULL, >= 0 |
| currency | CHAR(3) | NOT NULL |
| status | VARCHAR(20) | pending \| processing \| succeeded \| failed \| refunded |
| provider_fee_minor | BIGINT | nullable, >= 0 |
| raw_metadata | JSONB | |
| created_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

**UNIQUE:** (provider, provider_payment_id)

**Index:** (order_id)

---

## payment_webhook_events

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| provider | VARCHAR(50) | NOT NULL |
| provider_event_id | VARCHAR(255) | NOT NULL |
| payload_digest | VARCHAR(64) | NOT NULL |
| payload_json | JSONB | |
| processing_status | VARCHAR(20) | received \| processed \| failed \| ignored |
| processing_error | TEXT | |
| processed_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | NOT NULL |

**UNIQUE:** (provider, provider_event_id)

**Index:** (created_at DESC)

---

## refunds

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| order_id | BIGINT | NOT NULL, FK orders(id) ON DELETE RESTRICT |
| payment_id | BIGINT | FK payments(id) ON DELETE SET NULL |
| amount_minor | BIGINT | NOT NULL, > 0 |
| currency | CHAR(3) | NOT NULL |
| reason | TEXT | |
| provider_refund_id | VARCHAR(255) | |
| status | VARCHAR(20) | pending \| succeeded \| failed |
| created_by_user_id | BIGINT | FK users(id) ON DELETE SET NULL |
| created_at | TIMESTAMPTZ | NOT NULL |

**Index:** (order_id)

---

## order_events

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| order_id | BIGINT | NOT NULL, FK orders(id) ON DELETE CASCADE |
| event_type | VARCHAR(64) | NOT NULL |
| actor_user_id | BIGINT | FK users(id) ON DELETE SET NULL |
| payload | JSONB | NOT NULL, default {} |
| created_at | TIMESTAMPTZ | NOT NULL |

**Index:** (order_id, created_at DESC)

**Triggers:** UPDATE/DELETE forbidden (append-only)

---

## transport_requests

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| order_id | BIGINT | NOT NULL, UNIQUE, FK orders(id) ON DELETE RESTRICT |
| direction | VARCHAR(20) | to_event \| from_event \| both |
| pickup_note | TEXT | |
| pickup_lat | DOUBLE PRECISION | |
| pickup_lng | DOUBLE PRECISION | |
| contact_phone | VARCHAR(32) | NOT NULL |
| status | VARCHAR(20) | requested \| assigned \| completed \| cancelled |
| internal_notes | TEXT | |
| created_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

---

## transport_groups

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| public_id | UUID | NOT NULL, UNIQUE |
| event_id | BIGINT | NOT NULL, FK events(id) ON DELETE CASCADE |
| label | VARCHAR(120) | NOT NULL |
| pickup_landmark | TEXT | |
| scheduled_pickup_at | TIMESTAMPTZ | |
| vehicle_description | VARCHAR(255) | |
| driver_phone | VARCHAR(32) | |
| status | VARCHAR(20) | planned \| dispatched \| completed \| cancelled |
| created_at | TIMESTAMPTZ | NOT NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, trigger |

**Index:** (event_id)

---

## transport_assignments

| Column | Type | Constraints / notes |
|--------|------|---------------------|
| id | BIGSERIAL | PK |
| transport_request_id | BIGINT | NOT NULL, UNIQUE, FK transport_requests(id) ON DELETE CASCADE |
| transport_group_id | BIGINT | NOT NULL, FK transport_groups(id) ON DELETE CASCADE |
| assigned_at | TIMESTAMPTZ | NOT NULL |
| assigned_by_user_id | BIGINT | FK users(id) ON DELETE SET NULL |

**Index:** (transport_group_id)

---

## Functions and triggers (001)

| Name | Purpose |
|------|---------|
| public.app_set_updated_at() | Sets updated_at on UPDATE |
| public.app_prevent_order_events_mutation() | Blocks UPDATE/DELETE on order_events |
| tr_*_updated_at | Attached to tables with updated_at |

**Extensions:** pgcrypto, citext
