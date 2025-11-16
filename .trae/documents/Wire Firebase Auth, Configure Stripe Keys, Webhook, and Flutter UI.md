## Assumptions

- Gin server is already running in `backend/`.
- You will provide Stripe test keys and webhook signing secret (already shared).
- Firebase Authentication and Firestore are enabled in your Firebase project.

## Backend Configuration (No code changes yet)

1. Environment variables (set in your runtime):
   - `STRIPE_SECRET_KEY` = your `sk_test_...`
   - `STRIPE_WEBHOOK_SECRET` = `whsec_...`
   - `STRIPE_CONNECT_REFRESH_URL` = `https://digitalpayments.live/connect/refresh`
   - `STRIPE_CONNECT_REDIRECT_URL` = `https://digitalpayments.live/connect/return`
2. Confirm routes:
   - Connect: `/stripe/connect/account`, `/stripe/connect/account-link`, `/stripe/connect/account/:accountID/status`
   - Payments: `/payments/p2p/initiate`
   - Webhook: `/webhooks/stripe`

## Stripe Dashboard Webhook

1. Expose your backend publicly (e.g., `ngrok http 8080`).
2. Add webhook endpoint in Stripe Dashboard → Developers → Webhooks:
   - URL: `https://<public>/webhooks/stripe`
   - Events: `payment_intent.succeeded`, `payment_intent.payment_failed`, `setup_intent.created`, `setup_intent.succeeded`
3. Paste signing secret into `STRIPE_WEBHOOK_SECRET` in backend environment.
4. Send a test event; verify 200 OK and log entries.

## Firebase Integration Plan

1. Auth middleware (planned change):
   - Verify Firebase ID tokens on all protected routes.
   - Attach `uid` to `gin.Context` for downstream handlers.
2. Firestore persistence (planned change):
   - Users collection: store `stripe_account_id`, `stripe_customer_id`, `charges_enabled`, `payouts_enabled`, `onboarding_status`.
   - Transactions collection: store `payment_intent_id`, `transfer_id`, amount, currency, status, timestamps.
3. Backend handlers will update Firestore when:
   - Connected account is created and when status changes.
   - PaymentIntent succeeds and transfer is created.

## Flutter App Wiring

1. Onboarding flow:
   - After Firebase signup, call `POST /stripe/connect/account` with `{user_id:<uid>, email}`.
   - Save `account_id` in Firestore; request `POST /stripe/connect/account-link` and open the returned URL.
   - Poll `GET /stripe/connect/account/:accountID/status`; gate payment UI until `charges_enabled && payouts_enabled` are true.
2. Payment methods:
   - ACH via Plaid: run Plaid Link; send token to backend; create `us_bank_account` PaymentMethod with `/stripe/payment-methods/from-plaid`.
   - Optional cards: initialize Stripe Flutter SDK with `pk_test_...`; use `/stripe/setup-intent` to save card.
3. P2P payment:
   - Call `/payments/p2p/initiate` with sender/recipient IDs, recipient `stripe_account_id`, amount/currency, sender `customer_id`, `payment_method_id`.
   - Show status and store receipt (PI ID + Transfer ID) in Firestore.

## Testing Plan

- Two Firebase test users → onboard both to Stripe Connect.
- ACH/Card test payments for $1; confirm PI success and transfer on Stripe Dashboard.
- Trigger webhook test events and verify backend handling.

## Deliverables (after approval)

- Backend auth middleware validating Firebase tokens.
- Firestore persistence in backend for Stripe IDs, statuses, and transactions.
- Flutter UI updates for onboarding, gating, send-money, and receipts.

## Inputs Needed

- Public webhook URL (or approval to use `ngrok`).
- Firebase service account (or confirm client will write Firestore and backend reads it).
- Final decision on ACH-only vs ACH + cards.
