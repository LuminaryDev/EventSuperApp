import { relations } from "drizzle-orm/relations";
import { organizations, organizationMembers, users, venues, events, ticketTypes, orders, orderItems, tickets, payments, refunds, orderEvents, transportRequests, transportGroups, transportAssignments, auditAdminEvents, userSecurityTokens, analyticsEvents, eventTags, tags, promoCodes, orderPromoApplications, waitlistEntries, organizerPayoutProfiles, payoutBatches, payoutBatchItems, notificationTemplates, notificationJobs, fileAssets, dataSubjectExportRequests, userEventFavorites, cartSessions, cartLines, referralCodes, referralAttributions, userMarketingPreferences } from "./schema";

export const organizationMembersRelations = relations(organizationMembers, ({one}) => ({
	organization: one(organizations, {
		fields: [organizationMembers.organizationId],
		references: [organizations.id]
	}),
	user: one(users, {
		fields: [organizationMembers.userId],
		references: [users.id]
	}),
}));

export const organizationsRelations = relations(organizations, ({many}) => ({
	organizationMembers: many(organizationMembers),
	venues: many(venues),
	events: many(events),
	promoCodes: many(promoCodes),
	organizerPayoutProfiles: many(organizerPayoutProfiles),
	payoutBatches: many(payoutBatches),
	fileAssets: many(fileAssets),
}));

export const usersRelations = relations(users, ({many}) => ({
	organizationMembers: many(organizationMembers),
	orders: many(orders),
	tickets: many(tickets),
	refunds: many(refunds),
	orderEvents: many(orderEvents),
	transportAssignments: many(transportAssignments),
	auditAdminEvents_actorUserId: many(auditAdminEvents, {
		relationName: "auditAdminEvents_actorUserId_users_id"
	}),
	auditAdminEvents_impersonatedUserId: many(auditAdminEvents, {
		relationName: "auditAdminEvents_impersonatedUserId_users_id"
	}),
	userSecurityTokens: many(userSecurityTokens),
	analyticsEvents: many(analyticsEvents),
	waitlistEntries: many(waitlistEntries),
	notificationJobs: many(notificationJobs),
	fileAssets: many(fileAssets),
	dataSubjectExportRequests: many(dataSubjectExportRequests),
	userEventFavorites: many(userEventFavorites),
	cartSessions: many(cartSessions),
	referralCodes: many(referralCodes),
	referralAttributions: many(referralAttributions),
	userMarketingPreferences: many(userMarketingPreferences),
}));

export const venuesRelations = relations(venues, ({one, many}) => ({
	organization: one(organizations, {
		fields: [venues.organizationId],
		references: [organizations.id]
	}),
	events: many(events),
}));

export const eventsRelations = relations(events, ({one, many}) => ({
	organization: one(organizations, {
		fields: [events.organizationId],
		references: [organizations.id]
	}),
	venue: one(venues, {
		fields: [events.venueId],
		references: [venues.id]
	}),
	ticketTypes: many(ticketTypes),
	orders: many(orders),
	tickets: many(tickets),
	transportGroups: many(transportGroups),
	eventTags: many(eventTags),
	promoCodes: many(promoCodes),
	waitlistEntries: many(waitlistEntries),
	fileAssets: many(fileAssets),
	userEventFavorites: many(userEventFavorites),
	cartLines: many(cartLines),
}));

export const ticketTypesRelations = relations(ticketTypes, ({one, many}) => ({
	event: one(events, {
		fields: [ticketTypes.eventId],
		references: [events.id]
	}),
	orderItems: many(orderItems),
	tickets: many(tickets),
	waitlistEntries: many(waitlistEntries),
	cartLines: many(cartLines),
}));

export const ordersRelations = relations(orders, ({one, many}) => ({
	event: one(events, {
		fields: [orders.eventId],
		references: [events.id]
	}),
	user: one(users, {
		fields: [orders.userId],
		references: [users.id]
	}),
	orderItems: many(orderItems),
	payments: many(payments),
	refunds: many(refunds),
	orderEvents: many(orderEvents),
	transportRequests: many(transportRequests),
	orderPromoApplications: many(orderPromoApplications),
	waitlistEntries: many(waitlistEntries),
	payoutBatchItems: many(payoutBatchItems),
	referralAttributions: many(referralAttributions),
}));

