# Quick Icon Fix for TestFlight

## The Issue
TestFlight requires specific app icon sizes:
- iPhone: 120x120 pixels (60pt @2x) 
- iPad: 152x152 pixels (76pt @2x)
- Plus additional smaller sizes for settings, spotlight, etc.

## Quick Solution

### Option 1: Use AppIcon.co (Recommended - 2 minutes)
1. Go to https://appicon.co
2. Create a simple 1024x1024 icon (blue square with "CC" text)
3. Upload it to generate all required sizes
4. Download the zip file
5. Replace the contents of `ClaudeCodeiOS/Assets.xcassets/AppIcon.appiconset/`

### Option 2: Manual Creation in Xcode (5 minutes)
1. Open Xcode
2. Go to `ClaudeCodeiOS/Assets.xcassets/AppIcon`
3. Drag any 1024x1024 image into the AppIcon slot
4. Xcode will auto-generate missing sizes

### Option 3: Use SF Symbols App (Free)
1. Download SF Symbols app from Apple
2. Export the "terminal" symbol as 1024x1024 PNG
3. Use that as your base icon

## Temporary Placeholder
For now, I'll create the required Contents.json structure so you can quickly add icons.

## After Adding Icons
Once you have icons in place:
1. Clean build folder (Shift+Cmd+K in Xcode)
2. Archive again (Product > Archive)
3. Upload to TestFlight

The validation errors will disappear once proper icon files are in place.