"""One source of truth for project versions and release asset names."""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
VERSION_PATTERN = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"


def project_version(root=ROOT):
    section = ""
    for raw in (root / "project.godot").read_text().splitlines():
        line = raw.strip()
        if line.startswith("["):
            section = line
        if section == "[application]" and line.startswith("config/version="):
            version = line.split("=", 1)[1].strip().strip('"')
            if not re.fullmatch(VERSION_PATTERN, version):
                raise ValueError("project.godot version must be X.Y.Z")
            return version
    raise ValueError("project.godot has no application config/version")


def release_metadata(root=ROOT, tag=None):
    version = project_version(root)
    expected = "v" + version
    if tag is not None and tag != expected:
        raise ValueError(f"Tag {tag!r} does not match project version {expected}")
    return {"version": version, "tag": expected,
            "package": f"CPPet-v{version}-Linux-x64",
            "archive": f"CPPet-v{version}-Linux-x64.zip"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag")
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    try:
        metadata = release_metadata(tag=args.tag)
        if args.github_output:
            notes = ROOT / "releases" / (metadata["tag"] + ".md")
            if not notes.is_file() or not notes.read_text().strip():
                raise ValueError(f"Missing release notes: {notes}")
            with args.github_output.open("a") as output:
                for key, value in metadata.items():
                    output.write(f"{key}={value}\n")
        else:
            print(metadata["version"])
    except ValueError as error:
        parser.exit(1, f"Release validation failed: {error}\n")
