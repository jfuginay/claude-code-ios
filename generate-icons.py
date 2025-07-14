#!/usr/bin/env python3
"""
Generate app icons for Claude Code iOS using SF Symbols
Creates simple icons with the terminal symbol on a blue background
"""

from PIL import Image, ImageDraw
import os

# Icon sizes needed for iOS apps
ICON_SIZES = [
    # iPhone
    (40, "iphone-20@2x.png"),    # 20pt @2x
    (60, "iphone-20@3x.png"),    # 20pt @3x  
    (58, "iphone-29@2x.png"),    # 29pt @2x
    (87, "iphone-29@3x.png"),    # 29pt @3x
    (80, "iphone-40@2x.png"),    # 40pt @2x
    (120, "iphone-40@3x.png"),   # 40pt @3x
    (120, "iphone-60@2x.png"),   # 60pt @2x (App icon)
    (180, "iphone-60@3x.png"),   # 60pt @3x (App icon)
    
    # iPad
    (20, "ipad-20@1x.png"),      # 20pt @1x
    (40, "ipad-20@2x.png"),      # 20pt @2x
    (29, "ipad-29@1x.png"),      # 29pt @1x
    (58, "ipad-29@2x.png"),      # 29pt @2x
    (40, "ipad-40@1x.png"),      # 40pt @1x
    (80, "ipad-40@2x.png"),      # 40pt @2x
    (76, "ipad-76@1x.png"),      # 76pt @1x
    (152, "ipad-76@2x.png"),     # 76pt @2x (App icon)
    (167, "ipad-83.5@2x.png"),   # 83.5pt @2x
    
    # App Store
    (1024, "ios-marketing@1x.png") # 1024pt @1x
]

def create_icon(size, filename):
    """Create a simple icon with terminal symbol on blue background"""
    
    # Create image with blue background
    img = Image.new('RGB', (size, size), color='#007AFF')  # iOS blue
    draw = ImageDraw.Draw(img)
    
    # Create a simple terminal-like design
    # Draw rounded rectangle for terminal window
    margin = size // 8
    rect_size = size - (margin * 2)
    terminal_rect = [margin, margin, margin + rect_size, margin + rect_size]
    
    # Draw terminal window (dark background)
    draw.rounded_rectangle(terminal_rect, radius=size//16, fill='#1C1C1E')
    
    # Draw terminal header bar
    header_height = size // 12
    header_rect = [margin, margin, margin + rect_size, margin + header_height]
    draw.rounded_rectangle(header_rect, radius=size//16, fill='#2C2C2E')
    
    # Draw terminal dots (red, yellow, green)
    dot_size = size // 32
    dot_y = margin + header_height // 2
    
    # Red dot
    red_x = margin + dot_size * 2
    draw.ellipse([red_x - dot_size//2, dot_y - dot_size//2, 
                  red_x + dot_size//2, dot_y + dot_size//2], fill='#FF5F57')
    
    # Yellow dot
    yellow_x = red_x + dot_size * 2
    draw.ellipse([yellow_x - dot_size//2, dot_y - dot_size//2,
                  yellow_x + dot_size//2, dot_y + dot_size//2], fill='#FFBD2E')
    
    # Green dot
    green_x = yellow_x + dot_size * 2
    draw.ellipse([green_x - dot_size//2, dot_y - dot_size//2,
                  green_x + dot_size//2, dot_y + dot_size//2], fill='#28CA42')
    
    # Draw cursor/prompt line
    cursor_y = margin + header_height + size // 8
    cursor_x = margin + size // 16
    cursor_width = size // 32
    cursor_height = size // 24
    draw.rectangle([cursor_x, cursor_y, cursor_x + cursor_width, cursor_y + cursor_height], fill='#00FF41')
    
    return img

def main():
    """Generate all required app icons"""
    
    # Create output directory
    output_dir = "/Users/jfuginay/Documents/dev/claude-code-ios/ClaudeCodeiOS/ClaudeCodeiOS/Assets.xcassets/AppIcon.appiconset"
    
    print("🎨 Generating app icons...")
    
    for size, filename in ICON_SIZES:
        print(f"  Creating {filename} ({size}x{size})")
        icon = create_icon(size, filename)
        icon.save(os.path.join(output_dir, filename))
    
    print("✅ All icons generated successfully!")
    print("\nNext steps:")
    print("1. Open Xcode")
    print("2. The icons should now appear in Assets.xcassets > AppIcon")
    print("3. Build and archive again")

if __name__ == "__main__":
    main()