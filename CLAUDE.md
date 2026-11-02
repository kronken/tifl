# Spend It For Life (SIFL)

A simple iOS spending tracker. Log a purchase in a few seconds, organise it by your own categories, and see where the money goes per month, per year and per category.

Sister app to *Buy It For Life*, which lives in `../bfl-tracker`.

## Spec & designs

- Build spec: `design/spec.md`. It covers screens, copy, data rules and the build order.
- Design file: `design/sifl.html` (a self-unpacking bundled HTML — open in a browser to view).
- Follow the designs and the design system (Patina) closely when building UI.

## Target & platform

- iOS 26+, iPhone only. Dark appearance only.
- SwiftUI, SwiftData, Swift Charts. Swift 6 language mode. No third-party dependencies.

## Conventions

`../bfl-tracker/app` is the reference for styling, data handling and coding style. Read the matching code there before writing something new here, and reuse its theme, components, naming and folder layout (`Model/`, `Theme/`, `Support/`, `Features/<Feature>/`). The spec's folder list is only a suggestion.

## Tech & workflow

- The Xcode project is `SpendItForLife/SpendItForLife.xcodeproj`, created and managed by Xcode. Don't hand-edit or generate the project file; capabilities and target settings are changed in Xcode.
- Bundle ID `com.joakimkronqvist.sifl`, iCloud container `iCloud.com.joakimkronqvist.sifl`.
- Solo project: the user is the only developer and the only tester.
- Claude may commit changes on its own. Claude must **not push** to GitHub — the user pushes.

## Data & privacy

- No backend server. All data is stored in **CloudKit** (the user's own private iCloud database).
- No accounts, no analytics, no tracking, no third-party data collection.
- Money is stored and summed as whole cents (`Int`) and shown to users as decimals.
