"""Package only release files, preserving Unix modes and reproducible ZIP metadata."""
from pathlib import Path
import hashlib
import stat
import zipfile
from release_metadata import ROOT, release_metadata

RELEASE_FILES = (
    "CPPet.x86_64", "run.sh", "README.txt", "VALIDATION.md",
    "licenses/Droid-Apache-2.0.txt", "licenses/Droid-NOTICE.txt",
    "licenses/GODOT-LICENSE.txt", "licenses/GODOT-THIRD-PARTY.json",
    "licenses/THIRD_PARTY.md",
)


def package_linux(root=ROOT):
    metadata = release_metadata(root)
    package = root / "dist" / metadata["package"]
    for name in RELEASE_FILES:
        path = package / name
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"Missing release file or unexpected symlink: {path}")
    archive = root / "dist" / metadata["archive"]
    # Fixed entry order, time and permissions; identical inputs produce identical ZIPs.
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for name in RELEASE_FILES:
            entry = zipfile.ZipInfo(f"{metadata['package']}/{name}", (1980, 1, 1, 0, 0, 0))
            mode = 0o755 if name in ("CPPet.x86_64", "run.sh") else 0o644
            entry.create_system = 3
            entry.external_attr = (stat.S_IFREG | mode) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            output.writestr(entry, (package / name).read_bytes())
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n")
    return archive


if __name__ == "__main__":
    archive = package_linux()
    print(f"{archive} ({archive.stat().st_size / 1024**2:.1f} MiB)")
