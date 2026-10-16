# Oryt — Maintenance Playbook

Owner-facing. Everything needed to keep Oryt alive without any upstream dev.

---

## 1. Layout

- `plugin.video.oryttv/` — the addon source (edit this).
- `packages/` — release channel: `plugin.video.oryttv-<ver>.zip` + `oryt_version` (bare version
  string, no newline) + `oryt_changes` (Kodi BBCode, CRLF, top changelog entry only).
  The addon's built-in updater reads these from `raw/main/packages/` on the configured GitHub repo.
- `tools/build_zip.ps1` — release builder. `tools/gen_artwork.py` — icon/fanart generator.
- Workspace root (outside this repo): `scripts/sync-addon.ps1`, `scripts/dev-kodi.ps1`,
  `kodi-dev/` (portable Kodi 21), `secrets/oryt_account.json` (gitignored).

Old `packages/plugin.video.fen*` zips + `fen_light_*` manifests are upstream leftovers;
the updater only matches `plugin.video.oryttv-*` and `oryt_version`, so they are inert.
`Makefile` and `index.html` at repo root are upstream packaging/GitHub-Pages leftovers — unused.
`packages/index.html` IS used: it lists the `plugin.video.oryttv` zips for the
GitHub-Pages / Kodi File Manager install path — add a link line for every release.

## 2. Dev loop

```powershell
# edit files under plugin.video.oryttv/, then:
powershell -File scripts/sync-addon.ps1     # mirror source into dev Kodi
powershell -File scripts/dev-kodi.ps1       # launch dev Kodi
# fresh-profile test (simulates a new install):
#   delete kodi-dev\Kodi\portable_data\userdata\addon_data\plugin.video.oryttv
# log: kodi-dev\Kodi\portable_data\kodi.log
```

Syntax check without Kodi: `cd plugin.video.oryttv; python -m compileall -q resources/lib`
(then delete any `__pycache__` folders).

## 3. Release

```powershell
powershell -File kodi-addon/tools/build_zip.ps1 -Version 1.0.1 -GitHubUser jnhwyatt -GitHubRepo oryt-kodi
# then commit + push packages/ to the repo's main branch
```

Release repo: `github.com/jnhwyatt/oryt-kodi` (public). `packages/index.html` there is
served via GitHub Pages (`https://jnhwyatt.github.io/oryt-kodi/packages/`) as the
Kodi File Manager install source.

- The script stamps `ORYT_UPDATE_USER`/`ORYT_UPDATE_REPO` into the zip's `updater.py`,
  bumps `addon.xml`, prepends the changelog entry, bundles `secrets/oryt_account.json`
  into `resources/data/` (WARNs if missing), writes `oryt_version`/`oryt_changes`.
- Installed addons self-update on next Kodi start (Settings → Oryt → General has update
  action/delay). Rollback: addon → Tools → Changelog & Log Utils → previous versions.
- Token rotation = same thing: refresh `secrets/oryt_account.json`, bump version, build, push.
- Until a repo is stamped, the updater no-ops by design (see `updater.py:get_repo_details`).

## 4. Real-Debrid account (the baked-in one)

- **Harvest**: authorize RD once in dev Kodi (Oryt → Tools → Settings → Accounts →
  Real Debrid → Authorize, enter code at real-debrid.com/device), then run
  `python scripts/harvest_account.py` — it reads the four values from the dev Kodi's
  settings.db and writes `secrets\oryt_account.json`.
- **First run behavior**: `modules/oryt_seed.py` seeds empty settings from
  `resources/data/oryt_account.json` and sets `rd.enabled=true`. Never overwrites.
- **Kill switch**: real-debrid.com → account → revoke the device/app. All installs die.
  Rotate: re-authorize in dev Kodi, harvest, bump version, release.
- The zip contains your RD refresh token. Anyone with the zip has your RD account.
  Hand it only to your tester. RD terms are personal-use; multi-IP abuse can suspend you.

## 5. Torbox swap (if RD suspends you)

