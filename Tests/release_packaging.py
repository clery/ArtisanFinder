"""Check release notes and publishing configuration without network/uploads."""
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "Tools"))
from release_changelog import render

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    for flavor in ("RETAIL", "FOREVER"):
        (root / f"CHANGELOG_{flavor}.md").write_text(
            f"# Title\n\n## 3.0.0\n\n### Added\n- New {flavor} feature.\n\n## 2.0.0\n- Old feature.\n")
    notes = render(root)
    assert "## Retail — 3.0.0" in notes and "## Forever — 3.0.0" in notes
    assert "New RETAIL feature." in notes and "New FOREVER feature." in notes
    assert "Old feature." not in notes and notes.count("\n### Added\n") == 2
    (root / "CHANGELOG_FOREVER.md").write_text("# Empty")
    try:
        render(root)
    except ValueError:
        pass
    else:
        raise AssertionError("Empty release notes must stop publishing")

notes = render()
assert "## Retail" in notes and "## Forever" in notes
workflow = (ROOT / ".github/workflows/release.yml").read_text()
assert workflow.index("python3 Tests/run.py") < workflow.index("python3 Tools/release_changelog.py") < workflow.index("uses: BigWigsMods/packager")
assert "contents: write" in workflow and "-g retail" not in workflow
for manifest in ROOT.glob("ArtisanFinder*.toc"):
    assert "## Version: @project-version@" in manifest.read_text()
print("PASS release notes, empty-history guard, validation-before-upload and tag-based versions")
