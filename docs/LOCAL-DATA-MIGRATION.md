# HabitPulse — local data preservation and migration plan

## Current browser data

The existing app stores its complete `globalStore` JSON object in browser LocalStorage under:

- `habitpulse_ios_v9_clean`
- Session pointer: `habitpulse_remembered_user_v9`
- Theme: `habitpulse_theme_v1`

The app contains multiple user objects inside one local store. It also includes a hard-coded admin account path and client-side PIN/password logic. This design must not be copied as-is into the new multi-user backend.

## Before any migration

1. Keep the current published app unchanged.
2. Export a copy of the LocalStorage value from the same browser/device where the data exists.
3. Keep the export file private and make a second backup in a secure location.
4. Do not upload the export to GitHub, share it in chat, or include it in bug reports. It may contain personal data and photos.
5. Record the export date and the browser/device used.
6. Verify that the export parses as JSON and that it includes the expected user data before proceeding.

## Safe browser export

On the device/browser containing the HabitPulse data, open the existing HabitPulse site and use the browser developer console to run:

```js
const raw = localStorage.getItem('habitpulse_ios_v9_clean');
if (!raw) throw new Error('No HabitPulse local data found in this browser');
const parsed = JSON.parse(raw);
if (!parsed || !parsed.users || !parsed.currentUserId) {
  throw new Error('The stored data does not match the expected HabitPulse format');
}
const blob = new Blob([JSON.stringify(parsed, null, 2)], { type: 'application/json' });
const url = URL.createObjectURL(blob);
const a = document.createElement('a');
a.href = url;
a.download = 'habitpulse-private-backup.json';
a.click();
URL.revokeObjectURL(url);
```

This code only downloads a local backup; it does not send data anywhere. Do not run it on a shared/public computer.

## Migration mapping (provisional)

The legacy store must be inspected and mapped field-by-field before import. Likely destinations:

- Habit definitions and completion history → `habits`, `habit_entries`
- Gym sessions and exercises → `workouts`
- Meals and macros → `meals`
- University/personal tasks → `tasks`
- Weight/body-composition history → `body_metrics`
- Progress image data URLs → private Storage objects in `progress-photos`, with metadata in `progress_photos`
- Friend lists and ranking data → do not import as trusted friendships; users must establish friendships again through verified friend codes/invitations.
- Legacy account passwords, PINs, master passwords, admin flags and remembered sessions → never import.

## Import safeguards

- Do not overwrite or delete the original LocalStorage data during import.
- Import only data belonging to the authenticated account that owns it.
- Validate dates, units, IDs, duplicate rows and photo sizes before writing.
- Convert photos to supported image formats and compress them before upload; the private bucket currently limits each object to 5 MiB.
- Import into a test account first and compare record counts and sample values.
- Keep a rollback copy until the user confirms that the new app has all expected data.
- The migration tool must be idempotent or maintain a per-record import map to avoid duplicates on retry.

No data has been exported, uploaded, migrated, or deleted by this document.
