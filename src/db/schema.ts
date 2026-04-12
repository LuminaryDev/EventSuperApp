import { pgTable, index, bigserial, varchar, jsonb, text, timestamp, pgPolicy, check, uuid, foreignKey, bigint, char, doublePrecision, integer, boolean, inet, uniqueIndex, customType } from "drizzle-orm/pg-core"
import { sql } from "drizzle-orm"

/** PostgreSQL `citext` (case-insensitive text); enable `CREATE EXTENSION IF NOT EXISTS citext` in migrations. */
const citext = customType<{ data: string }>({
	dataType() {
		return "citext"
	},
})

/** PostgreSQL `bytea` binary column; `postgres` driver uses `Uint8Array` (Node `Buffer` is accepted on insert). */
const bytea = customType<{ data: Uint8Array }>({
	dataType() {
		return "bytea"
	},
})

export const paymentWebhookEvents = pgTable("payment_webhook_events", {
	id: bigserial({ mode: "bigint" }).notNull(),
	provider: varchar({ length: 50 }).notNull(),
	providerEventId: varchar("provider_event_id", { length: 255 }).notNull(),
	payloadDigest: varchar("payload_digest", { length: 64 }).notNull(),
	payloadJson: jsonb("payload_json"),
	processingStatus: varchar("processing_status", { length: 20 }).notNull(),
	processingError: text("processing_error"),
	processedAt: timestamp("processed_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).notNull(),
}, (table) => [
	index("idx_webhook_events_created").using("btree", table.createdAt.desc().nullsFirst().op("timestamptz_ops")),
]);

export const users = pgTable("users", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	email: citext("email"),
	phoneE164: varchar("phone_e164", { length: 32 }),
	passwordHash: text("password_hash"),
	displayName: varchar("display_name", { length: 200 }).default("O'Reilly").notNull(),
	status: varchar({ length: 20 }).default('active').notNull(),
	emailVerifiedAt: timestamp("email_verified_at", { withTimezone: true, mode: 'string' }),
	phoneVerifiedAt: timestamp("phone_verified_at", { withTimezone: true, mode: 'string' }),
	lastLoginAt: timestamp("last_login_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	deletedAt: timestamp("deleted_at", { withTimezone: true, mode: 'string' }),
}, (table) => [
	pgPolicy("users_update_self", { as: "permissive", for: "update", to: ["eventapp_web"], using: sql`(id = app.session_user_id())`, withCheck: sql`(id = app.session_user_id())`  }),
	pgPolicy("users_select_self", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("users_email_or_phone", sql`(email IS NOT NULL) OR (phone_e164 IS NOT NULL)`),
	check("users_status_check", sql`(status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying, 'deleted'::character varying])::text[])`),
]);

export const organizations = pgTable("organizations", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	name: varchar({ length: 255 }).notNull(),
	slug: varchar({ length: 100 }).notNull(),
	legalName: varchar("legal_name", { length: 255 }),
	taxId: varchar("tax_id", { length: 64 }),
	status: varchar({ length: 20 }).default('active').notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	pgPolicy("organizations_select_member", { as: "permissive", for: "select", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = organizations.id) AND (m.user_id = app.session_user_id()))))` }),
	check("organizations_status_check", sql`(status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])`),
]);

export const organizationMembers = pgTable("organization_members", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	organizationId: bigint("organization_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }).notNull(),
	role: varchar({ length: 20 }).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_org_members_org").using("btree", table.organizationId.asc().nullsLast().op("int8_ops")),
	index("idx_org_members_user").using("btree", table.userId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.organizationId],
			foreignColumns: [organizations.id],
			name: "organization_members_organization_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "organization_members_user_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("org_members_select_self", { as: "permissive", for: "select", to: ["eventapp_web"], using: sql`(user_id = app.session_user_id())` }),
	check("organization_members_role_check", sql`(role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])`),
]);

export const venues = pgTable("venues", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	organizationId: bigint("organization_id", { mode: "number" }),
	name: varchar({ length: 255 }).notNull(),
	line1: varchar({ length: 255 }),
	line2: varchar({ length: 255 }),
	city: varchar({ length: 120 }),
	region: varchar({ length: 120 }),
	postalCode: varchar("postal_code", { length: 32 }),
	country: char({ length: 2 }).default('ET').notNull(),
	latitude: doublePrecision(),
	longitude: doublePrecision(),
	timezone: varchar({ length: 64 }).default('Africa/Addis_Ababa').notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_venues_org").using("btree", table.organizationId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.organizationId],
			foreignColumns: [organizations.id],
			name: "venues_organization_id_fkey"
		}).onDelete("set null"),
	pgPolicy("venues_staff_update", { as: "permissive", for: "update", to: ["eventapp_web"], using: sql`((organization_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = venues.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))))`, withCheck: sql`((organization_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = venues.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))))`  }),
	pgPolicy("venues_staff_insert", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("venues_select_policy", { as: "permissive", for: "select", to: ["eventapp_web"] }),
]);

export const events = pgTable("events", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	organizationId: bigint("organization_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	venueId: bigint("venue_id", { mode: "number" }).notNull(),
	title: varchar({ length: 500 }).notNull(),
	slug: varchar({ length: 160 }).notNull(),
	description: text(),
	startsAt: timestamp("starts_at", { withTimezone: true, mode: 'string' }).notNull(),
	endsAt: timestamp("ends_at", { withTimezone: true, mode: 'string' }).notNull(),
	timezone: varchar({ length: 64 }).notNull(),
	status: varchar({ length: 20 }).default('draft').notNull(),
	publishedAt: timestamp("published_at", { withTimezone: true, mode: 'string' }),
	salesStartsAt: timestamp("sales_starts_at", { withTimezone: true, mode: 'string' }),
	salesEndsAt: timestamp("sales_ends_at", { withTimezone: true, mode: 'string' }),
	maxAttendees: integer("max_attendees"),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_events_org_status_starts").using("btree", table.organizationId.asc().nullsLast().op("int8_ops"), table.status.asc().nullsLast().op("int8_ops"), table.startsAt.asc().nullsLast().op("int8_ops")),
	index("idx_events_published_starts").using("btree", table.status.asc().nullsLast().op("text_ops"), table.startsAt.asc().nullsLast().op("text_ops")).where(sql`((status)::text = 'published'::text)`),
	foreignKey({
			columns: [table.organizationId],
			foreignColumns: [organizations.id],
			name: "events_organization_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.venueId],
			foreignColumns: [venues.id],
			name: "events_venue_id_fkey"
		}).onDelete("restrict"),
	pgPolicy("events_staff_delete", { as: "permissive", for: "delete", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = events.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])))))` }),
	pgPolicy("events_staff_update", { as: "permissive", for: "update", to: ["eventapp_web"] }),
	pgPolicy("events_staff_insert", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("events_select_policy", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("events_max_attendees_check", sql`(max_attendees IS NULL) OR (max_attendees > 0)`),
	check("events_status_check", sql`(status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'cancelled'::character varying, 'completed'::character varying])::text[])`),
	check("events_time_order", sql`ends_at > starts_at`),
]);

