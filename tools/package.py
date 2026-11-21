#!/usr/bin/env python3
"""Build and verify Bloodrunner's installable WoW: Forever ZIP."""

import argparse
from pathlib import Path, PurePosixPath
import re
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parent.parent
ADDON = ROOT / "Bloodrunner"
TOC = ADDON / "Bloodrunner_Camelot.toc"
TAG = re.compile(r"v(\d+\.\d+\.\d+)")


def package(tag, output_dir):
    manifest = TOC.read_bytes()
    toc = manifest.decode("utf-8")
    version = re.search(r"^## Version:[ \t]*(\S+)[ \t]*$", toc, re.MULTILINE)
    if not version:
        raise ValueError(f"missing ## Version in {TOC.name}")
    tag = tag if tag is not None else f"v{version[1]}"
    match = TAG.fullmatch(tag)
    if not match or match[1] != version[1]:
        raise ValueError(f"tag must be vMAJOR.MINOR.PATCH and match {TOC.name} ({version[1]})")
    if not re.search(r"^## Interface:[ \t]*16001[ \t]*$", toc, re.MULTILINE):
        raise ValueError(f"expected Forever interface 16001 in {TOC.name}")

    files = {}
    for line in toc.splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        relative = PurePosixPath(entry.replace("\\", "/"))
        source = ADDON / relative
        if relative.is_absolute() or ".." in relative.parts or not source.is_file():
            raise ValueError(f"invalid or missing TOC entry: {entry}")
        files[relative.as_posix()] = source

    for path in sorted((ADDON / "Media").rglob("*")):
        if path.is_file():
            files[path.relative_to(ADDON).as_posix()] = path
    if "Media/arrow.blp" not in files:
        raise ValueError("missing Media/arrow.blp")
    files["AGENTS.md"] = ROOT / "AGENTS.md"

    output_dir.mkdir(parents=True, exist_ok=True)
    archive = output_dir / f"Bloodrunner-{tag}-forever.zip"
    with ZipFile(archive, "w", compression=ZIP_DEFLATED) as zipped:
        # The release is Forever-only: give the active manifest the plain install name.
        zipped.writestr("Bloodrunner/Bloodrunner.toc", manifest)
        for relative, source in files.items():
            zipped.write(source, f"Bloodrunner/{relative}")
    with ZipFile(archive) as zipped:
        bad_file = zipped.testzip()
        if bad_file:
            raise ValueError(f"ZIP verification failed: {bad_file}")
    return archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", nargs="?", help="release tag (defaults to the Forever TOC version)")
    parser.add_argument("--output-dir", type=Path, default=Path("dist"))
    args = parser.parse_args()
    try:
        archive = package(args.tag, args.output_dir)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Packaging failed: {error}\n")
    print(f"Created {archive}")


if __name__ == "__main__":
    main()
