# prdctv

A SwiftUI task board for macOS 14+ and iOS 17+ that replaces the need to do and want to do whiteboard. Tickets move from Up Next to In Progress to Done. Finished Need tickets earn Want and Fun rewards, and widgets keep the board visible on the desktop and Home Screen. Tickets sync between devices through the user's private iCloud database.

## Requirements

- Xcode 26 or later, signed in with the Apple ID for team `TTM9BN6M53` (Xcode → Settings → Accounts)
- XcodeGen (`brew install xcodegen`)
- Python 3 with Pillow, for `make icons` and `make screenshots`

## Build and run

Run `make` to list every command.

| Command | What it does |
|---|---|
| `make mac` | Build and launch the Mac app, then restart its widgets |
| `make ios` | Run in Xcode on the iOS Simulator (`SIM="iPhone 17 Pro"` by default). Xcode builds, shows the simulator and launches the app. |
| `make device` | Build, install and launch on a connected iPhone (the first paired one, or `DEVICE=<id>`) |
| `make mac-demo`, `make ios-demo`, `make device-demo` | The same with sample data in an in-memory store. Nothing is saved or synced. |
| `make widgets` | Make the Mac widget use the development build and restart it. `make mac` does this for you. |
| `make widgets-store` | Give the Mac widget back to the App Store copy in `/Applications` |
| `make test` | Run the unit tests, built unsigned into `build/test` |
| `make screenshots` | Capture App Store screenshots for iPhone, iPad and Mac |
| `make store-art` | Make the App Store product page header (3840×1646) and search results art (3840×2560) in `build/store-art` from fresh iPhone screenshots |
| `make mac-dist` | Build the signed Mac App Store package in `build/dist` for Transporter |
| `make ios-xcode` | Open the project in Xcode to archive and upload the iOS app |
| `make sims`, `make devices` | List the simulators and devices you can target |
| `make icons` | Regenerate the app icons and logo from `scripts/make_icons.py` |
| `make clean` | Delete the `build/` folder |

Every command regenerates `prdctv.xcodeproj` from `project.yml` when the spec or file list changed. Edit `project.yml`, never the project file. To work in Xcode, run `make project` and open the project.

## Identifiers

| What | ID |
|---|---|
| App (Mac and iOS) | `com.jonathanlee.prdctv` |
| Widget | `com.jonathanlee.prdctv.widget` |
| App Group on Mac | `TTM9BN6M53.com.jonathanlee.prdctv` |
| App Group on iOS | `group.com.jonathanlee.prdctv` |
| iCloud container | `iCloud.com.jonathanlee.prdctv` |
| Link scheme | `prdctv://` |

Signing is automatic. The `make` commands pass `-allowProvisioningUpdates`, so new devices, IDs and capabilities are registered with Apple for you. If an ID ever changes, update `project.yml` and `prdctv/Shared/AppGroup.swift` together. After 1.0 ships the bundle ID and iCloud container can never change.

Targets are `prdctv` (Mac app), `prdctviOS`, `prdctvWidget`, `prdctvWidgetiOS` and `prdctvTests`, with schemes `prdctv` and `prdctviOS`. The widget kind stays `TicketBoardWidget`, the app's original name, because placed widgets are stored under it.

## iCloud sync

The app and its widget share one local SwiftData store through the App Group. Only the app syncs, using CloudKit's private database. The widget writes to the local store, and the app uploads those changes the next time it runs.

CloudKit has two separate environments.

- **Development** is used by every `make` build. Its schema updates itself whenever the app saves a new kind of record.
- **Production** is used by App Store and TestFlight builds. Its schema only changes when you deploy it.

Before every release that adds or changes a model property, deploy the schema.