export const ticketTypes = pgTable("ticket_types", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }).notNull(),
	name: varchar({ length: 120 }).notNull(),
	description: text(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	priceAmountMinor: bigint("price_amount_minor", { mode: "number" }).notNull(),
	currency: char({ length: 3 }).default('ETB').notNull(),
	quantityTotal: integer("quantity_total").notNull(),
	quantitySold: integer("quantity_sold").default(0).notNull(),
	maxPerOrder: integer("max_per_order").default(10).notNull(),
	sortOrder: integer("sort_order").default(0).notNull(),
	active: boolean().default(true).notNull(),
	salesStartsAt: timestamp("sales_starts_at", { withTimezone: true, mode: 'string' }),
	salesEndsAt: timestamp("sales_ends_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_ticket_types_event").using("btree", table.eventId.asc().nullsLast().op("int8_ops"), table.active.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "ticket_types_event_id_fkey"
		}).onDelete("restrict"),
	pgPolicy("ticket_types_staff_manage", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = ticket_types.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))`, withCheck: sql`(EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = ticket_types.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))`  }),
	pgPolicy("ticket_types_select_policy", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("ticket_types_max_per_order_check", sql`max_per_order >= 1`),
	check("ticket_types_price_amount_minor_check", sql`price_amount_minor >= 0`),
	check("ticket_types_quantity_sold_check", sql`quantity_sold >= 0`),
	check("ticket_types_quantity_total_check", sql`quantity_total >= 0`),
	check("ticket_types_sold_vs_total", sql`quantity_sold <= quantity_total`),
]);

export const orders = pgTable("orders", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }).notNull(),
	status: varchar({ length: 30 }).default('pending_payment').notNull(),
	currency: char({ length: 3 }).default('ETB').notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	subtotalMinor: bigint("subtotal_minor", { mode: "number" }).default(0).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	feesMinor: bigint("fees_minor", { mode: "number" }).default(0).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	taxMinor: bigint("tax_minor", { mode: "number" }).default(0).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	discountMinor: bigint("discount_minor", { mode: "number" }).default(0).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	totalMinor: bigint("total_minor", { mode: "number" }).default(0).notNull(),
	idempotencyKey: varchar("idempotency_key", { length: 128 }).notNull(),
	placedAt: timestamp("placed_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	paidAt: timestamp("paid_at", { withTimezone: true, mode: 'string' }),
	cancelledAt: timestamp("cancelled_at", { withTimezone: true, mode: 'string' }),
	notes: text(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_orders_event_status").using("btree", table.eventId.asc().nullsLast().op("int8_ops"), table.status.asc().nullsLast().op("text_ops")),
	index("idx_orders_user_placed").using("btree", table.userId.asc().nullsLast().op("int8_ops"), table.placedAt.desc().nullsFirst().op("int8_ops")),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "orders_event_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "orders_user_id_fkey"
		}).onDelete("restrict"),
	pgPolicy("orders_update_own", { as: "permissive", for: "update", to: ["eventapp_web"], using: sql`(user_id = app.session_user_id())`, withCheck: sql`(user_id = app.session_user_id())`  }),
	pgPolicy("orders_insert_own", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("orders_select_own", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("orders_discount_minor_check", sql`discount_minor >= 0`),
	check("orders_fees_minor_check", sql`fees_minor >= 0`),
	check("orders_status_check", sql`(status)::text = ANY ((ARRAY['pending_payment'::character varying, 'paid'::character varying, 'cancelled'::character varying, 'refunded'::character varying, 'partially_refunded'::character varying])::text[])`),
	check("orders_subtotal_minor_check", sql`subtotal_minor >= 0`),
	check("orders_tax_minor_check", sql`tax_minor >= 0`),
	check("orders_total_minor_check", sql`total_minor >= 0`),
]);

export const orderItems = pgTable("order_items", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	orderId: bigint("order_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	ticketTypeId: bigint("ticket_type_id", { mode: "number" }).notNull(),
	quantity: integer().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	unitPriceMinor: bigint("unit_price_minor", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	lineTotalMinor: bigint("line_total_minor", { mode: "number" }).notNull(),
	currency: char({ length: 3 }).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_order_items_order").using("btree", table.orderId.asc().nullsLast().op("int8_ops")),
	index("idx_order_items_ticket_type").using("btree", table.ticketTypeId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.orderId],
			foreignColumns: [orders.id],
			name: "order_items_order_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.ticketTypeId],
			foreignColumns: [ticketTypes.id],
			name: "order_items_ticket_type_id_fkey"
		}).onDelete("restrict"),
	pgPolicy("order_items_update_own", { as: "permissive", for: "update", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_items.order_id) AND (o.user_id = app.session_user_id()))))`, withCheck: sql`(EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_items.order_id) AND (o.user_id = app.session_user_id()))))`  }),
	pgPolicy("order_items_insert_own", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("order_items_select_own", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("order_items_line_total_minor_check", sql`line_total_minor >= 0`),
	check("order_items_quantity_check", sql`quantity >= 1`),
	check("order_items_unit_price_minor_check", sql`unit_price_minor >= 0`),
]);

