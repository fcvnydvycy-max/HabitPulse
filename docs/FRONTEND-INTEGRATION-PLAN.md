# HabitPulse — frontend integration plan

## Current decision

Keep the existing GitHub Pages app unchanged while the new backend adapter is reviewed. The new adapter lives at `supabase/browser-client.js` on the isolated branch and is not imported by `index.html`.

## Browser configuration

The app will eventually set a small configuration object before importing the adapter:

```html
<script>
  window.HABITPULSE_SUPABASE_CONFIG = {
    url: 'https://YOUR-PROJECT-REF.supabase.co',
    publishableKey: 'YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY'
  };
</script>
<script type="module">
  import { auth, profile, personalData, friends, progressPhotos } from './supabase/browser-client.js';
  // UI wiring is added after the current legacy auth flow is replaced.
</script>
```

The values above are placeholders. The URL and publishable/anon key can be used in a browser only because authorization is enforced by RLS. Never add a service_role key, database password, personal access token, or secret API key.

## Integration sequence

1. Add a dedicated sign-in / sign-up screen backed by Supabase Auth.
2. Remove the legacy client-side PIN, master-password and admin-account authentication paths from the new branch.
3. Subscribe to Auth state. On sign-out, clear all in-memory user data and show the sign-in screen.
4. Load only the authenticated user's records from the backend. Do not download all users into a global store.
5. Wire the existing UI modules incrementally: habits, gym, meals, tasks, body metrics, friends, challenges and photos.
6. Add loading, empty, offline and error states; do not silently pretend cloud saves succeeded.
7. Use signed URLs for private photos and do not persist them as public URLs.
8. Add an explicit export/backup action before any local-data migration.
9. Test two independent accounts before enabling friend features.
10. Keep the production deployment unchanged until the owner approves the staging result.

## Adapter API currently prepared

- `auth`: signUp, signIn, signOut, requestPasswordReset, updatePassword, onChange, currentUser.
- `profile`: getMine, updateMine.
- `personalData`: list/create helpers for habits, workouts, meals, tasks and body metrics.
- `friends`: findByCode, requestByCode, list, respond.
- `friendRequests`: inbox, sent.
- `habitEntries`: listForHabit, setCompletion.
- `challenges`: create, listMineAndJoined, join, addEntry, listMembers, listEntries.
- `progressPhotos`: upload, signedUrl, remove.

## Important implementation notes

- The adapter is a first integration layer, not a complete UI replacement.
- Existing app state shape is not yet mapped to normalized database rows.
- Habit entries need explicit create/update/list helpers and date handling before the habit module is wired.
- Workout exercise JSON needs a deliberate mapping from the legacy workout shape.
- Meal macros and task categories need validation and unit normalization.
- Challenge creation/joining/entry helpers and request inbox listing still need to be added.
- Photo compression and EXIF metadata stripping are not implemented in the adapter yet. Do not upload sensitive progress images until these are added and tested.
- The app currently uses one multi-user LocalStorage object. Do not load or sync that object into Supabase.

