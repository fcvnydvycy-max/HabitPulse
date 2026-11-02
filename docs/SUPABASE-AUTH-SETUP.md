# HabitPulse — Supabase Auth setup

This is a configuration checklist for the project owner. It is not a migration and does not require sharing passwords, keys, or tokens with anyone.

## Keep the project free

- Keep the Supabase project on the Free plan.
- Do not enable billing or add a payment method.
- Do not enable paid add-ons.
- Free-plan quotas and product terms can change; check the dashboard before enabling new services.

## Authentication settings to configure later

In Supabase Dashboard → Authentication → Providers:

1. Enable Email provider with email + password.
2. Keep email confirmation enabled for real users. Configure the confirmation email URL only after the production domain and callback paths are finalized.
3. Do not enable anonymous sign-in for the real HabitPulse user flow.
4. Do not enable public OAuth providers unless there is a clear need and the redirect URLs have been configured.

In Authentication → URL Configuration:

- Site URL should eventually be the published HabitPulse HTTPS URL.
- Add only the exact local/test and production redirect URLs needed by the app.
- Do not use wildcard redirect URLs for production.

## Frontend integration requirements

- Use the Supabase publishable key (or legacy anon key) in the browser only.
- Never put the service_role key, database password, personal access token, or secret key in HTML, JavaScript, GitHub, or browser storage.
- Use Supabase Auth sessions; do not store user passwords or PINs in LocalStorage.
- On sign-up, send only non-sensitive display metadata such as a display name and optional username. The database trigger creates the profile.
- On sign-in, use the authenticated user's UUID as the owner key for database records.
- On sign-out, clear in-memory user data and return to the sign-in screen.
- Password reset must use Supabase's password recovery flow and an exact configured redirect URL.
- Treat email addresses as private; friend discovery uses friend codes.

## Do not configure yet

Do not change Authentication settings until the app integration is ready to test. This document is preparation only. The database migration has not been applied and the published app is not connected to Supabase.