export const tickets = pgTable("tickets", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	orderItemId: bigint("order_item_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	ticketTypeId: bigint("ticket_type_id", { mode: "number" }).notNull(),
	holderName: varchar("holder_name", { length: 200 }),
	status: varchar({ length: 20 }).default('valid').notNull(),
	redemptionCodeHash: bytea("redemption_code_hash").notNull(),
	checkedInAt: timestamp("checked_in_at", { withTimezone: true, mode: 'string' }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	checkedInByUserId: bigint("checked_in_by_user_id", { mode: "number" }),
	voidedAt: timestamp("voided_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_tickets_event_status").using("btree", table.eventId.asc().nullsLast().op("text_ops"), table.status.asc().nullsLast().op("text_ops")),
	index("idx_tickets_order_item").using("btree", table.orderItemId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.checkedInByUserId],
			foreignColumns: [users.id],
			name: "tickets_checked_in_by_user_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "tickets_event_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.orderItemId],
			foreignColumns: [orderItems.id],
			name: "tickets_order_item_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.ticketTypeId],
			foreignColumns: [ticketTypes.id],
			name: "tickets_ticket_type_id_fkey"
		}).onDelete("restrict"),
	pgPolicy("tickets_staff_checkin", { as: "permissive", for: "update", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = tickets.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))`, withCheck: sql`(EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = tickets.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))`  }),
	pgPolicy("tickets_update_own", { as: "permissive", for: "update", to: ["eventapp_web"] }),
	pgPolicy("tickets_select_own", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("tickets_status_check", sql`(status)::text = ANY ((ARRAY['valid'::character varying, 'cancelled'::character varying, 'refunded'::character varying])::text[])`),
]);

export const payments = pgTable("payments", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	orderId: bigint("order_id", { mode: "number" }).notNull(),
	provider: varchar({ length: 50 }).notNull(),
	providerPaymentId: varchar("provider_payment_id", { length: 255 }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	amountMinor: bigint("amount_minor", { mode: "number" }).notNull(),
	currency: char({ length: 3 }).notNull(),
	status: varchar({ length: 20 }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	providerFeeMinor: bigint("provider_fee_minor", { mode: "number" }),
	rawMetadata: jsonb("raw_metadata"),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_payments_order").using("btree", table.orderId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.orderId],
			foreignColumns: [orders.id],
			name: "payments_order_id_fkey"
		}).onDelete("restrict"),
	pgPolicy("payments_select_own", { as: "permissive", for: "select", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = payments.order_id) AND (o.user_id = app.session_user_id()))))` }),
	check("payments_amount_minor_check", sql`amount_minor >= 0`),
	check("payments_provider_fee_minor_check", sql`(provider_fee_minor IS NULL) OR (provider_fee_minor >= 0)`),
	check("payments_status_check", sql`(status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'refunded'::character varying])::text[])`),
]);

export const refunds = pgTable("refunds", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	orderId: bigint("order_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	paymentId: bigint("payment_id", { mode: "number" }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	amountMinor: bigint("amount_minor", { mode: "number" }).notNull(),
	currency: char({ length: 3 }).notNull(),
	reason: text(),
	providerRefundId: varchar("provider_refund_id", { length: 255 }),
	status: varchar({ length: 20 }).default('pending').notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	createdByUserId: bigint("created_by_user_id", { mode: "number" }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_refunds_order").using("btree", table.orderId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.createdByUserId],
			foreignColumns: [users.id],
			name: "refunds_created_by_user_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.orderId],
			foreignColumns: [orders.id],
			name: "refunds_order_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.paymentId],
			foreignColumns: [payments.id],
			name: "refunds_payment_id_fkey"
		}).onDelete("set null"),
	pgPolicy("refunds_select_own", { as: "permissive", for: "select", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = refunds.order_id) AND (o.user_id = app.session_user_id()))))` }),
	check("refunds_amount_minor_check", sql`amount_minor > 0`),
	check("refunds_status_check", sql`(status)::text = ANY ((ARRAY['pending'::character varying, 'succeeded'::character varying, 'failed'::character varying])::text[])`),
]);

export const orderEvents = pgTable("order_events", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	orderId: bigint("order_id", { mode: "number" }).notNull(),
	eventType: varchar("event_type", { length: 64 }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	actorUserId: bigint("actor_user_id", { mode: "number" }),
	payload: jsonb().default({}).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_order_events_order_created").using("btree", table.orderId.asc().nullsLast().op("int8_ops"), table.createdAt.desc().nullsFirst().op("int8_ops")),
	foreignKey({
			columns: [table.actorUserId],
			foreignColumns: [users.id],
			name: "order_events_actor_user_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.orderId],
			foreignColumns: [orders.id],
			name: "order_events_order_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("order_events_insert_own", { as: "permissive", for: "insert", to: ["eventapp_web"], withCheck: sql`(EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_events.order_id) AND (o.user_id = app.session_user_id()))))`  }),
	pgPolicy("order_events_select_own", { as: "permissive", for: "select", to: ["eventapp_web"] }),
]);

export const transportRequests = pgTable("transport_requests", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	orderId: bigint("order_id", { mode: "number" }).notNull(),
	direction: varchar({ length: 20 }).notNull(),
	pickupNote: text("pickup_note"),
	pickupLat: doublePrecision("pickup_lat"),
	pickupLng: doublePrecision("pickup_lng"),
	contactPhone: varchar("contact_phone", { length: 32 }).notNull(),
	status: varchar({ length: 20 }).default('requested').notNull(),
	internalNotes: text("internal_notes"),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	foreignKey({
			columns: [table.orderId],
			foreignColumns: [orders.id],
			name: "transport_requests_order_id_fkey"
		}).onDelete("restrict"),
	pgPolicy("transport_req_update_own", { as: "permissive", for: "update", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = transport_requests.order_id) AND (o.user_id = app.session_user_id()))))`, withCheck: sql`(EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = transport_requests.order_id) AND (o.user_id = app.session_user_id()))))`  }),
	pgPolicy("transport_req_insert_own", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("transport_req_select_own", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("transport_requests_direction_check", sql`(direction)::text = ANY ((ARRAY['to_event'::character varying, 'from_event'::character varying, 'both'::character varying])::text[])`),
	check("transport_requests_status_check", sql`(status)::text = ANY ((ARRAY['requested'::character varying, 'assigned'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])`),
]);

