# Backup & restore

`requirements.md` §7 / §9(11): **never lose data.** p1.10 gives the user one encrypted file
that holds everything, that only their passphrase can open, and that restores exactly on the
same device or a new one. It is a store-release prerequisite
(`DEVELOPMENT_PLAN.md` Phase 1 exit gate).

## Pieces

| Piece | Lives in | Does |
|-------|----------|------|
| `BackupDocument` | `core/lib/src/backup/backup_document.dart` | The versioned, still-plaintext shape. Parses + validates JSON. |
| `BackupService` | `core/lib/src/backup/backup_service.dart` | `export()` reads the whole DB into a document; `import(doc)` replaces the whole DB with one. |
| `BackupCipher` | `core/lib/src/backup/backup_cipher.dart` | `seal` / `open` — AES-256-GCM under a PBKDF2 passphrase. |
| `BackupFileGateway` | `app/lib/src/backup/backup_gateway.dart` | The one file-system touch: system "save as" / "open" via `file_picker`. Interface + fake for tests. |
| `BackupController` | `app/lib/src/backup/backup_controller.dart` | Wires the three together; turns every expected failure into a result value. Since p2.3, `export()` first runs an optional `sweepRetention` hook so scheduled auto-deletion is applied before the snapshot. |
| `BackupPage` | `app/lib/src/backup/backup_page.dart` | UI. Reached from **Settings → Data → Backup & restore**. |

## The document

```jsonc
{
  "format": "olf.backup",
  "formatVersion": 1,          // bump when the JSON layout changes incompatibly
  "appSchemaVersion": 6,       // the DB schemaVersion this was taken from
  "createdAt": "2026-08-29T12:30:00.000Z",
  "tables": {
    "periods": [ { "id": 1, "start_date": 1724930000, "end_date": null }, ... ],
    ...                        // every table, raw column -> value maps
  }
}
```

- Rows are copied **raw** (`SELECT *` → `INSERT`). Only `int` / `double` / `String` / `bool` /
  `null` ever appear, so integer `DateTime`s, `REAL` temperatures and string enum names make
  the round trip byte-for-byte. "Reproduces all data exactly" holds by construction.
- `BackupDocument.fromJson` throws `BackupFormatException` on: a wrong `format`; a missing or
  non-integer `formatVersion`; a `formatVersion` **newer** than this build; a missing
  `appSchemaVersion`; an unreadable `createdAt`; malformed `tables`. A version **older** than
  current falls through to a forward-migration hook — empty today, the place to translate old
  layouts when `formatVersion` first rises.
- `formatVersion` is **not** the database `schemaVersion`. The DB version travels as
  `appSchemaVersion`; `BackupService.import` refuses a document whose `appSchemaVersion` ≠ the
  running build's rather than risk a lossy restore (a future version can migrate instead).

## Restore is whole-database replace

`BackupService.import` runs, in **one transaction**:

1. `DELETE FROM` every table, children before parents (the only FK is
   `daily_symptom_entries.symptom_type_id → symptom_types.id`).
2. `INSERT` every row from the document, parents before children.

All-or-nothing: a failure part-way leaves the existing data intact (the wipe is in the same
transaction). After it commits, `notifyUpdates` fires for every table so open screens rebuild.
There is **no merge and no selective import** — restoring overwrites everything.

`tableOrder` in `backup_service.dart` lists every table. `backup_service_test.dart` asserts it
equals the live schema, so adding a table without updating the list fails there.

## Encryption

`BackupCipher.seal` produces:

```
"OLFBK1"                     6 bytes, ASCII magic (trailing digit = container version)
uint32 big-endian            length of the header that follows
header JSON                  { kdf, iterations, salt, cipher, nonce, mac }  — all public
AES-256-GCM ciphertext       of the UTF-8 JSON document
```

- **Key** = PBKDF2-HMAC-SHA256(passphrase, 16-byte salt), 210 000 iterations. The count is in
  the header, so a later backup can raise it and old files still open.
- **Cipher** = AES-256-GCM (12-byte nonce). The GCM tag is stored in the header.
- A **wrong passphrase** (or any tampering) fails the tag → `BackupPassphraseException`. This
  is deliberately a different type from `BackupFormatException` so the UI can say "wrong
  passphrase" versus "this isn't an olf backup".
- `validateBackupPassphrase` requires ≥ 8 characters. The passphrase is **never stored** and
  cannot be recovered.
- Provided by the `cryptography` package (pure Dart, Dart ecosystem — not ad/analytics, the
  dependency-audit denylist is unaffected), added to `core`.
- This is a **separate secret** from the at-rest SQLCipher key (p0.4). Backup never reads or
  derives that key.

## The file

- Suggested name `olf-backup-YYYY-MM-DD.olfbackup`.
- Written and read through the platform **document picker** (`file_picker` → SAF on Android,
  `UIDocumentPicker` on iOS). No storage permission, no `AndroidManifest.xml` change.
- All plugin contact is inside `FilePickerBackupFileGateway`; everything above it takes the
  `BackupFileGateway` interface, so widget tests use an in-memory fake (same pattern as p1.7's
  `ReminderScheduler`).

## Tests

| File | Covers |
|------|--------|
| `core/test/backup/backup_document_test.dart` | Versioning: rejects newer / non-int / wrong-`format` / malformed; round-trips; older version still parses. |
| `core/test/backup/backup_cipher_test.dart` | seal→open; wrong passphrase + tampered bytes → `BackupPassphraseException`; garbage / truncated → `BackupFormatException`; passphrase length. |
| `core/test/backup/backup_service_test.dart` | export → fresh DB → import reproduces every table exactly; replace-not-merge; schema mismatch refused; failed insert rolls back; `tableOrder` == schema. |
| `app/test/backup/backup_controller_test.dart` | Round trip + every result branch (saved / cancelled / wrong passphrase / bad file) through a fake gateway; the p2.3 `sweepRetention` hook runs before the snapshot, and a `null` hook is skipped. |
| `app/test/backup/backup_flow_test.dart` | Widget: Settings → Backup page → export → wipe → restore → data back, pops home; wrong passphrase reported. |

The real `file_picker` SAF / `UIDocumentPicker` dialogs are exercised **manually / on-device**
only — CI covers the gateway seam with a fake, like p1.7's notification scheduler.

## Deferred (see `DEVELOPMENT_PLAN.md` §9)

- KDF runs on the **main isolate** — move to a background isolate (and consider Argon2id).
- JSON is **not compressed** before encryption — add gzip as history grows.
- Backup passphrase and the DB-at-rest key are **independent** — could derive both from one.
- Scheduled auto-deletion (p2.3) pre-purges every backup written **after** a retention window
  is set (`BackupController.export` sweeps first), but does **not** reach `.olfbackup` files
  already saved to disk — the app keeps no record of where they went.
- Restore hard-refuses a different `schemaVersion` — no cross-version format migration yet.
- `.olfbackup` isn't a registered file type; no "open with olf" from a file manager.
- No automatic / periodic / cloud backup.
