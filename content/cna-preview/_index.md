+++
title = "Sophgone SG-1"

# This page was the pre-disclosure preview handed to the CNA while the 14-day
# window ran. The write-up now lives at the site root, so anything already
# holding this URL -- the CVE request, mail threads, the vendor's own notes --
# lands on the real page instead of a 404.
redirect_to = "/"
+++
<<<<<<< HEAD
=======

## One file. Two architectures. Zero secure boot.

One **polyglot** `fip.bin` pwns *both* cores of the SG2000 at once.
The same file hijacks the aarch64 **A53** and the RISC-V **C906** mask
ROMs, then chainloads NixOS on whichever core the GPIO strap selects.

Both cores load one shared oversized BL2 whose first instruction is a dual-ISA trampoline:
the same bytes decode to a valid branch on aarch64 and on RISC-V with different
displacements. From there, each core relocates a small stub, reopens the SD card
through the ROM's own FatFs, loads a second image, and launches it, all before any
secure-boot verification runs.

Since this is a mask ROM vulnerability, there is no patch possible for these chips,
and they are broken until Sophgo ships a new silicon revision.

## Demo

<div id="arm-demo" class="demo" style="float: left"></div>
<div id="riscv-demo" class="demo" style="float: right"></div>

## The flaw

The mask ROM copies the FIP's `BL2` image using an attacker-controlled, unbounded
`BL2_IMG_SIZE` field **before** it decrypts or verifies BL2. This BL2 image ends
up overlapping with the mask ROM's stack prior to secure boot verification.
Drop the exploit fip.bin on the SD card and it will boot every time.

The size field lives in the FIP's `param1` header, which is protected only by a
CRC-16 checksum rather than a signature.

It defeats every secure-boot level the part supports:

- **SCS = 00.** Secure boot off.
- **SCS = 01.** RSA-2048 signature enforced. `VRK4.VBK.VCC.PE.BS.J.PWNED`. The
  key chain verifies, then control is taken before the BL2 signature is checked.
- **SCS = 02.** RSA plus AES image encryption enforced.
  `VRK4.VBK.DK4.VCC.PE.BS.J.PWNED`. The ROM even unwraps the image-encryption key
  first, then hands control to our plaintext bytes. Very nice of it!

No fuse setting changes where BL2 is loaded.

## Mask ROM RE

We dumped the 96 KiB mask ROM from inside BL2, the only context that can read it,
and reversed the FIP loader's verify sequence on both cores. They are identical:
`VRK, VBK, DK, VCC, VCP, load BL2, BL2 cksum, DB2, VB2`. The overrun happens at
*load BL2*, several steps before `DB2` (decrypt) and `VB2` (verify).

## How we found it

We found it after building a **polyglot FIP** for the
[Nix Badge](https://nix.vegas/blog/2026/badge)'s multi-architecture build.
We wanted one image both cores would accept, which meant working out how the SG2000's
FIP format actually works instead of how the documentation says it does.

## Timeline

- **2026-09.** Flaw discovered during Nix badge v2 bring-up. Full exploit
  developed and confirmed against SCS = 00, 01, and 02 on real silicon.
- **Coordinated disclosure in progress.** Vendor contact and CVE assignment are
  pending; the timeline here will expand as things advance.

## Security advisory

- **Affected.** Sophgo SG2000 / SG200x and CV180x / CV181x family mask ROMs
  (Milk-V Duo S and relatives).
- **Impact.** Full pre-verification code execution at the highest privilege of
  each core (EL3 Secure World on the A53, M-mode on the C906), defeating signed and
  signed+encrypted secure boot. Local attacker with control of the boot
  media.
- **Mitigation.** None in the ROM. Don't let anyone overwrite /boot/fip.bin.

## Notes

eMMC, SPINAND, and other boot modes are equally affected but will require a different
stack map in order to work since the affected function is at a different stack depth.
This demo was made for an SD card (hence the SD/... in the mask ROM boot line).

## Downloads

TBD

*Chevron seven, locked.*
>>>>>>> 5b7ea09 (Update things a bit)
