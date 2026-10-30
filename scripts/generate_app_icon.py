"""
Pasta Farfalle Wheel App Icon Generator
Renders the exact spec from Section 3 of the brief:
- 1024x1024 canvas
- 824x824 squircle at (100, 100) with r=185 continuous curvature
- Obsidian gradient (#2b2233 to #120d18) + radial lift + top highlight + drop shadow
- Subtle 8-segment wheel ring (diameter 560, stroke 2px, 8 radial ticks from r=250 to 280)
- Farfalle bowtie (520x340) with sunset gradient (#ffb347 to #f2611f), scalloped crimped edges (amplitude 10),
  inner folds (#c9460f @ 35%), 2px rim highlight, pinch band (56x150, #ffd089 to #ffa03a, shadow blur 12),
  and contact shadow (420x40, offset Y 150)
- Exports 1024 master, 512, 256, 128, 64, 32, 16 (1x and 2x), binary .icns, and monochrome menu bar glyphs.
"""

import os
import math
import struct
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def make_squircle_mask(size=1024, rect=(100, 100, 824, 824), r=185, ss=2):
    """
    Continuous curvature macOS squircle using superellipse approximation (n ~ 4.4).
    Rendered at supersampled resolution (ss x ss) for sub-pixel anti-aliasing.
    """
    w = size * ss
    rx, ry, rw, rh = [v * ss for v in rect]
    cx = rx + rw / 2.0
    cy = ry + rh / 2.0
    half_w = rw / 2.0
    half_h = rh / 2.0
    
    # Grid
    y_coords, x_coords = np.ogrid[:w, :w]
    dx = np.abs(x_coords - cx)
    dy = np.abs(y_coords - cy)
    
    # Straight box dimensions before corner rounding
    corner_r = r * ss
    straight_w = half_w - corner_r
    straight_h = half_h - corner_r
    
    # Compute signed distance / inside test with continuous exponent
    # Formula for Apple squircle: (|x|/half_w)^n + (|y|/half_h)^n <= 1 with n ~ 4.6
    n = 4.6
    dist = (dx / half_w) ** n + (dy / half_h) ** n
    
    mask_ss = (dist <= 1.0).astype(np.float32)
    # Anti-alias by box blur on supersampled grid
    img = Image.fromarray((mask_ss * 255).astype(np.uint8))
    img = img.resize((size, size), Image.Resampling.LANCZOS)
    return np.array(img, dtype=np.float32) / 255.0

