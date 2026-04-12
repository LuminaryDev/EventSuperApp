# Event SuperApp (web)

Next.js app for the Event SuperApp ticketing stack. It talks to PostgreSQL through **Drizzle ORM** using the **`eventapp_web`** role (row-level security). SQL migrations in `database/migrations/` are the source of truth for the schema.

---

## What is already done in this repo

These pieces are in place so a teammate can reproduce the setup without redoing your local troubleshooting:

| Area | Status |
|------|--------|
| **Next.js 16** (App Router, TypeScript, Tailwind, `src/`, `@/*`) | Done |
| **Drizzle** + `postgres` driver, schema in `src/db/schema.ts` | Done |
| **DB client** (`DATABASE_URL_WEB`), **RLS helper** `withSessionUser()`, **worker** `getDbWorker()` | Done |
| **`drizzle.config.ts`** reads `DATABASE_URL_WEB` from `.env.local` (via `dotenv`) | Done |
| **`.env.example`** template; **`.gitignore`** allows committing `.env.example` while ignoring secrets | Done |
| **SQL migrations** `001`–`004` in `database/migrations/` (+ `how_to_apply.txt`) | Done |
| **Health check** — `GET /api/health` runs `SELECT NOW()` against the DB | Done |
| **Scripts** — `npm run dev`, `build`, `lint`, `typecheck`, `format`, `db:studio` | Done |

### What you still build later (not in this README’s “run the app” path)

- **Auth + sessions**, then call **`withSessionUser(bigintUserId, tx => …)`** on routes that rely on RLS as `eventapp_web`.
- **Product features** (events UI, checkout, payment webhooks using **`getDbWorker()`**, etc.).
- **Optional migrations** `003_platform_extensions.sql` and `004_platform_security.sql` if you want platform tables beyond the MVP core.

---

## Prerequisites (your friend’s machine)