export const transportGroups = pgTable("transport_groups", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }).notNull(),
	label: varchar({ length: 120 }).notNull(),
	pickupLandmark: text("pickup_landmark"),
	scheduledPickupAt: timestamp("scheduled_pickup_at", { withTimezone: true, mode: 'string' }),
	vehicleDescription: varchar("vehicle_description", { length: 255 }),
	driverPhone: varchar("driver_phone", { length: 32 }),
	status: varchar({ length: 20 }).default('planned').notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_transport_groups_event").using("btree", table.eventId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "transport_groups_event_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("transport_groups_staff_all", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = transport_groups.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))`, withCheck: sql`(EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = transport_groups.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))`  }),
	check("transport_groups_status_check", sql`(status)::text = ANY ((ARRAY['planned'::character varying, 'dispatched'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])`),
]);

export const transportAssignments = pgTable("transport_assignments", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	transportRequestId: bigint("transport_request_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	transportGroupId: bigint("transport_group_id", { mode: "number" }).notNull(),
	assignedAt: timestamp("assigned_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	assignedByUserId: bigint("assigned_by_user_id", { mode: "number" }),
}, (table) => [
	index("idx_transport_assignments_group").using("btree", table.transportGroupId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.assignedByUserId],
			foreignColumns: [users.id],
			name: "transport_assignments_assigned_by_user_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.transportGroupId],
			foreignColumns: [transportGroups.id],
			name: "transport_assignments_transport_group_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.transportRequestId],
			foreignColumns: [transportRequests.id],
			name: "transport_assignments_transport_request_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("transport_assign_staff_delete", { as: "permissive", for: "delete", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM ((transport_groups tg
     JOIN events e ON ((e.id = tg.event_id)))
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((tg.id = transport_assignments.transport_group_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))` }),
	pgPolicy("transport_assign_staff_update", { as: "permissive", for: "update", to: ["eventapp_web"] }),
	pgPolicy("transport_assign_staff_write", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("transport_assign_select", { as: "permissive", for: "select", to: ["eventapp_web"] }),
]);

export const auditAdminEvents = pgTable("audit_admin_events", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	actorUserId: bigint("actor_user_id", { mode: "number" }),
	action: varchar({ length: 120 }).notNull(),
	entityTable: varchar("entity_table", { length: 100 }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	entityId: bigint("entity_id", { mode: "number" }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	impersonatedUserId: bigint("impersonated_user_id", { mode: "number" }),
	ipAddress: inet("ip_address"),
	userAgent: varchar("user_agent", { length: 512 }),
	payload: jsonb().notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).notNull(),
}, (table) => [
	index("idx_audit_admin_actor").using("btree", table.actorUserId.asc().nullsLast().op("int8_ops"), table.createdAt.desc().nullsFirst().op("int8_ops")),
	index("idx_audit_admin_created").using("btree", table.createdAt.desc().nullsFirst().op("timestamptz_ops")),
	foreignKey({
			columns: [table.actorUserId],
			foreignColumns: [users.id],
			name: "audit_admin_events_actor_user_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.impersonatedUserId],
			foreignColumns: [users.id],
			name: "audit_admin_events_impersonated_user_id_fkey"
		}).onDelete("set null"),
]);

export const userSecurityTokens = pgTable("user_security_tokens", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }).notNull(),
	purpose: varchar({ length: 32 }).notNull(),
	tokenHash: bytea("token_hash").notNull(),
	expiresAt: timestamp("expires_at", { withTimezone: true, mode: 'string' }).notNull(),
	consumedAt: timestamp("consumed_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).notNull(),
}, (table) => [
	index("idx_user_security_tokens_expires").using("btree", table.expiresAt.asc().nullsLast().op("timestamptz_ops")),
	index("idx_user_security_tokens_user_purpose").using("btree", table.userId.asc().nullsLast().op("int8_ops"), table.purpose.asc().nullsLast().op("text_ops")),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "user_security_tokens_user_id_fkey"
		}).onDelete("cascade"),
]);