1. Run the app from a `make` build and save a ticket that uses the new field (for repeats, set Repeat to anything but Never), so the Development schema includes every current field.
2. Open the [CloudKit Console](https://icloud.developer.apple.com), choose `iCloud.com.jonathanlee.prdctv`, and open Schema.
3. Choose Deploy Schema Changes and confirm the deploy to Production.

Skipping this breaks sync for every customer on the new version. Production schemas only accept additions, so never rename or remove a stored property on `Ticket` or `Redemption`. Add a new one instead.

`--demo` stores are in memory and never sync.

## Releasing

`release/` holds the Mac export settings (`ExportOptions.plist`), the store listing (`AppStore.md`) and the privacy policy (`privacy-policy.md`).

### Before the first release

1. In App Store Connect, create one app record with both iOS and macOS selected, bundle ID `com.jonathanlee.prdctv` and SKU `prdctv`. The widget ships inside the app and needs no record.
2. Paste the listing text from `release/AppStore.md`.
3. Publish `docs/` with GitHub Pages (repository Settings → Pages → deploy from the main branch, folder `/docs`). Enter `https://jonlee174.github.io/prdctv/` as the Support URL and `https://jonlee174.github.io/prdctv/privacy/` as the Privacy Policy URL.

### Each release

1. Raise `MARKETING_VERSION` in `project.yml` for a new version (for example `1.1`).
2. Deploy the iCloud schema if any model changed (see iCloud sync).
3. Run `make test`.
4. Upload the Mac build.
   1. Run `make mac-dist`. It archives a Release build and writes `build/dist/prdctv.pkg`. The app is signed with Apple Distribution, the package with the 3rd Party Mac Developer Installer certificate, and the build uses the Production iCloud environment. Before saying the package is ready it runs `scripts/check_mac_package.sh`, which fails if the installer signature or any app icon size up to 1024 pixels is missing. The build number comes from the clock, so every package gets a new one.
   2. Open Transporter, sign in with the Apple ID for the team, drag in `build/dist/prdctv.pkg` and choose Deliver.
5. Upload the iOS build.
   1. Run `make ios-archive`. It archives a Release build with a build number from the clock into Xcode's archive folder. Product → Archive would use the project's build number 1, which App Store Connect rejects once a build with it exists.
   2. In Xcode open Window → Organizer (in the menu bar at the top of the screen) and select the new archive under prdctviOS.
   3. Choose Distribute App, then App Store Connect, and upload.
6. Wait for both builds to finish processing in App Store Connect. They then show up in TestFlight for testing on your own devices.
7. Run `make screenshots` if the look changed, and upload the images from `build/screenshots`. Each folder matches an App Store Connect slot.

   | Folder | Size | Slot |
   |---|---|---|
   | `iphone-6.9` | 1320×2868 | 6.9 inch iPhone |
   | `iphone-6.5` | 1284×2778 | 6.5 inch iPhone |
   | `ipad-13` | 2064×2752 | 13 inch iPad |
   | `mac` | 2560×1600 | Mac |

8. Select the new builds on the version page in App Store Connect and submit for review.

`make screenshots` quits and reopens the Mac app while it runs, and uses light mode and sample data.

## Mac widget troubleshooting

- A rebuilt widget keeps running its old code until its process restarts. `make mac` restarts it, or run `make widgets`.
- Any other copy of `prdctv.app` that macOS knows about can take over the widget, and it then fails to load. Release archives, the unsigned test build and apps in the Trash have all done this. `make widgets` unregisters every copy except `build/Build/Products/Debug/prdctv.app`. Empty the Trash if an old copy is in it.
- To see why a widget won't update, read its log with `/usr/bin/log show --last 10m --predicate 'process == "prdctvWidget"'`. Use the full path, since zsh has its own `log` command.

## Layout

| Path | Contents |
|---|---|
| `prdctv/Shared/` | Models, reward math, `TicketOps`, store, tags, theme and intents. Compiled into the apps and the widget. |
| `prdctv/Board/` | Board, columns, ticket card, editor, history, lanes, tag settings and appearance |
| `prdctv/Rewards/` | Reward meter and redemption sheet |
| `prdctv/QuickAdd/` | Quick add parser, floating panel and view |
| `prdctv/Calendar/` | Month calendar of tickets by due date |
| `prdctv/Stats/` | Charts and streaks |
| `prdctv/Import/` | Whiteboard photo import, read on the device with Vision |
| `prdctv/App/` | Mac app, menu bar item and settings |
| `prdctv/iOS/` | iPhone and iPad app with tabs, quick add sheet and settings |
| `prdctvWidget/` | Widget code for both platforms (`prdctvWidgetiOS/` holds the iOS plist and entitlements) |
| `prdctvTests/` | Tests for rewards, tags, the quick add parser, the calendar grid and undo |
| `release/` | Export settings, App Store listing and privacy policy |
| `docs/` | Support and privacy pages for GitHub Pages |
| `scripts/` | Icon, wordmark and screenshot scripts |

## Keyboard on Mac

| Shortcut | Action |
|---|---|
| ⌥Space (global, set in Settings) | Quick add from any app |
| ⌘K | Quick add |
| `N` or ⌘N | New ticket |
| Arrow keys | Move the selection |
| Space | Move the selected ticket to the next column |
| Return | Edit the selected ticket |
| Escape | Clear the selection |
| `1` to `5` | Set points to 1, 2, 3, 5 or 8 (with points on) |
| ⌘⌫ | Delete the selected ticket |
| ⌘1 and ⌘2 | Show the board or the calendar |
| ⌘←, ⌘→ and ⌘T | Previous month, next month and today in the calendar |
| ⌘⇧S | Open Stats |
| ⌘⇧W and ⌘⇧F | Redeem a Want or Fun reward (with rewards on) |
| ⌘⇧I | Import a whiteboard photo |

Quick add syntax is `w: rewatch a movie 2 #movies !sat`. The prefix `n:`, `w:` or `f:` picks the category and Need is the default. A trailing 1, 2, 3, 5 or 8 sets the points. `#tag` adds a tag. `!today`, `!tmr`, `!fri`, `!3d`, `!10/3` and `!2026-10-03` set the due date.

## Product rules

### Board

- Three columns, Up Next, In Progress and Done. Done shows the current week and older tickets move to History, unless Settings keeps them all in Done.
- The Tag menu shows one tag at a time. Lanes groups each column by category or by tag, and on iPhone both are in the filter menu.
- A card leaves out whatever its lane heading already says. Tag lanes hide tags and category lanes hide the Need, Want or Fun label, with a locked reward's lock moving beside the title. Changing lanes rebuilds the cards.
- On iPhone a segmented control switches columns. Swipe right to advance, swipe left to delete and long press for more. Tickets can't be reordered within a column on iPhone.
- The editor's due date is a button showing the weekday, month and day without a year, and it opens a calendar. Picking a day closes the calendar.
- Quick add's `!10/3` takes a month and day with no year. The date is the next time that month and day comes around, today included, and Feb 29 waits for a leap year.
- Repeat (in the editor, Never by default) can be Daily, Weekly, Monthly or Custom, which is every 1 to 99 days, weeks or months. When the ticket is done, a copy goes to the end of Up Next with the same title, notes, category, points, tags and repeat. The copy is due one interval after the old due date, or after the day it was finished when there was no date. A copy finished late skips ahead to the first date after the finish day, and a monthly date on the 31st lands on the last day of shorter months. The finished ticket stops repeating, so reopening and finishing it again adds no second copy. Cards show the repeat, such as "Weekly".
- Finishing a ticket drops pink and green confetti over the board. Settings → Board turns it off per device.
- The calendar shows tickets on their due dates. Drag a ticket to another day, or in from Unscheduled, to reschedule it.

### Rewards and points

- Rewards are computed, never stored. `available = floor(needPointsDone / ratio) - redeemed`, with ratios of 4 for Want and 7 for Fun by default. Want and Fun count independently from the same Need points.
- Points use the scale 1, 2, 3, 5 and 8.
- A Want or Fun ticket stays locked until a reward is spent on it. Moving it to In Progress or Done asks first. Deleting an unlocked ticket that isn't done refunds the reward.
- Rewards can be turned off in Settings. That hides the meter, the Redeem commands, reward stats and Want and Fun tickets, which come back unchanged when rewards are turned on. New tickets are always Need while rewards are off. Cards also drop the Need label, since every ticket is Need, and lists show a plain dot instead of the category shape.
- Points can be turned off in Settings. That hides point values, and each finished Need ticket then counts as 1 toward rewards and stats. Switching changes the current balance, which can drop below zero. Stored point values are kept.

### Tags

- Tags are free text and keep the case they were typed in, so class codes like `Chem 101` read naturally. Tags that differ only in case are treated as one.
- Each tag has one color everywhere. It comes from the tag's name until one is chosen in Settings → Tags.
- Color tasks by tag (Settings → Tags, on by default) draws each task in its first tag's color, or standard green (`#458F32`) without a tag. This covers the card stripe, the points and the calendar marks. Turned off, tasks use their category color.
- Tag order (Settings → Tags) orders tag lanes on the board and List by tag in the widget. Custom follows the priority set with the arrows on each tag row, with unranked tags after in alphabetical order. Soonest due date puts the tag whose earliest open task is due first, with priority breaking ties. Tasks in a tag can keep the board order or go by soonest due date, undated last. Untagged tickets always come last.
- The editor suggests tags already in use.

### Widgets

- Sizes are small (reward meter, or Up Next when rewards are off), medium (Need tickets in Up Next), large (meter, In Progress and Up Next) and extra large (meter and two columns, also with List by tag).
- The widget shows only open tickets and never shows category icons. Rows show their first tag.
- Settings → Widget → Layout picks how the medium, large and extra large widgets list tickets. Columns is the original Up Next and In Progress lists. By tag lists open tickets under bold tag titles, with Show miscellaneous for untagged tickets. By status lists them under In Progress and Up Next titles, each sorted by due date with undated tickets last, and shows each row's first tag. Status titles and Tags in rows turn those off. The large widget's reward meter can be hidden too. These apply to every prdctv widget, and an older List by tag setting carries over as By tag.
- Settings → Widget → Due dates (off by default) adds "Due" and the date to widget rows, for example "Due Sun" or "Due Oct 28". Dates in the next 7 days show the weekday, later or overdue ones show a short date, and overdue ones are red. The date and points always show in full. The tag shows in full when there is room and otherwise takes up to half the space left, and the task name gets the rest and ends in "…". The widget refreshes at midnight so weekdays stay right.
- Widgets have no Edit Widget options on purpose. That kind of widget never received its settings in development builds.

### Look and settings

- Corners use three radii, 2, 4 and 6 points (`Radius` in `Shared/Theme.swift`). The default palette is shades of the logo green.
- Settings covers category colors and icons, column and accent colors, tag colors, rewards, points, confetti, widgets, the quick add shortcut, launch at login and appearance (System, Light or Dark). Appearance and colors are stored per device.
- Setting keys must not contain dots. SwiftUI watches settings with key value observing, which reads a dot as a path, so a dotted key never tells other views it changed.

### Logo

- `scripts/make_icons.py` redraws the logo and writes every icon size, the iOS dark and tinted variants, `LogoMark` and `LogoFull`.
- The logo green is `#9FD77F` in Display P3, saved in the icons as the matching sRGB `#8ED973`. The mark is `#E8E8E8`.
- The app icon background is a diagonal gradient from pink `#E0569B` at the top left to the logo green at the bottom right, blended in linear light so the middle doesn't turn brown. The iOS dark icon fills the mark with it. The logo mark and full logo stay one color.
- The wordmark is set in Bauhaus 93 and converted to outlines by `scripts/wordmark_outline.swift`, so the app ships artwork, not the font. Regenerating needs the font installed, or `LOGO_FONT=/path/to/Bauhaus93.ttf`.

## Debug launch options

Development builds accept these options, for example `open build/Build/Products/Debug/prdctv.app --args --demo --mode=calendar`.

| Option | Effect |
|---|---|
| `--demo` | Sample data in memory, never saved or synced |
| `--mode=board` or `--mode=calendar` | Mac view at launch |
| `--lanes=none`, `category` or `tag` | Lanes for this launch only |
| `--appearance=light` or `dark` | Appearance for this launch only |
| `--window-size=1280x800` | Mac window size |
| `--rewards=on` or `off` | Rewards on or off for this launch only, on Mac |
| `--tag-order=custom` or `dueDate`, `--task-order=board` or `dueDate` | Tag lane order for this launch only, on Mac |
| `--tab calendar` | iPhone tab at launch |

On Mac, join each value with `=`. A value passed as a separate word makes macOS treat the launch as opening a file, and the app then opens no window.
