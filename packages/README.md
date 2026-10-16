# packages/ - Oryt self-managed update channel

This directory backs the addon's built-in updater (`resources/lib/modules/updater.py`).
The addon fetches updates over raw GitHub URLs from the `packages/` directory of the
configured repo's `main` branch, so this layout must be preserved when publishing.

## Layout

- `plugin.video.oryttv-<version>.zip` - release zips. Each zip contains the
  `plugin.video.oryttv/` folder at its root.
- `oryt_version` - plain text, bare version string of the latest release, no
  trailing newline (e.g. `1.0.0`).
- `oryt_changes` - Kodi BBCode changelog of the LATEST release only (the top entry
  of the addon's `resources/text/changelog.txt`), CRLF line endings, no trailing
  newline. Format:
  ```
  [COLOR dodgerblue][B]Version 1.0.0 (2026-07-28)[/B][/COLOR]
  - Oryt 1.0.0 release.
  ```

## How the addon uses it

- Update check: `https://github.com/<user>/<repo>/raw/main/packages/oryt_version`
- Changelog view: same base URL + `oryt_changes`
- Zip download: same base URL + `plugin.video.oryttv-<version>.zip`
- Rollback listing: `https://api.github.com/repos/<user>/<repo>/contents/packages`

`<user>/<repo>` come from the build-time constants `ORYT_UPDATE_USER` /
`ORYT_UPDATE_REPO` stamped into `updater.py` by `tools/build_zip.ps1`. When the
constants are placeholders and no custom settings are configured, the updater
no-ops silently (no network calls, no dialogs).

## Building a release

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_zip.ps1 `
    -Version 1.0.1 -GitHubUser <user> -GitHubRepo <repo>
```

Then commit and push `packages/` (see the script's printed git next steps).
The legacy `fen_light_*` / `fen_version` manifests and `plugin.video.fen*`
zips below are kept for reference only and are not used by Oryt.