1. **Node.js** 20 or 22 ([nodejs.org](https://nodejs.org/)) — LTS recommended.  
2. **npm** (comes with Node).  
3. **PostgreSQL** 14 or newer, listening on the default port **5432** (or adjust the URL in `.env.local`).  
4. **Git**.  
5. **`psql`** (often installed with PostgreSQL) to apply SQL files.

**Windows tips (avoid common pain):**

- Keep the clone **outside OneDrive** (e.g. `C:\dev\eventsuperapp`) to avoid file-lock / permission issues.  
- If Postgres was installed on a non-default port, use that port in `DATABASE_URL_*`, or change `postgresql.conf` and restart the service.  
- Ensure the Windows service for PostgreSQL is **running** before `npm run dev`.

---

## First-time setup (clone → run)

### 1. Clone and install dependencies

```bash
git clone <YOUR_REPO_URL> eventsuperapp
cd eventsuperapp
npm install
```

### 2. Create the database

Connect as a superuser (often `postgres`) and create the database:

```sql
CREATE DATABASE event_superapp;
```

Example one-liner from a shell (adjust user/host if needed):

```bash
psql -U postgres -h localhost -c "CREATE DATABASE event_superapp;"
```

### 3. Apply MVP migrations (001 then 002)

From the **repository root** (paths are relative to this folder):

**macOS / Linux / Git Bash**

```bash
psql -U postgres -d event_superapp -v ON_ERROR_STOP=1 -f database/migrations/001_initial_schema.sql
psql -U postgres -d event_superapp -v ON_ERROR_STOP=1 -f database/migrations/002_security_grants_rls.sql
```

**Windows PowerShell** (if `psql` is on your PATH)

```powershell
psql -U postgres -d event_superapp -v ON_ERROR_STOP=1 -f database/migrations/001_initial_schema.sql
psql -U postgres -d event_superapp -v ON_ERROR_STOP=1 -f database/migrations/002_security_grants_rls.sql
```

If `psql` is not on PATH, use the full path to `psql.exe` under your PostgreSQL `bin` directory.

**MVP only:** you can stop after `002`. Optional platform pack: run `003` then `004` (see `database/how_to_apply.txt`).

### 4. Set passwords for app roles

Migration `002` creates **`eventapp_web`** and **`eventapp_worker`** but does not store passwords in the repo. Set them as a superuser:

```sql
ALTER ROLE eventapp_web PASSWORD 'choose-a-strong-secret';
ALTER ROLE eventapp_worker PASSWORD 'choose-a-different-strong-secret';
```

Use those secrets in the URLs in the next step.

### 5. Environment variables

```bash
cp .env.example .env.local
```

On Windows PowerShell:

```powershell
Copy-Item .env.example .env.local
```

Edit **`.env.local`** (this file is **gitignored** — never commit it):

| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_APP_URL` | Public site URL, e.g. `http://localhost:3000` |
| `DATABASE_URL_WEB` | `postgresql://eventapp_web:PASSWORD@HOST:5432/event_superapp` |
| `DATABASE_URL_WORKER` | `postgresql://eventapp_worker:PASSWORD@HOST:5432/event_superapp` |
| `TICKET_REDEMPTION_PEPPER` | Long random string (for future ticket-code hashing) |

Example shape (replace passwords and host if needed):

```env
NEXT_PUBLIC_APP_URL=http://localhost:3000
DATABASE_URL_WEB=postgresql://eventapp_web:YOUR_WEB_PASSWORD@localhost:5432/event_superapp
DATABASE_URL_WORKER=postgresql://eventapp_worker:YOUR_WORKER_PASSWORD@localhost:5432/event_superapp
TICKET_REDEMPTION_PEPPER=replace-with-a-long-random-string
```

### 6. Run the dev server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).  
Check the database link: [http://localhost:3000/api/health](http://localhost:3000/api/health) — you should see JSON like `{"status":"ok","time":"..."}`.

---

## Useful commands

| Command | Description |
|---------|-------------|
| `npm run dev` | Next.js dev server |
| `npm run build` | Production build |
| `npm run start` | Run production server (after `build`) |
| `npm run lint` | ESLint |
| `npm run typecheck` | TypeScript, no emit |
| `npm run format` | Prettier (write) |
| `npm run db:studio` | Drizzle Kit Studio (needs `DATABASE_URL_WEB` in `.env.local`) |

---

## Pushing to GitHub (checklist for you)

1. Create an empty repo on GitHub (no README/license if you already have them locally, or merge on first push).  
2. Confirm **`.env.local` is not tracked**: `git status` should not list it.  
3. Confirm **`.env.example` is tracked** (template for others).  
4. Add, commit, push:

   ```bash
   git init
   git add .
   git commit -m "Initial commit: Next.js + Drizzle + PostgreSQL migrations"
   git remote add origin <YOUR_REPO_URL>
   git branch -M main
   git push -u origin main
   ```

5. Optional: add a **`LICENSE`**, **branch protection**, and **GitHub Dependabot** when you are ready.

---

## Project layout (high level)

```text
database/migrations/   # SQL source of truth (apply with psql)
src/app/               # Next.js App Router (UI + route handlers)
src/db/                # Drizzle schema, db client, RLS + worker helpers
src/env/               # Server env helpers
drizzle/               # Drizzle Kit output / introspection artifacts (optional for teammates)
```

More detail on security roles and RLS: `database/how_to_apply.txt` and internal docs under `CheckList/Event SuperApp/docs/` if you keep that folder in the repo.

---

## Troubleshooting

| Problem | Things to check |
|---------|------------------|
| **`DATABASE_URL_WEB is not set`** | `.env.local` exists at repo root and contains `DATABASE_URL_WEB`. Restart `npm run dev` after editing. |
| **`password authentication failed`** | `ALTER ROLE` passwords match the URLs in `.env.local`. |
| **`connection refused`** | Postgres is running; host/port in the URL match (`5432` by default). |
| **`/api/health` 500** | Migrations applied; DB name is `event_superapp`; roles can connect. |
| **`drizzle-kit` / `db:studio` errors** | Same `DATABASE_URL_WEB` in `.env.local` (drizzle config loads it explicitly). |

---

## License

Private / unlicensed unless you add a `LICENSE` file.
