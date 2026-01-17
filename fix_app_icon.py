#!/usr/bin/env python3
"""
Fix App Icon Script
- Removes transparency (adds white background)
- Creates proper AppIcon.appiconset structure
- Generates all required icon sizes
"""

from PIL import Image
import os
import json
import shutil

# Paths
ASSETS_PATH = "/Users/kaleb/Desktop/invoice/Invoice/Assets.xcassets"
OLD_ICON_PATH = os.path.join(ASSETS_PATH, "AppIcon.imageset/AppIcon.png")
APPICONSET_PATH = os.path.join(ASSETS_PATH, "AppIcon.appiconset")

def remove_transparency(input_path, output_path, bg_color="white"):
    """Remove transparency from PNG and add solid background"""
    img = Image.open(input_path)
    
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Create a background
    background = Image.new('RGB', img.size, bg_color)
    
    # Paste the image onto the background
    background.paste(img, mask=img.split()[3])  # Use alpha channel as mask
    
    # Save as RGB (no alpha)
    background.save(output_path, 'PNG')
    print(f"✅ Removed transparency: {output_path}")
    return background

def resize_icon(img, size):
    """Resize icon to specific dimensions"""
    return img.resize((size, size), Image.Resampling.LANCZOS)

def create_appiconset():
    """Create proper AppIcon.appiconset with all required sizes"""
    
    # Create AppIcon.appiconset directory
    if os.path.exists(APPICONSET_PATH):
        print(f"🗑️  Removing old {APPICONSET_PATH}")
        shutil.rmtree(APPICONSET_PATH)
    
    os.makedirs(APPICONSET_PATH, exist_ok=True)
    print(f"📁 Created {APPICONSET_PATH}")
    
    # Remove transparency from original icon
    print(f"🔧 Processing {OLD_ICON_PATH}")
    base_icon = remove_transparency(OLD_ICON_PATH, 
                                   os.path.join(APPICONSET_PATH, "icon-1024.png"))
    
    # Generate required sizes
    sizes = [
        (40, 1, "ipad"),
        (40, 2, "ipad"),
        (60, 2, "iphone"),  # 120x120 - CRITICAL
        (60, 3, "iphone"),  # 180x180 - CRITICAL
        (76, 1, "ipad"),
        (76, 2, "ipad"),
        (83.5, 2, "ipad"),
        (1024, 1, "ios-marketing")  # 1024x1024 - CRITICAL
    ]
    
    images_json = []
    
    for size_pt, scale, idiom in sizes:
        pixel_size = int(size_pt * scale)
        filename = f"icon-{pixel_size}.png"
        filepath = os.path.join(APPICONSET_PATH, filename)
        
        # Resize and save
        resized = resize_icon(base_icon, pixel_size)
        resized.save(filepath, 'PNG')
        print(f"✅ Created {pixel_size}x{pixel_size}: {filename}")
        
        # Add to JSON
        size_str = f"{int(size_pt)}x{int(size_pt)}" if size_pt == int(size_pt) else f"{size_pt}x{size_pt}"
        scale_str = f"{int(scale)}x" if scale == int(scale) else f"{scale}x"
        
        images_json.append({
            "filename": filename,
            "idiom": idiom,
            "scale": scale_str,
            "size": size_str
        })
    
    # Create Contents.json
    contents = {
        "images": images_json,
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    contents_path = os.path.join(APPICONSET_PATH, "Contents.json")
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)
    
    print(f"✅ Created Contents.json")
    
    # Remove old AppIcon.imageset
    old_imageset = os.path.join(ASSETS_PATH, "AppIcon.imageset")
    if os.path.exists(old_imageset):
        shutil.rmtree(old_imageset)
        print(f"🗑️  Removed old AppIcon.imageset")
    
    print("\n✨ SUCCESS! App icon is now properly configured!")
    print(f"📂 Location: {APPICONSET_PATH}")
    print("\n🔄 Next steps:")
    print("1. Open Xcode")
    print("2. Clean Build Folder (Product > Clean Build Folder)")
    print("3. Increment Build number to 2")
    print("4. Archive again (Product > Archive)")
    print("5. Upload should succeed! ✅")

if __name__ == "__main__":
    try:
        create_appiconset()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
