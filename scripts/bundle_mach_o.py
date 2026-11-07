#!/usr/bin/env python3
"""
Pasta Relocatable Engine Bundler.
Bundles all 19 tools used by Pasta into a self-contained, relocatable directory
with all dynamic libraries copied, paths rewritten via install_name_tool,
Mach-O binaries signed with hardened runtime, and engines.json manifest generated.
"""

import argparse
import glob
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys

# All 19 tools defined in ToolLocator
TOOL_SPECS = [
    {"name": "ffmpeg", "is_optional": False, "version_flag": "-version", "type": "macho"},
    {"name": "ffprobe", "is_optional": False, "version_flag": "-version", "type": "macho"},
    {"name": "cwebp", "is_optional": False, "version_flag": "-version", "type": "macho"},
    {"name": "magick", "is_optional": False, "version_flag": "-version", "type": "macho"},
    {"name": "gs", "is_optional": False, "version_flag": "--version", "type": "macho"},
    {"name": "qpdf", "is_optional": False, "version_flag": "--version", "type": "macho"},
    {"name": "pdftoppm", "is_optional": False, "version_flag": "-v", "type": "macho"},
    {"name": "pdftotext", "is_optional": False, "version_flag": "-v", "type": "macho"},
    {"name": "exiftool", "is_optional": False, "version_flag": "-ver", "type": "perl"},
    {"name": "pandoc", "is_optional": False, "version_flag": "--version", "type": "macho"},
    {"name": "rsvg-convert", "is_optional": False, "version_flag": "--version", "type": "macho"},
    {"name": "unar", "is_optional": False, "version_flag": "-v", "type": "macho"},
    {"name": "7zz", "is_optional": False, "version_flag": "--help", "type": "macho"},
    {"name": "sips", "is_optional": False, "version_flag": "--version", "type": "system"},
    {"name": "ditto", "is_optional": False, "version_flag": "-h", "type": "system"},
    {"name": "tar", "is_optional": False, "version_flag": "--version", "type": "system"},
    {"name": "soffice", "is_optional": True, "version_flag": "--version", "type": "app_bundle", "app_name": "LibreOffice.app", "subpath": "Contents/MacOS/soffice"},
    {"name": "ebook-convert", "is_optional": True, "version_flag": "--version", "type": "app_bundle", "app_name": "calibre.app", "subpath": "Contents/MacOS/ebook-convert"},
    {"name": "avifenc", "is_optional": True, "version_flag": "--version", "type": "macho"}
]

SYSTEM_PATHS = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
BREW_PATHS = ["/opt/homebrew/bin", "/usr/local/bin"]

def is_macho(path: str) -> bool:
    if not os.path.isfile(path) or os.path.islink(path):
        return False
    try:
        with open(path, "rb") as f:
            magic = f.read(4)
            return magic in [
                b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",
                b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
                b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"
            ]
    except Exception:
        return False

def get_dependencies(macho_path: str) -> list[str]:
    try:
        out = subprocess.check_output(["otool", "-L", macho_path]).decode("utf-8", errors="replace")
        deps = []
        for line in out.splitlines()[1:]:
            m = re.match(r"\s+([^\s]+)", line)
            if m:
                dep = m.group(1)
                if not dep.startswith("/usr/lib") and not dep.startswith("/System"):
                    deps.append(dep)
        return deps
    except Exception as e:
        print(f"Warning: could not get dependencies for {macho_path}: {e}", file=sys.stderr)
        return []

def get_rpaths(macho_path: str) -> list[str]:
    try:
        out = subprocess.check_output(["otool", "-l", macho_path]).decode("utf-8", errors="replace")
        rpaths = []
        lines = out.splitlines()
        for i, line in enumerate(lines):
            if "cmd LC_RPATH" in line:
                for j in range(i + 1, min(i + 5, len(lines))):
                    m = re.search(r"path ([^\s]+)", lines[j])
                    if m:
                        rpaths.append(m.group(1))
                        break
        return rpaths
    except Exception:
        return []

def find_system_or_brew_tool(name: str) -> str | None:
    # Check brew first, then system
    for bp in BREW_PATHS:
        c = os.path.join(bp, name)
        if os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    for sp in SYSTEM_PATHS:
        c = os.path.join(sp, name)
        if os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    which_path = shutil.which(name)
    if which_path:
        return which_path
    return None

