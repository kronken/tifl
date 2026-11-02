# Spend It For Life — build spec

A simple iOS spending tracker. Log a purchase in a few seconds, organise it by your own categories, and see where the money goes per month, per year and per category.

Sister app to *Buy It For Life*: same design system (**Patina**), same Liquid Glass look, same code conventions where they overlap.

---

## 1. Platform and stack

- iOS 26+, iPhone only. SwiftUI throughout, Swift 6 strict concurrency.
- **Liquid Glass**: use system components (`TabView`, `NavigationStack`, `.sheet`, toolbars) so they pick up glass automatically. For custom floating controls use `.glassEffect()` / `GlassEffectContainer`. Never stack glass on glass.
- **Persistence**: SwiftData, synced through **CloudKit private database** (`ModelConfiguration(cloudKitDatabase: .private("iCloud.<bundle-id>"))`). No server, no accounts, no export screen.
- **Charts**: Swift Charts.
- No third-party dependencies.
- Dark appearance only (`.preferredColorScheme(.dark)`), matching Patina.

### CloudKit constraints for the models (important)

SwiftData + CloudKit requires:

- every stored property is optional **or** has a default value;
- every relationship is optional;
- no `@Attribute(.unique)`;
- deletes and inverse relationships set explicitly.

Enforce "required" rules (category on a purchase, at least one category) in the UI and view models, not in the schema.

---

## 2. Data model

```swift
@Model final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var colorKey: String = "moss"        // key into CategoryColor palette (§5.3)
    var symbolName: String = "cart"      // SF Symbol name from the icon set (§5.4)
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .nullify, inverse: \Purchase.category)
    var purchases: [Purchase]? = []
}

@Model final class Purchase {
    var id: UUID = UUID()
    var amountCents: Int = 0             // whole hundredths in every currency, never converted; shown as decimals
    var date: Date = Date.now            // calendar day that matters; store start-of-day local
    var title: String? = nil             // optional, trimmed; empty string → nil
    var category: Category? = nil        // required in UI
    var createdAt: Date = Date.now
}
```

### Settings

- `currencyCode: String` — synced across devices with `NSUbiquitousKeyValueStore`, mirrored to `@AppStorage` for fast reads. Default on first launch: `Locale.current.currency?.identifier ?? "EUR"`.
- `hasCompletedOnboarding: Bool` — local `@AppStorage`. On a fresh install with existing synced categories, skip onboarding automatically (see §4.1).

### Rules

