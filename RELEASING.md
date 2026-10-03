# Release Process

Two platforms ship from one repository under a single tag. Each release carries both
builds; the OS is named in the filename.

## Versioning

Use `vX.Y.Z`. Historical tags are inconsistent (`1.3`, `v1.5`) and are left alone so old
download links keep working — every new tag uses the `v` prefix.

```
v1.6.0
├── DM_Helper-1.6.0-macos.zip           signed + notarized .app
├── DM_Helper-1.6.0-macos.zip.sha256
├── DM_Helper-1.6.0-windows-x64.zip     self-contained exe
└── DM_Helper-1.6.0-windows-x64.zip.sha256
```

## Before tagging

**macOS** — build on a Mac holding the signing identity:

```bash
xcodebuild -project "D3 Skill Assistant.xcodeproj" -target d3key \
  -configuration Release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build

APP=$(find ~/Library/Developer/Xcode/DerivedData -name DM_Helper.app -type d | head -1)
ditto -c -k --keepParent "$APP" DM_Helper-$(git describe --tags | cut -d- -f2)-macos.zip
xcrun notarytool submit DM_Helper-*-macos.zip --keychain-profile "..." --wait
xcrun stapler staple "$APP"
```

**Windows** — the spike must pass first. See [win/README.md](win/README.md).

```bash
cd win
dotnet publish src/DM_Helper.Spike -c Release -r win-x64 --self-contained false
# Run DM_Helper_Spike.exe from an elevated prompt. Every line must read [ OK ].
```

The spike exists because the failure mode is silent: if `SendInput` is blocked, the app
runs fine and the macro simply never fires. A green build proves nothing about this.

## Publishing

1. Tag and push:

   ```bash
   git tag v1.6.0 && git push origin v1.6.0
   ```

2. Publish a draft release on GitHub with the release notes.

3. Publishing the release fires `.github/workflows/release.yml`, which builds the Windows
   exe, asserts `requireAdministrator` and `PerMonitorV2` are present in the binary, zips
   it with a SHA-256 file, and attaches both to the release.

4. Upload the signed macOS zip manually — the CI runner has no signing identity, so that
   job only prints a note.

## CI

`ci.yml` runs on every push to master:

| Job | Runs on | Does |
|---|---|---|
| `tests` | Linux, Windows, macOS | 158 core tests |
| `build-windows` | Windows | Publishes the app, verifies the manifest, uploads artifacts |
| `build-macos` | macOS | Compiles the Objective-C target (unsigned) |

The core tests run on all three operating systems on purpose. `DM_Helper.Core` targets
`net8.0` rather than `net8.0-windows` specifically so the domain logic and the Win32 interop
marshalling can be tested anywhere; running the matrix keeps that property honest.

## Renaming the repository

The repo is still named `mac-diablo-helper`, which no longer describes its contents.
Run `.github/workflows/rename-repo.yml` with the confirmation input to rename it to
`diablo-helper` and rewrite the links in the READMEs. GitHub keeps a redirect from the old
path, so existing clone URLs and download links continue to resolve.

## Note on binaries

Release artifacts are attached to GitHub Releases and are never committed. The 2.9MB
`dm_helper-1.5.zip` that used to sit in the repository root was removed from tracking; the
64MB Windows executable would have made every clone slower for no benefit.
