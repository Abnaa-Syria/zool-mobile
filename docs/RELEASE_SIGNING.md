# Release signing (Android)

All three apps are signed with one **upload key** (alias `zoolgo`). Google Play App Signing
holds the final app signing key; this key only signs what we upload.

- Keystore: `zoolgo-upload.jks` — kept **outside the repo** (owner's machine + an offline backup).
- Each app reads `apps/<app>/android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=zoolgo
storeFile=C:/path/to/zoolgo-upload.jks
```

- Without `key.properties` a release build is signed with the debug key (fine for local work,
  not accepted by Google Play).
- Losing the upload key is recoverable through Play Console support (key reset), but losing it
  before the first upload means re-creating it — back it up.
- Firebase / Google sign-in need the key's SHA-1 and SHA-256: `keytool -list -v -keystore zoolgo-upload.jks -alias zoolgo`.

An APK signed with this key cannot update one signed with the debug key (signature mismatch):
uninstall the old test build first.
