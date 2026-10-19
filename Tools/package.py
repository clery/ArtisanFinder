#!/usr/bin/env python3
"""Build either client flavor from this same checkout, without publishing."""
import argparse
import re
import subprocess
from pathlib import Path
import xml.etree.ElementTree as ET
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent.parent
MANIFESTS = {"retail": "ArtisanFinder_Mainline.toc", "forever": "ArtisanFinder_Camelot.toc"}


def runtime_files(manifest):
    files = set()

    def visit(path):
        path = path.resolve()
        if not path.is_relative_to(ROOT):
            raise ValueError(f"Runtime include escapes addon: {path}")
        if not path.is_file():
            raise FileNotFoundError(path)
        if path in files:
            return
        files.add(path)
        if path.suffix.lower() == ".xml":
            for node in ET.parse(path).getroot().iter():
                if node.tag.rsplit("}", 1)[-1] in {"Script", "Include"} and node.get("file"):
                    visit(path.parent / node.get("file").replace("\\", "/"))

    for line in manifest.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            visit(ROOT / line.replace("\\", "/"))
    return files


def build(flavor, output, version=None):
    if version is not None and not re.fullmatch(r"v?\d+\.\d+\.\d+(?:[-.][A-Za-z0-9]+)*", version):
        raise ValueError("Version must be a release version, for example 2.2.0")
    manifest = ROOT / MANIFESTS[flavor]
    files = runtime_files(manifest)
    for directory in ("Assets",):
        files.update(path for path in (ROOT / directory).rglob("*") if path.is_file()
                     and (flavor == "forever" or not path.is_relative_to(ROOT / "Assets/Forever")))
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md", "README.md", "ARCHITECTURE.md"):
        files.add(ROOT / name)
    # Preserve third-party license and notice files alongside vendored libraries.
    libraries = {path.relative_to(ROOT).parts[1] for path in files if path.is_relative_to(ROOT / "Libs")}
    for library in libraries:
        for path in (ROOT / "Libs" / library).rglob("*"):
            if path.is_file() and any(word in path.name.lower() for word in ("license", "copying", "notice")):
                files.add(path)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"ArtisanFinder-{flavor}.zip"
    with ZipFile(archive, "w", compression=ZIP_DEFLATED) as package:
        version = version or subprocess.run(
            ["git", "describe", "--tags", "--always", "--dirty"], cwd=ROOT,
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        package.writestr("ArtisanFinder/ArtisanFinder.toc",
                         manifest.read_text().replace("@project-version@", version))
        package.write(ROOT / f"CHANGELOG_{flavor.upper()}.md", "ArtisanFinder/CHANGELOG.md")
        for path in sorted(files):
            package.write(path, "ArtisanFinder/" + path.relative_to(ROOT).as_posix())
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flavor", choices=("retail", "forever", "all"), default="all")
    parser.add_argument("--output", type=Path, default=ROOT / ".release")
    parser.add_argument("--version", help="Explicit version for local release preparation; defaults to git describe")
    args = parser.parse_args()
    flavors = MANIFESTS if args.flavor == "all" else (args.flavor,)
    for flavor in flavors:
        print(build(flavor, args.output, args.version))