export const analyticsEvents = pgTable("analytics_events", {
	id: bigserial({ mode: "bigint" }).notNull(),
	occurredAt: timestamp("occurred_at", { withTimezone: true, mode: 'string' }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }),
	anonId: uuid("anon_id"),
	sessionId: uuid("session_id"),
	eventName: varchar("event_name", { length: 120 }).notNull(),
	properties: jsonb().notNull(),
}, (table) => [
	index("idx_analytics_name_time").using("btree", table.eventName.asc().nullsLast().op("timestamptz_ops"), table.occurredAt.desc().nullsFirst().op("timestamptz_ops")),
	index("idx_analytics_occurred").using("btree", table.occurredAt.desc().nullsFirst().op("timestamptz_ops")),
	index("idx_analytics_user_time").using("btree", table.userId.asc().nullsLast().op("int8_ops"), table.occurredAt.desc().nullsFirst().op("int8_ops")),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "analytics_events_user_id_fkey"
		}).onDelete("set null"),
]);

export const tags = pgTable("tags", {
	id: bigserial({ mode: "bigint" }).notNull(),
	slug: varchar({ length: 120 }).notNull(),
	name: varchar({ length: 160 }).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	pgPolicy("tags_select_all", { as: "permissive", for: "select", to: ["eventapp_web"], using: sql`true` }),
]);

export const eventTags = pgTable("event_tags", {
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	tagId: bigint("tag_id", { mode: "number" }).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_event_tags_tag").using("btree", table.tagId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "event_tags_event_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.tagId],
			foreignColumns: [tags.id],
			name: "event_tags_tag_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("event_tags_staff_write", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = event_tags.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))`, withCheck: sql`(EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = event_tags.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))`  }),
	pgPolicy("event_tags_select_visible", { as: "permissive", for: "select", to: ["eventapp_web"] }),
]);

export const promoCodes = pgTable("promo_codes", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	organizationId: bigint("organization_id", { mode: "number" }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }),
	code: citext("code").notNull(),
	discountKind: varchar("discount_kind", { length: 20 }).notNull(),
	percentBasisPoints: integer("percent_basis_points"),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	fixedAmountMinor: bigint("fixed_amount_minor", { mode: "number" }),
	currency: char({ length: 3 }).default('ETB').notNull(),
	maxRedemptions: integer("max_redemptions"),
	redemptionsCount: integer("redemptions_count").default(0).notNull(),
	perUserLimit: integer("per_user_limit").default(1).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	minOrderMinor: bigint("min_order_minor", { mode: "number" }).default(0).notNull(),
	startsAt: timestamp("starts_at", { withTimezone: true, mode: 'string' }),
	endsAt: timestamp("ends_at", { withTimezone: true, mode: 'string' }),
	active: boolean().default(true).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_promo_codes_active").using("btree", table.active.asc().nullsLast().op("timestamptz_ops"), table.startsAt.asc().nullsLast().op("bool_ops"), table.endsAt.asc().nullsLast().op("bool_ops")),
	index("idx_promo_codes_event").using("btree", table.eventId.asc().nullsLast().op("int8_ops")),
	index("idx_promo_codes_org").using("btree", table.organizationId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "promo_codes_event_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.organizationId],
			foreignColumns: [organizations.id],
			name: "promo_codes_organization_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("promo_staff_delete", { as: "permissive", for: "delete", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])) AND ((promo_codes.organization_id = m.organization_id) OR (EXISTS ( SELECT 1
           FROM events e
          WHERE ((e.id = promo_codes.event_id) AND (e.organization_id = m.organization_id))))))))` }),
	pgPolicy("promo_staff_update", { as: "permissive", for: "update", to: ["eventapp_web"] }),
	pgPolicy("promo_staff_write", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("promo_select_staff", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("promo_codes_discount_kind_check", sql`(discount_kind)::text = ANY ((ARRAY['percent_bp'::character varying, 'fixed_minor'::character varying])::text[])`),
	check("promo_codes_fixed_amount_minor_check", sql`(fixed_amount_minor IS NULL) OR (fixed_amount_minor >= 0)`),
	check("promo_codes_max_redemptions_check", sql`(max_redemptions IS NULL) OR (max_redemptions > 0)`),
	check("promo_codes_min_order_minor_check", sql`min_order_minor >= 0`),
	check("promo_codes_per_user_limit_check", sql`per_user_limit >= 1`),
	check("promo_codes_percent_basis_points_check", sql`(percent_basis_points IS NULL) OR ((percent_basis_points > 0) AND (percent_basis_points <= 10000))`),
	check("promo_codes_redemptions_count_check", sql`redemptions_count >= 0`),
	check("promo_discount_shape", sql`(((discount_kind)::text = 'percent_bp'::text) AND (percent_basis_points IS NOT NULL) AND (fixed_amount_minor IS NULL)) OR (((discount_kind)::text = 'fixed_minor'::text) AND (fixed_amount_minor IS NOT NULL) AND (percent_basis_points IS NULL))`),
	check("promo_event_requires_org", sql`(event_id IS NULL) OR (organization_id IS NOT NULL)`),
]);

export const orderPromoApplications = pgTable("order_promo_applications", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	orderId: bigint("order_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	promoCodeId: bigint("promo_code_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	discountMinor: bigint("discount_minor", { mode: "number" }).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_order_promo_order").using("btree", table.orderId.asc().nullsLast().op("int8_ops")),
	index("idx_order_promo_promo").using("btree", table.promoCodeId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.orderId],
			foreignColumns: [orders.id],
			name: "order_promo_applications_order_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.promoCodeId],
			foreignColumns: [promoCodes.id],
			name: "order_promo_applications_promo_code_id_fkey"
		}).onDelete("restrict"),
	pgPolicy("order_promo_insert_own", { as: "permissive", for: "insert", to: ["eventapp_web"], withCheck: sql`(EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_promo_applications.order_id) AND (o.user_id = app.session_user_id()))))`  }),
	pgPolicy("order_promo_staff_select", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	pgPolicy("order_promo_select_own", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("order_promo_applications_discount_minor_check", sql`discount_minor >= 0`),
]);

export const waitlistEntries = pgTable("waitlist_entries", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	ticketTypeId: bigint("ticket_type_id", { mode: "number" }),
	status: varchar({ length: 20 }).default('waiting').notNull(),
	positionHint: integer("position_hint"),
	offeredAt: timestamp("offered_at", { withTimezone: true, mode: 'string' }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	fulfilledOrderId: bigint("fulfilled_order_id", { mode: "number" }),
	notesInternal: text("notes_internal"),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_waitlist_event_status").using("btree", table.eventId.asc().nullsLast().op("int8_ops"), table.status.asc().nullsLast().op("text_ops")),
	uniqueIndex("waitlist_user_event_any_type").using("btree", table.userId.asc().nullsLast().op("int8_ops"), table.eventId.asc().nullsLast().op("int8_ops")).where(sql`(ticket_type_id IS NULL)`),
	uniqueIndex("waitlist_user_event_ticket_type").using("btree", table.userId.asc().nullsLast().op("int8_ops"), table.eventId.asc().nullsLast().op("int8_ops"), table.ticketTypeId.asc().nullsLast().op("int8_ops")).where(sql`(ticket_type_id IS NOT NULL)`),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "waitlist_entries_event_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.fulfilledOrderId],
			foreignColumns: [orders.id],
			name: "waitlist_entries_fulfilled_order_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.ticketTypeId],
			foreignColumns: [ticketTypes.id],
			name: "waitlist_entries_ticket_type_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "waitlist_entries_user_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("waitlist_delete_self", { as: "permissive", for: "delete", to: ["eventapp_web"], using: sql`(user_id = app.session_user_id())` }),
	pgPolicy("waitlist_update_self", { as: "permissive", for: "update", to: ["eventapp_web"] }),
	pgPolicy("waitlist_insert_self", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("waitlist_staff_select", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	pgPolicy("waitlist_select_self", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	pgPolicy("waitlist_staff_update", { as: "permissive", for: "update", to: ["eventapp_web"] }),
	check("waitlist_entries_status_check", sql`(status)::text = ANY ((ARRAY['waiting'::character varying, 'offered'::character varying, 'fulfilled'::character varying, 'expired'::character varying, 'cancelled'::character varying])::text[])`),
]);

export const organizerPayoutProfiles = pgTable("organizer_payout_profiles", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	organizationId: bigint("organization_id", { mode: "number" }).notNull(),
	payoutProvider: varchar("payout_provider", { length: 50 }).default('manual').notNull(),
	providerAccountId: varchar("provider_account_id", { length: 255 }),
	defaultCurrency: char("default_currency", { length: 3 }).default('ETB').notNull(),
	payoutMetadata: jsonb("payout_metadata").default({}).notNull(),
	verifiedAt: timestamp("verified_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	foreignKey({
			columns: [table.organizationId],
			foreignColumns: [organizations.id],
			name: "organizer_payout_profiles_organization_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("payout_profile_write_admin", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = organizer_payout_profiles.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])))))`, withCheck: sql`(EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = organizer_payout_profiles.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])))))`  }),
	pgPolicy("payout_profile_select_admin", { as: "permissive", for: "select", to: ["eventapp_web"] }),
]);

