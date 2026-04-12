# Full setup guide (beginner-friendly)

This guide assumes you are **new** to most of this stack. It explains **what each thing is**, **why it exists**, and **exactly what to click or type** (with **Windows / PowerShell** in mind).

If your project folder name has a **space** (for example `Event SuperApp`), always put quotes around the path when you `cd`:

```powershell
cd "C:\Users\pc\OneDrive\Desktop\Test-Integration\Renewed\Event SuperApp"
```

---

## What you are building (plain English)

You are setting up:

1. **PostgreSQL** — the database that stores users, events, tickets, orders, etc.
2. **SQL migrations** — scripts that create all the tables safely and in order.
3. **Node.js** — the runtime that runs your JavaScript/TypeScript on your computer (and later on a server).
4. **pnpm** — a **package manager**: it downloads libraries (like `next`) and runs scripts (`pnpm dev`).
5. **Next.js** — a **web framework** on top of **React**. It gives you pages, routing, and a way to run **server-side code** (API routes, database access) without exposing secrets to the browser.

You do **not** need to understand everything on day one. Follow the steps in order.

---

## Tiny glossary (read once, refer back later)

| Term | Simple meaning |
|------|----------------|
| **Terminal / shell** | A text window where you type commands. On Windows you can use **PowerShell** or **Command Prompt**. |
| **Command** | Something you type and press Enter, for example `node -v`. |
| **Repository (repo)** | Your project folder + its history if you use Git. |
| **Package** | A reusable library published on the internet (for example `next`). |
| **Dependency** | A package your app needs to run. |
| **`pnpm install`** | Downloads dependencies listed in `package.json` into a local folder. |
| **TypeScript** | JavaScript + types. Next.js projects usually use TypeScript (files end in `.ts` / `.tsx`). |
| **Environment variable** | A secret or setting stored outside your code (for example database password). Next.js reads server-only vars from `.env.local`. |
| **Migration** | A versioned change to the database schema (create tables, add columns). |
| **PostgreSQL role / user** | A database login. Your project uses special roles: `eventapp_web` and `eventapp_worker` (created by migration `002`). |
| **RLS (Row Level Security)** | Rules in PostgreSQL that hide rows a user should not see. Your API user `eventapp_web` needs `SET LOCAL app.user_id = ...` per request (you will wire this in code later). |

---

## Part A — Install tools on your PC

### A1. Git (optional but recommended)

**What it is:** tracks changes to your code (version control).

