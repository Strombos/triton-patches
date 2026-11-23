# Triton security patches

Signed security patches for Triton. Triton reads this folder at

    https://raw.githubusercontent.com/Strombos/triton-patches/main/

and you can change that in Settings > Security > Updates (an https folder, or a folder on disk for offline machines).

## What is here

- `feed.properties` + `feed.properties.sig`: the signed list of patches on offer. Its sequence number only goes up; Triton refuses an older list than one it has already seen.
- `<id>.tpatch` + `<id>.tpatch.sig`: one patch each. A patch is a set of replacement classes for a range of Triton builds.

## Why it is safe to be public

Nothing here is trusted because of where it is hosted. Each Triton build carries the public keys it accepts, and checks the Ed25519 signature on the list and on every patch when installing it and again on every start. A patch that keeps Triton from finishing starting twice is set aside automatically.

The private signing keys are never stored in this repository.

## Full builds

- `release.properties` + `release.properties.sig`: the signed notice of the newest full build: its release id (`p155-b6`), download link, size and SHA-256. Signed with the same keys, in a context of its own, so it can never pass for a feed or a patch.

Triton's updater (Settings > System > Triton Update) reads the notice, downloads the jar from the link, refuses it unless the size and SHA-256 match, and installs it on restart. The previous jar is kept as `triton.jar.previous`; a new build that fails to finish starting twice is replaced by it automatically.

To announce a build, upload the jar first (`triton-release\upload-release.ps1`), then:

    .\publish-release.ps1 -Release p155-b6 -Key E:\triton-patch-primary.key -Summary "One line for the update page."

## Releasing a patch

    .\release-patch.ps1 -Manifest path\to\patch.properties -Key E:\triton-patch-primary.key

See the header of `release-patch.ps1` for the details.
