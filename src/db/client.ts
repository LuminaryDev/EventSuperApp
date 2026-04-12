import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

function requireEnvUrl(name: "DATABASE_URL_WEB"): string {
	const url = process.env[name];
	if (!url?.trim()) {
		throw new Error(
			`${name} is not set. Copy .env.example to .env.local and set database URLs.`,
		);
	}
	return url;
}

const sql = postgres(requireEnvUrl("DATABASE_URL_WEB"));

export const db = drizzle(sql, { schema });

export type AppDb = typeof db;