def generate_pasta_master_icon():
    CANVAS_SIZE = 1024
    SS = 2 # Supersampling factor
    W = CANVAS_SIZE * SS
    H = CANVAS_SIZE * SS
    
    # Create canvas (RGBA)
    base = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    
    # 1. Drop shadow under squircle: Y +24, blur 48, black 28%
    # Squircle bounding box: (100, 100, 824, 824)
    squircle_mask_ss = make_squircle_mask(CANVAS_SIZE, (100, 100, 824, 824), r=185, ss=SS)
    
    shadow_layer = Image.new('RGBA', (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    shadow_mask = (squircle_mask_ss * 255 * 0.28).astype(np.uint8)
    shadow_layer.putalpha(Image.fromarray(shadow_mask))
    
    # Offset Y by 24 and blur by 48
    shadow_offset = Image.new('RGBA', (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    shadow_offset.paste(shadow_layer, (0, 24))
    shadow_blurred = shadow_offset.filter(ImageFilter.GaussianBlur(radius=48))
    
    # 2. Squircle Surface
    # Obsidian gradient: top #2b2233 to bottom #120d18
    top_c = np.array(hex_to_rgb('#2b2233'), dtype=np.float32)
    bot_c = np.array(hex_to_rgb('#120d18'), dtype=np.float32)
    
    # Gradient in range y = 100 to 924
    surface_arr = np.zeros((CANVAS_SIZE, CANVAS_SIZE, 4), dtype=np.float32)
    for y in range(CANVAS_SIZE):
        t = np.clip((y - 100.0) / 824.0, 0.0, 1.0)
        c = top_c * (1.0 - t) + bot_c * t
        surface_arr[y, :, :3] = c
    surface_arr[:, :, 3] = 255.0
    
    # Soft radial lift at top center: center (512, 160), radius 480, rgba(255, 255, 255, 0.07)
    cy, cx = 160.0, 512.0
    y_g, x_g = np.ogrid[:CANVAS_SIZE, :CANVAS_SIZE]
    dist_lift = np.sqrt((x_g - cx)**2 + (y_g - cy)**2)
    lift_alpha = np.clip(1.0 - (dist_lift / 460.0), 0.0, 1.0) * 0.07 * 255.0
    for ch in range(3):
        surface_arr[:, :, ch] += lift_alpha
    surface_arr[:, :, :3] = np.clip(surface_arr[:, :, :3], 0.0, 255.0)
    
    # Inner 1.5 px top highlight rgba(255, 255, 255, 0.22) fading to 0 by middle (y ~ 512)
    # Detect top boundary of squircle mask
    grad_y = np.maximum(0, -np.gradient(squircle_mask_ss, axis=0))
    highlight_intensity = grad_y * np.clip(1.0 - ((np.arange(CANVAS_SIZE)[:, None] - 100) / 412.0), 0.0, 1.0)
    for ch in range(3):
        surface_arr[:, :, ch] += highlight_intensity * 0.22 * 255.0 * 3.0
    surface_arr[:, :, :3] = np.clip(surface_arr[:, :, :3], 0.0, 255.0)
    
    # Apply squircle mask
    surface_arr[:, :, 3] = squircle_mask_ss * 255.0
    squircle_img = Image.fromarray(surface_arr.astype(np.uint8))
    
    # Combine Shadow + Squircle
    composite = Image.alpha_composite(shadow_blurred, squircle_img)
    
    # 3. Subtle Wheel Ring on Squircle
    # Circle diameter 560 centered at (512, 512), stroke 2 px rgba(255,255,255,0.10)
    # Eight radial ticks (every 45 deg) from radius 250 to 280, 2 px, rgba(255,255,255,0.10)
    ring_img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring_img)
    
    center = (512 * SS, 512 * SS)
    radius = 280 * SS
    ring_draw.ellipse(
        [center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius],
        outline=(255, 255, 255, int(255 * 0.10)),
        width=int(2 * SS)
    )
    
    for i in range(8):
        angle = i * (math.pi / 4.0)
        r_start = 250 * SS
        r_end = 280 * SS
        x1 = center[0] + r_start * math.cos(angle)
        y1 = center[1] + r_start * math.sin(angle)
        x2 = center[0] + r_end * math.cos(angle)
        y2 = center[1] + r_end * math.sin(angle)
        ring_draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, int(255 * 0.10)), width=int(2 * SS))
        
    ring_down = ring_img.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)
    composite = Image.alpha_composite(composite, ring_down)
    
    # 4. Contact Shadow under Bowtie
    # Ellipse under bowtie, 420 x 40, black 30%, blur 30, offset Y 150 -> center (512, 512 + 150) = (512, 662)
    contact_layer = Image.new('RGBA', (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    contact_draw = ImageDraw.Draw(contact_layer)
    cs_w = 420
    cs_h = 40
    cs_cx = 512
    cs_cy = 512 + 150
    contact_draw.ellipse(
        [cs_cx - cs_w/2, cs_cy - cs_h/2, cs_cx + cs_w/2, cs_cy + cs_h/2],
        fill=(0, 0, 0, int(255 * 0.30))
    )
    contact_blurred = contact_layer.filter(ImageFilter.GaussianBlur(radius=30))
    composite = Image.alpha_composite(composite, contact_blurred)
    
    # 5. Farfalle (Bowtie Pasta)
    # Centered at (512, 512), total width 520, height 340
    # Two wings, mirrored. Pinch half-height 36, outer half-height 170.
    # Scalloped outer edge (4 to 5 gentle waves, amplitude 10).
    # Sunset gradient: #ffb347 top-left to #f2611f bottom-right.
    # Darker inner fold (#c9460f @ 35%), 2px rim highlight (rgba(255,255,255,0.45)).
    
    farfalle_ss = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    farfalle_draw = ImageDraw.Draw(farfalle_ss)
    
    # Generate points for left wing
    # Pinch edge at x = 512 - 28 = 484
    # Outer edge at x = 512 - 260 = 252
    def get_wing_points(is_left=True):
        pts = []
        cx = 512 * SS
        cy = 512 * SS
        pinch_x = (512 - 28 if is_left else 512 + 28) * SS
        outer_x = (512 - 260 if is_left else 512 + 260) * SS
        
        # Top contour: flare from pinch top (cy - 36) to outer top (cy - 170)
        num_steps = 30
        for i in range(num_steps + 1):
            t = i / float(num_steps)
            x = pinch_x + (outer_x - pinch_x) * t
            # Smooth cubic flare curve
            ease = t * t * (3.0 - 2.0 * t)
            y = (cy - 36 * SS) - (170 - 36) * SS * (ease ** 0.85)
            pts.append((x, y))
            
        # Outer edge: scalloped edge with 5 gentle waves, amplitude 10 px
        num_scallops = 5
        scallop_steps = 50
        for i in range(scallop_steps + 1):
            s = i / float(scallop_steps)
            base_y = (cy - 170 * SS) + (340 * SS) * s
            # Scallop wave
            wave = math.sin(s * math.pi * num_scallops) * (10 * SS)
            x = outer_x - wave if is_left else outer_x + wave
            pts.append((x, base_y))
            
        # Bottom contour: flare from outer bottom (cy + 170) to pinch bottom (cy + 36)
        for i in range(num_steps + 1):
            t = i / float(num_steps)
            x = outer_x + (pinch_x - outer_x) * t
            ease = (1.0 - t) * (1.0 - t) * (3.0 - 2.0 * (1.0 - t))
            y = (cy + 36 * SS) + (170 - 36) * SS * (ease ** 0.85)
            pts.append((x, y))
            
        return pts
    
    left_wing_pts = get_wing_points(is_left=True)
    right_wing_pts = get_wing_points(is_left=False)
    
    # Render wing masks
    mask_wings = Image.new('L', (W, H), 0)
    mask_draw = ImageDraw.Draw(mask_wings)
    mask_draw.polygon(left_wing_pts, fill=255)
    mask_draw.polygon(right_wing_pts, fill=255)
    
    # Sunset linear gradient: #ffb347 (255, 179, 71) at top-left to #f2611f (242, 97, 31) at bottom-right
    c_tl = np.array(hex_to_rgb('#ffb347'), dtype=np.float32)
    c_br = np.array(hex_to_rgb('#f2611f'), dtype=np.float32)
    
    y_grid, x_grid = np.ogrid[:H, :W]
    # Diagonal t from (252, 342) to (772, 682)
    t_diag = ((x_grid / SS - 252.0) + (y_grid / SS - 342.0)) / (520.0 + 340.0)
    t_diag = np.clip(t_diag, 0.0, 1.0)
    
    wings_arr = np.zeros((H, W, 4), dtype=np.float32)
    for ch in range(3):
        wings_arr[:, :, ch] = c_tl[ch] * (1.0 - t_diag) + c_br[ch] * t_diag
    wings_arr[:, :, 3] = np.array(mask_wings, dtype=np.float32)
    
    # Darker inner fold on each wing: #c9460f @ 35% opacity
    # Radiating radial fold / crease from pinch center to outer middle
    fold_c = np.array(hex_to_rgb('#c9460f'), dtype=np.float32)
    fold_mask = Image.new('L', (W, H), 0)
    fold_draw = ImageDraw.Draw(fold_mask)
    
    # Crease triangles radiating across each wing
    # Left wing crease
    fold_draw.polygon([
        ((512 - 28) * SS, (512 - 10) * SS),
        ((512 - 250) * SS, (512 - 40) * SS),
        ((512 - 250) * SS, (512 + 40) * SS),
        ((512 - 28) * SS, (512 + 10) * SS)
    ], fill=int(255 * 0.35))
    
    # Right wing crease
    fold_draw.polygon([
        ((512 + 28) * SS, (512 - 10) * SS),
        ((512 + 250) * SS, (512 - 40) * SS),
        ((512 + 250) * SS, (512 + 40) * SS),
        ((512 + 28) * SS, (512 + 10) * SS)
    ], fill=int(255 * 0.35))
    
    fold_blurred = fold_mask.filter(ImageFilter.GaussianBlur(radius=8 * SS))
    fold_alpha = np.array(fold_blurred, dtype=np.float32) / 255.0
    
    for ch in range(3):
        wings_arr[:, :, ch] = wings_arr[:, :, ch] * (1.0 - fold_alpha) + fold_c[ch] * fold_alpha
        
    # Rim highlight: 2 px along upper edge rgba(255, 255, 255, 0.45)
    # Detect top edges of wings
    mask_wing_arr = np.array(mask_wings, dtype=np.float32) / 255.0
    top_rim = np.maximum(0, -np.gradient(mask_wing_arr, axis=0))
    rim_alpha = (top_rim > 0.08).astype(np.float32) * 0.45
    for ch in range(3):
        wings_arr[:, :, ch] = wings_arr[:, :, ch] * (1.0 - rim_alpha) + 255.0 * rim_alpha
        
    wings_img = Image.fromarray(wings_arr.astype(np.uint8))
    
    # 6. Pinch Band: rounded vertical band 56 wide, 150 tall
    # Centered at (512, 512) -> x from 484 to 540, y from 437 to 587
    # Lighter gradient: #ffd089 (top) to #ffa03a (bottom)
    # Soft shadow beneath it: blur 12, 30% black
    pinch_shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ps_draw = ImageDraw.Draw(pinch_shadow)
    pb_rect = [484 * SS, 437 * SS, 540 * SS, 587 * SS]
    pb_r = 20 * SS
    ps_draw.rounded_rectangle(pb_rect, radius=pb_r, fill=(0, 0, 0, int(255 * 0.30)))
    ps_blurred = pinch_shadow.filter(ImageFilter.GaussianBlur(radius=12 * SS))
    
    # Render Pinch Band with gradient
    pinch_mask = Image.new('L', (W, H), 0)
    pm_draw = ImageDraw.Draw(pinch_mask)
    pm_draw.rounded_rectangle(pb_rect, radius=pb_r, fill=255)
    
    p_top = np.array(hex_to_rgb('#ffd089'), dtype=np.float32)
    p_bot = np.array(hex_to_rgb('#ffa03a'), dtype=np.float32)
    pinch_arr = np.zeros((H, W, 4), dtype=np.float32)
    
    for y in range(H):
        t = np.clip((y / SS - 437.0) / 150.0, 0.0, 1.0)
        c = p_top * (1.0 - t) + p_bot * t
        pinch_arr[y, :, :3] = c
    pinch_arr[:, :, 3] = np.array(pinch_mask, dtype=np.float32)
    
    # Pinch subtle top rim highlight
    pm_arr = np.array(pinch_mask, dtype=np.float32) / 255.0
    p_rim = (np.maximum(0, -np.gradient(pm_arr, axis=0)) > 0.1).astype(np.float32) * 0.4
    for ch in range(3):
        pinch_arr[:, :, ch] = pinch_arr[:, :, ch] * (1.0 - p_rim) + 255.0 * p_rim
        
    pinch_img = Image.fromarray(pinch_arr.astype(np.uint8))
    
    # Assemble bowtie
    bowtie_layer = Image.alpha_composite(wings_img, ps_blurred)
    bowtie_layer = Image.alpha_composite(bowtie_layer, pinch_img)
    
    # Downsample bowtie to canvas size
    bowtie_down = bowtie_layer.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)
    
    # Composite all together
    final_icon = Image.alpha_composite(composite, bowtie_down)
    return final_icon

def generate_menu_bar_glyph():
    """
    Menu bar glyph (template image, monochrome):
    22 x 22 pt. A solid bowtie silhouette with a pinch band, no gradient, no ring, 1.5 pt padding.
    Export as SVG and high-res PNG.
    """
    svg_22 = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" width="22" height="22">
  <g fill="currentColor">
    <!-- Left Wing -->
    <path d="M 9.5 9.8 C 7.2 8.4 4.5 5.5 2.5 5.2 C 2.1 6.5 2.1 8.0 2.6 9.2 C 2.0 10.1 2.0 11.9 2.6 12.8 C 2.1 14.0 2.1 15.5 2.5 16.8 C 4.5 16.5 7.2 13.6 9.5 12.2 Z" />
    <!-- Right Wing -->
    <path d="M 12.5 9.8 C 14.8 8.4 17.5 5.5 19.5 5.2 C 19.9 6.5 19.9 8.0 19.4 9.2 C 20.0 10.1 20.0 11.9 19.4 12.8 C 19.9 14.0 19.9 15.5 19.5 16.8 C 17.5 16.5 14.8 13.6 12.5 12.2 Z" />
    <!-- Center Pinch Band -->
    <rect x="9.7" y="6.8" width="2.6" height="8.4" rx="1.3" />
  </g>
</svg>'''

    svg_18 = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" width="18" height="18">
  <g fill="currentColor">
    <!-- Left Wing -->
    <path d="M 7.8 8.0 C 5.9 6.9 3.7 4.5 2.0 4.3 C 1.7 5.3 1.7 6.5 2.1 7.5 C 1.6 8.3 1.6 9.7 2.1 10.5 C 1.7 11.5 1.7 12.7 2.0 13.7 C 3.7 13.5 5.9 11.1 7.8 10.0 Z" />
    <!-- Right Wing -->
    <path d="M 10.2 8.0 C 12.1 6.9 14.3 4.5 16.0 4.3 C 16.3 5.3 16.3 6.5 15.9 7.5 C 16.4 8.3 16.4 9.7 15.9 10.5 C 16.3 11.5 16.3 12.7 16.0 13.7 C 14.3 13.5 12.1 11.1 10.2 10.0 Z" />
    <!-- Center Pinch Band -->
    <rect x="8.0" y="5.6" width="2.0" height="6.8" rx="1.0" />
  </g>
</svg>'''
    return svg_22, svg_18

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

def main():
    os.makedirs('assets', exist_ok=True)
    os.makedirs('assets/AppIcon.iconset', exist_ok=True)
    
    print("Generating 1024x1024 Pasta Farfalle Wheel master icon...")
    master = generate_pasta_master_icon()
    master_path = 'assets/AppIcon-1024.png'
    master.save(master_path, 'PNG', optimize=True)
    print(f"Saved master icon: {master_path}")
    
    # Generate all standard macOS sizes
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
    
    # Generate Menu Bar Glyphs
    svg_22, svg_18 = generate_menu_bar_glyph()
    with open('assets/MenuBarIcon.svg', 'w', encoding='utf-8') as f:
        f.write(svg_22)
    with open('assets/MenuBarIcon-18.svg', 'w', encoding='utf-8') as f:
        f.write(svg_18)
    print("Saved MenuBarIcon.svg and MenuBarIcon-18.svg")

if __name__ == '__main__':
    main()