1. Get Torbox, authorize it once in dev Kodi (Settings → Accounts → TorBox).
2. Harvest `tb.token` (+ `tb.enabled`) from settings.db into `secrets/oryt_account.json`.
3. Extend `seed_keys` in `modules/oryt_seed.py` with the tb keys (and set `tb.enabled`).
4. Optionally flip default priorities in `caches/settings_cache.py`.
5. Bump version, release. No other code changes — the fork supports Torbox natively.

## 6. Scraper updates (most common fix)

Vendored module: **CocoScrapers 1.0.39** (GPLv3) at `resources/lib/cocoscrapers/`
(+ `resources/lib/pyparsing.py`, `resources/lib/coco_service.py`).
Upstream zips: `github.com/not-coco-joe/repository.cocoscrapers` → `zips/script.module.cocoscrapers/`.

Update procedure:
1. Download the new zip, extract `lib/cocoscrapers` (+ `lib/pyparsing.py`, `lib/service.py`).
2. Replace `resources/lib/cocoscrapers/` (keep `resources/lib/cocoscrapers/resources/settings.xml`
   from the new version too).
3. **Re-apply the Oryt patches** to `cocoscrapers/modules/control.py`:
   - `addonObject = addon('plugin.video.oryttv')`  (was script.module.cocoscrapers)
   - `SETTINGS_PATH = .../resources/lib/cocoscrapers/resources/settings.xml`
   - `dataPath = <addon profile>/cocoscrapers`
   - `settingsFile = <addon profile>/settings.xml`  (deliberately the addon's main profile file)
   - `refresh_debugReversed`: the RunPlugin call is replaced with `pass`
   - `isVersionUpdate`: `addon_folder = dataPath`; `curVersion = addonInfo('version')`
   - `clean_settings`: `addon_id = 'plugin.video.oryttv'`; `active_settings_xml = SETTINGS_PATH`
4. Re-apply to `coco_service.py` (their `lib/service.py` renamed):
   - `CheckSettingsFile`: uses `control.settingsFile`; after `setSetting('module.provider', ...)`
     add `control.setProviderDefaults()`
   - remove the bottom `main()` auto-call (our `service.py` threads it via `coco_scrapers_service`).
5. Compile-check, dev-Kodi test (scrape a title), bump version, release.

If a single provider breaks, you can also patch just that one file in
`resources/lib/cocoscrapers/sources_cocoscrapers/torrents/<provider>.py`.

## 7. Upstream Fen Light+ sync

- `git remote add upstream https://github.com/thejason40/FenLightPlus.git` (if not present),
  `git fetch upstream`, cherry-pick from `upstream/main` (path is `plugin.video.fenlight/`
  there vs `plugin.video.oryttv/` here — use `git cherry-pick -X subtree=plugin.video.oryttv`
  or apply by hand).
- Expect conflicts in: `windows/`, `modules/sources.py`, `apis/`, anything we patched
  (see section 6 + `modules/settings.py external_scraper_info`, `caches/settings_cache.py`
  defaults, `indexers/dialogs.py external_scraper_choice`, `modules/kodi_utils.py
  external_scraper_settings`, `modules/updater.py`, `service.py`, `apis/trakt_api.py`).
- Internal identifiers intentionally kept as `fenlight.*` to keep merges small. Keep it that way.

## 8. API keys

- **Trakt**: Settings → Accounts → Trakt → "Custom Client ID/Secret Key"
  (`trakt.client_id` / `trakt.client_secret`; blank = built-in default).
- **TMDb**: existing fork setting under Accounts.
- **RD alt API base**: existing fork setting (ISP blocks).

## 9. Breakage triage

- Log: dev Kodi `kodi-dev\Kodi\portable_data\kodi.log`; on-device via Kodi's log viewer.
  Oryt lines are tagged `###Oryt###`, scrapers `[ script.module.cocoscrapers ]`.
- No sources at all → RD token dead (revoked/expired refresh): rotate (section 4).
- Few/no torrents → provider broke: section 6.
- Addon won't start → Python traceback in log: fix, compile-check, release.
- "No Debrid Services Enabled" → `rd.enabled` got reset: re-seed / re-release.
