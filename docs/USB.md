# USB Operations and Safety

USB Operations can inspect removable storage, write an ISO, remove storage
signatures, or overwrite every addressable byte with zeroes. Use disposable
media for testing and independently verify every selected device.

## Shared target safety gate

Before mutation, CYBEROPS:

- Detects whole removable or USB-connected disks.
- Records path, type, transport, removable flag, byte size, model, serial, and WWN.
- Excludes disks backing `/`, `/boot`, or `/boot/efi`, including mapped parents.
- Displays the selected disk and requires destructive confirmation.
- Revalidates identity after confirmation and immediately before mutation.
- Unmounts whole-disk and child-partition filesystems.
- Refuses to continue while any target filesystem remains mounted.

## Bootable ISO creation

The ISO prompt supports Tab completion, quoted paths, spaces, and `~`. CYBEROPS
validates the file type and can compare an optional SHA-256 value before device
selection. The final write uses:

```bash
sudo dd if="image.iso" of="/dev/sdX" bs=4M status=progress conv=fsync
sync
```

An interrupted or failed write may leave incomplete boot media. Rewrite and
verify the device before use.

## Quick Reset

Quick Reset removes recognized filesystem, RAID, and partition-table signatures
from child partitions before removing the disk signature:

```bash
sudo wipefs --all -- /dev/sdX1 /dev/sdX
```

It normally completes in seconds and is useful before repartitioning.

> **Quick Reset is not a data wipe.** File contents are not overwritten and may
> remain recoverable.

## Full zero-fill

Full zero-fill overwrites the selected disk's exact byte capacity:

```bash
sudo dd if=/dev/zero of=/dev/sdX bs=16M count=<device-bytes>B status=progress conv=fsync
```

When byte-suffixed counts are unavailable, CYBEROPS uses the supported
`iflag=count_bytes` form. Exact capacity prevents a normal end-of-device result
from being misreported as `No space left on device`.

Zero-filling flash storage is not a guaranteed secure erase. Wear leveling and
remapped cells may retain data outside normal block addressing. The operation
also takes approximately device capacity divided by sustained write speed.

## Preview mode

Use `DRY_RUN=1 cyberops` to inspect ISO-write, unmount, Quick Reset, zero-fill,
and sync commands without changing the selected device.
