#!/usr/bin/env python3
"""Render both flavors' latest notes into the packager's upload changelog."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def render(root=ROOT):
    sections = ["# ArtisanFinder release notes"]
    for flavor in ("Retail", "Forever"):
        source = root / f"CHANGELOG_{flavor.upper()}.md"
        lines = source.read_text(encoding="utf-8").splitlines()
        starts = [index for index, line in enumerate(lines) if line.startswith("## ")]
        if not starts:
            raise ValueError(f"No release notes found in {source}")
        latest = lines[starts[0]:starts[1] if len(starts) > 1 else len(lines)]
        version = latest[0][3:]
        body = latest[1:]
        sections.append(f"## {flavor} — {version}\n\n" + "\n".join(body).strip())
    return "\n\n".join(sections) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "CHANGELOG.md")
    args = parser.parse_args()
    args.output.write_text(render(), encoding="utf-8")
    print(args.output)
