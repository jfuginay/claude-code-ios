#!/usr/bin/env python3
"""
Extract icons from the HTML generator and save them as PNG files
Replicates the same drawing logic from the JavaScript
"""

import os
import sys
import math

try:
    from PIL import Image, ImageDraw
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

def create_terminal_icon(size):
    """Create terminal icon using the same logic as the HTML generator"""
    if not HAS_PIL:
        print("❌ PIL/Pillow not available. Please install: pip3 install Pillow")
        return None
    
    # Create image
    img = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(img)
    
    # Background gradient (approximated with solid color)
    bg_color = (26, 26, 26)  # #1a1a1a
    draw.rectangle([0, 0, size, size], fill=bg_color)
    
    # Terminal window frame
    frame_size = int(size * 0.8)
    frame_x = (size - frame_size) // 2
    frame_y = (size - frame_size) // 2
    corner_radius = int(frame_size * 0.08)
    
    # Terminal background
    terminal_bg = (30, 30, 30)  # #1e1e1e
    terminal_rect = [frame_x, frame_y, frame_x + frame_size, frame_y + frame_size]
    draw.rounded_rectangle(terminal_rect, radius=corner_radius, fill=terminal_bg)
    
    # Terminal header bar
    header_height = int(frame_size * 0.15)
    header_bg = (45, 45, 45)  # #2d2d2d
    header_rect = [frame_x, frame_y, frame_x + frame_size, frame_y + header_height]
    draw.rounded_rectangle(header_rect, radius=corner_radius, fill=header_bg)
    
    # Traffic light buttons
    button_radius = int(header_height * 0.15)
    button_y = frame_y + header_height // 2
    button_spacing = int(header_height * 0.4)
    start_x = frame_x + int(header_height * 0.3)
    
    # Red button
    red_center = (start_x, button_y)
    red_bbox = [start_x - button_radius, button_y - button_radius,
                start_x + button_radius, button_y + button_radius]
    draw.ellipse(red_bbox, fill=(255, 95, 87))  # #ff5f57
    
    # Yellow button
    yellow_x = start_x + button_spacing
    yellow_bbox = [yellow_x - button_radius, button_y - button_radius,
                   yellow_x + button_radius, button_y + button_radius]
    draw.ellipse(yellow_bbox, fill=(255, 189, 46))  # #ffbd2e
    
    # Green button
    green_x = start_x + button_spacing * 2
    green_bbox = [green_x - button_radius, button_y - button_radius,
                  green_x + button_radius, button_y + button_radius]
    draw.ellipse(green_bbox, fill=(40, 202, 66))  # #28ca42
    
    # Claude "C" logo (simplified as circle for PIL)
    content_y = frame_y + header_height
    content_height = frame_size - header_height
    
    logo_size = int(frame_size * 0.35)
    logo_x = frame_x + (frame_size - logo_size) // 2
    logo_y = content_y + (content_height - logo_size) // 2
    
    # Draw "C" as arc (approximated with circle outline)
    c_radius = int(logo_size * 0.35)
    c_center_x = logo_x + logo_size // 2
    c_center_y = logo_y + logo_size // 2
    c_thickness = int(logo_size * 0.12)
    
    # Outer circle
    outer_bbox = [c_center_x - c_radius - c_thickness//2, c_center_y - c_radius - c_thickness//2,
                  c_center_x + c_radius + c_thickness//2, c_center_y + c_radius + c_thickness//2]
    draw.ellipse(outer_bbox, outline=(0, 255, 136), width=c_thickness)  # #00ff88
    
    # Remove part of circle to make "C" (draw black rectangle)
    gap_width = int(c_radius * 0.8)
    gap_rect = [c_center_x, c_center_y - gap_width//2,
                c_center_x + c_radius + c_thickness, c_center_y + gap_width//2]
    draw.rectangle(gap_rect, fill=terminal_bg)
    
    # Terminal cursor
    cursor_x = logo_x + int(logo_size * 0.75)
    cursor_y = logo_y + int(logo_size * 0.55)
    cursor_width = max(1, int(logo_size * 0.03))
    cursor_height = int(logo_size * 0.15)
    
    cursor_rect = [cursor_x, cursor_y, cursor_x + cursor_width, cursor_y + cursor_height]
    draw.rectangle(cursor_rect, fill=(0, 255, 136))  # #00ff88
    
    # Command prompt dots
    dot_radius = max(1, int(logo_size * 0.02))
    dot_y = logo_y + int(logo_size * 0.8)
    
    for i in range(3):
        dot_color = (0, 255, 136) if i == 0 else (102, 102, 102)  # #00ff88 or #666
        dot_x = logo_x + int(logo_size * 0.2) + i * int(logo_size * 0.08)
        dot_bbox = [dot_x - dot_radius, dot_y - dot_radius,
                    dot_x + dot_radius, dot_y + dot_radius]
        draw.ellipse(dot_bbox, fill=dot_color)
    
    return img

def main():
    """Generate all required iOS app icons"""
    
    if not HAS_PIL:
        print("❌ PIL/Pillow not available")
        print("🔧 Install with: pip3 install Pillow")
        print("💡 Alternative: Use the HTML file in browser and download icons manually")
        return
    
    # Icon sizes and filenames
    icon_specs = [
        (20, "Icon-20.png"),
        (40, "Icon-20@2x.png"),
        (60, "Icon-20@3x.png"),
        (29, "Icon-29.png"),
        (58, "Icon-29@2x.png"),
        (87, "Icon-29@3x.png"),
        (40, "Icon-40.png"),
        (80, "Icon-40@2x.png"),
        (120, "Icon-40@3x.png"),
        (120, "Icon-60@2x.png"),
        (180, "Icon-60@3x.png"),
        (76, "Icon-76.png"),
        (152, "Icon-76@2x.png"),
        (167, "Icon-83.5@2x.png"),
        (1024, "Icon-1024.png")
    ]
    
    output_dir = "/Users/jfuginay/Documents/dev/claude-code-ios/ClaudeCodeiOS/ClaudeCodeiOS/Assets.xcassets/AppIcon.appiconset"
    
    print("🎨 Generating Claude CLI iOS icons...")
    
    for size, filename in icon_specs:
        print(f"  Creating {filename} ({size}x{size})")
        
        icon = create_terminal_icon(size)
        if icon:
            icon.save(os.path.join(output_dir, filename))
        else:
            print(f"  ❌ Failed to create {filename}")
    
    print("✅ All icons generated!")
    print(f"📁 Icons saved to: {output_dir}")
    print("\n🚀 Next steps:")
    print("1. Open Xcode")
    print("2. Build and Archive (Product > Archive)")
    print("3. Upload to TestFlight")

if __name__ == "__main__":
    main()