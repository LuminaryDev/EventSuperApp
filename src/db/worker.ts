import { drizzle, type PostgresJsDatabase } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

let workerSql: ReturnType<typeof postgres> | undefined;
let workerDb: PostgresJsDatabase<typeof schema> | undefined;

/**
 * Lazy `eventapp_worker` pool (BYPASSRLS). Use only in trusted server paths:
 * webhooks, background jobs, signup/bootstrap — never from browser code.
 */
export function getDbWorker() {
	if (!workerDb) {
		const url = process.env.DATABASE_URL_WORKER?.trim();
		if (!url) {
			throw new Error(
				"DATABASE_URL_WORKER is not set. Required for worker-only database access.",
			);
		}
		workerSql = postgres(url);
		workerDb = drizzle(workerSql, { schema });
	}
	return workerDb;
}