def resolve_dylib(dep: str, search_rpaths: list[str]) -> str | None:
    if dep.startswith("/opt/homebrew/") or dep.startswith("/usr/local/"):
        if os.path.exists(dep):
            return os.path.realpath(dep)
    if dep.startswith("@rpath/"):
        lib_name = dep.replace("@rpath/", "")
        for rp in search_rpaths:
            candidate = os.path.join(rp, lib_name)
            if os.path.exists(candidate):
                return os.path.realpath(candidate)
        # Fallback search in standard brew locations
        standard_dirs = [
            "/opt/homebrew/lib",
            "/usr/local/lib"
        ] + glob.glob("/opt/homebrew/opt/*/lib") + glob.glob("/usr/local/opt/*/lib")
        for sd in standard_dirs:
            candidate = os.path.join(sd, lib_name)
            if os.path.exists(candidate):
                return os.path.realpath(candidate)
        # Search Cellar
        matches = glob.glob(f"/opt/homebrew/Cellar/*/*/{lib_name}") + glob.glob(f"/opt/homebrew/Cellar/*/*/lib/{lib_name}")
        if matches:
            return os.path.realpath(matches[0])
    return None

def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def get_tool_version(exec_path: str, flag: str) -> str:
    try:
        env = {"PATH": "/usr/bin:/bin"}
        res = subprocess.run([exec_path, flag], capture_output=True, text=True, timeout=5, env=env)
        out = (res.stdout or res.stderr or "").strip()
        first_line = out.splitlines()[0] if out else "Unknown"
        # Extract version like 9.0.2 or 1.6.0
        m = re.search(r"(\d+(\.\d+)+[a-zA-Z0-9_\-]*)", first_line)
        if m:
            return m.group(1)
        return first_line[:30]
    except Exception as e:
        return f"err: {e}"