export const orderItemsRelations = relations(orderItems, ({one, many}) => ({
	order: one(orders, {
		fields: [orderItems.orderId],
		references: [orders.id]
	}),
	ticketType: one(ticketTypes, {
		fields: [orderItems.ticketTypeId],
		references: [ticketTypes.id]
	}),
	tickets: many(tickets),
}));

export const ticketsRelations = relations(tickets, ({one}) => ({
	user: one(users, {
		fields: [tickets.checkedInByUserId],
		references: [users.id]
	}),
	event: one(events, {
		fields: [tickets.eventId],
		references: [events.id]
	}),
	orderItem: one(orderItems, {
		fields: [tickets.orderItemId],
		references: [orderItems.id]
	}),
	ticketType: one(ticketTypes, {
		fields: [tickets.ticketTypeId],
		references: [ticketTypes.id]
	}),
}));

export const paymentsRelations = relations(payments, ({one, many}) => ({
	order: one(orders, {
		fields: [payments.orderId],
		references: [orders.id]
	}),
	refunds: many(refunds),
}));

export const refundsRelations = relations(refunds, ({one}) => ({
	user: one(users, {
		fields: [refunds.createdByUserId],
		references: [users.id]
	}),
	order: one(orders, {
		fields: [refunds.orderId],
		references: [orders.id]
	}),
	payment: one(payments, {
		fields: [refunds.paymentId],
		references: [payments.id]
	}),
}));

export const orderEventsRelations = relations(orderEvents, ({one}) => ({
	user: one(users, {
		fields: [orderEvents.actorUserId],
		references: [users.id]
	}),
	order: one(orders, {
		fields: [orderEvents.orderId],
		references: [orders.id]
	}),
}));

export const transportRequestsRelations = relations(transportRequests, ({one, many}) => ({
	order: one(orders, {
		fields: [transportRequests.orderId],
		references: [orders.id]
	}),
	transportAssignments: many(transportAssignments),
}));

export const transportGroupsRelations = relations(transportGroups, ({one, many}) => ({
	event: one(events, {
		fields: [transportGroups.eventId],
		references: [events.id]
	}),
	transportAssignments: many(transportAssignments),
}));

export const transportAssignmentsRelations = relations(transportAssignments, ({one}) => ({
	user: one(users, {
		fields: [transportAssignments.assignedByUserId],
		references: [users.id]
	}),
	transportGroup: one(transportGroups, {
		fields: [transportAssignments.transportGroupId],
		references: [transportGroups.id]
	}),
	transportRequest: one(transportRequests, {
		fields: [transportAssignments.transportRequestId],
		references: [transportRequests.id]
	}),
}));

export const auditAdminEventsRelations = relations(auditAdminEvents, ({one}) => ({
	user_actorUserId: one(users, {
		fields: [auditAdminEvents.actorUserId],
		references: [users.id],
		relationName: "auditAdminEvents_actorUserId_users_id"
	}),
	user_impersonatedUserId: one(users, {
		fields: [auditAdminEvents.impersonatedUserId],
		references: [users.id],
		relationName: "auditAdminEvents_impersonatedUserId_users_id"
	}),
}));

export const userSecurityTokensRelations = relations(userSecurityTokens, ({one}) => ({
	user: one(users, {
		fields: [userSecurityTokens.userId],
		references: [users.id]
	}),
}));

export const analyticsEventsRelations = relations(analyticsEvents, ({one}) => ({
	user: one(users, {
		fields: [analyticsEvents.userId],
		references: [users.id]
	}),
}));

export const eventTagsRelations = relations(eventTags, ({one}) => ({
	event: one(events, {
		fields: [eventTags.eventId],
		references: [events.id]
	}),
	tag: one(tags, {
		fields: [eventTags.tagId],
		references: [tags.id]
	}),
}));

export const tagsRelations = relations(tags, ({many}) => ({
	eventTags: many(eventTags),
}));

export const promoCodesRelations = relations(promoCodes, ({one, many}) => ({
	event: one(events, {
		fields: [promoCodes.eventId],
		references: [events.id]
	}),
	organization: one(organizations, {
		fields: [promoCodes.organizationId],
		references: [organizations.id]
	}),
	orderPromoApplications: many(orderPromoApplications),
}));

export const orderPromoApplicationsRelations = relations(orderPromoApplications, ({one}) => ({
	order: one(orders, {
		fields: [orderPromoApplications.orderId],
		references: [orders.id]
	}),
	promoCode: one(promoCodes, {
		fields: [orderPromoApplications.promoCodeId],
		references: [promoCodes.id]
	}),
}));

