# Pasta Filesystem & Output Reservation Notes

*Documented for Phase R0 (macOS 27 APFS & POSIX Semantics).*

## 1. Atomic Output Reservation Architecture

Pasta adheres strictly to the **"Never Overwrite"** principle. Previously, `OutputPlanner.planOutput` checked `FileManager.fileExists` and returned a path string. Under concurrent execution (e.g. `BatchJobQueue`, concurrent CLI invocations, or rapid wheel drops), multiple jobs planned the exact same target path (e.g. `photo.jpg`) before either completed, leading to silent overwrite and lost user output.

### Atomic Claim Primitive
- **Files**: `open(path, O_CREAT | O_EXCL | O_WRONLY, 0o600)`.
  The operating system kernel guarantees mutual exclusion. Exactly one process succeeds in creating the placeholder; all others fail with `EEXIST` and immediately retry with an incremented numbered suffix (`photo 1.jpg`, `photo 2.jpg`, etc.).
- **Directories**: `mkdir(path, 0o700)`.
  Atomic directory creation. On `EEXIST`, retries with the next suffix (`photo extracted 1`, `photo extracted 2`).
- **In-Process Locking**: `OutputPlanner.activeReservedPaths` protected by `NSLock` guards against in-process race conditions.
- **Input Immutability**: The input path itself is never reserved (`candidatePath != inputStandardized`).

### Publication & Replacement Semantics (`rename(2)`)
- On macOS 27 (APFS), `rename(src, dst)` replaces the placeholder atomically with the validated conversion output in a single filesystem transaction.
- When `dst` is an empty directory created via `mkdir`, `rename(src, dst)` replaces the empty directory placeholder with the source directory atomically.
- **Cross-Volume / External Drives**: If source and destination reside on distinct volumes, `rename(2)` returns `EXDEV`. `OutputReservation.publish` catches `EXDEV`, copies the temp output to a hidden staging path `.pasta_stage_<UUID>` within the target destination directory on the destination volume, and performs the atomic `rename` on the same filesystem.

### Release & Safe Cleanup Rules
- On success: `reservation.publish(from:)` replaces the placeholder with the real output and unregisters the reservation.
- On failure, cancellation, or exception: `reservation.cleanup()` runs via `defer`.
  To ensure Pasta never deletes pre-existing user files, it queries `stat(url.path)` and only unlinks if:
  1. `st_dev == reservation.deviceId` (same filesystem device)
  2. `st_ino == reservation.inode` (same exact inode created during reservation)
  3. `st_size == 0` for files (or directory is empty).

### Crash Edge-Case Limitation
If a process is abruptly terminated (`SIGKILL` or system power failure), a 0-byte placeholder file may remain on disk. Pasta intentionally **does not auto-delete user-visible files** to prevent any risk of data loss. Instead, `pasta doctor` reports stale zero-byte placeholders older than 1 hour.