export const payoutBatches = pgTable("payout_batches", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	organizationId: bigint("organization_id", { mode: "number" }).notNull(),
	periodStart: timestamp("period_start", { withTimezone: true, mode: 'string' }).notNull(),
	periodEnd: timestamp("period_end", { withTimezone: true, mode: 'string' }).notNull(),
	status: varchar({ length: 20 }).default('draft').notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	grossMinor: bigint("gross_minor", { mode: "number" }).default(0).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	platformFeeMinor: bigint("platform_fee_minor", { mode: "number" }).default(0).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	netToOrgMinor: bigint("net_to_org_minor", { mode: "number" }).default(0).notNull(),
	currency: char({ length: 3 }).default('ETB').notNull(),
	providerPayoutId: varchar("provider_payout_id", { length: 255 }),
	notes: text(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_payout_batches_org").using("btree", table.organizationId.asc().nullsLast().op("int8_ops"), table.status.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.organizationId],
			foreignColumns: [organizations.id],
			name: "payout_batches_organization_id_fkey"
		}).onDelete("restrict"),
	pgPolicy("payout_batches_admin", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = payout_batches.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])))))`, withCheck: sql`(EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = payout_batches.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])))))`  }),
	check("payout_batch_period", sql`period_end > period_start`),
	check("payout_batches_gross_minor_check", sql`gross_minor >= 0`),
	check("payout_batches_net_to_org_minor_check", sql`net_to_org_minor >= 0`),
	check("payout_batches_platform_fee_minor_check", sql`platform_fee_minor >= 0`),
	check("payout_batches_status_check", sql`(status)::text = ANY ((ARRAY['draft'::character varying, 'submitted'::character varying, 'processing'::character varying, 'paid'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[])`),
]);

export const payoutBatchItems = pgTable("payout_batch_items", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	payoutBatchId: bigint("payout_batch_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	orderId: bigint("order_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	grossMinor: bigint("gross_minor", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	platformFeeMinor: bigint("platform_fee_minor", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	netToOrgMinor: bigint("net_to_org_minor", { mode: "number" }).notNull(),
	currency: char({ length: 3 }).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_payout_batch_items_order").using("btree", table.orderId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.orderId],
			foreignColumns: [orders.id],
			name: "payout_batch_items_order_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.payoutBatchId],
			foreignColumns: [payoutBatches.id],
			name: "payout_batch_items_payout_batch_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("payout_items_admin_delete", { as: "permissive", for: "delete", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM (payout_batches pb
     JOIN organization_members m ON ((m.organization_id = pb.organization_id)))
  WHERE ((pb.id = payout_batch_items.payout_batch_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])))))` }),
	pgPolicy("payout_items_admin_update", { as: "permissive", for: "update", to: ["eventapp_web"] }),
	pgPolicy("payout_items_admin_write", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("payout_items_admin_select", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("payout_batch_items_gross_minor_check", sql`gross_minor >= 0`),
	check("payout_batch_items_net_to_org_minor_check", sql`net_to_org_minor >= 0`),
	check("payout_batch_items_platform_fee_minor_check", sql`platform_fee_minor >= 0`),
]);