1. Download **Git for Windows** from [https://git-scm.com/download/win](https://git-scm.com/download/win).
2. Run the installer; keep default options unless you know you need something else.
3. Close and reopen your terminal.
4. Check:

   ```powershell
   git --version
   ```

   You should see a version number.

---

### A2. Node.js (required)

**What it is:** runs JavaScript on your machine. **npm** comes with Node.

1. Open [https://nodejs.org](https://nodejs.org).
2. Download the **LTS** version (even number line, for example **22.x** or **20.x**).
3. Run the installer. Accept defaults that add Node to your **PATH**.
4. Close and reopen your terminal.
5. Check:

   ```powershell
   node -v
   npm -v
   ```

   Both should print versions (not errors).

---

### A3. pnpm (recommended package manager)

**What it is:** faster, stricter alternative to `npm`. Next.js docs often use `pnpm`.

Node includes **corepack**, which can install pnpm for you.

```powershell
corepack enable
corepack prepare pnpm@latest --activate
```

Check:

```powershell
pnpm -v
```

**If `corepack` fails:** install pnpm using npm instead:

```powershell
npm install -g pnpm
pnpm -v
```

---

### A4. PostgreSQL (required)

**What it is:** your real database server.

#### Option 1 — Installer (simplest on Windows)

1. Download PostgreSQL for Windows from [https://www.postgresql.org/download/windows/](https://www.postgresql.org/download/windows/) (use the EnterpriseDB installer if offered).
2. During setup, remember the password you set for the **`postgres`** superuser. You will need it.
3. Keep the default port **5432** unless you know you must change it.
4. Finish the install.

**`psql` not found?** `psql` is the command-line SQL client. It lives in the PostgreSQL `bin` folder, often:

`C:\Program Files\PostgreSQL\16\bin`

Add that folder to your **PATH** (Windows: search “Environment Variables” → edit **Path** → add the `bin` folder), then open a **new** terminal and try:

```powershell
psql --version
```

#### Option 2 — Docker (if you already use Docker Desktop)

If you use Docker, you can run Postgres in a container instead of installing it. That is an advanced path; the installer above is easier for most beginners.

---

## Part B — Create the empty database

**What you are doing:** making a named database (like an empty filing cabinet) that migrations will fill with tables.

### B1. Open PowerShell in your project folder

```powershell
cd "C:\Users\pc\OneDrive\Desktop\Test-Integration\Renewed\Event SuperApp"
```

(Adjust the path if yours is different.)

### B2. Connect as the `postgres` user and create a database

Run (you will be asked for the **`postgres` password** you chose during install):

```powershell
psql -U postgres -h localhost -p 5432
```

Inside `psql`, run:

```sql
CREATE DATABASE event_superapp;
\q
```

**If `CREATE DATABASE` says it already exists:** that is fine. You can keep using it.

---

## Part C — Run the SQL migrations (create all tables)

**What you are doing:** executing the files in `database/migrations/` in order. They create extensions, tables, security roles, and (if you use them) platform extras.

From your **project root** (same folder that contains `database\migrations`), run:

### C1. Core (required): 001 + 002

```powershell
psql -U postgres -h localhost -d event_superapp -v ON_ERROR_STOP=1 -f "database/migrations/001_initial_schema.sql"
psql -U postgres -h localhost -d event_superapp -v ON_ERROR_STOP=1 -f "database/migrations/002_security_grants_rls.sql"
```

- **`-v ON_ERROR_STOP=1`** means “stop if something fails” (good).

### C2. Platform extras (optional): 003 + 004

Only run these if you want the extended “mega-platform” tables (promos, waitlist, payouts, etc.):

```powershell
psql -U postgres -h localhost -d event_superapp -v ON_ERROR_STOP=1 -f "database/migrations/003_platform_extensions.sql"
psql -U postgres -h localhost -d event_superapp -v ON_ERROR_STOP=1 -f "database/migrations/004_platform_security.sql"
```

**If a file fails:** read the error text. Common issues:

- Wrong folder (run `dir database\migrations` and confirm files exist).
- Wrong database name (`-d` must match what you created).
- Old PostgreSQL version (use 14+).

More detail: `database/how_to_apply.txt`.

---

## Part D — Set passwords for the app database users

Migrations created two login roles:

- **`eventapp_web`** — your normal API (with RLS).
- **`eventapp_worker`** — trusted jobs (webhooks, issuing tickets after payment, analytics ingest, etc.).

**You must set passwords yourself** (never commit passwords to Git).

Connect:

```powershell
psql -U postgres -h localhost -d event_superapp
```

Run (replace the passwords with long random strings you save in a password manager):

```sql
ALTER ROLE eventapp_web PASSWORD 'choose-a-strong-password-1';
ALTER ROLE eventapp_worker PASSWORD 'choose-a-strong-password-2';
\q
```

**Connection strings** (you will paste these into `.env.local` later):

```text
postgresql://eventapp_web:choose-a-strong-password-1@localhost:5432/event_superapp
postgresql://eventapp_worker:choose-a-strong-password-2@localhost:5432/event_superapp
```

**Special characters in passwords?** They must be **URL-encoded** inside connection strings. Easiest beginner fix: use passwords with **letters and numbers only** until you are comfortable encoding.

---

## Part E — Create the Next.js app inside this repo

**What you are doing:** scaffolding a real web project under `apps/web`.

### E1. From the project root

```powershell
cd "C:\Users\pc\OneDrive\Desktop\Test-Integration\Renewed\Event SuperApp"
```

### E2. Create the `apps` folder (if it does not exist)

```powershell
mkdir apps -ErrorAction SilentlyContinue
```

### E3. Scaffold Next.js

This command is **interactive** by default. If it asks questions, choose:

- TypeScript: **Yes**
- ESLint: **Yes**
- Tailwind CSS: **Yes**
- `src/` directory: **Yes**
- App Router: **Yes**
- Turbopack: **Yes** (optional; either is fine)
- Import alias `@/*`: **Yes**

Non-interactive equivalent (if your `create-next-app` supports these flags):

```powershell
pnpm create next-app@latest apps/web --typescript --eslint --tailwind --app --src-dir --import-alias "@/*"
```

### E4. Install dependencies and start the dev server

```powershell
cd apps\web
pnpm install
pnpm dev
```

Open a browser to [http://localhost:3000](http://localhost:3000). You should see the Next.js welcome page.

**Port already in use?** Stop the other app using port 3000, or run:

```powershell
pnpm dev -- -p 3001
```

Then open `http://localhost:3001`.

---

## Part F — Environment variables (`.env.local`)

**What this is:** a file Next.js reads **on your machine only**. It is **not** sent to the browser automatically (unless the variable name starts with `NEXT_PUBLIC_`).

### F1. Create the file

In `apps/web`, create a file named **`.env.local`** (same folder as `package.json`).

### F2. Paste and edit

```env
NEXT_PUBLIC_APP_URL=http://localhost:3000

DATABASE_URL_WEB=postgresql://eventapp_web:YOUR_WEB_PASSWORD@localhost:5432/event_superapp
DATABASE_URL_WORKER=postgresql://eventapp_worker:YOUR_WORKER_PASSWORD@localhost:5432/event_superapp

TICKET_REDEMPTION_PEPPER=paste-a-long-random-string-here-at-least-32-chars
```

**Line by line:**

- **`NEXT_PUBLIC_APP_URL`** — your site URL for links (safe to expose to the browser).
- **`DATABASE_URL_WEB`** — API pool user; respects RLS when you set `app.user_id` in a transaction (you will add this in code when you connect the DB).
- **`DATABASE_URL_WORKER`** — only use in **server** code paths you fully trust (webhooks, background jobs). Never call this from browser JavaScript.
- **`TICKET_REDEMPTION_PEPPER`** — secret used when hashing ticket codes (must stay server-only).

### F3. Make sure Git ignores secrets

Your Next.js template usually includes `.gitignore` with `.env*.local`. **Never commit** `.env.local`.

---

## Part G — Connect the database from code (next learning step)

You **do not** have to finish this on day one, but this is the intended path:

1. Pick **Drizzle** or **Prisma** (see `docs/APP_ENVIRONMENT_SETUP.md` section 5).
2. Run queries only in **server** code: Route Handlers (`app/api/.../route.ts`) or Server Actions — **not** in plain React components that run in the browser.

**RLS reminder:** when using `eventapp_web`, your server should run:

```sql
SET LOCAL app.user_id = '<internal bigint user id>';
```

inside the **same transaction** as your queries.

---

## Part H — “Did I mess something up?” (common problems)

| Symptom | What to try |
|---------|-------------|
| `psql` is not recognized | PostgreSQL `bin` is not on PATH; add it and open a new terminal. |
| Password authentication failed | Wrong `-U` user or wrong password; try `-U postgres` first. |
| `FATAL: database "event_superapp" does not exist` | Create it (`CREATE DATABASE event_superapp;`). |
| Migration errors about `EXECUTE PROCEDURE` | Use PostgreSQL **14+** (13 can differ for triggers). |
| `pnpm` is not recognized | Run `corepack enable` or reinstall pnpm globally. |
| `EADDRINUSE` on port 3000 | Another app uses the port; change port or stop the other app. |
| Blank page / build errors after edits | Read the terminal stack trace; fix the file path shown at the top. |

---

## Part I — Where everything lives in this repo

```text
Event SuperApp/
  database/
    migrations/          ← SQL you already have (001–004)
    how_to_apply.txt     ← short migration reminder
  docs/
    FULL_SETUP_GUIDE_FOR_BEGINNERS.md   ← this file
    APP_ENVIRONMENT_SETUP.md            ← shorter “pro” stack notes + Drizzle/Prisma/Nest
    DATABASE_ERD.md                     ← diagrams
    DATABASE_FIELD_REFERENCE.md         ← every column (core)
    DATABASE_FIELD_REFERENCE_PLATFORM.md← every column (003)
  apps/
    web/                 ← you create this with create-next-app
```

---

## Part J — What to do after setup

1. Confirm **Postgres** is running (installer usually starts a Windows service automatically).
2. Confirm migrations applied (**001** and **002** at minimum).
3. Confirm **Next.js** runs (`pnpm dev`).
4. Read **`docs/APP_ENVIRONMENT_SETUP.md`** section **10** for the suggested build order (auth → events → checkout → webhooks → …).

When you are ready to add Drizzle or Prisma, use **`docs/APP_ENVIRONMENT_SETUP.md`** as the technical companion to this beginner guide.

---

## One-sentence cheat sheet

**Install Node + pnpm + Postgres → create DB → run SQL migrations → set role passwords → scaffold Next.js → add `.env.local` → `pnpm dev`.**
