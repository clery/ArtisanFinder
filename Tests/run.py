#!/usr/bin/env python3
"""Run from any directory; validate package paths, XML and every Lua fixture."""
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
import sys
sys.path.insert(0, str(root / "Tools"))
from package import runtime_files, build
flavors = {}
for name in ("ArtisanFinder.toc", "ArtisanFinder_Mainline.toc", "ArtisanFinder_Camelot.toc"):
    paths = runtime_files(root / name)
    flavors[name] = {p.relative_to(root).as_posix() for p in paths}
    entries = [line.strip().replace("\\", "/") for line in (root / name).read_text().splitlines() if line.strip() and not line.startswith("#")]
    flavor = "Retail" if "Mainline" in name else "Forever"
    assert entries.index(f"Flavors/{flavor}.lua") < entries.index("Core/Bootstrap.lua"), "Flavor must precede bootstrap"
    print(f"PASS {flavor} recursive TOC/XML includes: {len(paths)} runtime files", flush=True)
retail = flavors["ArtisanFinder_Mainline.toc"]
forever = flavors["ArtisanFinder_Camelot.toc"]
assert flavors["ArtisanFinder.toc"] == forever, "Fallback must load the same Forever modules"
for path in ("Features/Retail/Crafter/CustomerPreview.lua", "Features/Retail/Orders/Notifications.lua", "Features/Retail/Customer/PreparationTracker.lua", "Features/Retail/Customer/ShoppingList.lua", "Features/Retail/Data/OrderableRecipes.lua", "Features/Retail/Crafter/RecipeCapability.lua", "Features/Retail/Crafter/ReagentControls.lua"):
    assert path in retail and path not in forever, f"Retail-only module leaked: {path}"
assert not any(path.startswith("Features/Forever/") for path in retail), "Forever module leaked into Retail"
assert "Features/Forever/DirectoryUI.lua" in forever
assert "Changelogs/Retail.lua" in retail and "Changelogs/Retail.lua" not in forever
assert "Changelogs/Forever.lua" in forever and "Changelogs/Forever.lua" not in retail
for path in ("Core/Core.lua", "Core/Data.lua", "Core/Transfer.lua", "Features/Social/Comms.lua", "Features/Crafter/Scanner.lua", "Features/Crafter/UI.lua", "Features/Crafter/ProfessionRecipes.lua", "Features/Customer/ProfessionOpening.lua", "Features/Customer/PreparationTracker.lua", "Locales/Shared.xml", "SharedCore.xml", "Features/SharedData.xml", "UI/SharedWidgets.xml"):
    assert path in retail & forever, f"Expected shared module: {path}"
for flavor, paths, other in (("Retail", retail, "Forever"), ("Forever", forever, "Retail")):
    assert not any(path.startswith(f"Features/{other}/") or path.startswith(f"Locales/{other}/") for path in paths)
    assert f"Features/{flavor}/Options.lua" in paths
    assert f"Features/{flavor}/Tutorial.lua" in paths
    assert f"Locales/{flavor}/enUS.lua" in paths
    assert f"Locales/{flavor}/frFR.lua" in paths
    assert f"Flavors/{other}.lua" not in paths
print("PASS flavor isolation and shared module selection", flush=True)
for path in sorted(root.rglob("*.lua")):
    subprocess.run(["luac", "-p", str(path)], cwd=root, check=True)
print("PASS Lua syntax: all addon, library and test files", flush=True)
subprocess.run([sys.executable, str(root / "Tests/release_packaging.py")], cwd=root, check=True)
tests = sorted((root / "Tests").glob("*.lua"))
for path in tests:
    print(f"→ {path.name}", flush=True)
    subprocess.run(["lua5.1", str(path)], cwd=root, check=True)
print(f"PASS {len(tests)} regression suites", flush=True)

# Validate what users install, including XML includes inside each actual ZIP.
import tempfile
from zipfile import ZipFile
with tempfile.TemporaryDirectory(prefix="artisanfinder-packages-") as directory:
    for flavor in ("retail", "forever"):
        archive = build(flavor, Path(directory))
        with ZipFile(archive) as package:
            names = set(package.namelist())
            manifest = package.read("ArtisanFinder/ArtisanFinder.toc").decode()
            changelog = package.read("ArtisanFinder/CHANGELOG.md")
            assert changelog == (root / f"CHANGELOG_{flavor.upper()}.md").read_bytes()
            assert "@project-version@" not in manifest
            other = "Retail" if flavor == "forever" else "Forever"
            assert f"ArtisanFinder/Changelogs/{other}.lua" not in names
            assert f"Flavors\\{flavor.title()}.lua" in manifest
            assert sum(name.endswith(".toc") for name in names) == 1
            pending = ["ArtisanFinder/" + line.strip().replace("\\", "/") for line in manifest.splitlines() if line.strip() and not line.startswith("#")]
            visited = set()
            while pending:
                name = pending.pop()
                assert name in names, f"Missing packaged runtime file: {name}"
                if name in visited:
                    continue
                visited.add(name)
                if name.endswith(".xml"):
                    for node in ET.fromstring(package.read(name)).iter():
                        if node.tag.rsplit("}",1)[-1] in {"Script","Include"} and node.get("file"):
                            pending.append(str(Path(name).parent / node.get("file").replace("\\", "/")))
            assert not any("/Media/" in name for name in names)
            for icon in ("Advertising.tga", "Featured.tga"):
                assert (f"ArtisanFinder/Assets/Forever/{icon}" in names) == (flavor == "forever")
            if flavor == "forever":
                assert not any("Features/Retail/Orders/" in name or "Libs/LibEditMode/" in name for name in names)
            else:
                assert "ArtisanFinder/Features/Retail/Orders/Notifications.lua" in names
                assert not any("Features/Forever/" in name for name in names)
print("PASS both installable archives: correct flavor, complete includes, client-only dependencies isolated", flush=True)
