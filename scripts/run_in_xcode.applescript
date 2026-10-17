-- Runs a scheme in Xcode on a named simulator, so the simulator shows in Xcode.
-- Usage: osascript run_in_xcode.applescript /path/to/prdctv.xcodeproj prdctviOS "iPhone 17 Pro" [launch arguments…]
on run argv
	set projectPath to item 1 of argv
	set schemeName to item 2 of argv
	set deviceName to item 3 of argv
	set launchArguments to {}
	if (count of argv) > 3 then set launchArguments to items 4 thru -1 of argv

	tell application "Xcode"
		activate
		set doc to open projectPath
		-- The workspace has to finish loading before its schemes and destinations exist.
		repeat 120 times
			if loaded of doc then exit repeat
			delay 0.5
		end repeat
		if not (loaded of doc) then error "Xcode didn't finish opening " & projectPath

		set active scheme of doc to scheme schemeName of doc
		set destinations to (run destinations of doc whose platform is "iphonesimulator" and name is deviceName)
		if (count of destinations) is 0 then error "No simulator named " & deviceName & " for " & schemeName
		set active run destination of doc to item 1 of destinations

		run doc with command line arguments launchArguments
	end tell
	return "Running " & schemeName & " on " & deviceName & " in Xcode"
end run
