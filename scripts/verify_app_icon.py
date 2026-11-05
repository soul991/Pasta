#!/usr/bin/env python3
"""
Verify AppIcon-1024.png dimensions, alpha channel, and transparent corner pixels.
Pure standard library Python 3 (no third-party packages).
"""

import os
import struct
import subprocess
import sys
import zlib


def verify_with_sips(png_path):
    """Run macOS sips to verify width, height, and alpha channel presence."""
    try:
        out = subprocess.check_output(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", png_path],
            text=True,
            stderr=subprocess.STDOUT
        )
        if "pixelWidth: 1024" not in out:
            print(f"[FAIL] sips pixelWidth is not 1024:\n{out}", file=sys.stderr)
            return False
        if "pixelHeight: 1024" not in out:
            print(f"[FAIL] sips pixelHeight is not 1024:\n{out}", file=sys.stderr)
            return False
        if "hasAlpha: yes" not in out:
            print(f"[FAIL] sips hasAlpha is not 'yes':\n{out}", file=sys.stderr)
            return False
        print(f"[PASS] sips confirmed 1024x1024 with alpha channel for {png_path}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[FAIL] sips invocation failed: {e.output}", file=sys.stderr)
        return False


def verify_corners_pure_python(png_path):
    """
    Decodes the PNG using standard library zlib and struct.
    Validates dimensions (1024x1024), RGBA color type, and transparent corners.
    """
    with open(png_path, "rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n":
            print(f"[FAIL] {png_path} is not a valid PNG file", file=sys.stderr)
            return False

        idat_chunks = bytearray()
        width = height = bit_depth = color_type = interlace = None

        while True:
            chunk_header = f.read(8)
            if len(chunk_header) < 8:
                break
            length, chunk_type = struct.unpack(">I4s", chunk_header)
            data = f.read(length)
            f.read(4)  # CRC32

            if chunk_type == b"IHDR":
                width, height, bit_depth, color_type, comp, filt, interlace = struct.unpack(
                    ">IIBBBBB", data
                )
            elif chunk_type == b"IDAT":
                idat_chunks.extend(data)
            elif chunk_type == b"IEND":
                break

    if width != 1024 or height != 1024:
        print(f"[FAIL] Image dimensions {width}x{height} != 1024x1024", file=sys.stderr)
        return False

    if bit_depth != 8:
        print(f"[FAIL] Bit depth {bit_depth} != 8", file=sys.stderr)
        return False

    if color_type != 6:  # RGBA
        print(f"[FAIL] Color type {color_type} != 6 (RGBA)", file=sys.stderr)
        return False

    if interlace != 0:
        print(f"[FAIL] Interlaced PNG not supported for corner verification", file=sys.stderr)
        return False

    raw = zlib.decompress(bytes(idat_chunks))
    bpp = 4  # RGBA 8-bit
    stride = 1 + width * bpp
    prev_row = bytearray(width * bpp)

    corners = {}

    for y in range(height):
        row_start = y * stride
        ftype = raw[row_start]
        curr = raw[row_start + 1 : row_start + stride]
        out_row = bytearray(width * bpp)

        if ftype == 0:  # None
            out_row[:] = curr
        elif ftype == 1:  # Sub
            for i in range(width * bpp):
                left = out_row[i - bpp] if i >= bpp else 0
                out_row[i] = (curr[i] + left) & 0xFF
        elif ftype == 2:  # Up
            for i in range(width * bpp):
                up = prev_row[i]
                out_row[i] = (curr[i] + up) & 0xFF
        elif ftype == 3:  # Average
            for i in range(width * bpp):
                left = out_row[i - bpp] if i >= bpp else 0
                up = prev_row[i]
                out_row[i] = (curr[i] + ((left + up) // 2)) & 0xFF
        elif ftype == 4:  # Paeth
            for i in range(width * bpp):
                a = out_row[i - bpp] if i >= bpp else 0
                b = prev_row[i]
                c = prev_row[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                out_row[i] = (curr[i] + pr) & 0xFF
        else:
            print(f"[FAIL] Unknown PNG filter type {ftype}", file=sys.stderr)
            return False

        if y == 0:
            corners["Top-Left (0, 0)"] = tuple(out_row[0:4])
            tr_idx = (width - 1) * bpp
            corners["Top-Right (1023, 0)"] = tuple(out_row[tr_idx : tr_idx + 4])
        elif y == height - 1:
            corners["Bottom-Left (0, 1023)"] = tuple(out_row[0:4])
            br_idx = (width - 1) * bpp
            corners["Bottom-Right (1023, 1023)"] = tuple(out_row[br_idx : br_idx + 4])

        prev_row = out_row

    print(f"Corner Pixel Values for {png_path}:")
    opaque_corners = []
    for pos, (r, g, b, a) in corners.items():
        print(f"  {pos}: RGBA({r}, {g}, {b}, {a})")
        if a != 0:
            opaque_corners.append((pos, a))

    if opaque_corners:
        print(f"[FAIL] Opaque corner pixels detected: {opaque_corners}", file=sys.stderr)
        print("A gray box around the Dock icon is the known risk if corners are opaque.", file=sys.stderr)
        return False

    print(f"[PASS] All 4 corner pixels are 100% transparent (alpha == 0).")
    return True


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "assets/AppIcon-1024.png"
    if not os.path.exists(target):
        print(f"[FAIL] Target icon file not found: {target}", file=sys.stderr)
        sys.exit(1)

    # sips check
    sips_ok = verify_with_sips(target)
    # pure python corner check
    corners_ok = verify_corners_pure_python(target)

    if sips_ok and corners_ok:
        print(f"[SUCCESS] App icon verification PASSED for {target}")
        sys.exit(0)
    else:
        print(f"[FAILURE] App icon verification FAILED for {target}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
