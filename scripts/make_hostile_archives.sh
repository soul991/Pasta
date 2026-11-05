#!/usr/bin/env bash
# scripts/make_hostile_archives.sh
# Generates hostile archive test fixtures dynamically at test time.
# NEVER commit binary bombs or exploit payloads to git.

set -euo pipefail

TARGET_DIR="${1:-/tmp/pasta_hostile_fixtures_$$}"
mkdir -p "$TARGET_DIR"

python3 - <<EOF
import os
import sys
import zipfile
import tarfile
import gzip

target_dir = "$TARGET_DIR"

# 1. Relative path escape: ../escape.txt
with zipfile.ZipFile(os.path.join(target_dir, "slip_rel.zip"), "w") as zf:
    zf.writestr("../escape.txt", "HOSTILE_RELATIVE_ZIP_DATA\n")

with tarfile.open(os.path.join(target_dir, "slip_rel.tar"), "w") as tf:
    ti = tarfile.TarInfo("../escape.txt")
    ti.size = 26
    tf.addfile(ti, fileobj=__import__("io").BytesIO(b"HOSTILE_RELATIVE_TAR_DATA\n"))

# 2. Absolute path escape: /tmp/pasta_abs_escape.txt
with tarfile.open(os.path.join(target_dir, "slip_abs.tar"), "w") as tf:
    ti = tarfile.TarInfo("/tmp/pasta_abs_escape.txt")
    ti.size = 26
    tf.addfile(ti, fileobj=__import__("io").BytesIO(b"HOSTILE_ABSOLUTE_TAR_DATA\n"))

# 3. Symlink pointing outside: link -> /tmp
with tarfile.open(os.path.join(target_dir, "symlink_outside.tar"), "w") as tf:
    ti = tarfile.TarInfo("symlink_to_tmp")
    ti.type = tarfile.SYMTYPE
    ti.linkname = "/tmp"
    tf.addfile(ti)

# 4. Symlink pointing to /etc/passwd
with tarfile.open(os.path.join(target_dir, "symlink_passwd.tar"), "w") as tf:
    ti = tarfile.TarInfo("passwd_link")
    ti.type = tarfile.SYMTYPE
    ti.linkname = "/etc/passwd"
    tf.addfile(ti)

# 5. Entry through symlink hopping outside (escaped_dir -> /tmp, and entry escaped_dir/payload.txt)
with tarfile.open(os.path.join(target_dir, "symlink_hop.tar"), "w") as tf:
    ti1 = tarfile.TarInfo("escaped_dir")
    ti1.type = tarfile.SYMTYPE
    ti1.linkname = "/tmp"
    tf.addfile(ti1)
    ti2 = tarfile.TarInfo("escaped_dir/hop_escape.txt")
    ti2.size = 19
    tf.addfile(ti2, fileobj=__import__("io").BytesIO(b"HOSTILE_HOPPED_DATA\n"))

# 6. Hard link pointing to an external file
with tarfile.open(os.path.join(target_dir, "hardlink_outside.tar"), "w") as tf:
    ti = tarfile.TarInfo("hardlink_to_etc")
    ti.type = tarfile.LNKTYPE
    ti.linkname = "/etc/hosts"
    tf.addfile(ti)

# 7. Duplicate names in the same archive
with zipfile.ZipFile(os.path.join(target_dir, "duplicate_names.zip"), "w") as zf:
    zf.writestr("duplicate.txt", "FIRST_VERSION\n")
    zf.writestr("duplicate.txt", "SECOND_VERSION_OVERWRITE\n")

# 8. Case collision (A.txt vs a.txt)
with zipfile.ZipFile(os.path.join(target_dir, "case_collision.zip"), "w") as zf:
    zf.writestr("A.txt", "UPPERCASE_DATA\n")
    zf.writestr("a.txt", "LOWERCASE_DATA\n")

