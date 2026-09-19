# Timezones

**Timezones** is a macOS menu-bar SwiftUI app for tracking and comparing time across multiple cities and time zones.

It lives in the menu bar as `M/D HH:MM` for Local time, with a popover for details, plus support for detached windows, copy presets, settings, and quit.

## Features

### Menu-Bar World Clock
- Always-visible Local time in the menu bar (`TimeStore.menuBarText`).
- Popover UI via `NSStatusItem` + `NSPopover` managed by `AppDelegate`.
- Support for `New Window`, `Presets` menu, `Settings...`, and `Quit`.
- Live ticking via `liveNow` vs editable `baseDate` + `isLive` flag in `TimeStore`.

### Multiple Zones
- `localDef` (system time zone) shown by default.
- Custom zones: `CustomZone { id, city, timeZoneID }` selected via `extraIDs` (max 8 extras).
- `zones`, `allCatalog`, `isSelected`, `canAddMore`, `addCustomZone`, `removeCustomZone`.
- City renaming via `customCities[id]` with `cityName(for:)` / `setCityName`.
- Smart city-to-timezone suggestion via `suggestedTimeZoneID(forCity:)` backed by `cityTimeZoneMap`.

### Time Viewing and Editing
- Per-zone hour/minute, date, abbreviation, and GMT offset.
- `TimeWheelPicker`: HH:MM text fields with live-commit and focus-aware sync.
- `DateField`: M/D text fields with validation, month-length clamping, and arrow stepping.
- `HoldStepButton` for press-and-hold stepping (hour/day/minute).
- `ZoneCalendarButton` for calendar-based date picking.
- Time math in `TimeStore`: `calendar(for:)`, `hourMinute(for:in:)`, `yearMonthDay(for:in:)`, `setTime`, `setDate`, `stepHour`, `stepDay`, `stepMonth`, `stepMinute30`, `monthLength`, `twelveHour`, `abbreviation`, `gmtOffsetString`, `gmtParenString`, `displayName`.

### Copy / Sharing System
Highly customizable clipboard output for scheduling across zones:

- `CopyToken`: `city, date, dateMDYY, dateMDYYYY, dateISO, monthYear, year2, year4, time12, time24, abbr`, and more.
- `copyOrder` with `toggleCopyToken`, `moveCopyTokens`, `resetCopyFormat`, `orderedTokensForDisplay`.
- Per-zone selection via `copySelectedIDs` / `toggleCopy`.
- `tokenString(for:zone:)`, `copyLine(for:)`, `copySentence`, `paddedCopyLines`, `clipboardText`, `copyAllToClipboard`, `copySingleToClipboard`.
- Per-zone copy and bulk copy with copy feedback in `ContentView`.

### Copy Presets
Reusable format + zone snapshots:

- `CopyPreset { id, name, tokens, zones }` + `PresetZoneEntry { city, timeZoneID, isCopySelected }`.
- `snapshotZonesForPreset`, `saveCopyPreset`, `applyCopyPreset`, `applyPresetZones`, `deleteCopyPreset`.
- Persisted to `UserDefaults` as JSON, including `__local__` handling.

### Settings
`SettingsView` for:

- Managing time zones: Local is default, add up to 8 extras.
- Editing city names shown on the left and in copies.
- Toggling zones for display and for copy.
- Customizing copy token order and presets.
- Adding custom city + time zone ID pairs with validation.

### Persistence
All user state in `UserDefaults`:

- `extraZoneIDs`
- `customCityNames`
- `copySelectedIDs`
- `copyTokenOrder`
- `customZones`
- `copyPresets`

### Tests
`TimeStoreTests` covers timezone correctness, copy formatting, preset save/apply/delete, custom zone add/remove, and 12-hour formatting.

In short: a fast menu-bar world-clock + time-converter + copy-formatter for scheduling across zones, with custom cities/zones, editable base time, and reusable copy presets.
