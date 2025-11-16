## Overview

* Implement Stripe Connect so every app user has a connected account tied to their app profile.

* Use Separate Charges and Transfers (SCaT): charge on the platform (owner) account, then transfer funds to the recipient’s connected account.

* Enforce that both sender and recipient have active app accounts with completed Stripe onboarding before any transaction.

## Architecture

* Platform account: your primary Stripe account receives all charges.

* Connected accounts: one per user (Stripe Express), stored in your DB as `stripe_account_id`, with `charges_enabled`/`payouts_enabled` flags.

* Customers & payment methods: store `stripe_customer_id` and link verified bank/card payment methods (existing Plaid + Stripe flow for ACH is reused).

* Funds flow: PaymentIntent on platform → succeeds → Transfer to recipient connected account (optionally grouped via `transfer_group`).

## Backend (Go) Additions

* Account onboarding

  * POST `/stripe/connect/account` → create Express connected account for a user and return `account.id`.

  * POST `/stripe/connect/account-link` → return onboarding Account Link URL; client opens it to complete KYC.

  * GET `/stripe/connect/account/:id/status` → return `charges_enabled`, `payouts_enabled`, requirements.

* Payments

  * POST `/payments/p2p/initiate` → body: `senderUserId`, `recipientUserId`, `amount`, `currency`, optional `paymentMethodId`.

    * Validations: both users exist, both onboarded (`charges_enabled` for platform charge, `payouts_enabled` on recipient before transfer).

    * Create PaymentIntent on platform using sender’s method (ACH via Plaid-created `us_bank_account` or card via Stripe Payment Sheet).

    * On success, create Transfer to `recipient.stripe_account_id` with `transfer_group` linking to the PaymentIntent.

  * GET `/payments/:id` → status of PI and transfer.

* Webhooks

  * `payment_intent.succeeded` → mark charge success; enqueue/create Transfer if not already done.

  * `payment_intent.payment_failed` → record failure and surface error.

  * `transfer.created`/`transfer.failed` → update payout status.

* Security & reliability

  * Use idempotency keys for critical POSTs.

  * Validate webhook signatures using `STRIPE_WEBHOOK_SECRET`.

  * Rate limit payment endpoints; audit logs for each step.

## Backend: Where It Fits

* Reuse current Stripe client:

  * PaymentIntent creation: `backend/stripe_client.go:94`.

  * Transfer creation: `backend/stripe_client.go:171`.

  * Webhook validation: `backend/stripe_client.go:227` and handler `backend/stripe_handlers.go:374`.

* New methods to add:

  * Create connected account and account links.

  * PaymentIntent with `transfer_group` and post-success Transfer orchestration.

## Flutter App Changes

* Onboarding

  * After signup, call backend to create the user’s connected account.

  * Open returned Account Link URL in a WebView/Chrome Custom Tab; poll backend for `charges_enabled`/`payouts_enabled`.

  * Gate payment UI until onboarding requirements are met.

* Payment collection

  * For ACH: continue using Plaid to verify bank, then create a Stripe PaymentMethod (`us_bank_account`) via backend; or use `flutter_stripe` for card payments.

  * Start payment: call `/payments/p2p/initiate` with recipient, amount, and selected payment method; display status and receipt.

* Recipient selection & validation

  * Ensure both users have active app accounts; show helpful prompts if recipient is not onboarded yet.

## Funds Flow Details (SCaT)

* Charge on platform:

  * Create PaymentIntent on platform with sender’s `payment_method` and confirm.

* Transfer after success:

  * Create Transfer to recipient’s connected account; optionally include `transfer_group` referencing the PaymentIntent.

* Reconciliation:

  * Store PI ID + Transfer ID per transaction; expose in admin and user receipts.

## Data Model

* Users: `id`, `email`, `stripe_customer_id`, `stripe_account_id`, `charges_enabled`, `payouts_enabled`, `onboarding_status`.

* Payment methods: `id`, `type` (ach/card), `verified` (Plaid), `customer_id`, `last4`, \`bank/card brand).

* Transactions: `id`, `sender_user_id`, `recipient_user_id`, `amount`, `currency`, `payment_intent_id`, `transfer_id`, `status`, `failure_code`.

## Compliance & Risk

* Stripe Express account onboarding collects KYC/Tax; you must not move funds to users without completed requirements.

* Dispute/refund handling: refunds reverse transfers where applicable; define policy and implement administrative flows.

* Legal: confirm your business supports money transmission using Stripe Connect in your regions.

## Configuration

* Required env vars: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_CONNECT_REDIRECT_URL`, `STRIPE_CONNECT_REFRESH_URL`.

* Webhook endpoint (example): `POST /stripe/webhook` hosted on your backend, publicly reachable.

* Publishable key for Flutter: used by `flutter_stripe` when collecting card details (ACH stays via Plaid → backend PM creation).

## Testing Plan

* Unit: mock Stripe client for account creation, PI, transfers.

* Integration: test full flow with test keys and two test users; simulate PI succeed/failed; verify transfers.

* End-to-end: onboard both users, send $1 test charge, confirm transfer arrives in recipient’s Stripe test dashboard.

## Milestones

1. Account onboarding endpoints and Flutter UI gating.
2. PaymentIntent creation with Plaid-sourced ACH and manual confirmation.
3. Transfer orchestration and webhook-driven reliability.
4. Receipts, history, and admin audit logs.

## What I Need From You

* Stripe account with Connect (Express) enabled and test keys.

  Publisable key:pk\_test\_51SEcirK1iBm9UZtEoOKynLRugDPzIGbBhLck8KinOIjYkXjhtbB1amJKjQ3gzwkdkHDqAZ11OyXw71WAMWlPfDd700ZI5zJbXY

  Secrect Key: sk\_test\_51SEcirK1iBm9UZtEHltRH7UDhXdwMrTvTCA5Ptk6UBjLGLdYUqcRX9xIirHlyRUvYxHggSfwi9Pb5DX3hgNS5t3C00pLgw8ghv

* Business details to configure onboarding (country, capabilities).\
  \
  United States,

* Domain/URL for webhook and redirect/refresh URLs.\
  <https://digitalpayments.live/>

* Decision: support ACH only, or ACH + cards via Payment Sheet.

* Any existing user database schema to attach Stripe IDs, or permission to extend it.

