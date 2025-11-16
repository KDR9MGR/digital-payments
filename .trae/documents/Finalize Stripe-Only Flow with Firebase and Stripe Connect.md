## What’s Done

- Stripe Connect onboarding endpoints
  - Create Express account using Firebase UID and email: backend/stripe_handlers.go:450, route in backend/main.go:114.
  - Account Link for KYC: backend/stripe_handlers.go:490.
  - Status endpoint with Firestore merge: backend/stripe_handlers.go:450.
- Payments flow (Separate Charges and Transfers)
  - Platform PaymentIntent with metadata + transfer to recipient: backend/stripe_handlers.go:598.
  - Webhook `payment_intent.succeeded` triggers transfer fallback: backend/stripe_handlers.go:409.
- Firebase-only backend
  - Firebase Auth verification middleware: backend/middleware.go:37.
  - Firestore persistence for users and transactions: backend/stripe_handlers.go:479, backend/stripe_handlers.go:624.
- SetupIntent endpoint for card methods: backend/stripe_handlers.go:646; route wired in backend/main.go:119.

## What’s Pending

1. Auto-create Stripe Connect account + Stripe Customer on app user creation (currently needs client call).
2. Client UI wiring to call the new endpoints and gate flows by onboarding status.
3. Remove Plaid usage from app and backend routes (we’ll keep ACH off for now, cards only via Stripe).
4. Simplify P2P endpoint inputs: use Firestore lookups for recipient; remove need to pass `recipient_account_id` and reduce need for `customer_id` by backend-managed customer creation.
5. Idempotency keys and error handling for payment and transfer endpoints.
6. Stripe Dashboard webhook setup against your public URL.

## Step-by-Step Plan

1) Environment & Webhook
- Set env vars on the running Gin server:
  - STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET
  - GOOGLE_APPLICATION_CREDENTIALS (service account JSON), FIREBASE_PROJECT_ID
  - STRIPE_CONNECT_REFRESH_URL, STRIPE_CONNECT_REDIRECT_URL
- Expose webhook URL publicly (e.g., ngrok) and configure Stripe Dashboard:
  - POST `https://<public>/webhooks/stripe` for events: payment_intent.succeeded, payment_intent.payment_failed, setup_intent.created, setup_intent.succeeded.

2) Auto-Onboarding on Signup
- Backend: add a lightweight "ensure onboarding" endpoint or hook that:
  - Reads Firebase UID and email from context.
  - If no `stripe_account_id`, create Express account and store in Firestore.
  - If no `stripe_customer_id`, create Stripe Customer and store in Firestore.
- Flutter: call this endpoint immediately after Firebase signup/login.

3) KYC Flow & Gating
- Flutter: call `/stripe/connect/account-link`, open URL (WebView/Chrome Custom Tab).
- Poll `/stripe/connect/account/:id/status?user_id=<uid>` until `charges_enabled && payouts_enabled`.
- Gate send-money UI on both sender and recipient statuses from Firestore.

4) Card Payment Method Setup
- Flutter: use Stripe SDK with publishable key.
- Call `/stripe/setup-intent` to get client secret; present Payment Sheet; store PaymentMethod on Customer.
- Backend: attach saved PaymentMethod to Customer and persist IDs in Firestore (optional next step).

5) Send Money
- Flutter: call `/payments/p2p/initiate` with:
  - `recipient_user_id`, `amount`, `currency`, `payment_method_id` (backend will look up Customer and recipient account via Firestore; sender UID from token).
- Backend performs platform charge and transfer; writes transaction record to Firestore.
- Display receipt with `payment_intent_id` and `transfer_id`.

6) Clean-Up Plaid
- Remove Plaid UI and calls from Flutter.
- Optionally disable Plaid routes in backend.

7) Hardening & Ops
- Add idempotency keys for POST endpoints (payments/transfers).
- Add rate limiting and improved error responses.
- Confirm webhook signature verification and retry handling.

## Deliverables
- Auto-onboarding endpoint that ensures `stripe_account_id` and `stripe_customer_id` in Firestore.
- Simplified P2P initiation using Firestore lookups.
- Flutter UI updates: onboarding + gating + send-money + receipts.
- Removal of Plaid dependencies in app/backend.

## Inputs Needed
- Public webhook URL (domain/ngrok).
- Firebase project ID and service account path.
- Confirm: cards-only payments initially; no ACH.