export const notificationTemplates = pgTable("notification_templates", {
	id: bigserial({ mode: "bigint" }).notNull(),
	templateKey: varchar("template_key", { length: 100 }).notNull(),
	channel: varchar({ length: 20 }).notNull(),
	locale: varchar({ length: 10 }).default('en').notNull(),
	subjectTemplate: text("subject_template"),
	bodyTemplate: text("body_template").notNull(),
	active: boolean().default(true).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	pgPolicy("notification_templates_select", { as: "permissive", for: "select", to: ["eventapp_web"], using: sql`true` }),
]);

export const notificationJobs = pgTable("notification_jobs", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	templateId: bigint("template_id", { mode: "number" }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }),
	channel: varchar({ length: 20 }).notNull(),
	toAddress: text("to_address").notNull(),
	payload: jsonb().default({}).notNull(),
	status: varchar({ length: 20 }).default('pending').notNull(),
	attempts: integer().default(0).notNull(),
	nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true, mode: 'string' }),
	sentAt: timestamp("sent_at", { withTimezone: true, mode: 'string' }),
	lastError: text("last_error"),
	correlationId: uuid("correlation_id"),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_notification_jobs_status_next").using("btree", table.status.asc().nullsLast().op("text_ops"), table.nextAttemptAt.asc().nullsLast().op("text_ops")),
	index("idx_notification_jobs_user").using("btree", table.userId.asc().nullsLast().op("int8_ops"), table.createdAt.desc().nullsFirst().op("timestamptz_ops")),
	foreignKey({
			columns: [table.templateId],
			foreignColumns: [notificationTemplates.id],
			name: "notification_jobs_template_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "notification_jobs_user_id_fkey"
		}).onDelete("set null"),
	pgPolicy("notification_jobs_insert_own", { as: "permissive", for: "insert", to: ["eventapp_web"], withCheck: sql`(user_id = app.session_user_id())`  }),
	pgPolicy("notification_jobs_select_own", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("notification_jobs_attempts_check", sql`attempts >= 0`),
	check("notification_jobs_channel_check", sql`(channel)::text = ANY ((ARRAY['email'::character varying, 'sms'::character varying, 'push'::character varying, 'in_app'::character varying])::text[])`),
	check("notification_jobs_status_check", sql`(status)::text = ANY ((ARRAY['pending'::character varying, 'queued'::character varying, 'sending'::character varying, 'sent'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[])`),
]);

export const fileAssets = pgTable("file_assets", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	storageProvider: varchar("storage_provider", { length: 50 }).notNull(),
	bucket: varchar({ length: 255 }).notNull(),
	objectKey: text("object_key").notNull(),
	mimeType: varchar("mime_type", { length: 120 }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	byteSize: bigint("byte_size", { mode: "number" }).notNull(),
	checksumSha256: varchar("checksum_sha256", { length: 64 }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	uploadedByUserId: bigint("uploaded_by_user_id", { mode: "number" }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	organizationId: bigint("organization_id", { mode: "number" }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }),
	purpose: varchar({ length: 50 }).default('general').notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_file_assets_event").using("btree", table.eventId.asc().nullsLast().op("int8_ops")),
	index("idx_file_assets_org").using("btree", table.organizationId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "file_assets_event_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.organizationId],
			foreignColumns: [organizations.id],
			name: "file_assets_organization_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.uploadedByUserId],
			foreignColumns: [users.id],
			name: "file_assets_uploaded_by_user_id_fkey"
		}).onDelete("set null"),
	pgPolicy("file_assets_insert", { as: "permissive", for: "insert", to: ["eventapp_web"], withCheck: sql`((uploaded_by_user_id = app.session_user_id()) OR (EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = file_assets.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))) OR ((event_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = file_assets.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))))`  }),
	pgPolicy("file_assets_select", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("file_assets_byte_size_check", sql`byte_size >= 0`),
	check("file_assets_purpose_check", sql`(purpose)::text = ANY ((ARRAY['general'::character varying, 'event_cover'::character varying, 'event_gallery'::character varying, 'user_avatar'::character varying, 'org_logo'::character varying, 'export_archive'::character varying, 'other'::character varying])::text[])`),
]);

export const featureFlags = pgTable("feature_flags", {
	id: bigserial({ mode: "bigint" }).notNull(),
	flagKey: varchar("flag_key", { length: 100 }).notNull(),
	enabled: boolean().default(false).notNull(),
	rolloutPercent: integer("rollout_percent").default(0).notNull(),
	metadata: jsonb().default({}).notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	pgPolicy("feature_flags_select", { as: "permissive", for: "select", to: ["eventapp_web"], using: sql`true` }),
	check("feature_flags_rollout_percent_check", sql`(rollout_percent >= 0) AND (rollout_percent <= 100)`),
]);

export const dataSubjectExportRequests = pgTable("data_subject_export_requests", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }).notNull(),
	status: varchar({ length: 20 }).default('pending').notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	fileAssetId: bigint("file_asset_id", { mode: "number" }),
	requestedAt: timestamp("requested_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	readyAt: timestamp("ready_at", { withTimezone: true, mode: 'string' }),
	expiresAt: timestamp("expires_at", { withTimezone: true, mode: 'string' }),
	error: text(),
}, (table) => [
	index("idx_data_export_user").using("btree", table.userId.asc().nullsLast().op("int8_ops"), table.requestedAt.desc().nullsFirst().op("int8_ops")),
	foreignKey({
			columns: [table.fileAssetId],
			foreignColumns: [fileAssets.id],
			name: "data_subject_export_requests_file_asset_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "data_subject_export_requests_user_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("data_export_update_own", { as: "permissive", for: "update", to: ["eventapp_web"], using: sql`(user_id = app.session_user_id())`, withCheck: sql`(user_id = app.session_user_id())`  }),
	pgPolicy("data_export_insert_own", { as: "permissive", for: "insert", to: ["eventapp_web"] }),
	pgPolicy("data_export_select_own", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	check("data_subject_export_requests_status_check", sql`(status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'ready'::character varying, 'expired'::character varying, 'failed'::character varying])::text[])`),
]);

export const userEventFavorites = pgTable("user_event_favorites", {
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_favorites_event").using("btree", table.eventId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "user_event_favorites_event_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "user_event_favorites_user_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("favorites_all_own", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`(user_id = app.session_user_id())`, withCheck: sql`(user_id = app.session_user_id())`  }),
]);

export const cartSessions = pgTable("cart_sessions", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }),
	label: varchar({ length: 120 }),
	expiresAt: timestamp("expires_at", { withTimezone: true, mode: 'string' }).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_cart_sessions_expires").using("btree", table.expiresAt.asc().nullsLast().op("timestamptz_ops")),
	index("idx_cart_sessions_user").using("btree", table.userId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "cart_sessions_user_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("cart_session_own", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`((user_id = app.session_user_id()) AND (user_id IS NOT NULL))`, withCheck: sql`((user_id = app.session_user_id()) AND (user_id IS NOT NULL))`  }),
]);

