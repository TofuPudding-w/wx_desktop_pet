"""Package without external zip dependency, preserving Unix executable bits."""
from pathlib import Path
import hashlib
import zipfile
root = Path('dist')
package = root / 'CPPet-v0.1.0-Linux-x64'
archive = root / (package.name + '.zip')
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as output:
    for path in sorted(package.rglob('*')):
        if path.is_file():
            output.write(path, path.relative_to(root))
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n')
print(f'{archive} ({archive.stat().st_size / 1024**2:.1f} MiB)')
