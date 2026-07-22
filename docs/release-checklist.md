# Release checklist

## Signing

Release builds never use the debug key. Provide either ignored
`android/keystore.properties`:

```properties
storeFile=/absolute/path/to/rana-upload.jks
storePassword=...
keyAlias=...
keyPassword=...
```

or CI secrets `RANA_KEYSTORE_PATH`, `RANA_KEYSTORE_PASSWORD`,
`RANA_KEY_ALIAS`, and `RANA_KEY_PASSWORD`. A release Gradle task fails early
with a clear message when any value is missing. Keystores and property files
must remain outside Git and be backed up in the owner's secrets manager.

Use Google Play App Signing: keep the app-signing key in Play, protect the
separate upload key, document key rotation ownership, and never generate or
commit a replacement key during an automated build.

## Pre-release gates

- Confirm application ID `com.rana.app.rana`, min SDK 24, target SDK 36.
- Run formatter, reproducible Pigeon/Riverpod generation, analyzer, all Flutter
  tests, Kotlin JVM tests, Android lint, and release bundle build.
- Confirm parity thresholds and permission audit.
- Complete the physical device matrix, including orientation cold starts and
  lifecycle stress.
- Verify low-storage, revoked-permission, interrupted Film Roll, retry,
  reinitialize, settings, and lens-fallback UI actions.
- Inspect local diagnostic output for absence of media identifiers.
- Tag only a clean commit already pushed to the remote.