def safe_copy(src: str, dst: str):
    if os.path.exists(dst) or os.path.islink(dst):
        try:
            os.chmod(dst, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
            if os.path.isdir(dst) and not os.path.islink(dst):
                shutil.rmtree(dst)
            else:
                os.remove(dst)
        except Exception:
            pass
    if os.path.isdir(src):
        shutil.copytree(src, dst)
    else:
        shutil.copy2(src, dst)
    try:
        os.chmod(dst, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
    except Exception:
        pass

def generate_entitlements(path: str):
    entitlements_xml = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>"""
    with open(path, "w") as f:
        f.write(entitlements_xml)

def sign_binary(path: str, entitlements_path: str):
    try:
        subprocess.run(
            ["codesign", "-s", "-", "-f", "--options", "runtime", "--entitlements", entitlements_path, path],
            check=True,
            capture_output=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Warning: codesign failed for {path}: {e.stderr.decode('utf-8', errors='replace')}", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="Pasta Engine Bundler")
    parser.add_argument("dest_dir", nargs="?", default="Pasta.app/Contents/Resources/Engines", help="Destination Engines directory")
    parser.add_argument("--manifest", help="Manifest output path (defaults to <dest_dir>/engines.json)")
    parser.add_argument("--allow-missing-optional", action="store_true", default=True, help="Allow missing optional engines (soffice, calibre)")
    parser.add_argument("--strict", action="store_true", help="Fail if any tool is missing")
    args = parser.parse_args()

    dest_dir = os.path.abspath(args.dest_dir)
    manifest_path = os.path.abspath(args.manifest or os.path.join(dest_dir, "engines.json"))
    bin_dir = os.path.join(dest_dir, "bin")
    lib_dir = os.path.join(dest_dir, "lib")
    share_dir = os.path.join(dest_dir, "share")

    os.makedirs(bin_dir, exist_ok=True)
    os.makedirs(lib_dir, exist_ok=True)
    os.makedirs(share_dir, exist_ok=True)

    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    assets_ent = os.path.join(repo_root, "assets", "entitlements.plist")
    if os.path.exists(assets_ent):
        entitlements_file = assets_ent
    else:
        entitlements_file = "/tmp/pasta_engine_entitlements.plist"
        generate_entitlements(entitlements_file)

    print(f"==> Packaging relocatable engines into: {dest_dir}")

    # Track binaries and dylibs
    macho_binaries = []
    manifest_entries = []
    tools_bundled = []

    # 1. Process each tool specification
    for spec in TOOL_SPECS:
        name = spec["name"]
        tool_type = spec["type"]
        is_opt = spec["is_optional"]

        if tool_type == "system":
            # Wrapper script for system binary into bin/ (avoiding external symlinks that break codesign)
            sys_path = f"/usr/bin/{name}"
            if os.path.exists(sys_path):
                dest_bin = os.path.join(bin_dir, name)
                if os.path.exists(dest_bin) or os.path.islink(dest_bin):
                    os.remove(dest_bin)
                wrapper_content = f"""#!/bin/sh
exec {sys_path} "$@"
"""
                with open(dest_bin, "w") as f:
                    f.write(wrapper_content)
                os.chmod(dest_bin, 0o755)
                v = get_tool_version(dest_bin, spec["version_flag"])
                size = os.path.getsize(sys_path)
                sha = sha256_file(sys_path)
                manifest_entries.append({
                    "id": name,
                    "version": v,
                    "sha256": sha,
                    "size": size,
                    "entry_point": f"bin/{name}",
                    "source": "system_wrapper"
                })
                tools_bundled.append(name)
                print(f"  [system] {name} -> {sys_path} ({v})")
            elif not is_opt:
                if args.strict:
                    sys.exit(f"Error: required system tool {name} not found!")

        elif tool_type == "app_bundle":
            app_name = spec["app_name"]
            subpath = spec["subpath"]
            app_candidates = [
                os.path.join("/Applications", app_name),
                os.path.join(os.path.expanduser("~/Applications"), app_name)
            ]
            found_app = next((p for p in app_candidates if os.path.isdir(p)), None)
            if found_app:
                exec_target = os.path.join(found_app, subpath)
                dest_bin = os.path.join(bin_dir, name)
                wrapper_content = f"""#!/bin/sh
exec "{exec_target}" "$@"
"""
                with open(dest_bin, "w") as f:
                    f.write(wrapper_content)
                os.chmod(dest_bin, 0o755)
                v = get_tool_version(dest_bin, spec["version_flag"])
                size = os.path.getsize(dest_bin)
                sha = sha256_file(dest_bin)
                manifest_entries.append({
                    "id": name,
                    "version": v,
                    "sha256": sha,
                    "size": size,
                    "entry_point": f"bin/{name}",
                    "source": "cask_wrapper"
                })
                tools_bundled.append(name)
                print(f"  [app_bundle] {name} -> {exec_target} ({v})")
            else:
                if not is_opt and args.strict:
                    sys.exit(f"Error: required app bundle {app_name} not found!")
                else:
                    print(f"  [skip optional] {name} ({app_name} not installed)")

        elif tool_type == "perl":
            src = find_system_or_brew_tool(name)
            if src:
                dest_bin = os.path.join(bin_dir, name)
                with open(src, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
                # Rewrite Homebrew @INC unshift paths to relative lib
                content = re.sub(r"unshift @INC, \"/opt/homebrew[^\"]+\";\n?", "", content)
                content = re.sub(r"unshift @INC, \"/usr/local[^\"]+\";\n?", "", content)
                hook = """
use File::Basename ();
my $_pasta_lib = File::Basename::dirname(File::Basename::dirname(__FILE__)) . "/lib/perl5";
unshift @INC, $_pasta_lib;
"""
                content = content.replace("# add lib directory at start of include path", "# add lib directory at start of include path\n" + hook)
                with open(dest_bin, "w") as f:
                    f.write(content)
                os.chmod(dest_bin, 0o755)

                # Copy perl5 lib from Cellar
                cellar_libs = glob.glob("/opt/homebrew/Cellar/exiftool/*/libexec/lib/perl5/*") + glob.glob("/usr/local/Cellar/exiftool/*/libexec/lib/perl5/*")
                perl_lib_dest = os.path.join(lib_dir, "perl5")
                os.makedirs(perl_lib_dest, exist_ok=True)
                for item in cellar_libs:
                    target_item = os.path.join(perl_lib_dest, os.path.basename(item))
                    safe_copy(item, target_item)

                v = get_tool_version(dest_bin, spec["version_flag"])
                size = os.path.getsize(dest_bin)
                sha = sha256_file(dest_bin)
                manifest_entries.append({
                    "id": name,
                    "version": v,
                    "sha256": sha,
                    "size": size,
                    "entry_point": f"bin/{name}",
                    "source": "bundled_script"
                })
                tools_bundled.append(name)
                print(f"  [perl] {name} -> {dest_bin} ({v})")
            elif not is_opt and args.strict:
                sys.exit(f"Error: required tool {name} not found!")

        elif tool_type == "macho":
            src = find_system_or_brew_tool(name)
            if src:
                real_src = os.path.realpath(src)
                if name in ("magick", "gs"):
                    dest_bin_real = os.path.join(bin_dir, f"{name}-bin")
                    safe_copy(real_src, dest_bin_real)
                    macho_binaries.append(dest_bin_real)
                    dest_bin = os.path.join(bin_dir, name)
                    if name == "magick":
                        wrapper_content = """#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINES_DIR="$(cd "$DIR/.." && pwd)"
export MAGICK_HOME="$ENGINES_DIR"
export MAGICK_CODER_MODULE_PATH="$ENGINES_DIR/lib/ImageMagick/modules-Q16HDRI/coders"
export MAGICK_CONFIGURE_PATH="$ENGINES_DIR/etc/ImageMagick-7:$ENGINES_DIR/lib/ImageMagick/config-Q16HDRI"
exec "$DIR/magick-bin" "$@"
"""
                    else:
                        wrapper_content = """#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINES_DIR="$(cd "$DIR/.." && pwd)"
export GS_LIB="$ENGINES_DIR/share/ghostscript/Resource/Init:$ENGINES_DIR/share/ghostscript/lib:$ENGINES_DIR/share/ghostscript/Resource/Font:$ENGINES_DIR/share/ghostscript/fonts"
exec "$DIR/gs-bin" "$@"
"""
                    with open(dest_bin, "w") as f:
                        f.write(wrapper_content)
                    os.chmod(dest_bin, 0o755)
                    v = get_tool_version(dest_bin, spec["version_flag"])
                    size = os.path.getsize(dest_bin_real)
                    sha = sha256_file(dest_bin_real)
                    manifest_entries.append({
                        "id": name,
                        "version": v,
                        "sha256": sha,
                        "size": size,
                        "entry_point": f"bin/{name}",
                        "source": "bundled_macho_wrapper"
                    })
                    tools_bundled.append(name)
                    print(f"  [macho_wrapper] {name} -> {dest_bin} ({v})")
                else:
                    dest_bin = os.path.join(bin_dir, name)
                    safe_copy(real_src, dest_bin)
                    macho_binaries.append(dest_bin)
                    v = get_tool_version(real_src, spec["version_flag"])
                    size = os.path.getsize(dest_bin)
                    sha = sha256_file(dest_bin)
                    manifest_entries.append({
                        "id": name,
                        "version": v,
                        "sha256": sha,
                        "size": size,
                        "entry_point": f"bin/{name}",
                        "source": "bundled_macho"
                    })
                    tools_bundled.append(name)
                    print(f"  [macho] {name} -> {dest_bin} ({v})")
            else:
                if not is_opt and args.strict:
                    sys.exit(f"Error: required tool {name} not found!")
                else:
                    print(f"  [skip optional] {name} (not found)")

    # 2. Gather auxiliary share data for Ghostscript and ImageMagick if present
    gs_share = glob.glob("/opt/homebrew/share/ghostscript/*") + glob.glob("/usr/local/share/ghostscript/*")
    if gs_share:
        target_gs = os.path.join(share_dir, "ghostscript")
        os.makedirs(target_gs, exist_ok=True)
        for s in gs_share:
            t = os.path.join(target_gs, os.path.basename(s))
            safe_copy(s, t)

    im_share = glob.glob("/opt/homebrew/share/ImageMagick-*") + glob.glob("/usr/local/share/ImageMagick-*")
    if im_share:
        for s in im_share:
            t = os.path.join(share_dir, os.path.basename(s))
            safe_copy(s, t)

    im_lib_coders = glob.glob("/opt/homebrew/Cellar/imagemagick/*/lib/ImageMagick") + glob.glob("/usr/local/Cellar/imagemagick/*/lib/ImageMagick")
    im_coders_dest = os.path.join(lib_dir, "ImageMagick")
    if im_lib_coders:
        safe_copy(im_lib_coders[0], im_coders_dest)

    im_etc = glob.glob("/opt/homebrew/Cellar/imagemagick/*/etc/ImageMagick-7") + glob.glob("/usr/local/Cellar/imagemagick/*/etc/ImageMagick-7")
    im_etc_dest = os.path.join(dest_dir, "etc", "ImageMagick-7")
    if im_etc:
        etc_dir = os.path.join(dest_dir, "etc")
        os.makedirs(etc_dir, exist_ok=True)
        safe_copy(im_etc[0], im_etc_dest)

    coder_so_files = []
    if os.path.exists(im_coders_dest):
        for root, dirs, files in os.walk(im_coders_dest):
            for file in files:
                full_p = os.path.join(root, file)
                if file.endswith(".so"):
                    coder_so_files.append(full_p)
                elif file.endswith(".la"):
                    try:
                        os.chmod(full_p, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
                        with open(full_p, "r", encoding="utf-8", errors="replace") as f:
                            content = f.read()
                        content = re.sub(r"dependency_libs=\x27[^\x27]*\x27", "dependency_libs=\x27\x27", content)
                        content = re.sub(r"libdir=\x27[^\x27]*\x27", "libdir=\x27\x27", content)
                        with open(full_p, "w", encoding="utf-8") as f:
                            f.write(content)
                    except Exception:
                        pass
                elif file == "configure.xml":
                    try:
                        os.chmod(full_p, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
                        with open(full_p, "r", encoding="utf-8", errors="replace") as f:
                            content = f.read()
                        content = re.sub(r"/opt/homebrew[^\"]*", "", content)
                        content = re.sub(r"/usr/local[^\"]*", "", content)
                        with open(full_p, "w", encoding="utf-8") as f:
                            f.write(content)
                    except Exception:
                        pass

    if os.path.exists(im_etc_dest):
        for root, dirs, files in os.walk(im_etc_dest):
            for file in files:
                if file.endswith(".xml"):
                    full_p = os.path.join(root, file)
                    try:
                        os.chmod(full_p, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
                        with open(full_p, "r", encoding="utf-8", errors="replace") as f:
                            content = f.read()
                        content = re.sub(r"/opt/homebrew[^\"]*", "", content)
                        content = re.sub(r"/usr/local[^\"]*", "", content)
                        with open(full_p, "w", encoding="utf-8") as f:
                            f.write(content)
                    except Exception:
                        pass

    # 3. Transitive Dylib Discovery & Collection
    print("==> Resolving and copying transitive Mach-O dynamic libraries...")
    discovered_dylibs = {}  # real_path -> (original_ref, base_name, dest_path)

    # Discover any perl bundles / mach-o files in lib/perl5
    perl_machos = []
    perl_lib_dest = os.path.join(lib_dir, "perl5")
    if os.path.exists(perl_lib_dest):
        for root, dirs, files in os.walk(perl_lib_dest):
            for file in files:
                full_p = os.path.join(root, file)
                if is_macho(full_p):
                    perl_machos.append(full_p)

    queue = list(macho_binaries) + list(coder_so_files) + list(perl_machos)
    visited_macho = set()

    while queue:
        curr = queue.pop(0)
        if curr in visited_macho:
            continue
        visited_macho.add(curr)

        rpaths = get_rpaths(curr)
        deps = get_dependencies(curr)

        for dep in deps:
            resolved = resolve_dylib(dep, rpaths)
            if resolved and resolved not in discovered_dylibs:
                base = os.path.basename(resolved)
                dest_dylib = os.path.join(lib_dir, base)
                safe_copy(resolved, dest_dylib)
                discovered_dylibs[resolved] = (dep, base, dest_dylib)
                queue.append(dest_dylib)

    print(f"==> Copied {len(discovered_dylibs)} shared dynamic libraries to {lib_dir}")

    # 4. Mach-O Path Rewriting (install_name_tool)
    print("==> Rewriting library load paths to relative @loader_path...")

    def find_matching_dylib(dep_str: str, caller_rpaths: list[str]) -> tuple[str, str] | None:
        # Returns (base_name, dest_dylib_path)
        resolved = resolve_dylib(dep_str, caller_rpaths)
        if not resolved and os.path.exists(dep_str):
            resolved = os.path.realpath(dep_str)
        if resolved and resolved in discovered_dylibs:
            return discovered_dylibs[resolved][1], discovered_dylibs[resolved][2]

        dep_base = os.path.basename(dep_str)
        for real_path, (orig_ref, base, dest_p) in discovered_dylibs.items():
            if dep_base == base or dep_base == os.path.basename(orig_ref):
                return base, dest_p
            # Match prefix e.g. libwebp.7.dylib vs libwebp.7.2.0.dylib
            d_prefix = dep_base.split(".dylib")[0]
            b_prefix = base.split(".dylib")[0]
            if d_prefix.startswith(b_prefix) or b_prefix.startswith(d_prefix):
                return base, dest_p
        return None

    # Also create symlinks for unversioned / soname aliases in lib_dir
    for real_path, (orig_ref, base, dest_dylib) in list(discovered_dylibs.items()):
        names_to_link = set()
        if orig_ref.startswith("@rpath/"):
            names_to_link.add(orig_ref.replace("@rpath/", ""))
        orig_base = os.path.basename(orig_ref)
        if orig_base != base:
            names_to_link.add(orig_base)
        m = re.match(r"(lib[a-zA-Z0-9_\-]+)\.\d+.*\.dylib", base)
        if m:
            names_to_link.add(f"{m.group(1)}.dylib")
        for alias in names_to_link:
            alias_path = os.path.join(lib_dir, alias)
            if not os.path.exists(alias_path) and not os.path.islink(alias_path):
                os.symlink(base, alias_path)

    # Clean rpaths and rewrite binaries in bin/
    for b in macho_binaries:
        b_rpaths = get_rpaths(b)
        for rp in b_rpaths:
            if "/opt/homebrew" in rp or "/usr/local" in rp:
                subprocess.run(["install_name_tool", "-delete_rpath", rp, b], capture_output=True)
        subprocess.run(["install_name_tool", "-add_rpath", "@loader_path/../lib", b], capture_output=True)

        deps = get_dependencies(b)
        for dep in deps:
            match = find_matching_dylib(dep, b_rpaths)
            if match:
                base, _ = match
                subprocess.run(["install_name_tool", "-change", dep, f"@loader_path/../lib/{base}", b], capture_output=True)

    # Rewrite dylibs in lib/
    for real_path, (orig_ref, base, dest_dylib) in discovered_dylibs.items():
        subprocess.run(["install_name_tool", "-id", f"@loader_path/{base}", dest_dylib], capture_output=True)
        d_rpaths = get_rpaths(dest_dylib)
        for rp in d_rpaths:
            if "/opt/homebrew" in rp or "/usr/local" in rp:
                subprocess.run(["install_name_tool", "-delete_rpath", rp, dest_dylib], capture_output=True)
        subprocess.run(["install_name_tool", "-add_rpath", "@loader_path", dest_dylib], capture_output=True)

        deps = get_dependencies(dest_dylib)
        for dep in deps:
            match = find_matching_dylib(dep, d_rpaths)
            if match:
                other_base, _ = match
                subprocess.run(["install_name_tool", "-change", dep, f"@loader_path/{other_base}", dest_dylib], capture_output=True)

    # Rewrite coder modules in lib/ImageMagick
    for c_so in coder_so_files:
        c_rpaths = get_rpaths(c_so)
        for rp in c_rpaths:
            if "/opt/homebrew" in rp or "/usr/local" in rp:
                subprocess.run(["install_name_tool", "-delete_rpath", rp, c_so], capture_output=True)
        subprocess.run(["install_name_tool", "-add_rpath", "@loader_path/../../..", c_so], capture_output=True)

        deps = get_dependencies(c_so)
        for dep in deps:
            match = find_matching_dylib(dep, c_rpaths)
            if match:
                other_base, _ = match
                subprocess.run(["install_name_tool", "-change", dep, f"@loader_path/../../../{other_base}", c_so], capture_output=True)

    # Rewrite perl bundles in lib/perl5
    for p_macho in perl_machos:
        p_rpaths = get_rpaths(p_macho)
        for rp in p_rpaths:
            if "/opt/homebrew" in rp or "/usr/local" in rp:
                subprocess.run(["install_name_tool", "-delete_rpath", rp, p_macho], capture_output=True)
        rel_lib = os.path.relpath(lib_dir, os.path.dirname(p_macho))
        subprocess.run(["install_name_tool", "-add_rpath", f"@loader_path/{rel_lib}", p_macho], capture_output=True)

        deps = get_dependencies(p_macho)
        for dep in deps:
            match = find_matching_dylib(dep, p_rpaths)
            if match:
                other_base, _ = match
                subprocess.run(["install_name_tool", "-change", dep, f"@loader_path/{rel_lib}/{other_base}", p_macho], capture_output=True)

    # 5. Ad-Hoc Sign with Hardened Runtime
    print("==> Signing all Mach-O binaries and dylibs with hardened runtime...")
    for _, (_, _, dest_dylib) in discovered_dylibs.items():
        sign_binary(dest_dylib, entitlements_file)
    for b in macho_binaries:
        sign_binary(b, entitlements_file)
    for c_so in coder_so_files:
        sign_binary(c_so, entitlements_file)
    for p in perl_machos:
        sign_binary(p, entitlements_file)

    # 6. Verification Pass: Zero references to /opt/homebrew or /usr/local
    print("==> Verifying Mach-O isolation...")
    failed_checks = []
    for f in macho_binaries + [d[2] for d in discovered_dylibs.values()] + coder_so_files + perl_machos:
        deps = get_dependencies(f)
        for dep in deps:
            if "/opt/homebrew" in dep or "/usr/local" in dep:
                failed_checks.append((f, dep))
    if failed_checks:
        print("ERROR: Mach-O binaries retain external homebrew references:", file=sys.stderr)
        for f, dep in failed_checks:
            print(f"  {f} -> {dep}", file=sys.stderr)
        sys.exit(1)
    else:
        print("✓ All bundled Mach-O files are 100% free of external Homebrew/local paths!")

    # 7. Functional Launch Verification: Ensure every bundled engine launches under clean PATH
    print("==> Verifying bundled engine execution under clean PATH (/usr/bin:/bin)...")
    tool_spec_map = {s["name"]: s for s in TOOL_SPECS}
    for entry in manifest_entries:
        tool_id = entry["id"]
        spec = tool_spec_map.get(tool_id)
        flag = spec["version_flag"] if spec else "--version"
        exec_path = os.path.join(dest_dir, entry["entry_point"])
        env = {"PATH": "/usr/bin:/bin"}
        res = subprocess.run([exec_path, flag], capture_output=True, text=True, env=env)
        out = (res.stdout or res.stderr or "").strip()
        expected_code = 1 if tool_id == "ditto" and flag == "-h" else 0
        if res.returncode != expected_code:
            sys.exit(f"Error: Bundled engine {tool_id} failed to launch! Returncode: {res.returncode}, Output: {out}")
        first_line = out.splitlines()[0] if out else "OK"
        print(f"  ✓ {tool_id:<14} launched cleanly: {first_line[:40]}")

    # 8. Write Manifest
    manifest_entries.sort(key=lambda x: x["id"])
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest_entries, f, indent=2)
    print(f"==> Wrote manifest ({len(manifest_entries)} tools) to {manifest_path}")

    # 8. Print Size Report Table
    print("\n==================================================")
    print("           PASTA ENGINES SIZE REPORT              ")
    print("==================================================")
    print(f"{'Engine ID':<15} {'Version':<18} {'Size (KB)':<12} {'Entry Point'}")
    print("-" * 65)
    for entry in manifest_entries:
        sz_kb = entry["size"] / 1024.0
        print(f"{entry['id']:<15} {entry['version']:<18} {sz_kb:<12.1f} {entry['entry_point']}")
    print("-" * 65)

    def dir_size_mb(path):
        if not os.path.exists(path):
            return 0.0
        total = 0
        for root, dirs, files in os.walk(path):
            for file in files:
                p = os.path.join(root, file)
                if not os.path.islink(p):
                    total += os.path.getsize(p)
        return total / (1024 * 1024)

    engines_size = dir_size_mb(dest_dir)
    print(f"Total Engines Directory Size: {engines_size:.2f} MB")

    # App total if inside Pasta.app
    app_root = None
    curr = dest_dir
    while curr and curr != "/":
        if curr.endswith("Pasta.app"):
            app_root = curr
            break
        curr = os.path.dirname(curr)
    if app_root:
        app_size = dir_size_mb(app_root)
        print(f"Total Pasta.app Bundle Size:  {app_size:.2f} MB")
    print("==================================================\n")

if __name__ == "__main__":
    main()
