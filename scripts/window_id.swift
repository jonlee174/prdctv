// Prints the number, width and height of prdctv's largest window on any Space, for screencapture -l.
import CoreGraphics

let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
let board = windows
    .filter { ($0[kCGWindowOwnerName as String] as? String) == "prdctv" && ($0[kCGWindowLayer as String] as? Int) == 0 }
    .filter { height($0) > 300 } // skips the menu bar item's thin windows
    .max { area($0) < area($1) }
if let board, area(board) > 0, let number = board[kCGWindowNumber as String] as? Int {
    let bounds = board[kCGWindowBounds as String] as? [String: Any]
    print(number, Int(bounds?["Width"] as? Double ?? 0), Int(height(board)))
}

func area(_ window: [String: Any]) -> Double {
    let bounds = window[kCGWindowBounds as String] as? [String: Any]
    return (bounds?["Width"] as? Double ?? 0) * height(window)
}

func height(_ window: [String: Any]) -> Double {
    (window[kCGWindowBounds as String] as? [String: Any])?["Height"] as? Double ?? 0
}
