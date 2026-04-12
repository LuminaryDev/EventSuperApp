import { sql } from "drizzle-orm";
import type { ExtractTablesWithRelations } from "drizzle-orm";
import type { PgTransaction } from "drizzle-orm/pg-core";
import type { PostgresJsQueryResultHKT } from "drizzle-orm/postgres-js";
import * as schema from "./schema";
import { db } from "./client";

type Schema = typeof schema;
type Relations = ExtractTablesWithRelations<Schema>;
export type AppTransaction = PgTransaction<
	PostgresJsQueryResultHKT,
	Schema,
	Relations
>;

function assertInternalUserId(userId: bigint): string {
	const s = userId.toString();
	if (!/^\d+$/.test(s) || userId < BigInt(1)) {
		throw new TypeError("userId must be a positive internal users.id (bigint)");
	}
	return s;
}

/**
 * Runs `fn` inside one DB transaction with `SET LOCAL app.user_id` so RLS policies
 * using `app.session_user_id()` apply. Use one transaction per HTTP request.
 */
export async function withSessionUser<T>(
	userId: bigint,
	fn: (tx: AppTransaction) => Promise<T>,
): Promise<T> {
	const id = assertInternalUserId(userId);
	return db.transaction(async (tx) => {
		await tx.execute(
			sql`select set_config('app.user_id', ${id}, true)`,
		);
		return fn(tx as AppTransaction);
	});
}
