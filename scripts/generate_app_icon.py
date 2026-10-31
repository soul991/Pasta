"""
Pasta App Icon & Menu Bar Glyph Generator

Processes an exported master icon (assets/AppIcon-1024.png) into standard macOS iconsets
and AppIcon.icns with high-quality LANCZOS downscaling.
Generates solid monochrome template glyphs for MenuBarIcon (18 pt and 22 pt).

NOTE: All procedural redrawing of the app icon in Python has been removed per Phase 10B spec.
Master icon is provided externally (e.g. Figma export).
"""

import os
import struct
import subprocess
from PIL import Image

def build_icns_file(iconset_png_map, output_icns_path):
    """
    Pack PNGs into standard Apple ICNS format binary file.
    Types:
    'icp4': 16x16
    'ic11': 32x32 (16x16@2x)
    'icp5': 32x32
    'ic12': 64x64 (32x32@2x)
    'icp6': 64x64
    'ic07': 128x128
    'ic13': 256x256 (128x128@2x)
    'ic08': 256x256
    'ic14': 512x512 (256x256@2x)
    'ic09': 512x512
    'ic10': 1024x1024 (512x512@2x)
    """
    type_size_map = [
        ('icp4', 16),
        ('ic11', 32),
        ('icp5', 32),
        ('ic12', 64),
        ('icp6', 64),
        ('ic07', 128),
        ('ic13', 256),
        ('ic08', 256),
        ('ic14', 512),
        ('ic09', 512),
        ('ic10', 1024)
    ]
    
    chunks = []
    total_len = 8 # 4 bytes 'icns' + 4 bytes length
    
    for tag, sz in type_size_map:
        if sz in iconset_png_map:
            png_bytes = iconset_png_map[sz]
            chunk_len = 8 + len(png_bytes)
            chunk_hdr = tag.encode('ascii') + struct.pack('>I', chunk_len)
            chunks.append(chunk_hdr + png_bytes)
            total_len += chunk_len
            
    header = b'icns' + struct.pack('>I', total_len)
    with open(output_icns_path, 'wb') as f:
        f.write(header)
        for chk in chunks:
            f.write(chk)
    print(f"Generated ICNS file ({total_len} bytes) at: {output_icns_path}")

def generate_menu_bar_glyphs():
    """
    Menu bar glyph (template image, monochrome silhouette):
    Solid diagonal rigatoni tube silhouette (no gradient).
    Generates 22 pt and 18 pt vector SVGs and exports 18 pt MenuBarIcon.pdf.
    Label: 'needs visual check on a Mac'
    """
    svg_22 = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" width="22" height="22">
  <g transform="rotate(-45 11 11)" fill="currentColor">
    <path fill-rule="evenodd" d="
      M 7.0 4.0
      C 7.0 2.2, 15.0 2.2, 15.0 4.0
      L 15.0 17.5
      C 15.0 19.3, 7.0 19.3, 7.0 17.5
      Z
      
      M 11.0 2.8
      C 13.2 2.8, 13.2 4.4, 11.0 4.4
      C 8.8 4.4, 8.8 2.8, 11.0 2.8
      Z
      
      M 9.1 5.6 H 9.75 V 16.5 H 9.1 Z
      M 12.25 5.6 H 12.9 V 16.5 H 12.25 Z
    " />
  </g>
</svg>'''

    svg_18 = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" width="18" height="18">
  <g transform="rotate(-45 9 9)" fill="currentColor">
    <path fill-rule="evenodd" d="
      M 5.7 3.2
      C 5.7 1.7, 12.3 1.7, 12.3 3.2
      L 12.3 14.4
      C 12.3 15.9, 5.7 15.9, 5.7 14.4
      Z
      
      M 9.0 2.2
      C 10.8 2.2, 10.8 3.5, 9.0 3.5
      C 7.2 3.5, 7.2 2.2, 9.0 2.2
      Z
      
      M 7.4 4.5 H 7.95 V 13.6 H 7.4 Z
      M 10.05 4.5 H 10.6 V 13.6 H 10.05 Z
    " />
  </g>
</svg>'''

    with open('assets/MenuBarIcon.svg', 'w', encoding='utf-8') as f:
        f.write(svg_22)
    with open('assets/MenuBarIcon-18.svg', 'w', encoding='utf-8') as f:
        f.write(svg_18)
    print("Saved assets/MenuBarIcon.svg (22pt) and assets/MenuBarIcon-18.svg (18pt)")

    # Export PDF using rsvg-convert at 72 dpi (18 pt)
    try:
        subprocess.run(
            ['rsvg-convert', '--dpi-x', '72', '--dpi-y', '72', '-f', 'pdf', '-o', 'assets/MenuBarIcon.pdf', 'assets/MenuBarIcon-18.svg'],
            check=True
        )
        print("Generated assets/MenuBarIcon.pdf (18 pt vector template) [needs visual check on a Mac]")
    except Exception as e:
        print(f"Warning: Could not run rsvg-convert to build PDF: {e}")

def main():
    os.makedirs('assets', exist_ok=True)
    os.makedirs('assets/AppIcon.iconset', exist_ok=True)
    
    master_path = 'assets/AppIcon-1024.png'
    if not os.path.exists(master_path):
        print(f"Error: Master icon not found at {master_path}.")
        print("Master icon must be exported from Figma or provided externally (no procedural redrawing).")
        return
        
    print(f"Loading master icon from {master_path}...")
    master = Image.open(master_path).convert('RGBA')
    
    # Generate all standard macOS sizes from master PNG with high-quality LANCZOS downscaling
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    iconset_map = {}
    
    for s in sizes:
        # 1x
        resized = master.resize((s, s), Image.Resampling.LANCZOS)
        out_name = f'assets/AppIcon.iconset/icon_{s}x{s}.png'
        resized.save(out_name, 'PNG', optimize=True)
        with open(out_name, 'rb') as f:
            iconset_map[s] = f.read()
            
        # 2x (@2x)
        if s <= 512:
            s2 = s * 2
            resized2 = master.resize((s2, s2), Image.Resampling.LANCZOS)
            out_name2 = f'assets/AppIcon.iconset/icon_{s}x{s}@2x.png'
            resized2.save(out_name2, 'PNG', optimize=True)
            
    print("Building standard macOS AppIcon.icns...")
    build_icns_file(iconset_map, 'assets/AppIcon.icns')
    
    print("Generating MenuBarIcon template glyphs (needs visual check on a Mac)...")
    generate_menu_bar_glyphs()

if __name__ == '__main__':
    main()