# 9. Unicode normalization duplicates (NFC vs NFD for 'café.txt')
# NFC: 'e' with acute as single codepoint \u00e9
# NFD: 'e' (\u0065) + combining acute (\u0301)
nfc_name = "caf\u00e9.txt"
nfd_name = "cafe\u0301.txt"
with zipfile.ZipFile(os.path.join(target_dir, "unicode_normalization.zip"), "w") as zf:
    zf.writestr(nfc_name, "NFC_CONTENT\n")
    zf.writestr(nfd_name, "NFD_CONTENT\n")

# 10. Deep nesting (100 levels)
nested_path = "/".join(["dir_{:03d}".format(i) for i in range(100)]) + "/nested_file.txt"
with tarfile.open(os.path.join(target_dir, "deep_nesting.tar"), "w") as tf:
    ti = tarfile.TarInfo(nested_path)
    ti.size = 12
    tf.addfile(ti, fileobj=__import__("io").BytesIO(b"DEEP_CONTENT\n"))

# 11. Very long entry name (> 255 characters component)
long_name = "a" * 300 + ".txt"
with tarfile.open(os.path.join(target_dir, "very_long_names.tar"), "w") as tf:
    ti = tarfile.TarInfo(long_name)
    ti.size = 12
    tf.addfile(ti, fileobj=__import__("io").BytesIO(b"LONG_CONTENT\n"))

# 12. Many tiny entries (1,000 files)
with zipfile.ZipFile(os.path.join(target_dir, "many_files.zip"), "w") as zf:
    for i in range(1000):
        zf.writestr("tiny_{:04d}.txt".format(i), "X")

# 13. Small gzip expansion bomb (10MB of zeroes compresses to ~10KB)
bomb_tar_path = os.path.join(target_dir, "expansion_bomb.tar")
with tarfile.open(bomb_tar_path, "w") as tf:
    ti = tarfile.TarInfo("zero_bomb.bin")
    ti.size = 10 * 1024 * 1024 # 10 MB uncompressed
    # Sparse / zero stream
    class ZeroStream:
        def __init__(self, size):
            self.remaining = size
        def read(self, n):
            chunk = min(n, self.remaining)
            self.remaining -= chunk
            return b"\x00" * chunk
    tf.addfile(ti, fileobj=ZeroStream(ti.size))

bomb_gz_path = os.path.join(target_dir, "expansion_bomb.tar.gz")
with open(bomb_tar_path, "rb") as f_in, gzip.open(bomb_gz_path, "wb", compresslevel=9) as f_out:
    import shutil
    shutil.copyfileobj(f_in, f_out)
try:
    os.remove(bomb_tar_path)
except OSError:
    pass

# 14. Setuid and setgid bits in tar archive
with tarfile.open(os.path.join(target_dir, "setuid_setgid.tar"), "w") as tf:
    ti1 = tarfile.TarInfo("setuid_executable")
    ti1.mode = 0o4755 # setuid
    ti1.size = 13
    tf.addfile(ti1, fileobj=__import__("io").BytesIO(b"SETUID_BINARY\n"))
    
    ti2 = tarfile.TarInfo("setgid_executable")
    ti2.mode = 0o2755 # setgid
    ti2.size = 13
    tf.addfile(ti2, fileobj=__import__("io").BytesIO(b"SETGID_BINARY\n"))

# 15. Benign multi-level archive (guard against false positives)
with zipfile.ZipFile(os.path.join(target_dir, "benign_valid.zip"), "w") as zf:
    zf.writestr("README.md", "# Valid Archive\nThis is safe.\n")
    zf.writestr("docs/guide.txt", "User guide content.\n")
    zf.writestr("docs/sub/detail.txt", "Deep details.\n")
    zf.writestr("images/photo.png", "PNG_DUMMY_DATA\n")

print("Created 15 hostile and benign test archives in " + target_dir)
EOF

echo "$TARGET_DIR"
