# Triton security patches

Signed security patches for Triton. Triton reads this folder at

    https://raw.githubusercontent.com/ZeroC0deT1me/triton-patches/main/

and you can change that in Settings > Security > Updates (an https folder, or a folder on disk for offline machines).

## What is here

- `feed.properties` + `feed.properties.sig`: the signed list of patches on offer. Its sequence number only goes up; Triton refuses an older list than one it has already seen.
- `<id>.tpatch` + `<id>.tpatch.sig`: one patch each. A patch is a set of replacement classes for a range of Triton builds.

## Why it is safe to be public

Nothing here is trusted because of where it is hosted. Each Triton build carries the public keys it accepts, and checks the Ed25519 signature on the list and on every patch when installing it and again on every start. A patch that keeps Triton from finishing starting twice is set aside automatically.

The private signing keys are never stored in this repository.

## Releasing a patch

    .\release-patch.ps1 -Manifest path\to\patch.properties -Key E:\triton-patch-primary.key

See the header of `release-patch.ps1` for the details.
