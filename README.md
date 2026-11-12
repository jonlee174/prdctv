# prdctv

A SwiftUI task board for macOS 14+ and iOS 17+. Tickets move from Up Next to In Progress to Done, finished Need tickets earn Want and Fun rewards, and widgets show the board on the desktop and Home Screen. Tickets sync through the user's private iCloud database.

Product rules, shortcuts, launch options and design decisions are in [AGENTS.md](AGENTS.md).

## Requirements

- Xcode 26 or later, signed in with the Apple ID for team `TTM9BN6M53`
- XcodeGen (`brew install xcodegen`)
- Python 3 with Pillow, for `make icons` and `make screenshots`

## Build and run

Run `make` to list every command. The common ones are below.

| Command | What it does |
|---|---|
| `make mac` | Build and launch the Mac app with your real data |
| `make ios` | Run in Xcode on the iOS Simulator (`SIM="iPhone 17 Pro"`) |
| `make device` | Install and launch on a connected iPhone (`DEVICE=<id>`) |
| `make mac-demo`, `make ios-demo` | Sample data in memory, never saved or synced |
| `make test` | Run the unit tests |
| `make mac-dist` | Build the Mac App Store package for Transporter |
| `make ios-archive` | Archive the iOS app for the Xcode Organizer |

Edit `project.yml`, never the Xcode project. Every command regenerates the project when needed.

## iCloud sync

`make` builds use the Development environment. App Store and TestFlight builds use Production, which only changes when you deploy its schema.

When a release adds a stored property, deploy the schema before any TestFlight or App Store build runs.

1. Open the [CloudKit Console](https://icloud.developer.apple.com) and check that the container is `iCloud.com.jonathanlee.prdctv`, not the old `TicketBoard` one.
2. In Development, make sure every new field is on its record type. Add any that are missing.
3. Choose Deploy Schema Changes.

Never rename or remove a stored property on `Ticket` or `Redemption`. Production only accepts additions.

## Releasing

1. Raise `MARKETING_VERSION` in `project.yml`.
2. Deploy the iCloud schema if a model changed.
3. Run `make test`.
4. Run `make mac-dist`, then deliver `build/dist/prdctv.pkg` with Transporter.
5. Run `make ios-archive`, then in Xcode open Window → Organizer, select the new archive, and choose Distribute App → App Store Connect.
6. Paste the listing text from `release/AppStore.md`, select the new builds, and submit for review.

Both commands give each build a new number from the clock. Product → Archive would reuse build number 1, which App Store Connect rejects.