export const cartLines = pgTable("cart_lines", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	cartId: bigint("cart_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	eventId: bigint("event_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	ticketTypeId: bigint("ticket_type_id", { mode: "number" }).notNull(),
	quantity: integer().notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_cart_lines_cart").using("btree", table.cartId.asc().nullsLast().op("int8_ops")),
	index("idx_cart_lines_event").using("btree", table.eventId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.cartId],
			foreignColumns: [cartSessions.id],
			name: "cart_lines_cart_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.eventId],
			foreignColumns: [events.id],
			name: "cart_lines_event_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.ticketTypeId],
			foreignColumns: [ticketTypes.id],
			name: "cart_lines_ticket_type_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("cart_lines_via_cart", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`(EXISTS ( SELECT 1
   FROM cart_sessions c
  WHERE ((c.id = cart_lines.cart_id) AND (c.user_id = app.session_user_id()))))`, withCheck: sql`(EXISTS ( SELECT 1
   FROM cart_sessions c
  WHERE ((c.id = cart_lines.cart_id) AND (c.user_id = app.session_user_id()))))`  }),
	check("cart_lines_quantity_check", sql`quantity >= 1`),
]);

export const referralCodes = pgTable("referral_codes", {
	id: bigserial({ mode: "bigint" }).notNull(),
	publicId: uuid("public_id").defaultRandom().notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }).notNull(),
	code: citext("code").notNull(),
	maxUses: integer("max_uses"),
	usesCount: integer("uses_count").default(0).notNull(),
	active: boolean().default(true).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_referral_codes_user").using("btree", table.userId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "referral_codes_user_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("referral_codes_own", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`(user_id = app.session_user_id())`, withCheck: sql`(user_id = app.session_user_id())`  }),
	check("referral_codes_max_uses_check", sql`(max_uses IS NULL) OR (max_uses > 0)`),
	check("referral_codes_uses_count_check", sql`uses_count >= 0`),
]);

export const referralAttributions = pgTable("referral_attributions", {
	id: bigserial({ mode: "bigint" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	referralCodeId: bigint("referral_code_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	referredUserId: bigint("referred_user_id", { mode: "number" }).notNull(),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	firstOrderId: bigint("first_order_id", { mode: "number" }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_referral_attr_code").using("btree", table.referralCodeId.asc().nullsLast().op("int8_ops")),
	foreignKey({
			columns: [table.firstOrderId],
			foreignColumns: [orders.id],
			name: "referral_attributions_first_order_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.referralCodeId],
			foreignColumns: [referralCodes.id],
			name: "referral_attributions_referral_code_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.referredUserId],
			foreignColumns: [users.id],
			name: "referral_attributions_referred_user_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("referral_attr_insert_self", { as: "permissive", for: "insert", to: ["eventapp_web"], withCheck: sql`(referred_user_id = app.session_user_id())`  }),
	pgPolicy("referral_attr_select_referrer", { as: "permissive", for: "select", to: ["eventapp_web"] }),
	pgPolicy("referral_attr_select_referred", { as: "permissive", for: "select", to: ["eventapp_web"] }),
]);

export const userMarketingPreferences = pgTable("user_marketing_preferences", {
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	userId: bigint("user_id", { mode: "number" }).notNull(),
	emailOptIn: boolean("email_opt_in").default(false).notNull(),
	smsOptIn: boolean("sms_opt_in").default(false).notNull(),
	pushOptIn: boolean("push_opt_in").default(false).notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "user_marketing_preferences_user_id_fkey"
		}).onDelete("cascade"),
	pgPolicy("marketing_prefs_own", { as: "permissive", for: "all", to: ["eventapp_web"], using: sql`(user_id = app.session_user_id())`, withCheck: sql`(user_id = app.session_user_id())`  }),
]);
