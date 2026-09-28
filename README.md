# prdctv

A SwiftUI app for macOS 14+ and iOS 17+ that replaces the need-to-do / want-to-do whiteboard. Tickets live on a board, and completed need points earn Want and Fun rewards. A desktop widget keeps the board visible.

## Build and run

Run `make` to list the shortcuts:

| Command | What it does |
|---|---|
| `make mac` | Build and launch the Mac app |
| `make ios` | Build and launch in the iOS Simulator (`SIM="iPhone 17 Pro"` by default) |
| `make device` | Build, install and launch on your connected iPhone (the first paired device, or `DEVICE=<id>`) |
| `make mac-demo`, `make ios-demo`, `make device-demo` | The same, but with sample data in an in-memory store. Nothing is saved or synced. |
| `make widgets` | Restart the Mac widgets so they load the latest build, and warn if a reload fails. `make mac` does this for you. |
| `make test` | Run the unit tests (built unsigned into `build/test`, so it never replaces the signed app) |
| `make sims`, `make devices` | List the simulators and devices you can target |
| `make icons` | Regenerate the app icons and logo mark from `scripts/make_icons.py` |
| `make clean` | Delete the `build/` folder |

Every command regenerates `TicketBoard.xcodeproj` from `project.yml` with XcodeGen (`brew install xcodegen`) when the spec or file list changed. Edit `project.yml`, not the project file. To work in Xcode, run `make project` and then open the project.

### Name and icons

- The app is called **prdctv** (`prdctv.app`). Xcode targets, schemes, Swift types and bundle IDs keep their original `TicketBoard` names, because the bundle IDs, App Group and iCloud container tie the app to its existing data.
- `scripts/make_icons.py` redraws the logo from its measured geometry. It writes the macOS icon sizes, the iOS icon with dark and tinted variants, `LogoMark` (the square mark, used in the menu bar and quick-add panel), and `LogoFull` (the mark plus the "prdctv" wordmark, used as the title on the Mac window and the iPhone board). It needs Pillow.
- Colors: the logo file is in Display P3, where the green is `#9FD77F`. The icons are saved as sRGB `#8ED973`, which is the same color. The mark is `#E8E8E8`.
- The wordmark is set in Bauhaus 93, which comes with Microsoft Office. The script converts it to vector outlines with `scripts/wordmark_outline.swift`, so the app contains artwork, not the font. Regenerating needs the font installed, or `LOGO_FONT=/path/to/Bauhaus93.ttf`.

### Signing and sync

- Team `TTM9BN6M53` with automatic signing. The `make` commands pass `-allowProvisioningUpdates`, so new devices and capabilities get registered for you.
- **App Groups** (app ↔ widget): `TTM9BN6M53.com.jonathanlee.TicketBoard` on macOS and `group.com.jonathanlee.TicketBoard` on iOS.
- **iCloud:** both apps sync the container `iCloud.com.jonathanlee.TicketBoard` (private database, CloudKit development environment). Widgets don't sync on their own. They share the local store, and the app uploads their changes the next time it runs.
- If you change an ID, update `project.yml` and `TicketBoard/Shared/AppGroup.swift` together.
- The reward ratios are stored per device and don't sync.

## Layout

| Path | Contents |
|---|---|
| `TicketBoard/Shared/` | Models, `RewardEngine`, `TicketOps`, store, intents, and theme. Compiled into both the app and the widget. |
| `TicketBoard/Board/` | Board, columns, ticket card, editor, and history |
| `TicketBoard/Rewards/` | Reward meter and redemption sheet |
| `TicketBoard/QuickAdd/` | Parser, floating `NSPanel`, and quick-add view |
| `TicketBoard/Stats/` | Charts and streaks |
| `TicketBoard/Calendar/` | Month calendar of tickets by due date |
| `TicketBoard/Import/` | Whiteboard photo OCR import |
| `TicketBoard/App/` | Mac app entry point, menu bar, and settings |
| `TicketBoard/iOS/` | iPhone/iPad app: tabbed board, quick-add sheet, and settings |
| `TicketWidget/` | Widget code, built as a Mac extension and as an iOS extension (`TicketWidgetiOS/` holds the iOS plist) |
| `TicketBoardTests/` | Reward engine and parser tests |

## Keyboard

| Shortcut | Action |
|---|---|
| ⌥Space (global, configurable) | Quick add |
| `N` / ⌘N | New ticket |
| Arrow keys | Move the selection |
| Space | Advance the selected ticket one column |
| Return | Edit the selected ticket |
| `1`–`5` | Set points to 1, 2, 3, 5, or 8 |
| ⌘⌫ | Delete the selected ticket |
| ⌘⇧W / ⌘⇧F | Redeem a Want / Fun reward |
| ⌘⇧S | Open Stats |
| ⌘1 / ⌘2 | Switch the main window between Board and Calendar |
| ⌘← / ⌘→, ⌘T | Calendar: previous or next month, jump to today |
| ⌘⇧I | Import a whiteboard photo |

