/**
 * Server-only env helpers. Do not import from Client Components.
 * Next.js loads `.env.local` automatically for the dev server and build.
 */

export function getTicketRedemptionPepper(): string {
	const v = process.env.TICKET_REDEMPTION_PEPPER?.trim();
	if (!v) {
		throw new Error(
			"TICKET_REDEMPTION_PEPPER is not set. Add a long random secret to .env.local (see .env.example).",
		);
	}
	return v;
}

export function getPublicAppUrl(): string {
	return (
		process.env.NEXT_PUBLIC_APP_URL?.trim() || "http://localhost:3000"
	);
}
