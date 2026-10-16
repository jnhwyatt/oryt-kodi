# Oryt

Movies and TV in Kodi. Install, open, press play. No accounts, no setup.

Oryt is a personal fork of **Fen Light+ v2.4.0** (by Tikipeter / thejason40) with
scrapers (CocoScrapers, GPLv3) bundled inside and everything pre-configured.

## Install (any device)

1. Install **Kodi 21** (Omega) on your device (kodi.tv, or the Downloader app on Fire Stick).
2. Download the latest `plugin.video.oryttv-X.Y.Z.zip` from this repo's `packages/` folder
   (on Fire Stick: open the zip's URL in the **Downloader** app; otherwise copy it to the device).
3. In Kodi: **Settings → Add-ons → Install from zip file** → pick the zip.
4. Open **Oryt** from the Add-ons section. That's it.

- **Fire Stick**: same steps. Navigate with the remote; press Play on a title and it plays.
- **iPad**: Kodi itself must be sideloaded first (AltStore/Sideloadly). After that, same steps.
- Updates arrive by themselves once installed - no reinstalling, ever.

## For the developer (repo owner)

Everything dev-side lives in the parent workspace:

- `scripts/sync-addon.ps1` - mirror addon source into the portable dev Kodi (`kodi-dev/`).
- `scripts/dev-kodi.ps1` - launch the portable dev Kodi.
- `tools/build_zip.ps1` - cut a release zip + update the `packages/` manifests.
- `secrets/oryt_account.json` (gitignored) - the pre-authorized Real-Debrid account
  that gets baked into release zips.
- **MAINTENANCE.md** - the full playbook: releases, account rotation, scraper sync,
  upstream sync, breakage triage.

Credits: Tikipeter (Fen Light), thejason40 (Fen Light+), minicoz (mirror), CocoJoe (CocoScrapers).
Private, closed-beta software. Do not redistribute.
