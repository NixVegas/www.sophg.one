+++
title = "Sophgone SG-1"
template = "sophgone.html"
+++

## One file. Two architectures. Zero secure boot.

A single strap-selectable **polyglot** `fip.bin` pwns *both* cores of the SG2000
at once. The same file hijacks the aarch64 **A53** and the RISC-V **C906** mask
ROMs, then chainloads NixOS on whichever core the GPIO strap selects. One image,
no per-core reflash, and it walks straight through every level of secure boot the
silicon offers.

## Demo

<div id="arm-demo"></div>
<div id="riscv-demo"></div>

## The flaw

The mask ROM copies the FIP's `BL2` image using an attacker-controlled, unbounded
`BL2_IMG_SIZE` field **before** it decrypts or verifies BL2. That is a
load-before-verify bug: the oversized copy overruns the ROM's own stack and lands
attacker bytes on the return chain, so control is hijacked inside `load_image`,
upstream of the AES engine and the RSA signature check.

The size field lives in the FIP's `param1` header, which is protected only by a
CRC-16 checksum. Nothing signs the value the ROM trusts to size that copy, so
nothing downstream ever gets a say.

It defeats every secure-boot level the part supports:

- **SCS = 00.** Secure boot off. A genuinely unsigned image is rejected by the
  enforcing configs, yet the graft still boots.
- **SCS = 01.** RSA-2048 signature enforced. `VRK4.VBK.VCC.PE.BS.J.PWNED`. The
  key chain verifies, then control is taken before the BL2 signature is checked.
- **SCS = 02.** RSA plus AES image encryption enforced.
  `VRK4.VBK.DK4.VCC.PE.BS.J.PWNED`. The ROM even unwraps the image-encryption key
  first, then hands control to our plaintext bytes.

Because the copy is upstream of both the AES engine and the signature check,
**it is not fixable in the ROM.** No fuse setting changes it.

## Mask ROM RE

We dumped the 96 KiB mask ROM from inside BL2, the only context that can read it,
and reversed the FIP loader's verify sequence on both cores. They are identical:
`VRK, VBK, DK, VCC, VCP, load BL2, BL2 cksum, DB2, VB2`. The overrun happens at
*load BL2*, several steps before `DB2` (decrypt) and `VB2` (verify). Everything
after the copy is dead code as far as the attacker is concerned.

## The chainloader

The weaponized payload is a **chainloader**. Both cores load one shared oversized
BL2 whose first words are a dual-ISA trampoline: the same bytes decode to a valid
branch on aarch64 and on RISC-V. From there each core relocates a tiny per-ISA
stub, reopens the SD card through the ROM's own FatFs, loads a second image, and
launches it, all before any secure-boot verification runs.

The result is one `fip.bin` that boots a full NixOS on either the A53 or the
C906, selected only by the boot strap, with secure boot fully enabled and fully
bypassed.

## How we found it

We were not looking for it. We found it after building a **polyglot FIP** for the
badge's multi-architecture build: we wanted one image both cores would accept,
which meant working out how the SG2000's FIP format actually works instead of how
the documentation says it does. We wanted to know how the FIP really worked. We
definitely found out.

## Timeline

- **2026-09.** Flaw discovered during Nix badge v2 bring-up. Full exploit
  developed and confirmed against SCS = 00, 01, and 02 on real silicon.
- **Coordinated disclosure in progress.** Vendor contact and CVE assignment are
  pending; the timeline here will expand as things advance.

## Security advisory

- **Affected.** Sophgo SG2000 / SG200x and CV180x / CV181x family mask ROMs
  (Milk-V Duo S and relatives).
- **Impact.** Full pre-verification code execution at the highest privilege of
  each core (EL3 on the A53, M-mode on the C906), defeating signed and
  signed-plus-encrypted secure boot. Local attacker with control of the boot
  media.
- **Mitigation.** None in the ROM. Downstream measures (physically restricting
  boot media, chip-level attestation of later stages) are the only levers.

## Downloads

Proof-of-concept artifacts, the reproduction harness, and the full technical
write-up are forthcoming. Check back, or watch this space.

*Chevron seven, locked.*
