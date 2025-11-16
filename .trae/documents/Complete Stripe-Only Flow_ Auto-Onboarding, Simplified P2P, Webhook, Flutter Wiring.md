## Current State
- Firebase-only auth middleware active (requires Firebase ID token).
- Firestore persistence for users and transactions.
- Stripe Connect endpoints: create account, account link (KYC), status.
- P2P payments using Separate Charges and Transfers; webhook fallback present.
- SetupIntent endpoint for card payment methods.

## Pending Items
1. Auto-onboarding at signup (create Stripe Express account + Stripe Customer).
2. Simplify P2P initiation inputs (backend fetches IDs from Firestore; no need to pass `customer_id`/`recipient_account_id`).
3. Idempotency keys and error normalization for payment/transfer endpoints.
4. Use Cloud Function webhook URL for production transfer orchestration and Firestore writes.
5. Remove Plaid routes and any client-side references (Stripe-only).
6. Flutter wiring: onboarding, KYC link, status gating, card setup via Payment Sheet, send-money and receipts.

## Implementation Plan
### 1) Auto-Onboarding Endpoint
- Add `POST /stripe/ensure-onboarding` (protected).
- Reads Firebase UID/email; if missing:
  - Create Express connected account → save `stripe_account_id` in Firestore.
  - Create Stripe Customer → save `stripe_customer_id` in Firestore.
- Flutter calls this immediately after Firebase signup/login.

### 2) Simplify P2P Initiate
- Update `POST /payments/p2p/initiate` body to `{ recipient_user_id, amount, currency, payment_method_id }`.
- Backend:
  - Sender UID from Firebase token → fetch `stripe_customer_id`.
  - Fetch recipient `stripe_account_id` from Firestore.
  - Create platform PaymentIntent; on success, create Transfer.
  - Merge transaction into Firestore; support `Idempotency-Key` header.

### 3) Webhook (Cloud Function)
- Stripe Dashboard → set webhook to `https://asia-south1-digital-payments-52cac.cloudfunctions.net/stripeWebhook`.
- In CF:
  - Validate signature using `STRIPE_WEBHOOK_SECRET`.
  - On `payment_intent.succeeded`, read `recipient_account_id` from metadata, create Transfer, update Firestore.
- Keep backend webhook for local dev; production uses CF.

### 4) Remove Plaid
- Disable Plaid routes in backend router.
- Remove Plaid UI flows from Flutter; use cards-only via Stripe Payment Sheet.

### 5) Card Payment Method Setup (Flutter)
- Initialize Stripe SDK with publishable key.
- Call `/stripe/setup-intent`; present Payment Sheet; optionally store `payment_method_id` in Firestore.

### 6) UI Wiring & Gating (Flutter)
- After signup: call `ensure-onboarding`; open account link URL; poll status; set `onboarding_status` in Firestore.
- Gate send-money until both parties have `charges_enabled && payouts_enabled`.
- Initiate payments with simplified endpoint; show receipt with PI ID + Transfer ID; sync from Firestore.

### 7) Hardening
- Add idempotency keys to `payments/p2p/initiate` and transfer-related actions.
- Rate-limit payment endpoints; normalize error responses.
- Structured audit logs across payment lifecycle.

## Testing
- Two Firebase test users → ensure onboarding → complete KYC.
- Save card via Payment Sheet; send $1 test payment.
- Verify PI and Transfer in Stripe Dashboard.
- Trigger webhook test events; confirm transfer and Firestore updates.

## Inputs Needed to Proceed
- Confirm cards-only (no ACH) is final.
- Confirm we should disable Plaid routes immediately.
- Provide publishable key usage in Flutter (you shared test key; we will use it).
- Ensure `GOOGLE_APPLICATION_CREDENTIALS` and `FIREBASE_PROJECT_ID` set in backend environment.