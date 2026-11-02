# HabitPulse — security verification plan

Status: prepared, not yet executed against the live Supabase project.

This plan is for the isolated branch `habitpulse/auth-data-foundation`. It does not change the deployed GitHub Pages app.

## Important constraints

- Keep the Supabase project on the Free plan. Do not enable billing or enter a payment method.
- Do not put a Supabase service-role key, database password, or personal access token in the browser or repository.
- Do not run the schema migration until the checks below have been reviewed.
- Use two test accounts with data created specifically for testing. Do not use real personal measurements or photos.
- Do not claim the policies are verified until the tests have actually been run and their results recorded.

## Preconditions

1. Confirm the project is still on the Free plan and the database is healthy.
2. Confirm the migration file is the current version in this branch:
   `supabase/migrations/001_initial_schema.sql`.
3. Create two disposable test accounts, User A and User B, through Supabase Auth after the migration is installed.
4. Use separate browser sessions (for example, a normal window and a private window) so the accounts do not share a session.

## Manual isolation tests

Create one test habit, workout, meal, task, body metric and progress photo metadata row as User A. Repeat with distinct data as User B.

| Test | Expected result |
|---|---|
| A selects their own habits, entries, workouts, meals and tasks | Only A's rows appear |
| B selects those same tables | Only B's rows appear |
| A selects body metrics and progress photo metadata | Only A's rows appear |
| B attempts to select A's private rows by UUID | No rows returned |
| A uploads a file under `<A-auth-uid>/<filename>` to the private `progress-photos` bucket | Allowed |
| B lists or downloads A's object | Denied |
| B uploads into A's folder | Denied |
| A searches B using B's exact friend code | Only basic profile fields returned |
| A calls the friend lookup with a random code | No profile returned |
| A sends B a friend request by code | Request is created |
| B accepts the request using `respond_to_friend_request` | Friendship is created |
| A and B list their friends | Each sees the other's basic profile |
| A tries to accept a request addressed to B | Function rejects the operation |
| A creates a challenge | A is automatically added as a member |
| A's friend B joins the challenge | Allowed |
| Unrelated User C attempts to join B's challenge | Denied |
| A/B submit challenge entries | Members can see entries for that challenge only |

## Known intentional boundaries

- Friend-facing profile data is limited to the output of dedicated RPC functions. Do not expose the full `profiles` table to friends.
- Habits, food logs, workouts, body measurements, task descriptions and progress photos are private. The current schema does not publish a habit-completion leaderboard or share detailed health/fitness data.
- Friend-request acceptance and friend-code requests must go through their RPC functions; direct client updates to requests and direct inserts into friendships are intentionally not granted.
- Photo storage is private, with a 5 MiB per-object limit and image MIME allowlist. Client-side compression and actual device upload tests are still required.
- The schema is a foundation, not yet a complete application integration. No migration, auth flow, photo upload, data migration or production release has been performed.

## Release gate

Do not connect the production app or invite real friends until:
1. The migration has been reviewed and applied to a disposable/test project or a safe test environment.
2. Every isolation test above has a recorded passing result.
3. The frontend uses only the Supabase publishable/anon key, never a service-role key.
4. Registration, email confirmation, sign-in, sign-out and password reset have been tested.
5. Existing browser-local data has an export and restore path before any migration or storage reset.
6. The user has explicitly approved any change that affects the published app.


## Additional hardening included in the migration

- Profile rows are owner-only. Friend-facing profile data is returned through narrow RPCs.
- A database trigger prevents a client from changing the profile UUID or generated friend code.
- Friend requests can only be created through `request_friend_by_code()`; direct client INSERT permission and the direct-insert policy are removed.
- Challenge and friendship helper functions bind checks to the authenticated caller rather than accepting an arbitrary claimed user ID.

