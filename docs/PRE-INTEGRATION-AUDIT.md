# HabitPulse — pre-integration audit (staging)

Date: 2026-11-02

## Status

- The Supabase project `HabitPulse-Test` was created on the Free plan in a European region.
- The initial schema migration was run successfully in that test project.
- The user verified 13 public tables and RLS enabled on all 13.
- The user verified the four Storage policies and the `progress-photos` bucket configuration: private, 5 MiB per object, JPEG/PNG/WebP/HEIC.
- These checks confirm that objects and policies exist. They do **not** yet prove that cross-account access is blocked or that every workflow works.
- Production GitHub Pages and the `main` branch remain unchanged.

## Critical legacy-app findings

The current `index.html` is a single-page app whose authentication and data model are not safe to expose to multiple real users yet:

1. The app stores a global object containing all user accounts and their records in one LocalStorage value. The legacy cloud-save path writes the entire object to one shared Firestore document when Firebase is configured.
2. Account PINs and admin authentication material are handled in browser code and stored in the client-side data model. A credential-like value is embedded in the source. Treat it as compromised: do not reuse it; rotate it anywhere it may still be active. Do not copy it into documentation, issues, screenshots or the new backend.
3. The legacy app hardwires an admin account and a default account identity in its initialization path. That behavior must be removed from the new auth flow.
4. The existing Face ID/WebAuthn flow creates/checks credentials locally without a server challenge/response verification. It is not a replacement for Supabase Auth and must not be carried over as account authentication.
5. Physical progress photos are stored as Data URLs in the legacy user object. They must be exported and uploaded separately to the private Storage bucket; never copy them into profile fields or a shared JSON document.
6. The current friends ranking is derived from the global in-browser user collection. It must be replaced by minimal, consented friend/challenge data returned through RLS-protected tables or narrow RPCs.

## Schema coverage review

The initial schema covers the primary domains:
- profiles, habits, habit_entries
- workouts, meals, tasks, body_metrics, progress_photos
- friend_requests, friendships
- challenges, challenge_members, challenge_entries

The existing UI also stores data that is not yet represented by the schema/adapter:
- weekly gym routines/templates (including day-of-week exercise plans)
- water intake by day
- favorite meals / saved meal templates
- meals grouped by day and meal type (some fields can map to `meals`, but mapping must be explicit)
- exams / academic calendar details
- study-minute totals and study/pomodoro history
- user preferences and some goal/target settings
- legacy habit weekly arrays/streak fields (must be normalized into dated `habit_entries` without losing historical meaning)

Do not begin a one-way import until the missing data model is decided and a tested export exists. Prefer explicit relational tables for records that need querying; use JSON only for bounded configuration objects such as a weekly routine when justified.

## Adapter review

`supabase/browser-client.js` is a foundation, not a complete app integration:
- Auth methods exist for email/password sign-up, sign-in, sign-out and password reset.
- Profile, personal-record, friend, challenge and photo helper methods exist.
- UI wiring is not present in `index.html`.
- The current adapter has no complete importer/exporter and no migration rollback.
- Photo uploads enforce type and 5 MiB size, but client-side compression and EXIF/location metadata stripping are not implemented. Do not upload sensitive body-progress images until that pipeline is added and tested.
- HEIC is allowed by Storage, but browser preview/compression support is inconsistent. The UI should convert HEIC to JPEG/WebP where supported or clearly explain when the browser cannot process it.
- The photo removal flow should be made retry-safe: coordinate metadata and object deletion so a transient failure cannot leave confusing orphan records/objects.
- The adapter's challenge and friends flows require integration tests against the actual schema and two accounts before UI wiring.

## Security review notes

Positive controls observed in the migration:
- RLS is enabled on all 13 application tables.
- Personal-record policies bind ownership to `auth.uid()`.
- Profiles are owner-only through direct table access; friend-facing profile fields are exposed through narrow RPCs.
- Friend requests are participant-readable; sending/responding is routed through RPCs.
- Storage bucket is private and object paths are restricted to the authenticated user's UUID folder.
- Security-definer functions inspected use a fixed `search_path` and check the current authenticated user where appropriate.

Still required before production:
1. Inspect every function's execute privileges and ensure no unintended `PUBLIC` or `anon` execution remains.
2. Verify the challenge membership/entry policies using two independent authenticated users; confirm users cannot join a challenge unless the creator is an accepted friend and cannot forge another user's entries.
3. Review whether challenge-entry notes should be visible to every challenge member; avoid storing private notes in a member-visible table.
4. Verify profile RPCs return only the intended public fields and do not reveal email, measurements, habits, nutrition or photos.
5. Run negative tests: user A cannot select/update/delete user B's habits, meals, workouts, tasks, metrics, photo metadata or Storage objects.
6. Run positive tests: each user can CRUD their own records; accepted friends can discover only allowed profile fields; challenge members see only the challenge data needed for ranking.
7. Confirm Storage signed URLs are short-lived and are not persisted in LocalStorage or public profile fields.
8. Add rate limiting/abuse controls for friend-code lookup and friend requests where feasible.
9. Review Supabase Auth email confirmation, password policy, redirect URLs and recovery settings.
10. Confirm the project stays on Free; do not enable billing or upgrade prompts.

## Required manual staging tests

Use two disposable test accounts with addresses you control. Do not use the real account's password or personal data.

- Sign up account A and account B through Supabase Auth.
- Verify the profile trigger creates exactly one minimal profile for each.
- Sign in as A; create one habit and one private photo test object.
- Sign in as B; verify A's habit, photo metadata and Storage object are invisible and inaccessible.
- Attempt forged insert/update/delete requests using A's IDs while authenticated as B; they must fail.
- Verify B cannot read A's profile directly, but a friend-code lookup returns only the three documented fields.
- Verify challenge creation, creator membership, friend-only joining and per-member entries.
- Delete test accounts and confirm cascading cleanup.

## Migration and release rules

- Keep all work on `habitpulse/auth-data-foundation` until reviewed.
- Do not merge to `main`, enable GitHub Pages from a new branch, or change the production app without explicit approval.
- Before importing anything, add a downloadable JSON export and photo export/manifest to the legacy app and verify a restore from that export.
- Never upload a service-role key, database password, GitHub token or other secret to browser code or GitHub.
- The Supabase publishable/anon key may be used in the browser only after RLS and grants have passed negative tests.
- No automatic billing; monitor Free quotas and understand that inactivity may pause the project.

## Next implementation milestone

Complete a field-by-field mapping document from the legacy `createUserAccount()` object and UI write paths to the backend schema. Extend the schema deliberately for missing academic, water, saved-meal and gym-routine data. Then add export/import tooling and a test harness. Only after those steps should the login screen and modules be wired to Supabase.
