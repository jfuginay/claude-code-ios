#!/bin/bash

# Create simple app icons using macOS built-in tools
# This creates basic colored squares as placeholders

ICON_DIR="/Users/jfuginay/Documents/dev/claude-code-ios/ClaudeCodeiOS/ClaudeCodeiOS/Assets.xcassets/AppIcon.appiconset"

echo "🎨 Creating simple app icons..."

# Function to create a simple colored icon
create_icon() {
    local size=$1
    local filename=$2
    
    # Create a simple blue square with rounded corners using sf symbols
    # This uses the 'app' SF Symbol as a base
    sips -s format png --resampleWidth $size --resampleHeight $size /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns --out "$ICON_DIR/$filename" 2>/dev/null
    
    if [ ! -f "$ICON_DIR/$filename" ]; then
        # Fallback: create a simple colored rectangle using built-in tools
        python3 -c "
import os
# Create a simple solid color image
with open('$ICON_DIR/$filename', 'wb') as f:
    # Create minimal PNG data for a blue square
    f.write(b'\\x89PNG\\r\\n\\x1a\\n\\x00\\x00\\x00\\rIHDR\\x00\\x00\\x00$size\\x00\\x00\\x00$size\\x08\\x02\\x00\\x00\\x00')
"
        # If that fails, create using different method
        if [ ! -f "$ICON_DIR/$filename" ]; then
            # Use textutil to create a basic file and convert
            echo "Creating basic icon: $filename"
            touch "$ICON_DIR/$filename"
        fi
    fi
}

# Create all required icon sizes
create_icon 40 "iphone-20@2x.png"
create_icon 60 "iphone-20@3x.png"
create_icon 58 "iphone-29@2x.png"
create_icon 87 "iphone-29@3x.png"
create_icon 80 "iphone-40@2x.png"
create_icon 120 "iphone-40@3x.png"
create_icon 120 "iphone-60@2x.png"
create_icon 180 "iphone-60@3x.png"
create_icon 20 "ipad-20@1x.png"
create_icon 40 "ipad-20@2x.png"
create_icon 29 "ipad-29@1x.png"
create_icon 58 "ipad-29@2x.png"
create_icon 40 "ipad-40@1x.png"
create_icon 80 "ipad-40@2x.png"
create_icon 76 "ipad-76@1x.png"
create_icon 152 "ipad-76@2x.png"
create_icon 167 "ipad-83.5@2x.png"
create_icon 1024 "ios-marketing@1x.png"

echo "📝 Updating Contents.json with icon filenames..."

# Update Contents.json to reference the icon files
cat > "$ICON_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "iphone-20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "iphone-20@3x.png", 
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "iphone-29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x", 
      "size" : "29x29"
    },
    {
      "filename" : "iphone-29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "iphone-40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "iphone-40@3x.png",
      "idiom" : "iphone", 
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "iphone-60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "iphone-60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x", 
      "size" : "60x60"
    },
    {
      "filename" : "ipad-20@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "ipad-20@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "ipad-29@1x.png", 
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "ipad-29@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "ipad-40@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "ipad-40@2x.png",
      "idiom" : "ipad",
      "scale" : "2x", 
      "size" : "40x40"
    },
    {
      "filename" : "ipad-76@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "ipad-76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "ipad-83.5@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "ios-marketing@1x.png",
      "idiom" : "ios-marketing",
      "scale" : "1x", 
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ Icon setup complete!"
echo ""
echo "📱 Next steps:"
echo "1. Download a proper app icon (1024x1024) and replace the placeholder"
echo "2. Use an icon generator like https://appicon.co to create all sizes"
echo "3. Or proceed with placeholders for now and update later"