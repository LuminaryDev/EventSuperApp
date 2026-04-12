# Database model — diagrams, ORM mirroring, security (001–004)

Canonical SQL:

- Core MVP: `001_initial_schema.sql`, `002_security_grants_rls.sql`
- Platform extensions: `003_platform_extensions.sql`, `004_platform_security.sql` (optional)

Full column lists: `docs/DATABASE_FIELD_REFERENCE.md` + `docs/DATABASE_FIELD_REFERENCE_PLATFORM.md`.

---

## ORM choice (to mirror this schema in code)

| Tool | Best when | Mirroring |
|------|-----------|-----------|
| **Drizzle** + drizzle-kit | SQL files stay source of truth; TS close to Postgres | Hand-write `schema.ts` from the field references, or run **`drizzle-kit introspect`** on a DB with 001–004 applied, then tidy enums/types. |
| **Prisma** | You want Prisma Client and one `schema.prisma` | Apply migrations, then **`prisma db pull`**, or hand-write models and avoid drift. |
| **TypeORM** | NestJS + decorators | Entities per table; **`synchronize: false`**; align columns to the reference. |

**002 reminder:** ORMs map tables/columns only. **RLS and roles** (`eventapp_web`, `eventapp_worker`, `SET LOCAL app.user_id`) stay in how you connect and query.

---

## ER diagram (relationships)

```mermaid
erDiagram
  users ||--o{ organization_members : has
  organizations ||--o{ organization_members : includes
  organizations ||--o{ venues : owns_opt
  organizations ||--o{ events : owns
  venues ||--o{ events : hosts
  events ||--o{ ticket_types : offers
  users ||--o{ orders : places
  events ||--o{ orders : for
  orders ||--o{ order_items : lines
  ticket_types ||--o{ order_items : type
  order_items ||--o{ tickets : issues
  events ||--o{ tickets : at
  ticket_types ||--o{ tickets : kind
  orders ||--o{ payments : payment
  orders ||--o{ refunds : refund
  payments ||--o{ refunds : link
  users ||--o{ refunds : created_by
  orders ||--o{ order_events : audit
  users ||--o{ order_events : actor
  orders ||--o| transport_requests : opt
  events ||--o{ transport_groups : groups
  transport_requests ||--o| transport_assignments : slot
  transport_groups ||--o{ transport_assignments : contains
  users ||--o{ tickets : checked_in_by
  users ||--o{ transport_assignments : assigned_by
```

---

## Class-style view (entities as “classes”)

```mermaid
classDiagram
  class Users {
    +id PK
    +public_id UK
    email UK
    phone_e164 UK
    password_hash
    display_name
    status
    verifications
    timestamps
    deleted_at
  }
  class Organizations {
    +id PK
    +public_id UK
    name slug UK
    legal tax_id status
    timestamps
  }
  class OrganizationMembers {
    +id PK
    org_id FK
    user_id FK
    role
    created_at
  }
  class Venues {
    +id PK
    +public_id UK
    org_id FK
    address geo
    timezone
    timestamps
  }
  class Events {
    +id PK
    +public_id UK
    org_id FK
    venue_id FK
    title slug
    schedule timezone
    status sales_window
    max_attendees
    timestamps
  }
  class TicketTypes {
    +id PK
    +public_id UK
    event_id FK
    name price_minor
    inventory sold
    limits active
    timestamps
  }
  class Orders {
    +id PK
    +public_id UK
    user_id FK
    event_id FK
    status
    money fields
    idempotency_key UK
    timestamps
  }
  class OrderItems {
    +id PK
    order_id FK
    ticket_type_id FK
    qty prices
    created_at
  }
  class Tickets {
    +id PK
    +public_id UK
    order_item_id FK
    event_id FK
    ticket_type_id FK
    holder_name
    status
    redemption_code_hash UK
    checkin void
    created_at
  }
  class Payments {
    +id PK
    +public_id UK
    order_id FK
    provider ids
    amount status
    metadata
    timestamps
  }
  class PaymentWebhookEvents {
    +id PK
    provider event_id UK
    digest payload
    status error
    timestamps
  }
  class Refunds {
    +id PK
    +public_id UK
    order_id FK
    payment_id FK
    amount status
    created_by
    created_at
  }
  class OrderEvents {
    +id PK
    order_id FK
    event_type
    actor_user_id FK
    payload
    created_at
  }
  class TransportRequests {
    +id PK
    +public_id UK
    order_id FK UK
    direction pickup
    phone status
    internal_notes
    timestamps
  }
  class TransportGroups {
    +id PK
    +public_id UK
    event_id FK
    label landmark schedule
    vehicle driver
    status timestamps
  }
  class TransportAssignments {
    +id PK
    request_id FK UK
    group_id FK
    assigned_at
    assigned_by FK
  }
  Users --> OrganizationMembers
  Organizations --> OrganizationMembers
  Organizations --> Venues
  Organizations --> Events
  Venues --> Events
  Events --> TicketTypes
  Users --> Orders
  Events --> Orders
  Orders --> OrderItems
  TicketTypes --> OrderItems
  OrderItems --> Tickets
  Events --> Tickets
  TicketTypes --> Tickets
  Orders --> Payments
  Orders --> Refunds
  Payments --> Refunds
  Orders --> OrderEvents
  Orders --> TransportRequests
  Events --> TransportGroups
  TransportRequests --> TransportAssignments
  TransportGroups --> TransportAssignments
```

