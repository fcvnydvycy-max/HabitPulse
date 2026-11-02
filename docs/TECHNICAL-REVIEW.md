# HabitPulse — current technical review and remaining release gates

Last reviewed: 2026-11-02
Working branch: `habitpulse/auth-data-foundation`

## What has been prepared

- Initial Supabase schema for profiles, habits, habit entries, workouts, meals, tasks, body metrics, progress-photo metadata, friend requests, friendships, challenges, members and challenge entries.
- Row-level security policies for owner-only personal data.
- Private Storage bucket configuration for progress photos (5 MiB per object; JPEG, PNG, WebP and HEIC).
- Auth-user trigger to create a minimal profile.
- Friend-code lookup, friend-request and friend-acceptance RPCs.
- Challenge creator membership trigger and caller-bound authorization helper functions.
- Profile identity protection and restriction of profile creation to the Auth trigger.
- Security test plan, Auth setup checklist and local-data preservation plan.

## Legacy app audit observations

The existing `main/index.html` is a single-page client app. It currently stores the entire multi-user state object in LocalStorage under `habitpulse_ios_v9_clean`. The code also contains legacy client-side PIN/password handling, a forced admin account path and a global Firestore document path. This data model must not be carried into the new backend.

The app's current Firebase code is conditional on injected Firebase configuration and is not a ready-to-use Supabase integration. The new Supabase client, Auth UI and per-user data access have not yet been implemented.

## Important limitations and unverified items

- The SQL has been reviewed and corrected for a function-body delimiter issue, but it has **not** been parsed or executed against a PostgreSQL/Supabase test database.
- RLS policies and RPC behavior have **not** been tested with separate authenticated users.
- The migration is a first backend foundation, not yet a production-ready complete application.
- The friend system currently provides profile discovery and friend relationships, but no leaderboard sharing of private habit details.
- Challenge score/entry semantics need product decisions before a public ranking is built.
- No profile avatar upload policy or general media upload feature has been implemented.
- Photo upload compression, EXIF stripping, signed URL lifecycle and device compatibility still need implementation and testing.
- No automated migration importer has been written. The legacy store must be backed up and mapped field-by-field before import.
- No changes have been made to the production `main` branch or deployed GitHub Pages site.

## Next engineering steps

1. Validate the complete SQL using a disposable PostgreSQL/Supabase test environment. Do not use the user's production project for first-run debugging.
2. Resolve all SQL and RLS test failures, then record actual test outcomes.
3. Create a frontend Supabase integration on this isolated branch, preserving the current app until the new version passes tests.
4. Build export/import tooling for the existing LocalStorage data, with no automatic deletion or overwrite.
5. Test signup, email confirmation, login, logout, password reset, two-user isolation, friend flows, challenges and private photo access.
6. Only after explicit user approval, apply the migration to the user's Supabase project and connect a staging deployment.
7. Do not merge to `main` or replace the live site without explicit user approval.

## Free-plan constraint

Keep Supabase on the Free plan. Do not enable billing, add a card, or deploy paid services. Supabase Free projects can pause after inactivity and have quotas; this must be explained before launch. Storage limits and current plan terms must be rechecked at launch because provider pricing can change.
