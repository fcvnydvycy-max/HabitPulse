# HabitPulse — legacy-to-backend data mapping

Source reviewed: `index.html` on `habitpulse/auth-data-foundation`, especially `createUserAccount()`, the legacy LocalStorage store and the existing Supabase adapter.

This is a planning map, not an import script. No user data is read or moved by this document.

| Legacy field / feature | Current backend destination | Decision / gap |
|---|---|---|
| `username`, `profile.name` | `profiles.username`, `profiles.display_name` | Map after validation and uniqueness handling. |
| `profile.age`, `profile.weight`, `profile.height` | No safe complete destination yet | Do not put body weight/height in public profiles. Add private profile-settings or metrics fields; decide whether age is needed at all. |
| `profile.goal`, `targetKcal`, `targetProtein`, `targetCarbs`, `targetFat`, `targetWaterLiters` | Not currently represented | Add a private per-user settings table or a strictly owner-only settings row. |
| `pin`, legacy admin role, local Face ID credential ID | None | Never import. Supabase Auth owns credentials. Re-enrol passkeys only after a real server-verified WebAuthn design; do not reuse legacy Face ID IDs. |
| `friendCode`, `friends` | `profiles.friend_code`, `friend_requests`, `friendships` | Generate backend friend codes; do not preserve arbitrary legacy IDs or automatically trust old friend links. Require consent/reconfirmation. |
| `habits[]` identity/title/emoji/color | `habits` | Map fields; use new UUIDs and preserve a migration mapping if child entries reference old IDs. |
| `habits[].days[7]`, `baseStreak`, `lastWeekMondayISO` | `habit_entries` | Legacy booleans are relative to a rolling week, not a complete dated history. Need an explicit reference Monday and must not invent historical dates. Preserve streak metadata only if its meaning is verified. |
| `weeklyGymRoutine[day].title/exercises` | `workouts` is for completed sessions, not templates | Missing gym-routine/template table. Add a separate routine table with day-of-week and structured exercise items. |
| `waterGlassesByDay[7]` | Not currently represented | Missing dated water-intake table. Weekly array alone is ambiguous without the Monday date. |
| `favoriteMeals[]` | `meals` stores consumed meal records | Missing saved-meal/template table; do not import favorites as consumed meals. |
| `mealsByDay` | `meals` | Map each consumed item with explicit date/time, meal type, description and macros. Inspect actual UI write paths before defining exact conversions. |
| `tasks[]` | `tasks` | Map after inspecting every task shape and due-date/category representation. |
| `exams[]` | No dedicated table | Could use a separate academic-events table; do not silently mix exams with generic tasks because calendar fields/status may differ. |
| `studyMinutesWeek` and Pomodoro state/history | Not currently represented | Decide whether to persist study sessions and derive weekly totals, rather than storing a mutable total only. |
| `physiquePhotos[]` Data URLs | `progress_photos` metadata + private Storage object | Export separately; validate image; strip EXIF/location metadata; compress/convert; upload under `auth.uid()/...`; verify signed URL and cross-user denial. Never import Data URLs into Postgres JSON. |
| `weightHistory[]` | `body_metrics` | Map only records with real dates and valid values; do not infer missing measurements. |
| Theme and display preferences | Browser-local preference or private settings | Keep non-sensitive UI-only preference local unless cross-device sync is specifically wanted. |

## Required discovery before writing an importer

1. Inspect all UI handlers that add/edit/delete habits, workouts, meals, tasks, exams, study sessions, routines, water and photos.
2. Record actual legacy object shapes and date semantics from the source; do not assume that similarly named fields share units.
3. Build an export-only tool first. It must download JSON plus a separate photo manifest/blobs and report record counts.
4. Add a dry-run importer that validates and reports skipped/ambiguous records without writing.
5. Test export and restore in a disposable browser profile before any cloud import.
6. Add schema migration `002` only after the missing entities and constraints are agreed and reviewed.
7. Use idempotent import keys and a migration log so retrying cannot duplicate records.
8. Keep account credentials, old PINs, admin flags and local WebAuthn credential IDs out of the export/import payload.

## Important limitation

The existing rolling seven-day habit and water arrays do not contain a full historical timeline by themselves. Only import dates that can be grounded in an explicit stored week start or other source data. If dates cannot be established, preserve the current snapshot as a clearly labelled legacy snapshot rather than fabricating daily history.