Quick-add syntax: `w: rewatch Arrival 2 #movies !sat`. The prefix is `n:`, `w:`, or `f:`. A trailing number sets points on the 1/2/3/5/8 scale. `#tag` adds a tag. `!today`, `!tmr`, `!fri`, `!3d`, `!10/3`, and `!2026-10-03` set the due date.

## Rules and decisions

- Rewards are computed, never stored: `available = floor(needPointsDone / ratio) - redeemed`. The ratios default to 4 for Want and 7 for Fun and can be changed in Settings.
- Want and Fun counters are independent.
- Rewards can be turned off in Settings → Rewards (on by default). Off hides the meter, the Redeem commands, reward stats, and Want and Fun tickets, which are kept and come back when rewards are turned on. New tickets are always Need, and the small widget lists Up Next instead of the meter.
- Settings → Widget → Rewards in the large widget hides the meter on the large size only.
- Points use the Fibonacci scale: 1, 2, 3, 5, 8.
- Points can be turned off in Settings → Board (on by default). Off hides point values everywhere, the 1–5 keys do nothing, quick add keeps a trailing number in the title, and each finished Need ticket counts as 1 toward rewards and stats. Stored point values are kept for when points come back on.
- A Want or Fun ticket stays locked until a reward is spent on it. Moving it into In Progress or Done asks you to confirm first. Deleting an unlocked ticket that isn't done refunds its reward.
- Tags mark a class or topic. Each tag keeps one color everywhere, picked from its name until you choose one in Settings → Tags. Tag colors are stored per device. The widget shows a ticket's first tag, and the editor suggests tags already in use.
- The board can show one tag at a time (the Tag menu), and Lanes groups each column by category or by tag. On iPhone both are in the filter menu. With tag lanes, Plain Tag Titles shows headings as bold text, and cards leave out the tag their heading already shows.
- Settings → Widget → List by tag lists open tickets (In Progress, then Up Next) under bold tag titles instead of by column. Show Miscellaneous adds untagged tickets at the end. The extra-large widget spreads tags across three columns, and a tag that doesn't fit shows its first tickets.
- The widget shows only open tickets, never Done ones, and no category icons.
- The board has three columns: Up Next, In Progress, and Done. Older versions had a Backlog column; tickets left there move to the end of Up Next on first launch.
- The calendar shows tickets on their due dates. Pick a day to see its tickets or add one due that day. Drag a ticket to another day to reschedule it, or drag it in from the Unscheduled list; the + button schedules on the selected day. On iPhone it's the Calendar tab.
- **Look:** corners use three tight radii (2, 4 and 6 pt, in `Radius` in `Shared/Theme.swift`). The default palette is shades of the logo green, darkened where needed so text stays readable in light and dark mode.
- Settings → Categories: Need, Want and Fun each get a color (system color picker) and an icon (a grid of 36 symbols), with a reset to the defaults (`#458F32`, `#709929`, `#2A8463`). Open screens redraw when these change, and the widget reloads.
- Settings → Colors: Up Next, In Progress, Done, Calendar and Accent (buttons, switches, selection, links) are green by default. Every color setting, here and under Categories, works the same way: picking a color applies it immediately, and ↺ returns to the default. Colors are stored per device and also tint the widget's column headings.
- Appearance is System by default, or Light or Dark (Settings → General on Mac, Settings → Appearance on iPhone). It's stored per device. Widgets always follow the system, since macOS and iOS draw them.
- Setting keys must not contain dots (e.g. `colorUpNext`, `categoryNeedColor`). SwiftUI watches settings with key-value observing, which treats a dot as a path separator, so a dotted key never tells other views it changed. `LegacySettingsMigration` moves values saved under the old dotted names.
- `--demo` stores never sync. Before this was fixed, one Mac demo run on 2026-09-26 uploaded its sample records to iCloud; `LeakedDemoCleanup` in `Shared/DemoData.swift` removes exactly those records on launch and can be deleted once every device has run it.
- The Done column shows the current week, and older tickets move to History. Settings has a toggle to keep them all in Done.
- The Mac board and the iPhone board share views and rules: the ticket card, the editor, rewards, stats, and the unlock dialogs in `Board/BoardSupport.swift`.
- On iPhone, a segmented control switches between columns. Swipe right to advance a ticket, swipe left to delete it, and long-press for move, points, and edit. Tickets can't be reordered within a column on iPhone.
