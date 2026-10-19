# Release 2.2.0

Release date: 2026-10-19. Changes since v2.1.5 are documented in the [Forever changelog](CHANGELOG_FOREVER.md) and [Retail changelog](CHANGELOG_RETAIL.md), with English/French in-game notes. Other locales use the English fallback for this release's notes.

## Local preparation

Run from the repository root with Python 3 and Lua 5.1 installed:

```sh
rtk proxy python3 Tests/run.py
rtk proxy python3 Tools/package.py --flavor all --version 2.2.0 --output .release/2.2.0
rtk proxy python3 Tools/release_changelog.py --output .release/2.2.0/CHANGELOG.md
```

The local builder packages the current working tree, including new agreement modules. Both ZIPs contain an ArtisanFinder folder and exact version 2.2.0. Retail and Forever are alternative installations; install only the matching ZIP. Source manifests retain the packager's version token, which the tag-triggered release replaces automatically. In-game fallback versions and release histories are 2.2.0.

## Before publishing

- Complete the [two-client agreement checks](Tests/AGREEMENTS.md), especially customer material snapshots at acceptance, completion confirmation/stamps, notifications and reconnect/reload behavior. Both players need a compatible build.
- Perform the [Retail and Forever live checks](Tests/README.md), including Retail personal-order notifications and profession scanning. Automated UI fixtures do not verify rendering inside WoW.
- Review and commit all intended tracked and new source files, including the agreement modules and shared notification sound. Rerun validation if source changes.
- Create and push tag v2.2.0 on the reviewed release commit when ready to publish. Pushing that tag runs the [release workflow](.github/workflows/release.yml): validation, combined release notes, then BigWigs packaging and uploads using configured service credentials.

Local preparation does not create a commit/tag, push changes or publish a release. The [root changelog](CHANGELOG.md) summarizes version 2.2.0 for both clients and links to their full histories; publishing generates the upload notes from both flavor histories.
