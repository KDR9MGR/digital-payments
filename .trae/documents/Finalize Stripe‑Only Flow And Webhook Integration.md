## Inputs Confirmed

- Webhook URL: `https://asia-south1-digital-payments-52cac.cloudfunctions.net/stripeWebhook`
- Backend already runs with Firebase-only auth and Firestore persistence; Stripe Connect and P2P routes are in place.

## Pending Items

- Auto-onboarding at user signup (create Stripe Express account + Stripe Customer) without manual client calls
- Simplify P2P initiation inputs (use Firestore lookups; remove need to pass `customer_id` and `recipient_account_id`)
- Idempotency keys + improved error handling on payments/transfers
- Align webhook-driven transfer orchestration with Cloud Function endpoint
- Remove Plaid routes and app calls (Stripe-only)
- Flutter UI wiring for onboarding, gating, payment method setup, send-money, receipts

## Implementation Plan

### 1) Auto-Onboarding Endpoint
- Add `POST /stripe/ensure-onboarding` (protected by Firebase token)
  - Read `uid` and `email` from context
  - If no `stripe_account_id` in Firestore, create Express account and save
  - If no `stripe_customer_id`, create Stripe Customer and save
- Flutter: call this endpoint immediately after Firebase signup/login

### 2) Simplify P2P Initiate
- Update `/payments/p2p/initiate` request body to accept:
  - `recipient_user_id`, `amount`, `currency`, `payment_method_id`
- Backend:
  - Use sender UID from Firebase token
  - Look up sender `stripe_customer_id` and recipient `stripe_account_id` in Firestore
  - Create platform PaymentIntent and, on success, Transfer to recipient
  - Add idempotency key support via header `Idempotency-Key`
  - Persist transaction to Firestore

### 3) Webhook Integration (Cloud Function)
- Move transfer fallback logic to Cloud Function webhook:
  - On `payment_intent.succeeded`, read `recipient_account_id` from PaymentIntent metadata
  - Create Transfer to recipient and write transaction status to Firestore
- Keep backend webhook for local dev only (optional); primary webhook is Cloud Function URL

### 4) Remove Plaid
- Disable Plaid routes in backend router and remove Plaid usage in Flutter
- Stripe is the sole processor; card methods via SetupIntent/Payment Sheet

### 5) Card Payment Method Setup
- Flutter:
  - Initialize Stripe SDK with publishable key
  - Call `/stripe/setup-intent` to get client secret and present Payment Sheet
  - (Optional) record `payment_method_id` in Firestore for reuse

### 6) UI Wiring & Gating
- After signup: call `ensure-onboarding`, then open Account Link URL
- Poll account status and set `onboarding_status` in Firestore
- Gate send-money until both parties have `charges_enabled && payouts_enabled`
- Send money via simplified endpoint; show receipt (PI ID + Transfer ID) from Firestore

### 7) Hardening
- Add idempotency keys on critical POSTs (`payments/p2p/initiate`, transfer creation)
- Rate-limit payment endpoints and normalize error shapes
- Add structured logs for auditability

## Deliverables
- New `ensure-onboarding` endpoint and simplified P2P initiation
- Idempotency handling and error responses
- Webhook fallback executed by Cloud Function; backend adjusted accordingly
- Plaid removed; Stripe-only flow
- Flutter calls and gating logic documented and/or implemented

## Needed From You
- Confirm publishable key to use in Flutter SDK (test key is OK)
- Confirm we will keep Cloud Function as the sole webhook processor (backend webhook used only for local dev)
- Approval to disable Plaid routes now