# App environment setup — TypeScript stack

**New to all of this?** Start here first: [`docs/FULL_SETUP_GUIDE_FOR_BEGINNERS.md`](FULL_SETUP_GUIDE_FOR_BEGINNERS.md) — step-by-step from zero (Windows-friendly), explains every tool, migrations, `.env.local`, and common errors.

This page is the shorter **technical companion**: stack choices, Drizzle/Prisma, optional Nest/Fastify.

---

This guide matches the stack we aligned on: **TypeScript**, **Next.js** (web + API routes or BFF), **Node.js** API option (**NestJS** or **Fastify**), and **PostgreSQL** with your existing SQL migrations in `database/migrations/`.

Pick **one** API style to avoid duplication:

- **A — Next.js only:** Server Actions + Route Handlers (`app/api/...`) talking to the DB. Fastest to ship a single deployable.
- **B — Next.js + NestJS:** Next for UI/SEO; Nest for a dedicated REST API, queues, webhooks. Best when the backend will grow large teams or modules.
- **C — Next.js + Fastify:** Lighter than Nest; good if you want a small standalone service for webhooks and workers.

---

## 1. Machine prerequisites

Install:

- **Node.js** 20 LTS or 22 LTS ([nodejs.org](https://nodejs.org/))
- **pnpm** (recommended) or npm: `corepack enable` then `corepack prepare pnpm@latest --activate`
- **PostgreSQL** 14+ (local or Docker)
- **Git**

Optional:

- **Docker Desktop** (Windows) if you prefer containerized Postgres
- **psql** client (often bundled with PostgreSQL)

---

## 2. PostgreSQL database

1. Create a database, for example `event_superapp`.
2. Apply migrations in order:

   ```bash
   psql -U postgres -d event_superapp -v ON_ERROR_STOP=1 -f database/migrations/001_initial_schema.sql
   psql -U postgres -d event_superapp -v ON_ERROR_STOP=1 -f database/migrations/002_security_grants_rls.sql
   psql -U postgres -d event_superapp -v ON_ERROR_STOP=1 -f database/migrations/003_platform_extensions.sql
   psql -U postgres -d event_superapp -v ON_ERROR_STOP=1 -f database/migrations/004_platform_security.sql
   ```

   Omit `003` and `004` if you only want the core MVP schema (`001` + `002`). See `database/how_to_apply.txt`.

3. Set runtime role passwords (do not commit):

   ```sql
   ALTER ROLE eventapp_web PASSWORD '...';
   ALTER ROLE eventapp_worker PASSWORD '...';
   ```

4. Connection strings (example):

   - **API (RLS):** `postgresql://eventapp_web:SECRET@localhost:5432/event_superapp`
   - **Worker (webhooks / ticket issuance):** `postgresql://eventapp_worker:SECRET@localhost:5432/event_superapp`

5. **RLS:** For every HTTP request using `eventapp_web`, start the transaction with:

   ```sql
   SET LOCAL app.user_id = '<bigint internal user id>';
   ```

   Use a pool and **one transaction per request** so the setting never leaks across clients.

---

## 3. Monorepo layout (recommended)

```text
Event SuperApp/
  apps/
    web/                 # Next.js
    api/                 # optional: Nest or Fastify
  packages/
    db/                  # optional: Drizzle/Prisma client shared by web + api
    config/              # optional: eslint, tsconfig
  database/
    migrations/          # existing SQL (source of truth unless you switch to ORM migrations)
  docs/
```

If you start **single-app**, use a flat `src/` under one Next project and add `apps/api` only when needed.

---

## 4. Create the Next.js app

From the repo root (adjust app name/path):

```bash
pnpm create next-app@latest apps/web --typescript --eslint --tailwind --app --src-dir --import-alias "@/*"
cd apps/web
```

**Environment variables** (`.env.local` — never commit):

```env
# Public
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Server-only
DATABASE_URL_WEB=postgresql://eventapp_web:...@localhost:5432/event_superapp
DATABASE_URL_WORKER=postgresql://eventapp_worker:...@localhost:5432/event_superapp
TICKET_REDEMPTION_PEPPER=<long-random-secret>
```

Use `DATABASE_URL_WEB` for user-facing routes and `DATABASE_URL_WORKER` only inside secure server contexts (webhook handler, background job).

---

## 5. Database access from TypeScript

### Option A — Drizzle (SQL-first, mirrors 001 closely)

```bash
cd apps/web
pnpm add drizzle-orm postgres
pnpm add -D drizzle-kit
```

- Add `drizzle.config.ts` pointing at `DATABASE_URL_WEB`.
- Define tables in `src/db/schema.ts` to match `docs/DATABASE_ERD.md`, or introspect after applying 001+002.
- Run queries inside Route Handlers / Server Actions; for RLS, open a transaction, `SET LOCAL app.user_id`, then query.

### Option B — Prisma

```bash
cd apps/web
pnpm add prisma @prisma/client
pnpm exec prisma init
```

- Set `datasource.url` to `DATABASE_URL_WEB` for development.
- Either `prisma db pull` after migrations, or hand-write `schema.prisma`.
- For RLS, use `$executeRaw` in a transaction to set `app.user_id` before other calls, or use a Prisma middleware pattern with raw transaction control.

---

## 6. Optional: NestJS API (`apps/api`)

```bash
pnpm dlx @nestjs/cli new apps/api --package-manager pnpm
cd apps/api
pnpm add @nestjs/config
pnpm add drizzle-orm postgres
# or: pnpm add @prisma/client prisma
```

- Load `DATABASE_URL_WEB` / `DATABASE_URL_WORKER` from env.
- Implement modules: `Auth`, `Events`, `Orders`, `Payments` (webhook controller uses **worker** URL + no public exposure without auth).
- **Global validation:** `ValidationPipe` with `whitelist: true`.
- **Throttling** on public routes (e.g. `@nestjs/throttler`) especially check-in and login.

---

## 7. Optional: Fastify service

```bash
mkdir -p apps/api-fastify && cd apps/api-fastify
pnpm init
pnpm add fastify @fastify/env postgres drizzle-orm
```

- Single `server.ts`, register env plugin, one `pg` Pool per role (web vs worker).
- Mount `/webhooks/payments` with signature verification before DB writes.

---

## 8. Quality and safety baseline

- **TypeScript:** `"strict": true` in `tsconfig.json`.
- **Lint/format:** ESLint + Prettier (Next default is fine).
- **Secrets:** only in env / secret manager; never in SQL or client bundles.
- **Dependencies:** `pnpm audit` periodically; enable Dependabot if on GitHub.
- **Migrations:** keep applying `001`/`002` via `psql` until you explicitly move ownership to Drizzle Kit or Prisma Migrate; then avoid drifting.

---

## 9. Run locally

```bash
# Terminal 1 — Postgres running locally or Docker

# Terminal 2
cd apps/web
pnpm dev
```

Open `http://localhost:3000`.

---

## 10. What to build first (order)

1. Auth + session (map session → `users.id` for `SET LOCAL app.user_id`).
2. Published events list + detail (read-only).
3. Create pending `orders` + `order_items` (transaction + inventory lock on `ticket_types`).
4. Payment webhook worker path (`eventapp_worker`) → insert `payments`, flip `orders.status`, insert `tickets` with `redemption_code_hash`.
5. Organizer CRUD for events/ticket types (respect RLS staff policies).
6. Transport add-on on checkout (`transport_requests`).
7. Admin export: query transport + orders (staff role).

---

## Reference docs

- **Beginner full setup (start here if new):** `docs/FULL_SETUP_GUIDE_FOR_BEGINNERS.md`
- Diagrams + ORM mirroring: `docs/DATABASE_ERD.md`
- Every column (001): `docs/DATABASE_FIELD_REFERENCE.md`
- Platform tables (003): `docs/DATABASE_FIELD_REFERENCE_PLATFORM.md`
- Migration commands: `database/how_to_apply.txt`
