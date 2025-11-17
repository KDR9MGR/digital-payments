## What Will Change

* App will use your Cloud Run HTTPS base URL everywhere.

* App will initialize Stripe with your live publishable key.

* Backend will read live secret key and webhook secret from Cloud Run env/Secret Manager (not committed).

* Connect onboarding will return users back into the app via a redirect URL you control.

* Visible labels will use "Digital Payments" (remove any "Stripe" text in UI labels).

* Single production environment only (remove localhost/Android emulator URLs).

## Exact App Updates

1. `lib/routes/routes.dart`

   * Replace `_detectBaseUrl()` to return your Cloud Run URL (no platform branching).

   * Set `_stripePk` to `pk_live_51SEcihGeG3YjuRGbzDXziTISGZum98th9D0ZQA3CVJcewtdBNeSsy2rILIrx4CI8UwEyrSLIqLzoeJnTecs5vbGc00Q0gqS1Oc`.
2. UI labels

   * Update any remaining visible "Stripe" labels to "Digital Payments" (e.g., navigation labels).
3. Onboarding redirect

   * Continue launching external onboarding link.

   * Ensure redirect URL configured in backend points back to the app (universal link or app scheme) so users return to OnboardingScreen which will poll status and proceed.

## Backend Config (Cloud Run)

* Env vars/secrets to set:

  * `STRIPE_SECRET_KEY=sk_live_...` (use Secret Manager)

  * `STRIPE_WEBHOOK_SECRET=<live webhook secret>`

  * `STRIPE_ENVIRONMENT=live`

  * `STRIPE_CONNECT_REFRESH_URL=https://your-domain/onboarding/refresh`

  * `STRIPE_CONNECT_REDIRECT_URL=https://your-domain/onboarding/complete` (this should deep-link back to the app)

  * `FIREBASE_PROJECT_ID=<prod project>`

  * `GOOGLE_APPLICATION_CREDENTIALS=/workspace/service-account.json` (or mounted path)

  * `ALLOWED_ORIGINS=https://your-domain`

* Stripe: add webhook endpoint to Cloud Run `/webhooks/stripe` and set signing secret.

## Redirect-to-App Options

* Prefer HTTPS Universal Link/App Link on your domain that opens the app.

* If not available, use custom scheme `digitalpayments://onboarding/complete` and configure Android/iOS deep link handling in Flutter; backend `STRIPE_CONNECT_REDIRECT_URL` should use this scheme.

## Verification Steps

1. Onboarding

   * Ensure/connect account, open link, complete KYC; confirm app returns and shows `Status: enabled`.
2. Payments

   * Create customer, setup intent, attach payment method; run a small payment; confirm webhook `payment_intent.succeeded` and Firestore transaction.
3. P2P Transfer

   * Initiate P2P; verify recipient got transfer; confirm logs and records.
4. App Smoke

   * Login, dashboard, send money, QR code; no Stripe brand text in UI.

## Notes on Secrets

* The provided live secret key will be configured in Cloud Run/Secret Manager only; it will NOT be committed to source code.

If you confirm, I will:

* Update the app config to the Cloud Run URL and live publishable key.

* Adjust labels to "Digital Payments".

* Guide Cloud Run env/secret setup and the redirect URL to return users to the app.

* Run the end-to-end verification checks and report results.

Please processed with all above
