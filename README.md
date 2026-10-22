# Teach Connect — Flutter app for lms_k12

Native Flutter client for the K-12 ERP (`D:\lms_k12` web app + `D:\next_lms_erp` Laravel backend), with
[Shorebird](https://shorebird.dev) code push so Dart changes can ship without a store release.

## How it mirrors lms_k12

| lms_k12 (web) | This app |
| --- | --- |
| `app/login/page.tsx` + `AuthContext` — `POST /api/api-login`, forgot password, 30-min idle and daily session expiry | `ui/login_page.dart`, `core/auth_controller.dart` (JWT kept in secure storage; same expiry rules) |
| `useMenuRights` + `buildMenuTree` — `POST /api/menu-rights`, 3 levels, rights-filtered, hidden/deferred links removed | `core/menu.dart` (same tree rules), `ui/menu_page.dart`, `ui/home_page.dart` |
| `routeMapper.ts` — menu link → web route | `core/route_mapper.dart` + **generated** `core/route_table.g.dart` |
| Every page under `app/**` (~3,100) | **Native Flutter screens, no WebView.** Pages are server-driven: Mobile Page Builder layouts (`/api/mobile-page-builder/runtime/{slug}`) are rendered by `ui/sdui/page_renderer.dart`; stat pages by `DynamicPageScreen`; role dashboards and API-backed rows by the generic `DataScreen` (`ui/native_screens.dart`) |
| Menu search | `ui/search_page.dart` |

**Scope, stated plainly:** there is no WebView. Each menu row the user has mobile access to opens a native
screen if it has one - a Mobile Page Builder page (forms, search-and-save lists), a native_dynamic stat page,
a role dashboard, or an ERP endpoint shown by the generic data screen. A row with none of these is shown
with a "Soon" tag. The ~3,100 bespoke web pages are not individually re-implemented: a page becomes native by
being authored in the Mobile Page Builder (admin, no app release) or by adding a Dart screen and mapping it in
`MobileMenuRepository.targetFor`. Because builder pages are server-driven, new pages ship without a store release
or even a Shorebird patch.

Not included yet: Google sign-in (web login has it when `NEXT_PUBLIC_GOOGLE_CLIENT_ID` is set), push
notifications, and the synthetic "AI insights" level-3 rows the web adds.

## Configure

The ERP host, set at build time (defaults in `lib/core/config.dart`):

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

* `API_BASE_URL` — the Laravel ERP (login, menu, handoff).
* Android blocks plain `http://` outside debug builds; use HTTPS for release.

## Keeping routes in sync

```
node tool/gen_routes.mjs D:/lms_k12     # rewrites lib/core/route_table.g.dart
```

Re-run it when `app/data/routeMapper.ts` changes. The skip lists in `route_mapper.dart`
(`_deferredPrefixes`, `_hiddenLinks`, `_noScreenLinks`) are hand-copied from `lib/roadmap/index.ts` and
`app/data/menuMappers.ts`.

## Code push (Shorebird)

`shorebird_code_push` is wired in (`core/updater.dart`): the app checks for a patch on start and downloads
it in the background; it applies on the next restart. One-time setup (needs your Shorebird account):

```powershell
# install CLI (Windows)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -UseBasicParsing 'https://raw.githubusercontent.com/shorebirdtech/install/main/install.ps1' | iex

shorebird login
shorebird init          # creates shorebird.yaml (app_id) and adds it to pubspec assets
```

Ship a store build, then patch it:

```powershell
shorebird release android --flutter-version=3.44.8     # upload the .aab to Play (and `release ios` for App Store)
# ...change Dart code...
shorebird patch android                                 # live to installed users, no store review
```

Patches can change Dart code and assets only. A new plugin, native/permission change, or Flutter upgrade
needs a new `shorebird release`. Releases are tied to the Flutter version they were built with.

## Android release signing

`android/app/build.gradle.kts` still signs release with the debug key (Flutter default). Create an upload
keystore and wire it before publishing — Shorebird patches must be built from the same signed release.

## Develop

```
flutter pub get
flutter analyze
flutter test
```