---

## Security objects (002 only — not extra tables)

| Object | Role |
|--------|------|
| Schema `app` | Namespace |
| `app.session_user_id()` | Reads GUC `app.user_id` for RLS |
| `eventapp_migrator` | Owns schema; migrations |
| `eventapp_web` | API pool; RLS; `SET LOCAL app.user_id` per txn |
| `eventapp_worker` | BYPASSRLS; webhooks + ticket insert + payments/refunds insert |
| Policies + FORCE RLS | All public tables per `002_security_grants_rls.sql` |
| Revokes | e.g. `payment_webhook_events` not for web; no web INSERT on `tickets`/`payments`/`refunds` |

---

## Platform ER extensions (003) — relationships

```mermaid
erDiagram
  events ||--o{ event_tags : tagged
  tags ||--o{ event_tags : used
  organizations ||--o{ promo_codes : owns
  events ||--o{ promo_codes : scoped
  promo_codes ||--o{ order_promo_applications : applied
  orders ||--o{ order_promo_applications : uses
  users ||--o{ waitlist_entries : joins
  events ||--o{ waitlist_entries : for
  ticket_types ||--o{ waitlist_entries : optional
  orders ||--o{ waitlist_entries : fulfilled
  organizations ||--o{ organizer_payout_profiles : profile
  organizations ||--o{ payout_batches : settlements
  payout_batches ||--o{ payout_batch_items : lines
  orders ||--o{ payout_batch_items : included
  notification_templates ||--o{ notification_jobs : template
  users ||--o{ notification_jobs : recipient
  users ||--o{ file_assets : uploaded
  organizations ||--o{ file_assets : org
  events ||--o{ file_assets : media
  file_assets ||--o{ data_subject_export_requests : archive
  users ||--o{ data_subject_export_requests : subject
  users ||--o{ analytics_events : tracked
  users ||--o{ user_event_favorites : saves
  events ||--o{ user_event_favorites : favorited
  users ||--o{ cart_sessions : owns
  cart_sessions ||--o{ cart_lines : lines
  events ||--o{ cart_lines : item
  ticket_types ||--o{ cart_lines : type
  users ||--o{ referral_codes : shares
  referral_codes ||--o{ referral_attributions : converts
  users ||--o{ referral_attributions : referred
  orders ||--o{ referral_attributions : first_order
  users ||--o{ user_security_tokens : challenges
  users ||--o{ user_marketing_preferences : prefs
```

**004** layers RLS + revokes on these tables (see `004_platform_security.sql`). Worker-only: `analytics_events`, `audit_admin_events`, `user_security_tokens`; template mutations; platform-wide promo validation path.

---

## MVP readiness and future extensions

**Core (001+002):** identity, org RBAC, venues/events, catalog, checkout orders, payments + webhook dedupe, refunds row, ticket rows (hash-only codes), audit stream, transport MVP + grouping.

**Platform (003+004):** discovery tags, promos, waitlist, organizer payout batches, notification templates + jobs, file metadata, feature flags, admin audit log, GDPR export requests, analytics sink, favorites, multi-event carts, referrals, auth token hashes, marketing consent.

**Still optional later:** seat maps, disputes/chargebacks, organizer SaaS subscriptions, dedicated platform-staff RBAC tables, advanced tax jurisdictions.

---

## Apply order

See `database/how_to_apply.txt`: **001 → 002** (required); **003 → 004** (optional platform).
