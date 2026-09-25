# Ticket Board

A macOS 14+ SwiftUI app that replaces the need-to-do / want-to-do whiteboard. Tickets live on a board, and completed need points earn Want and Fun rewards. A desktop widget keeps the board visible.

## Build

The Xcode project is generated from `project.yml`, so edit that file rather than the `.xcodeproj`:

```sh
brew install xcodegen      # once
xcodegen generate
open TicketBoard.xcodeproj # run the TicketBoard scheme
```

To build and test from the command line:

```sh
xcodebuild -scheme TicketBoard -derivedDataPath build -allowProvisioningUpdates build
xcodebuild -scheme TicketBoard -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

Signing uses team `TTM9BN6M53` with the App Group `TTM9BN6M53.com.jonathanlee.TicketBoard`. The group ID is team-prefixed, so it doesn't need to be registered in the developer portal. If you change it, update `APP_GROUP_ID` in `project.yml` and `AppGroup.id` in `TicketBoard/Shared/AppGroup.swift`.

**Demo mode:** `open build/Build/Products/Debug/TicketBoard.app --args --demo` runs against an in-memory store filled with sample tickets. Your real data isn't touched.

## Layout

| Path | Contents |
|---|---|
| `TicketBoard/Shared/` | Models, `RewardEngine`, `TicketOps`, store, intents, and theme. Compiled into both the app and the widget. |
| `TicketBoard/Board/` | Board, columns, ticket card, editor, and history |
| `TicketBoard/Rewards/` | Reward meter and redemption sheet |
| `TicketBoard/QuickAdd/` | Parser, floating `NSPanel`, and quick-add view |
| `TicketBoard/Stats/` | Charts and streaks |
| `TicketBoard/Import/` | Whiteboard photo OCR import |
| `TicketBoard/App/` | App entry point, menu bar, settings, and demo data |
| `TicketWidget/` | Widget extension (small, medium, large, and extra large) |
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
| ⌘⇧I | Import a whiteboard photo |

Quick-add syntax: `w: rewatch Arrival 2 #movies !sat`. The prefix is `n:`, `w:`, or `f:`. A trailing number sets points on the 1/2/3/5/8 scale. `#tag` adds a tag. `!today`, `!tmr`, `!fri`, `!3d`, `!10/3`, and `!2026-10-03` set the due date.

## Rules and decisions

- Rewards are computed, never stored: `available = floor(needPointsDone / ratio) - redeemed`. The ratios default to 4 for Want and 7 for Fun and can be changed in Settings.
- Want and Fun counters are independent.
- Points use the Fibonacci scale: 1, 2, 3, 5, 8.
- A Want or Fun ticket stays locked until a reward is spent on it. Moving it into In Progress or Done asks you to confirm first. Deleting an unlocked ticket that isn't done refunds its reward.
- The Done column shows the current week, and older tickets move to History. Settings has a toggle to keep them all in Done.
- The model is CloudKit-compatible (every property has a default and nothing is marked unique), but sync isn't enabled.