export const waitlistEntriesRelations = relations(waitlistEntries, ({one}) => ({
	event: one(events, {
		fields: [waitlistEntries.eventId],
		references: [events.id]
	}),
	order: one(orders, {
		fields: [waitlistEntries.fulfilledOrderId],
		references: [orders.id]
	}),
	ticketType: one(ticketTypes, {
		fields: [waitlistEntries.ticketTypeId],
		references: [ticketTypes.id]
	}),
	user: one(users, {
		fields: [waitlistEntries.userId],
		references: [users.id]
	}),
}));

export const organizerPayoutProfilesRelations = relations(organizerPayoutProfiles, ({one}) => ({
	organization: one(organizations, {
		fields: [organizerPayoutProfiles.organizationId],
		references: [organizations.id]
	}),
}));

export const payoutBatchesRelations = relations(payoutBatches, ({one, many}) => ({
	organization: one(organizations, {
		fields: [payoutBatches.organizationId],
		references: [organizations.id]
	}),
	payoutBatchItems: many(payoutBatchItems),
}));

export const payoutBatchItemsRelations = relations(payoutBatchItems, ({one}) => ({
	order: one(orders, {
		fields: [payoutBatchItems.orderId],
		references: [orders.id]
	}),
	payoutBatch: one(payoutBatches, {
		fields: [payoutBatchItems.payoutBatchId],
		references: [payoutBatches.id]
	}),
}));

export const notificationJobsRelations = relations(notificationJobs, ({one}) => ({
	notificationTemplate: one(notificationTemplates, {
		fields: [notificationJobs.templateId],
		references: [notificationTemplates.id]
	}),
	user: one(users, {
		fields: [notificationJobs.userId],
		references: [users.id]
	}),
}));

export const notificationTemplatesRelations = relations(notificationTemplates, ({many}) => ({
	notificationJobs: many(notificationJobs),
}));

export const fileAssetsRelations = relations(fileAssets, ({one, many}) => ({
	event: one(events, {
		fields: [fileAssets.eventId],
		references: [events.id]
	}),
	organization: one(organizations, {
		fields: [fileAssets.organizationId],
		references: [organizations.id]
	}),
	user: one(users, {
		fields: [fileAssets.uploadedByUserId],
		references: [users.id]
	}),
	dataSubjectExportRequests: many(dataSubjectExportRequests),
}));

export const dataSubjectExportRequestsRelations = relations(dataSubjectExportRequests, ({one}) => ({
	fileAsset: one(fileAssets, {
		fields: [dataSubjectExportRequests.fileAssetId],
		references: [fileAssets.id]
	}),
	user: one(users, {
		fields: [dataSubjectExportRequests.userId],
		references: [users.id]
	}),
}));

export const userEventFavoritesRelations = relations(userEventFavorites, ({one}) => ({
	event: one(events, {
		fields: [userEventFavorites.eventId],
		references: [events.id]
	}),
	user: one(users, {
		fields: [userEventFavorites.userId],
		references: [users.id]
	}),
}));

export const cartSessionsRelations = relations(cartSessions, ({one, many}) => ({
	user: one(users, {
		fields: [cartSessions.userId],
		references: [users.id]
	}),
	cartLines: many(cartLines),
}));

export const cartLinesRelations = relations(cartLines, ({one}) => ({
	cartSession: one(cartSessions, {
		fields: [cartLines.cartId],
		references: [cartSessions.id]
	}),
	event: one(events, {
		fields: [cartLines.eventId],
		references: [events.id]
	}),
	ticketType: one(ticketTypes, {
		fields: [cartLines.ticketTypeId],
		references: [ticketTypes.id]
	}),
}));

export const referralCodesRelations = relations(referralCodes, ({one, many}) => ({
	user: one(users, {
		fields: [referralCodes.userId],
		references: [users.id]
	}),
	referralAttributions: many(referralAttributions),
}));

export const referralAttributionsRelations = relations(referralAttributions, ({one}) => ({
	order: one(orders, {
		fields: [referralAttributions.firstOrderId],
		references: [orders.id]
	}),
	referralCode: one(referralCodes, {
		fields: [referralAttributions.referralCodeId],
		references: [referralCodes.id]
	}),
	user: one(users, {
		fields: [referralAttributions.referredUserId],
		references: [users.id]
	}),
}));

export const userMarketingPreferencesRelations = relations(userMarketingPreferences, ({one}) => ({
	user: one(users, {
		fields: [userMarketingPreferences.userId],
		references: [users.id]
	}),
}));