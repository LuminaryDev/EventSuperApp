import { config as loadEnv } from "dotenv";
import { defineConfig } from "drizzle-kit";

// drizzle-kit runs outside Next.js — load the same vars developers use locally
loadEnv({ path: ".env.local" });
loadEnv();

const url = process.env.DATABASE_URL_WEB;
if (!url?.trim()) {
	throw new Error(
		"DATABASE_URL_WEB is not set. Add it to .env.local (see .env.example).",
	);
}

export default defineConfig({
	schema: "./src/db/schema.ts",
	out: "./drizzle",
	dialect: "postgresql",
	dbCredentials: {
		url,
	},
});