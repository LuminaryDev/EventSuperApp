-- Current sql file was generated after introspecting the database
-- If you want to run this migration please uncomment this code before executing migrations
/*
CREATE TABLE "payment_webhook_events" (
	"id" bigserial NOT NULL,
	"provider" varchar(50) NOT NULL,
	"provider_event_id" varchar(255) NOT NULL,
	"payload_digest" varchar(64) NOT NULL,
	"payload_json" jsonb,
	"processing_status" varchar(20) NOT NULL,
	"processing_error" text,
	"processed_at" timestamp with time zone,
	"created_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"email" "citext",
	"phone_e164" varchar(32),
	"password_hash" text,
	"display_name" varchar(200) DEFAULT '' NOT NULL,
	"status" varchar(20) DEFAULT 'active' NOT NULL,
	"email_verified_at" timestamp with time zone,
	"phone_verified_at" timestamp with time zone,
	"last_login_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "users_email_or_phone" CHECK ((email IS NOT NULL) OR (phone_e164 IS NOT NULL)),
	CONSTRAINT "users_status_check" CHECK ((status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying, 'deleted'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "users" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "organizations" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"name" varchar(255) NOT NULL,
	"slug" varchar(100) NOT NULL,
	"legal_name" varchar(255),
	"tax_id" varchar(64),
	"status" varchar(20) DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "organizations_status_check" CHECK ((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "organizations" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "organization_members" (
	"id" bigserial NOT NULL,
	"organization_id" bigint NOT NULL,
	"user_id" bigint NOT NULL,
	"role" varchar(20) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "organization_members_role_check" CHECK ((role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "organization_members" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "venues" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"organization_id" bigint,
	"name" varchar(255) NOT NULL,
	"line1" varchar(255),
	"line2" varchar(255),
	"city" varchar(120),
	"region" varchar(120),
	"postal_code" varchar(32),
	"country" char(2) DEFAULT 'ET' NOT NULL,
	"latitude" double precision,
	"longitude" double precision,
	"timezone" varchar(64) DEFAULT 'Africa/Addis_Ababa' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "venues" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "events" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"organization_id" bigint NOT NULL,
	"venue_id" bigint NOT NULL,
	"title" varchar(500) NOT NULL,
	"slug" varchar(160) NOT NULL,
	"description" text,
	"starts_at" timestamp with time zone NOT NULL,
	"ends_at" timestamp with time zone NOT NULL,
	"timezone" varchar(64) NOT NULL,
	"status" varchar(20) DEFAULT 'draft' NOT NULL,
	"published_at" timestamp with time zone,
	"sales_starts_at" timestamp with time zone,
	"sales_ends_at" timestamp with time zone,
	"max_attendees" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "events_max_attendees_check" CHECK ((max_attendees IS NULL) OR (max_attendees > 0)),
	CONSTRAINT "events_status_check" CHECK ((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'cancelled'::character varying, 'completed'::character varying])::text[])),
	CONSTRAINT "events_time_order" CHECK (ends_at > starts_at)
);
--> statement-breakpoint
ALTER TABLE "events" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "ticket_types" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"event_id" bigint NOT NULL,
	"name" varchar(120) NOT NULL,
	"description" text,
	"price_amount_minor" bigint NOT NULL,
	"currency" char(3) DEFAULT 'ETB' NOT NULL,
	"quantity_total" integer NOT NULL,
	"quantity_sold" integer DEFAULT 0 NOT NULL,
	"max_per_order" integer DEFAULT 10 NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"sales_starts_at" timestamp with time zone,
	"sales_ends_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ticket_types_max_per_order_check" CHECK (max_per_order >= 1),
	CONSTRAINT "ticket_types_price_amount_minor_check" CHECK (price_amount_minor >= 0),
	CONSTRAINT "ticket_types_quantity_sold_check" CHECK (quantity_sold >= 0),
	CONSTRAINT "ticket_types_quantity_total_check" CHECK (quantity_total >= 0),
	CONSTRAINT "ticket_types_sold_vs_total" CHECK (quantity_sold <= quantity_total)
);
--> statement-breakpoint
ALTER TABLE "ticket_types" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "orders" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"user_id" bigint NOT NULL,
	"event_id" bigint NOT NULL,
	"status" varchar(30) DEFAULT 'pending_payment' NOT NULL,
	"currency" char(3) DEFAULT 'ETB' NOT NULL,
	"subtotal_minor" bigint DEFAULT 0 NOT NULL,
	"fees_minor" bigint DEFAULT 0 NOT NULL,
	"tax_minor" bigint DEFAULT 0 NOT NULL,
	"discount_minor" bigint DEFAULT 0 NOT NULL,
	"total_minor" bigint DEFAULT 0 NOT NULL,
	"idempotency_key" varchar(128) NOT NULL,
	"placed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"paid_at" timestamp with time zone,
	"cancelled_at" timestamp with time zone,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "orders_discount_minor_check" CHECK (discount_minor >= 0),
	CONSTRAINT "orders_fees_minor_check" CHECK (fees_minor >= 0),
	CONSTRAINT "orders_status_check" CHECK ((status)::text = ANY ((ARRAY['pending_payment'::character varying, 'paid'::character varying, 'cancelled'::character varying, 'refunded'::character varying, 'partially_refunded'::character varying])::text[])),
	CONSTRAINT "orders_subtotal_minor_check" CHECK (subtotal_minor >= 0),
	CONSTRAINT "orders_tax_minor_check" CHECK (tax_minor >= 0),
	CONSTRAINT "orders_total_minor_check" CHECK (total_minor >= 0)
);
--> statement-breakpoint
ALTER TABLE "orders" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "order_items" (
	"id" bigserial NOT NULL,
	"order_id" bigint NOT NULL,
	"ticket_type_id" bigint NOT NULL,
	"quantity" integer NOT NULL,
	"unit_price_minor" bigint NOT NULL,
	"line_total_minor" bigint NOT NULL,
	"currency" char(3) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "order_items_line_total_minor_check" CHECK (line_total_minor >= 0),
	CONSTRAINT "order_items_quantity_check" CHECK (quantity >= 1),
	CONSTRAINT "order_items_unit_price_minor_check" CHECK (unit_price_minor >= 0)
);
--> statement-breakpoint
ALTER TABLE "order_items" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "tickets" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"order_item_id" bigint NOT NULL,
	"event_id" bigint NOT NULL,
	"ticket_type_id" bigint NOT NULL,
	"holder_name" varchar(200),
	"status" varchar(20) DEFAULT 'valid' NOT NULL,
	"redemption_code_hash" "bytea" NOT NULL,
	"checked_in_at" timestamp with time zone,
	"checked_in_by_user_id" bigint,
	"voided_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "tickets_status_check" CHECK ((status)::text = ANY ((ARRAY['valid'::character varying, 'cancelled'::character varying, 'refunded'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "tickets" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "payments" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"order_id" bigint NOT NULL,
	"provider" varchar(50) NOT NULL,
	"provider_payment_id" varchar(255) NOT NULL,
	"amount_minor" bigint NOT NULL,
	"currency" char(3) NOT NULL,
	"status" varchar(20) NOT NULL,
	"provider_fee_minor" bigint,
	"raw_metadata" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "payments_amount_minor_check" CHECK (amount_minor >= 0),
	CONSTRAINT "payments_provider_fee_minor_check" CHECK ((provider_fee_minor IS NULL) OR (provider_fee_minor >= 0)),
	CONSTRAINT "payments_status_check" CHECK ((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'refunded'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "payments" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "refunds" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"order_id" bigint NOT NULL,
	"payment_id" bigint,
	"amount_minor" bigint NOT NULL,
	"currency" char(3) NOT NULL,
	"reason" text,
	"provider_refund_id" varchar(255),
	"status" varchar(20) DEFAULT 'pending' NOT NULL,
	"created_by_user_id" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "refunds_amount_minor_check" CHECK (amount_minor > 0),
	CONSTRAINT "refunds_status_check" CHECK ((status)::text = ANY ((ARRAY['pending'::character varying, 'succeeded'::character varying, 'failed'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "refunds" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "order_events" (
	"id" bigserial NOT NULL,
	"order_id" bigint NOT NULL,
	"event_type" varchar(64) NOT NULL,
	"actor_user_id" bigint,
	"payload" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "order_events" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "transport_requests" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"order_id" bigint NOT NULL,
	"direction" varchar(20) NOT NULL,
	"pickup_note" text,
	"pickup_lat" double precision,
	"pickup_lng" double precision,
	"contact_phone" varchar(32) NOT NULL,
	"status" varchar(20) DEFAULT 'requested' NOT NULL,
	"internal_notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "transport_requests_direction_check" CHECK ((direction)::text = ANY ((ARRAY['to_event'::character varying, 'from_event'::character varying, 'both'::character varying])::text[])),
	CONSTRAINT "transport_requests_status_check" CHECK ((status)::text = ANY ((ARRAY['requested'::character varying, 'assigned'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "transport_requests" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "transport_groups" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"event_id" bigint NOT NULL,
	"label" varchar(120) NOT NULL,
	"pickup_landmark" text,
	"scheduled_pickup_at" timestamp with time zone,
	"vehicle_description" varchar(255),
	"driver_phone" varchar(32),
	"status" varchar(20) DEFAULT 'planned' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "transport_groups_status_check" CHECK ((status)::text = ANY ((ARRAY['planned'::character varying, 'dispatched'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "transport_groups" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "transport_assignments" (
	"id" bigserial NOT NULL,
	"transport_request_id" bigint NOT NULL,
	"transport_group_id" bigint NOT NULL,
	"assigned_at" timestamp with time zone DEFAULT now() NOT NULL,
	"assigned_by_user_id" bigint
);
--> statement-breakpoint
ALTER TABLE "transport_assignments" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "audit_admin_events" (
	"id" bigserial NOT NULL,
	"actor_user_id" bigint,
	"action" varchar(120) NOT NULL,
	"entity_table" varchar(100),
	"entity_id" bigint,
	"impersonated_user_id" bigint,
	"ip_address" "inet",
	"user_agent" varchar(512),
	"payload" jsonb NOT NULL,
	"created_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_security_tokens" (
	"id" bigserial NOT NULL,
	"user_id" bigint NOT NULL,
	"purpose" varchar(32) NOT NULL,
	"token_hash" "bytea" NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"consumed_at" timestamp with time zone,
	"created_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
CREATE TABLE "analytics_events" (
	"id" bigserial NOT NULL,
	"occurred_at" timestamp with time zone NOT NULL,
	"user_id" bigint,
	"anon_id" uuid,
	"session_id" uuid,
	"event_name" varchar(120) NOT NULL,
	"properties" jsonb NOT NULL
);
--> statement-breakpoint
CREATE TABLE "tags" (
	"id" bigserial NOT NULL,
	"slug" varchar(120) NOT NULL,
	"name" varchar(160) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "tags" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "event_tags" (
	"event_id" bigint NOT NULL,
	"tag_id" bigint NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "event_tags" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "promo_codes" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"organization_id" bigint,
	"event_id" bigint,
	"code" "citext" NOT NULL,
	"discount_kind" varchar(20) NOT NULL,
	"percent_basis_points" integer,
	"fixed_amount_minor" bigint,
	"currency" char(3) DEFAULT 'ETB' NOT NULL,
	"max_redemptions" integer,
	"redemptions_count" integer DEFAULT 0 NOT NULL,
	"per_user_limit" integer DEFAULT 1 NOT NULL,
	"min_order_minor" bigint DEFAULT 0 NOT NULL,
	"starts_at" timestamp with time zone,
	"ends_at" timestamp with time zone,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "promo_codes_discount_kind_check" CHECK ((discount_kind)::text = ANY ((ARRAY['percent_bp'::character varying, 'fixed_minor'::character varying])::text[])),
	CONSTRAINT "promo_codes_fixed_amount_minor_check" CHECK ((fixed_amount_minor IS NULL) OR (fixed_amount_minor >= 0)),
	CONSTRAINT "promo_codes_max_redemptions_check" CHECK ((max_redemptions IS NULL) OR (max_redemptions > 0)),
	CONSTRAINT "promo_codes_min_order_minor_check" CHECK (min_order_minor >= 0),
	CONSTRAINT "promo_codes_per_user_limit_check" CHECK (per_user_limit >= 1),
	CONSTRAINT "promo_codes_percent_basis_points_check" CHECK ((percent_basis_points IS NULL) OR ((percent_basis_points > 0) AND (percent_basis_points <= 10000))),
	CONSTRAINT "promo_codes_redemptions_count_check" CHECK (redemptions_count >= 0),
	CONSTRAINT "promo_discount_shape" CHECK ((((discount_kind)::text = 'percent_bp'::text) AND (percent_basis_points IS NOT NULL) AND (fixed_amount_minor IS NULL)) OR (((discount_kind)::text = 'fixed_minor'::text) AND (fixed_amount_minor IS NOT NULL) AND (percent_basis_points IS NULL))),
	CONSTRAINT "promo_event_requires_org" CHECK ((event_id IS NULL) OR (organization_id IS NOT NULL))
);
--> statement-breakpoint
ALTER TABLE "promo_codes" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "order_promo_applications" (
	"id" bigserial NOT NULL,
	"order_id" bigint NOT NULL,
	"promo_code_id" bigint NOT NULL,
	"discount_minor" bigint NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "order_promo_applications_discount_minor_check" CHECK (discount_minor >= 0)
);
--> statement-breakpoint
ALTER TABLE "order_promo_applications" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "waitlist_entries" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"user_id" bigint NOT NULL,
	"event_id" bigint NOT NULL,
	"ticket_type_id" bigint,
	"status" varchar(20) DEFAULT 'waiting' NOT NULL,
	"position_hint" integer,
	"offered_at" timestamp with time zone,
	"fulfilled_order_id" bigint,
	"notes_internal" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "waitlist_entries_status_check" CHECK ((status)::text = ANY ((ARRAY['waiting'::character varying, 'offered'::character varying, 'fulfilled'::character varying, 'expired'::character varying, 'cancelled'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "waitlist_entries" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "organizer_payout_profiles" (
	"id" bigserial NOT NULL,
	"organization_id" bigint NOT NULL,
	"payout_provider" varchar(50) DEFAULT 'manual' NOT NULL,
	"provider_account_id" varchar(255),
	"default_currency" char(3) DEFAULT 'ETB' NOT NULL,
	"payout_metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"verified_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "organizer_payout_profiles" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "payout_batches" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"organization_id" bigint NOT NULL,
	"period_start" timestamp with time zone NOT NULL,
	"period_end" timestamp with time zone NOT NULL,
	"status" varchar(20) DEFAULT 'draft' NOT NULL,
	"gross_minor" bigint DEFAULT 0 NOT NULL,
	"platform_fee_minor" bigint DEFAULT 0 NOT NULL,
	"net_to_org_minor" bigint DEFAULT 0 NOT NULL,
	"currency" char(3) DEFAULT 'ETB' NOT NULL,
	"provider_payout_id" varchar(255),
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "payout_batch_period" CHECK (period_end > period_start),
	CONSTRAINT "payout_batches_gross_minor_check" CHECK (gross_minor >= 0),
	CONSTRAINT "payout_batches_net_to_org_minor_check" CHECK (net_to_org_minor >= 0),
	CONSTRAINT "payout_batches_platform_fee_minor_check" CHECK (platform_fee_minor >= 0),
	CONSTRAINT "payout_batches_status_check" CHECK ((status)::text = ANY ((ARRAY['draft'::character varying, 'submitted'::character varying, 'processing'::character varying, 'paid'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "payout_batches" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "payout_batch_items" (
	"id" bigserial NOT NULL,
	"payout_batch_id" bigint NOT NULL,
	"order_id" bigint NOT NULL,
	"gross_minor" bigint NOT NULL,
	"platform_fee_minor" bigint NOT NULL,
	"net_to_org_minor" bigint NOT NULL,
	"currency" char(3) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "payout_batch_items_gross_minor_check" CHECK (gross_minor >= 0),
	CONSTRAINT "payout_batch_items_net_to_org_minor_check" CHECK (net_to_org_minor >= 0),
	CONSTRAINT "payout_batch_items_platform_fee_minor_check" CHECK (platform_fee_minor >= 0)
);
--> statement-breakpoint
ALTER TABLE "payout_batch_items" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "notification_templates" (
	"id" bigserial NOT NULL,
	"template_key" varchar(100) NOT NULL,
	"channel" varchar(20) NOT NULL,
	"locale" varchar(10) DEFAULT 'en' NOT NULL,
	"subject_template" text,
	"body_template" text NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "notification_templates" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "notification_jobs" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"template_id" bigint,
	"user_id" bigint,
	"channel" varchar(20) NOT NULL,
	"to_address" text NOT NULL,
	"payload" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"status" varchar(20) DEFAULT 'pending' NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"next_attempt_at" timestamp with time zone,
	"sent_at" timestamp with time zone,
	"last_error" text,
	"correlation_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "notification_jobs_attempts_check" CHECK (attempts >= 0),
	CONSTRAINT "notification_jobs_channel_check" CHECK ((channel)::text = ANY ((ARRAY['email'::character varying, 'sms'::character varying, 'push'::character varying, 'in_app'::character varying])::text[])),
	CONSTRAINT "notification_jobs_status_check" CHECK ((status)::text = ANY ((ARRAY['pending'::character varying, 'queued'::character varying, 'sending'::character varying, 'sent'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "notification_jobs" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "file_assets" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"storage_provider" varchar(50) NOT NULL,
	"bucket" varchar(255) NOT NULL,
	"object_key" text NOT NULL,
	"mime_type" varchar(120) NOT NULL,
	"byte_size" bigint NOT NULL,
	"checksum_sha256" varchar(64),
	"uploaded_by_user_id" bigint,
	"organization_id" bigint,
	"event_id" bigint,
	"purpose" varchar(50) DEFAULT 'general' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "file_assets_byte_size_check" CHECK (byte_size >= 0),
	CONSTRAINT "file_assets_purpose_check" CHECK ((purpose)::text = ANY ((ARRAY['general'::character varying, 'event_cover'::character varying, 'event_gallery'::character varying, 'user_avatar'::character varying, 'org_logo'::character varying, 'export_archive'::character varying, 'other'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "file_assets" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "feature_flags" (
	"id" bigserial NOT NULL,
	"flag_key" varchar(100) NOT NULL,
	"enabled" boolean DEFAULT false NOT NULL,
	"rollout_percent" integer DEFAULT 0 NOT NULL,
	"metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "feature_flags_rollout_percent_check" CHECK ((rollout_percent >= 0) AND (rollout_percent <= 100))
);
--> statement-breakpoint
ALTER TABLE "feature_flags" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "data_subject_export_requests" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"user_id" bigint NOT NULL,
	"status" varchar(20) DEFAULT 'pending' NOT NULL,
	"file_asset_id" bigint,
	"requested_at" timestamp with time zone DEFAULT now() NOT NULL,
	"ready_at" timestamp with time zone,
	"expires_at" timestamp with time zone,
	"error" text,
	CONSTRAINT "data_subject_export_requests_status_check" CHECK ((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'ready'::character varying, 'expired'::character varying, 'failed'::character varying])::text[]))
);
--> statement-breakpoint
ALTER TABLE "data_subject_export_requests" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "user_event_favorites" (
	"user_id" bigint NOT NULL,
	"event_id" bigint NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "user_event_favorites" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "cart_sessions" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"user_id" bigint,
	"label" varchar(120),
	"expires_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "cart_sessions" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "cart_lines" (
	"id" bigserial NOT NULL,
	"cart_id" bigint NOT NULL,
	"event_id" bigint NOT NULL,
	"ticket_type_id" bigint NOT NULL,
	"quantity" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "cart_lines_quantity_check" CHECK (quantity >= 1)
);
--> statement-breakpoint
ALTER TABLE "cart_lines" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "referral_codes" (
	"id" bigserial NOT NULL,
	"public_id" uuid DEFAULT gen_random_uuid() NOT NULL,
	"user_id" bigint NOT NULL,
	"code" "citext" NOT NULL,
	"max_uses" integer,
	"uses_count" integer DEFAULT 0 NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "referral_codes_max_uses_check" CHECK ((max_uses IS NULL) OR (max_uses > 0)),
	CONSTRAINT "referral_codes_uses_count_check" CHECK (uses_count >= 0)
);
--> statement-breakpoint
ALTER TABLE "referral_codes" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "referral_attributions" (
	"id" bigserial NOT NULL,
	"referral_code_id" bigint NOT NULL,
	"referred_user_id" bigint NOT NULL,
	"first_order_id" bigint,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "referral_attributions" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "user_marketing_preferences" (
	"user_id" bigint NOT NULL,
	"email_opt_in" boolean DEFAULT false NOT NULL,
	"sms_opt_in" boolean DEFAULT false NOT NULL,
	"push_opt_in" boolean DEFAULT false NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "user_marketing_preferences" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "organization_members" ADD CONSTRAINT "organization_members_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organization_members" ADD CONSTRAINT "organization_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "venues" ADD CONSTRAINT "venues_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "events" ADD CONSTRAINT "events_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "events" ADD CONSTRAINT "events_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ticket_types" ADD CONSTRAINT "ticket_types_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_ticket_type_id_fkey" FOREIGN KEY ("ticket_type_id") REFERENCES "public"."ticket_types"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_checked_in_by_user_id_fkey" FOREIGN KEY ("checked_in_by_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_order_item_id_fkey" FOREIGN KEY ("order_item_id") REFERENCES "public"."order_items"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_ticket_type_id_fkey" FOREIGN KEY ("ticket_type_id") REFERENCES "public"."ticket_types"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_events" ADD CONSTRAINT "order_events_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_events" ADD CONSTRAINT "order_events_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_requests" ADD CONSTRAINT "transport_requests_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_groups" ADD CONSTRAINT "transport_groups_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_assignments" ADD CONSTRAINT "transport_assignments_assigned_by_user_id_fkey" FOREIGN KEY ("assigned_by_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_assignments" ADD CONSTRAINT "transport_assignments_transport_group_id_fkey" FOREIGN KEY ("transport_group_id") REFERENCES "public"."transport_groups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_assignments" ADD CONSTRAINT "transport_assignments_transport_request_id_fkey" FOREIGN KEY ("transport_request_id") REFERENCES "public"."transport_requests"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "audit_admin_events" ADD CONSTRAINT "audit_admin_events_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "audit_admin_events" ADD CONSTRAINT "audit_admin_events_impersonated_user_id_fkey" FOREIGN KEY ("impersonated_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_security_tokens" ADD CONSTRAINT "user_security_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "analytics_events" ADD CONSTRAINT "analytics_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "event_tags" ADD CONSTRAINT "event_tags_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "event_tags" ADD CONSTRAINT "event_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "promo_codes" ADD CONSTRAINT "promo_codes_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "promo_codes" ADD CONSTRAINT "promo_codes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_promo_applications" ADD CONSTRAINT "order_promo_applications_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_promo_applications" ADD CONSTRAINT "order_promo_applications_promo_code_id_fkey" FOREIGN KEY ("promo_code_id") REFERENCES "public"."promo_codes"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "waitlist_entries" ADD CONSTRAINT "waitlist_entries_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "waitlist_entries" ADD CONSTRAINT "waitlist_entries_fulfilled_order_id_fkey" FOREIGN KEY ("fulfilled_order_id") REFERENCES "public"."orders"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "waitlist_entries" ADD CONSTRAINT "waitlist_entries_ticket_type_id_fkey" FOREIGN KEY ("ticket_type_id") REFERENCES "public"."ticket_types"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "waitlist_entries" ADD CONSTRAINT "waitlist_entries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organizer_payout_profiles" ADD CONSTRAINT "organizer_payout_profiles_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payout_batches" ADD CONSTRAINT "payout_batches_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payout_batch_items" ADD CONSTRAINT "payout_batch_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payout_batch_items" ADD CONSTRAINT "payout_batch_items_payout_batch_id_fkey" FOREIGN KEY ("payout_batch_id") REFERENCES "public"."payout_batches"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_jobs" ADD CONSTRAINT "notification_jobs_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."notification_templates"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_jobs" ADD CONSTRAINT "notification_jobs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "file_assets" ADD CONSTRAINT "file_assets_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "file_assets" ADD CONSTRAINT "file_assets_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "file_assets" ADD CONSTRAINT "file_assets_uploaded_by_user_id_fkey" FOREIGN KEY ("uploaded_by_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_subject_export_requests" ADD CONSTRAINT "data_subject_export_requests_file_asset_id_fkey" FOREIGN KEY ("file_asset_id") REFERENCES "public"."file_assets"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_subject_export_requests" ADD CONSTRAINT "data_subject_export_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_event_favorites" ADD CONSTRAINT "user_event_favorites_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_event_favorites" ADD CONSTRAINT "user_event_favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cart_sessions" ADD CONSTRAINT "cart_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cart_lines" ADD CONSTRAINT "cart_lines_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "public"."cart_sessions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cart_lines" ADD CONSTRAINT "cart_lines_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cart_lines" ADD CONSTRAINT "cart_lines_ticket_type_id_fkey" FOREIGN KEY ("ticket_type_id") REFERENCES "public"."ticket_types"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referral_codes" ADD CONSTRAINT "referral_codes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referral_attributions" ADD CONSTRAINT "referral_attributions_first_order_id_fkey" FOREIGN KEY ("first_order_id") REFERENCES "public"."orders"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referral_attributions" ADD CONSTRAINT "referral_attributions_referral_code_id_fkey" FOREIGN KEY ("referral_code_id") REFERENCES "public"."referral_codes"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referral_attributions" ADD CONSTRAINT "referral_attributions_referred_user_id_fkey" FOREIGN KEY ("referred_user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_marketing_preferences" ADD CONSTRAINT "user_marketing_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_webhook_events_created" ON "payment_webhook_events" USING btree ("created_at" timestamptz_ops);--> statement-breakpoint
CREATE INDEX "idx_org_members_org" ON "organization_members" USING btree ("organization_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_org_members_user" ON "organization_members" USING btree ("user_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_venues_org" ON "venues" USING btree ("organization_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_events_org_status_starts" ON "events" USING btree ("organization_id" int8_ops,"status" int8_ops,"starts_at" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_events_published_starts" ON "events" USING btree ("status" text_ops,"starts_at" text_ops) WHERE ((status)::text = 'published'::text);--> statement-breakpoint
CREATE INDEX "idx_ticket_types_event" ON "ticket_types" USING btree ("event_id" int8_ops,"active" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_orders_event_status" ON "orders" USING btree ("event_id" int8_ops,"status" text_ops);--> statement-breakpoint
CREATE INDEX "idx_orders_user_placed" ON "orders" USING btree ("user_id" int8_ops,"placed_at" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_order_items_order" ON "order_items" USING btree ("order_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_order_items_ticket_type" ON "order_items" USING btree ("ticket_type_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_tickets_event_status" ON "tickets" USING btree ("event_id" text_ops,"status" text_ops);--> statement-breakpoint
CREATE INDEX "idx_tickets_order_item" ON "tickets" USING btree ("order_item_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_payments_order" ON "payments" USING btree ("order_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_refunds_order" ON "refunds" USING btree ("order_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_order_events_order_created" ON "order_events" USING btree ("order_id" int8_ops,"created_at" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_transport_groups_event" ON "transport_groups" USING btree ("event_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_transport_assignments_group" ON "transport_assignments" USING btree ("transport_group_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_audit_admin_actor" ON "audit_admin_events" USING btree ("actor_user_id" int8_ops,"created_at" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_audit_admin_created" ON "audit_admin_events" USING btree ("created_at" timestamptz_ops);--> statement-breakpoint
CREATE INDEX "idx_user_security_tokens_expires" ON "user_security_tokens" USING btree ("expires_at" timestamptz_ops);--> statement-breakpoint
CREATE INDEX "idx_user_security_tokens_user_purpose" ON "user_security_tokens" USING btree ("user_id" int8_ops,"purpose" text_ops);--> statement-breakpoint
CREATE INDEX "idx_analytics_name_time" ON "analytics_events" USING btree ("event_name" timestamptz_ops,"occurred_at" timestamptz_ops);--> statement-breakpoint
CREATE INDEX "idx_analytics_occurred" ON "analytics_events" USING btree ("occurred_at" timestamptz_ops);--> statement-breakpoint
CREATE INDEX "idx_analytics_user_time" ON "analytics_events" USING btree ("user_id" int8_ops,"occurred_at" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_event_tags_tag" ON "event_tags" USING btree ("tag_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_promo_codes_active" ON "promo_codes" USING btree ("active" timestamptz_ops,"starts_at" bool_ops,"ends_at" bool_ops);--> statement-breakpoint
CREATE INDEX "idx_promo_codes_event" ON "promo_codes" USING btree ("event_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_promo_codes_org" ON "promo_codes" USING btree ("organization_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_order_promo_order" ON "order_promo_applications" USING btree ("order_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_order_promo_promo" ON "order_promo_applications" USING btree ("promo_code_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_waitlist_event_status" ON "waitlist_entries" USING btree ("event_id" int8_ops,"status" text_ops);--> statement-breakpoint
CREATE UNIQUE INDEX "waitlist_user_event_any_type" ON "waitlist_entries" USING btree ("user_id" int8_ops,"event_id" int8_ops) WHERE (ticket_type_id IS NULL);--> statement-breakpoint
CREATE UNIQUE INDEX "waitlist_user_event_ticket_type" ON "waitlist_entries" USING btree ("user_id" int8_ops,"event_id" int8_ops,"ticket_type_id" int8_ops) WHERE (ticket_type_id IS NOT NULL);--> statement-breakpoint
CREATE INDEX "idx_payout_batches_org" ON "payout_batches" USING btree ("organization_id" int8_ops,"status" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_payout_batch_items_order" ON "payout_batch_items" USING btree ("order_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_notification_jobs_status_next" ON "notification_jobs" USING btree ("status" text_ops,"next_attempt_at" text_ops);--> statement-breakpoint
CREATE INDEX "idx_notification_jobs_user" ON "notification_jobs" USING btree ("user_id" int8_ops,"created_at" timestamptz_ops);--> statement-breakpoint
CREATE INDEX "idx_file_assets_event" ON "file_assets" USING btree ("event_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_file_assets_org" ON "file_assets" USING btree ("organization_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_data_export_user" ON "data_subject_export_requests" USING btree ("user_id" int8_ops,"requested_at" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_favorites_event" ON "user_event_favorites" USING btree ("event_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_cart_sessions_expires" ON "cart_sessions" USING btree ("expires_at" timestamptz_ops);--> statement-breakpoint
CREATE INDEX "idx_cart_sessions_user" ON "cart_sessions" USING btree ("user_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_cart_lines_cart" ON "cart_lines" USING btree ("cart_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_cart_lines_event" ON "cart_lines" USING btree ("event_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_referral_codes_user" ON "referral_codes" USING btree ("user_id" int8_ops);--> statement-breakpoint
CREATE INDEX "idx_referral_attr_code" ON "referral_attributions" USING btree ("referral_code_id" int8_ops);--> statement-breakpoint
CREATE POLICY "users_update_self" ON "users" AS PERMISSIVE FOR UPDATE TO "eventapp_web" USING ((id = app.session_user_id())) WITH CHECK ((id = app.session_user_id()));--> statement-breakpoint
CREATE POLICY "users_select_self" ON "users" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "organizations_select_member" ON "organizations" AS PERMISSIVE FOR SELECT TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = organizations.id) AND (m.user_id = app.session_user_id())))));--> statement-breakpoint
CREATE POLICY "org_members_select_self" ON "organization_members" AS PERMISSIVE FOR SELECT TO "eventapp_web" USING ((user_id = app.session_user_id()));--> statement-breakpoint
CREATE POLICY "venues_staff_update" ON "venues" AS PERMISSIVE FOR UPDATE TO "eventapp_web" USING (((organization_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = venues.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))))) WITH CHECK (((organization_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = venues.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))));--> statement-breakpoint
CREATE POLICY "venues_staff_insert" ON "venues" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "venues_select_policy" ON "venues" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "events_staff_delete" ON "events" AS PERMISSIVE FOR DELETE TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = events.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[]))))));--> statement-breakpoint
CREATE POLICY "events_staff_update" ON "events" AS PERMISSIVE FOR UPDATE TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "events_staff_insert" ON "events" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "events_select_policy" ON "events" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "ticket_types_staff_manage" ON "ticket_types" AS PERMISSIVE FOR ALL TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = ticket_types.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = ticket_types.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))));--> statement-breakpoint
CREATE POLICY "ticket_types_select_policy" ON "ticket_types" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "orders_update_own" ON "orders" AS PERMISSIVE FOR UPDATE TO "eventapp_web" USING ((user_id = app.session_user_id())) WITH CHECK ((user_id = app.session_user_id()));--> statement-breakpoint
CREATE POLICY "orders_insert_own" ON "orders" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "orders_select_own" ON "orders" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "order_items_update_own" ON "order_items" AS PERMISSIVE FOR UPDATE TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_items.order_id) AND (o.user_id = app.session_user_id()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_items.order_id) AND (o.user_id = app.session_user_id())))));--> statement-breakpoint
CREATE POLICY "order_items_insert_own" ON "order_items" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "order_items_select_own" ON "order_items" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "tickets_staff_checkin" ON "tickets" AS PERMISSIVE FOR UPDATE TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = tickets.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = tickets.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))));--> statement-breakpoint
CREATE POLICY "tickets_update_own" ON "tickets" AS PERMISSIVE FOR UPDATE TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "tickets_select_own" ON "tickets" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "payments_select_own" ON "payments" AS PERMISSIVE FOR SELECT TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = payments.order_id) AND (o.user_id = app.session_user_id())))));--> statement-breakpoint
CREATE POLICY "refunds_select_own" ON "refunds" AS PERMISSIVE FOR SELECT TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = refunds.order_id) AND (o.user_id = app.session_user_id())))));--> statement-breakpoint
CREATE POLICY "order_events_insert_own" ON "order_events" AS PERMISSIVE FOR INSERT TO "eventapp_web" WITH CHECK ((EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_events.order_id) AND (o.user_id = app.session_user_id())))));--> statement-breakpoint
CREATE POLICY "order_events_select_own" ON "order_events" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "transport_req_update_own" ON "transport_requests" AS PERMISSIVE FOR UPDATE TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = transport_requests.order_id) AND (o.user_id = app.session_user_id()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = transport_requests.order_id) AND (o.user_id = app.session_user_id())))));--> statement-breakpoint
CREATE POLICY "transport_req_insert_own" ON "transport_requests" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "transport_req_select_own" ON "transport_requests" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "transport_groups_staff_all" ON "transport_groups" AS PERMISSIVE FOR ALL TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = transport_groups.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = transport_groups.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))));--> statement-breakpoint
CREATE POLICY "transport_assign_staff_delete" ON "transport_assignments" AS PERMISSIVE FOR DELETE TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM ((transport_groups tg
     JOIN events e ON ((e.id = tg.event_id)))
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((tg.id = transport_assignments.transport_group_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))));--> statement-breakpoint
CREATE POLICY "transport_assign_staff_update" ON "transport_assignments" AS PERMISSIVE FOR UPDATE TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "transport_assign_staff_write" ON "transport_assignments" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "transport_assign_select" ON "transport_assignments" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "tags_select_all" ON "tags" AS PERMISSIVE FOR SELECT TO "eventapp_web" USING (true);--> statement-breakpoint
CREATE POLICY "event_tags_staff_write" ON "event_tags" AS PERMISSIVE FOR ALL TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = event_tags.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = event_tags.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))));--> statement-breakpoint
CREATE POLICY "event_tags_select_visible" ON "event_tags" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "promo_staff_delete" ON "promo_codes" AS PERMISSIVE FOR DELETE TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])) AND ((promo_codes.organization_id = m.organization_id) OR (EXISTS ( SELECT 1
           FROM events e
          WHERE ((e.id = promo_codes.event_id) AND (e.organization_id = m.organization_id)))))))));--> statement-breakpoint
CREATE POLICY "promo_staff_update" ON "promo_codes" AS PERMISSIVE FOR UPDATE TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "promo_staff_write" ON "promo_codes" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "promo_select_staff" ON "promo_codes" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "order_promo_insert_own" ON "order_promo_applications" AS PERMISSIVE FOR INSERT TO "eventapp_web" WITH CHECK ((EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.id = order_promo_applications.order_id) AND (o.user_id = app.session_user_id())))));--> statement-breakpoint
CREATE POLICY "order_promo_staff_select" ON "order_promo_applications" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "order_promo_select_own" ON "order_promo_applications" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "waitlist_delete_self" ON "waitlist_entries" AS PERMISSIVE FOR DELETE TO "eventapp_web" USING ((user_id = app.session_user_id()));--> statement-breakpoint
CREATE POLICY "waitlist_update_self" ON "waitlist_entries" AS PERMISSIVE FOR UPDATE TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "waitlist_insert_self" ON "waitlist_entries" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "waitlist_staff_select" ON "waitlist_entries" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "waitlist_select_self" ON "waitlist_entries" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "waitlist_staff_update" ON "waitlist_entries" AS PERMISSIVE FOR UPDATE TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "payout_profile_write_admin" ON "organizer_payout_profiles" AS PERMISSIVE FOR ALL TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = organizer_payout_profiles.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = organizer_payout_profiles.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[]))))));--> statement-breakpoint
CREATE POLICY "payout_profile_select_admin" ON "organizer_payout_profiles" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "payout_batches_admin" ON "payout_batches" AS PERMISSIVE FOR ALL TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = payout_batches.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = payout_batches.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[]))))));--> statement-breakpoint
CREATE POLICY "payout_items_admin_delete" ON "payout_batch_items" AS PERMISSIVE FOR DELETE TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM (payout_batches pb
     JOIN organization_members m ON ((m.organization_id = pb.organization_id)))
  WHERE ((pb.id = payout_batch_items.payout_batch_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying])::text[]))))));--> statement-breakpoint
CREATE POLICY "payout_items_admin_update" ON "payout_batch_items" AS PERMISSIVE FOR UPDATE TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "payout_items_admin_write" ON "payout_batch_items" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "payout_items_admin_select" ON "payout_batch_items" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "notification_templates_select" ON "notification_templates" AS PERMISSIVE FOR SELECT TO "eventapp_web" USING (true);--> statement-breakpoint
CREATE POLICY "notification_jobs_insert_own" ON "notification_jobs" AS PERMISSIVE FOR INSERT TO "eventapp_web" WITH CHECK ((user_id = app.session_user_id()));--> statement-breakpoint
CREATE POLICY "notification_jobs_select_own" ON "notification_jobs" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "file_assets_insert" ON "file_assets" AS PERMISSIVE FOR INSERT TO "eventapp_web" WITH CHECK (((uploaded_by_user_id = app.session_user_id()) OR (EXISTS ( SELECT 1
   FROM organization_members m
  WHERE ((m.organization_id = file_assets.organization_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))) OR ((event_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM (events e
     JOIN organization_members m ON ((m.organization_id = e.organization_id)))
  WHERE ((e.id = file_assets.event_id) AND (m.user_id = app.session_user_id()) AND ((m.role)::text = ANY ((ARRAY['owner'::character varying, 'admin'::character varying, 'staff'::character varying])::text[]))))))));--> statement-breakpoint
CREATE POLICY "file_assets_select" ON "file_assets" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "feature_flags_select" ON "feature_flags" AS PERMISSIVE FOR SELECT TO "eventapp_web" USING (true);--> statement-breakpoint
CREATE POLICY "data_export_update_own" ON "data_subject_export_requests" AS PERMISSIVE FOR UPDATE TO "eventapp_web" USING ((user_id = app.session_user_id())) WITH CHECK ((user_id = app.session_user_id()));--> statement-breakpoint
CREATE POLICY "data_export_insert_own" ON "data_subject_export_requests" AS PERMISSIVE FOR INSERT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "data_export_select_own" ON "data_subject_export_requests" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "favorites_all_own" ON "user_event_favorites" AS PERMISSIVE FOR ALL TO "eventapp_web" USING ((user_id = app.session_user_id())) WITH CHECK ((user_id = app.session_user_id()));--> statement-breakpoint
CREATE POLICY "cart_session_own" ON "cart_sessions" AS PERMISSIVE FOR ALL TO "eventapp_web" USING (((user_id = app.session_user_id()) AND (user_id IS NOT NULL))) WITH CHECK (((user_id = app.session_user_id()) AND (user_id IS NOT NULL)));--> statement-breakpoint
CREATE POLICY "cart_lines_via_cart" ON "cart_lines" AS PERMISSIVE FOR ALL TO "eventapp_web" USING ((EXISTS ( SELECT 1
   FROM cart_sessions c
  WHERE ((c.id = cart_lines.cart_id) AND (c.user_id = app.session_user_id()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM cart_sessions c
  WHERE ((c.id = cart_lines.cart_id) AND (c.user_id = app.session_user_id())))));--> statement-breakpoint
CREATE POLICY "referral_codes_own" ON "referral_codes" AS PERMISSIVE FOR ALL TO "eventapp_web" USING ((user_id = app.session_user_id())) WITH CHECK ((user_id = app.session_user_id()));--> statement-breakpoint
CREATE POLICY "referral_attr_insert_self" ON "referral_attributions" AS PERMISSIVE FOR INSERT TO "eventapp_web" WITH CHECK ((referred_user_id = app.session_user_id()));--> statement-breakpoint
CREATE POLICY "referral_attr_select_referrer" ON "referral_attributions" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "referral_attr_select_referred" ON "referral_attributions" AS PERMISSIVE FOR SELECT TO "eventapp_web";--> statement-breakpoint
CREATE POLICY "marketing_prefs_own" ON "user_marketing_preferences" AS PERMISSIVE FOR ALL TO "eventapp_web" USING ((user_id = app.session_user_id())) WITH CHECK ((user_id = app.session_user_id()));
*/