- Amount must be > 0. Accept both `.` and `,` as decimal separator. Max 2 decimals (0 for currencies like JPY — use the currency's `maximumFractionDigits`).
- Changing currency changes formatting only; stored amounts are never converted.
- Deleting a category with purchases requires the user to pick another category to move them to (or to delete them, with a destructive confirmation). Deleting the **last** category is not allowed.
- Category names are trimmed and must be non-empty; duplicates (case-insensitive) are rejected with an inline message.

---

## 3. App structure

```
TabView (3 tabs, Liquid Glass tab bar)
├── Spending   (list of purchases)
├── Insights   (charts)
└── Settings   (currency, categories)

+ Floating "Add purchase" button, visible on all three tabs
```

- Use the iOS 26 tab bar with a separate trailing action (`Tab(role: .search)`-style accessory pattern) **or** a custom `.glassEffect()` circular button bottom-right, beside the tab bar. 64 pt, brass fill, `plus` symbol, `accessibilityLabel("Add purchase")`. It must be reachable with one thumb on every tab.
- The add button opens the **Add purchase** sheet.

Suggested folders:

```
App/            SpendItForLifeApp.swift, RootView.swift
Models/         Category.swift, Purchase.swift, CategoryColor.swift, CategoryIcon.swift
Settings/       AppSettings.swift (currency, onboarding flag)
Features/
  Onboarding/   WelcomeView, CurrencyStepView, CategoriesStepView
  Spending/     SpendingView, PurchaseRow, DaySection
  AddPurchase/  AddPurchaseSheet, AmountField, CategoryPicker
  Insights/     InsightsView, PeriodChart, CategoryBreakdown, TrendRow, StatTile
  Settings/     SettingsView, CurrencyPickerView, CategoryEditorView
DesignSystem/   PatinaTokens.swift, GlassCard.swift, Typography.swift
Formatting/     Money.swift (currency formatting from settings)
```

---

## 4. Screens

Reference designs: the **Spend it for life** design canvas (Patina). Match layout, copy and states from there.

### 4.1 Onboarding (3 steps, shown until finished)

1. **Welcome**
   - App icon tile, wordmark "Spend It For Life" (large title), line: "Know where your money goes, one purchase at a time."
   - Three feature rows: Log in seconds / Your categories / See the pattern.
   - Page dots (1 of 3), brass **Get started**.
2. **Currency**
   - Title "Your currency", subtitle "Picked from your iPhone's region. Change it any time in Settings."
   - Card showing region name and a sample amount formatted in the chosen currency (e.g. `€1,234.50`) plus currency name.
   - Chips for common currencies (EUR, USD, GBP, SEK, NOK, CHF) and an **All currencies** link to the full picker.
   - Brass button "Use EUR" (code updates with selection).
3. **Categories (required)**
   - Title "Your categories", subtitle "Add at least one to start. More can come later in Settings."
   - **No categories exist beforehand.** Inline creator card: name field with live icon preview, 8 colour swatches, 12-icon grid, "Add "<name>"" button (disabled until a name is entered).
   - Added categories appear as chips above the creator. After adding, the form resets and moves on to the next colour.
   - "Ideas · tap to fill in" chips (Groceries, Eating out, Transport, Home, Bills, Clothing) only **fill the form**. Nothing is created until the user taps Add. Ideas already added are hidden.
   - **Start tracking** is disabled with the hint "Add one category to continue" until ≥ 1 category exists. Then it becomes brass and finishes onboarding.

Skip onboarding if CloudKit already delivered categories (reinstall or second device): after the first sync, if `Category` count > 0, set `hasCompletedOnboarding = true`.

### 4.2 Spending (tab 1)

- Subtitle: full date ("Monday 2 November"), large title "Spending".
- **This month card** (solid surface): caption "NOVEMBER SO FAR", month total in `figure-hero` (ink, not brass), a thin bar split by category colour, and a legend of category name + amount. Footer line: "October closed at €1,284.10 · 2 days into November". Link "Insights" → Insights tab.
- **Purchase list** grouped by day, newest first. Section header: "TODAY" / "YESTERDAY" / "SATURDAY 31 OCTOBER" with that day's total on the right.
- Row: category icon tile (colour at 16% opacity, symbol in the colour), title (or the category name when there's no title, with the subline "No title"), category name, amount on the right (rounded font, tabular figures).
- Tap row → Add purchase sheet in **edit mode** (same form, "Edit purchase" title, Delete button in red at the bottom). Swipe to delete with undo.
- **Empty state**: month total `€0.00` and "Nothing logged yet. Tap + to add your first purchase."
- Paginate or lazy-load older months (`LazyVStack`, fetch by month).

### 4.3 Add purchase (sheet)

- `.presentationDetents([.large])`, grabber, glass **Cancel** at top-left, title "New purchase".
- **Amount**: large centred field, `.keyboardType(.decimalPad)`, focused on appear, currency symbol in front (faint until a value is entered).
- **Category (required)**: wrapping chips with icon + name, single select, in `sortOrder` order. "New category" link opens the category editor; once it's saved, the new category is pre-selected.
  - Default selection: none on first use; afterwards preselect the most recently used category (keep this behind a constant so it's easy to change).
- **Title (optional)**: text field, placeholder "Optional, e.g. K-Market".
- **Date**: segmented chips **Today** (default) / **Yesterday** / **Pick…**. Pick opens a graphical `DatePicker`, no future dates; the chip then shows the chosen date.
- **Primary button** (bottom, full width, 56 pt): disabled with a hint ("Enter an amount and pick a category", "Pick a category", …) until valid. When valid it is brass and reads "Add €23.85". On save: haptic success, dismiss sheet.
- VoiceOver: chips are radio buttons (`.accessibilityAddTraits(.isSelected)` on the chosen one), and the hint text is announced politely.

### 4.4 Insights (tab 2)

- Subtitle "6 categories · tracking since Jan 2023", large title "Insights".
- **Period control**: segmented Months / Years.
- **Over-time card**
  - Caption: period name (e.g. "OCTOBER 2026"), plus " · CATEGORY" when a category is focused. Total in `figure-hero`. A note comparing with average ("12% above your average of €1,140"); for the current partial period use "2 days in · average month is €1,140" or "January to today · €X a month".
  - **Stacked bar chart** (`BarMark` stacked by category, category colours): Months = last 12 months; Years = every year with data. The selected bar is full opacity and the others are dimmed (~40%). Tap a bar to select it (`chartXSelection`). Dashed `RuleMark` at the average of **complete** periods, labelled "avg €1,140".
  - Hint line under the chart.
- **By category card** (for the selected period)
  - Horizontal split bar and rows: icon tile, name, amount, percentage of the period total, thin progress bar in the category colour. Sorted by amount.
  - **Category focus**: tapping a row shows only that category in the chart (bars, total, average and label all switch to that category). The other rows dim but stay tappable, so tapping another one switches focus. Tapping the focused row again, or the glass **Show all** button (appears beside the card header while a category is focused), resets the focus. Percentages always stay relative to the full period total.
  - Focus is kept when the period or the selected bar changes.
- **Stat tiles** (2 × 2): Average month (or year), Top category (+ % share), Purchases (count in period), Biggest one (amount + category + date).
- **Category trends card**: one row per category with average per month, a sparkline (`LineMark`, category colour) over the last 12 complete months, and the change of the latest complete month vs. its average ("+12%"). Footer: "Change compares October with your 12-month average."
- Empty and sparse data: hide the trends card if there are fewer than 2 months of data; show the chart with a single bar otherwise.

### 4.5 Settings (tab 3)

- Large title "Settings". **No data/export section** — syncing is automatic through iCloud.
- **General**
  - Currency row: "€" tile, "Currency", subline "From your region: Finland" (only while it still matches the locale default; otherwise just the currency name), value "Euro", chevron → Currency picker.
- **Categories**
  - List of categories in `sortOrder`: icon tile, name, purchase count, chevron → Category editor.
  - "Add category" row (denim) → Category editor (new).
  - **Reorder** / **Done** toggle in the section header, using edit mode with drag handles (`.onMove`).
  - Footer: "Order here is the order in Add purchase. Deleting a category asks where its purchases should go."

### 4.6 Currency picker

- Pushed view with glass back button, title "Currency", search field.
- Section "FROM YOUR REGION · FINLAND" with the locale currency first (name, code, sample format).
- Section "ALL CURRENCIES": `Locale.commonISOCurrencyCodes`, localized names (`Locale.current.localizedString(forCurrencyCode:)`), symbol tile, code. Checkmark on the current one.
- Footer: "Changing currency changes the symbol only. Amounts you logged are not converted."

### 4.7 Category editor (sheet, new + edit)

- Glass **Cancel**, title "New category" / "Edit category", brass **Save** (disabled until the name is valid).
- Live preview: 88 pt tile in the chosen colour with the chosen icon, and the name below it.
- Name field (placeholder "Groceries, Rent, Coffee").
- Colour: 8 swatches in a row, with a selection ring.
- Icon: grid of 18 icons, 6 columns; the selected one gets a colour tint and stroke.
- Edit mode only: red **Delete category** button with the note "912 purchases use it. You choose where they move before it goes." Delete opens a picker of the other categories ("Move 912 purchases to…") plus a destructive "Delete purchases too" option. Disabled when it's the last category.

---

## 5. Design system — Patina

Dark-first. Two layers: **solid content** (cards) under **floating glass** (tab bar, toolbars, add button, sheet headers). When Reduce Transparency is on, glass falls back to `surface100` plus a hairline stroke.

### 5.1 Colour tokens

| Token | Value | Use |
|---|---|---|
| bg | `#09090b` | App background |
| surface100 | `#141417` | Cards, list groups |
| surface200 | `#1f1f23` | Inputs, segmented track, inactive tiles |
| glassFill | white 7% | Glass controls (use system glass in SwiftUI) |
| glassFillStrong | white 13% | Selected glass / selected chip |
| glassStroke | white 16% | 1 px hairlines on cards and glass, row separators |
| ink | `#f5f5f7` | Primary text |
| inkMuted | `#a1a1a6` | Secondary text, captions |
| inkFaint | `#6e6e73` | Placeholders, disabled only (fails 4.5:1) |
| brass | `#d6ad66` | **One** primary action per screen (add button / save / continue) and the selected tab icon |
| onBrass | `#1a1206` | Text and icons on brass |
| denim | `#7d9cf0` | Links, secondary actions |
| negative | `#ff453a` | Destructive actions only |

Rule: if two things on a screen are brass, one of them is wrong. Totals are in ink, not brass.

### 5.2 Type

- Text in SF Pro (system). Numbers that matter in **SF Pro Rounded** with tabular figures: `.font(.system(size:, weight:, design: .rounded)).monospacedDigit()`.
- figure-hero 48/52 bold · figure 22/28 semibold · large-title 34/41 bold · title 22/28 bold · headline 17/22 semibold · body 17/22 · subheadline 15/20 · caption 12/16 medium (uppercase allowed for captions only).
- Map these to Dynamic Type text styles so they scale; layouts must reflow at accessibility sizes.

### 5.3 Category colours (`CategoryColor` enum, stored as key)

| Key | Hex |
|---|---|
| brass | `#d6ad66` |
| denim | `#7d9cf0` |
| teal | `#4fc1b0` |
| clay | `#e0896a` |
| violet | `#b392f0` |
| moss | `#93c46b` |
| rose | `#ef8fb0` |
| steel | `#9aa4b1` |

Icon tiles use the colour at 16% opacity as background and the full colour for the symbol.

### 5.4 Category icons (`CategoryIcon`, SF Symbols)

`cart`, `fork.knife`, `cup.and.saucer`, `tram`, `car`, `airplane`, `house`, `bolt`, `iphone`, `repeat`, `tshirt`, `heart`, `dumbbell`, `book`, `ticket`, `gift`, `wrench.and.screwdriver`, `tag`.
The first 12 are shown in onboarding; all 18 are shown in the editor.

### 5.5 Shape and spacing

- Radius: sm 10 (fields, small tiles), md 16 (nested elements), lg 26 (cards, sheets), pill (buttons, chips).
- Spacing: 4 / 8 / 12 / 16 (screen margin, card padding) / 24 (between sections).
- Card shadow `0 1 2 black 60%`. Glass shadow: top inner highlight + `0 8 32 black 50%` (system glass handles this).
- Minimum tap target 44 × 44 pt everywhere.

### 5.6 Voice

Terse, practical, a little dry. Numbers first. No exclamation marks, no emoji. Sentence case. Confirmation copy example: "Logged. €23.85 on Groceries."

---

## 6. Money and dates

- Amounts are stored and summed as whole cents (`Int`), as in Buy It For Life, and only converted to `Decimal` for display and from user input. Always hundredths, whatever the currency, so changing currency never changes the number.
- One `Money` formatter built from `currencyCode` + `Locale.current`: `Decimal.FormatStyle.Currency(code:locale:)`. Use it everywhere; never hard-code "€".
- Totals: two decimals in lists and hero figures; whole units are acceptable in chart axis labels and the "avg" label.
- Months and years use `Calendar.current` and local time zone. Store `Purchase.date` as start-of-day so grouping is stable across time zones.

---

## 7. Accessibility

- VoiceOver labels on all icon-only buttons; purchase rows read "K-Market, Groceries, €23.85, today".
- Charts: provide `accessibilityChartDescriptor` plus per-bar labels ("October 2026, €1,284.10").
- Selected states exposed via traits, not colour alone.
- Respect Reduce Transparency (solid fallback) and Reduce Motion (no bar animations).
- Dynamic Type up to AX5: chips wrap, rows grow, and the hero figure may scale down (`minimumScaleFactor(0.6)`).

---

## 8. Acceptance criteria

1. A fresh install shows onboarding; the user cannot reach the tabs without creating ≥ 1 category.
2. The currency defaults to the device region's currency; changing it in Settings reformats every amount without changing stored values.
3. The add button is visible on all three tabs and opens the sheet with the amount field focused and the date set to today.
4. A purchase cannot be saved without amount > 0 and a category; title is optional.
5. Categories can be created, edited (name, colour, icon), reordered and deleted (with reassignment). The last one cannot be deleted.
6. Insights shows stacked monthly and yearly bars, an average line, and a per-category breakdown for the selected bar. Tapping a category focuses the chart on it; tapping it again or **Show all** resets.
7. Data syncs between two devices on the same iCloud account via the private CloudKit database; a reinstall restores data and skips onboarding.
8. All screens pass VoiceOver navigation and render correctly at the largest Dynamic Type size.

---

## 9. Suggested build order

1. Models, CloudKit container, `Money` formatter, Patina tokens.
2. Onboarding (currency + required category) and Category editor.
3. Spending tab + Add purchase sheet (create / edit / delete).
4. Settings: currency picker, category list with reorder and delete-with-reassign.
5. Insights: period chart, selection, average line, breakdown with focus, tiles, trends.
6. Accessibility pass, empty states, sync test on two devices.

Add unit tests for: amount parsing (`,` and `.`), monthly/yearly aggregation, average of complete periods, category reassignment on delete, and onboarding gating. Add SwiftUI previews with an in-memory container seeded with sample data.
