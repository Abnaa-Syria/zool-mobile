# ZoolGo Mobile

Flutter monorepo (Dart pub workspace) for the three ZoolGo apps. The backend, API contract and
screen-to-API map live in the backend repository (`docs/APP_DEVELOPER_GUIDE.md`,
`docs/SCREEN_API_MAP.md`, `docs/MISSING_SCREENS.md`, `zool-go-backend/docs/openapi.yaml`).

| Path | What | Status |
|---|---|---|
| `packages/zool_core` | API client (envelope, errors, one shared token refresh), OTP auth sessions, money / Sudan-time / phone formatting, Arabic error messages | ✅ |
| `packages/zool_ui` | Brand theme from the Figma file (RTL Arabic, Cairo, mint background, Iconsax icons) and shared widgets: OTP login, seat map, hold countdown, QR ticket, route timeline, paged list, states, dialogs | ✅ |
| `apps/broker` | Agent-office app — `com.zoolgo.broker` | ✅ |
| `apps/customer` | Customer app — `com.zoolgo.customer` | next |
| `apps/driver` | Driver app — `com.zoolgo.driver` | after the customer app |

## Run

```bash
flutter pub get                      # once, at the repository root (workspace)
cd apps/broker
flutter run                          # staging API: https://zoolgo-api.nodeteam.site/api/v1
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1   # local backend from the Android emulator
```

- Demo accounts: `docs/APP_DEVELOPER_GUIDE.md` §2 in the backend repo. Locally the login screen offers
  the dev OTP; on staging use the fixed codes the project owner hands out.
- Requests send `X-Client-Platform: android|ios`, so refresh tokens come in the body and are stored in
  the Keychain / Keystore (`flutter_secure_storage`).

## Rules (same as the backend)

- Money is integer minor units (`*Minor`); the app never computes prices, it shows the server quote.
- Dates are shown in Sudan time (UTC+2); `date=` parameters are Sudan days; digits are Latin.
- Branch on error `code`, never on `message`; every Arabic message comes from `kErrorMessages`.
- Purchases send an idempotency key per attempt (reused on a network retry).
- Colors, radii and type come from `zool_ui` (`ZoolColors`, `zoolTheme()`); screens do not hard-code them.

## Tests

```bash
flutter analyze                       # whole workspace
(cd packages/zool_core && flutter test)
(cd apps/broker && flutter test)      # logic, app boot, screen rendering (fails on layout overflow)

# Contract test against a running dev backend (books one seat and cancels it):
(cd apps/broker && LIVE_API=http://localhost:4000/api/v1 flutter test test/live_api_test.dart)

# Review screenshots of the main screens → apps/broker/test/_screens/*.png (not committed)
(cd apps/broker && flutter test test/screens_test.dart --update-goldens)
```
