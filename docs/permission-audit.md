# Android permission audit

| Permission | Scope | Reason |
|---|---|---|
| `CAMERA` | All supported APIs | Live preview and capture |
| `WRITE_EXTERNAL_STORAGE` | Through API 28 | Legacy MediaStore capture writes |
| `READ_EXTERNAL_STORAGE` | Through API 32 | Browsing media created by older installs |
| `READ_MEDIA_IMAGES` | API 33+ | User-requested gallery browsing |
| `READ_MEDIA_VISUAL_USER_SELECTED` | API 34+ | Android selected-photo access |

Rana-owned MediaStore rows can be written and reopened on modern Android without
broad storage permission. Camera permission is independent from gallery access;
denying gallery access must not disable capture on API 29+.

The manifest declares no microphone, location, contacts, network analytics, or
broad all-files permission. Diagnostic telemetry is local, numeric, bounded to
256 samples, and excludes URI/image payloads.
