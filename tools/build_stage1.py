"""Local cross-platform test packages. Never tags, uploads, or overwrites releases."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import struct
import subprocess
import zipfile
from release_metadata import ROOT, project_version
from user_guide import render as render_user_guide

TARGETS = {
    'linux': ('Linux x86_64', 'Linux-x64', 'CPPet.x86_64'),
    'windows': ('Windows x86_64', 'Windows-x64', 'CPPet.exe'),
    'macos': ('macOS Universal Experimental', 'macOS-Universal-EXPERIMENTAL', 'CPPet.zip'),
}
LICENSES = {
    'assets/fonts/LICENSE.txt': 'Droid-Apache-2.0.txt',
    'assets/fonts/NOTICE.txt': 'Droid-NOTICE.txt',
    'docs/GODOT-LICENSE.txt': 'GODOT-LICENSE.txt',
    'docs/GODOT-THIRD-PARTY.json': 'GODOT-THIRD-PARTY.json',
    'docs/THIRD_PARTY.md': 'THIRD_PARTY.md',
}

def fingerprint():
    paths = [ROOT / 'project.godot', ROOT / 'export_presets.cfg', ROOT / 'run.sh', ROOT / 'docs/guide/START_HERE.template.html']
    for directory in ['assets', 'data', 'scenes', 'scripts', 'tools']:
        paths.extend(p for p in (ROOT / directory).rglob('*')
                     if p.is_file() and '__pycache__' not in p.parts)
    h = hashlib.sha256()
    for path in sorted(paths):
        h.update(path.relative_to(ROOT).as_posix().encode() + b'\0')
        h.update(hashlib.sha256(path.read_bytes()).digest())
    return h.hexdigest()


def validate_archive(archive, target):
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise ValueError('ZIP integrity check failed')
        files = {Path(n).name: n for n in z.namelist() if not n.endswith('/')}
        for name in ['BUILD_INFO.json', 'TEST_CHECKLIST.md', 'README.txt']:
            if name not in files:
                raise ValueError('Missing ' + name)
        if target == 'windows':
            binary = z.read(files['CPPet.exe'])
            pe_offset = struct.unpack_from('<I', binary, 0x3C)[0]
            if binary[:2] != b'MZ' or binary[pe_offset:pe_offset+4] != b'PE\0\0' or struct.unpack_from('<H', binary, pe_offset+4)[0] != 0x8664:
                raise ValueError('Not a Windows x64 PE executable')
            if len(z.read(files['CPPet.pck'])) < 1000:
                raise ValueError('Missing project resources')
        elif target == 'linux':
            binary = z.read(files['CPPet.x86_64'])
            if binary[:5] != b'\x7fELF\x02' or struct.unpack_from('<H', binary, 18)[0] != 62:
                raise ValueError('Not a Linux x64 ELF executable')
            for name in ['CPPet.x86_64', 'run.sh']:
                if not ((z.getinfo(files[name]).external_attr >> 16) & 0o111):
                    raise ValueError('Missing execute permissions')
        else:
            plists = [n for n in z.namelist() if n.endswith('.app/Contents/Info.plist')]
            if len(plists) != 1:
                raise ValueError('Expected one macOS app bundle')
            info = plistlib.loads(z.read(plists[0]))
            executable = plists[0].removesuffix('Info.plist') + 'MacOS/' + info['CFBundleExecutable']
            binary = z.read(executable)
            if binary[:4] != b'\xca\xfe\xba\xbe':
                raise ValueError('Expected Universal 2 Mach-O')
            count = struct.unpack_from('>I', binary, 4)[0]
            cpus = {struct.unpack_from('>I', binary, 8 + i * 20)[0] for i in range(count)}
            if cpus != {0x01000007, 0x0100000C}:
                raise ValueError('Universal binary must contain x64 and arm64')
            if not ((z.getinfo(executable).external_attr >> 16) & 0o111):
                raise ValueError('macOS executable permission missing')
            if not any(n.endswith('.pck') for n in z.namelist()):
                raise ValueError('macOS project resources missing')


def build(target, engine, destination, build_id, source_digest, stage=1):
    preset, label, filename = TARGETS[target]
    package_name = f'CPPet-stage{stage}-{build_id}-{label}'
    folder = destination / package_name
    folder.mkdir()
    log = destination / (label + '-export.log')
    environment = os.environ.copy()
    if target == 'macos':
        # Godot's macOS validation also checks the standard template directory.
        # Keep it project-local instead of installing into the user's profile.
        data_home = ROOT / '.tools/godot-data'
        templates = data_home / 'godot/export_templates/4.6.1.stable'
        templates.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / '.tools/templates/macos.zip', templates / 'macos.zip')
        environment['XDG_DATA_HOME'] = str(data_home)
    with log.open('w') as output:
        subprocess.run([str(engine), '--headless', '--path', str(ROOT), '--export-release', preset, str(folder / filename)], cwd=ROOT, env=environment, stdout=output, stderr=subprocess.STDOUT, check=True)
    export_log = log.read_text()
    if 'SCRIPT ERROR:' in export_log or 'Parse Error:' in export_log:
        raise ValueError('Export contained script errors; inspect ' + str(log))
    info = {'build_id': build_id, 'project_version': project_version(), 'target': label,
            'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            'working_tree_modified': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
            'source_fingerprint': source_digest, 'engine': '4.6.1.stable',
            'distribution': f'local-stage{stage}-test-only', 'device_validation': 'pending',
            'signing': 'ad-hoc only; not notarized' if target == 'macos' else 'unsigned',
            'built_utc': datetime.now(timezone.utc).isoformat()}
    (folder / 'BUILD_INFO.json').write_text(json.dumps(info, indent=2) + '\n')
    shutil.copy2(ROOT / f'docs/testing/STAGE{stage}_CHECKLIST.md', folder / 'TEST_CHECKLIST.md')
    (folder / 'licenses').mkdir()
    for source, name in LICENSES.items():
        shutil.copy2(ROOT / source, folder / 'licenses' / name)
    instructions = {
        'linux': 'Extract, then run ./run.sh. X11/XWayland required. Create desktop/menu shortcuts: python3 create-shortcut.py.\nEye-only: ./run.sh -- --eye-demo\nHug-only: ./run.sh -- --hug-demo\n',
        'windows': 'Extract the WHOLE ZIP before launching CPPet.exe or run.cmd. Keep CPPet.pck beside CPPet.exe. Run create-shortcut.cmd for an optional desktop shortcut.\nUse test-eye-contact.cmd / test-hug.cmd to isolate each interaction. Close existing pets first.\nUse diagnose.cmd if needed; logs: %LOCALAPPDATA%\\WangXianPet\\Stage1\\pet.log\n',
        'macos': 'EXPERIMENTAL / UNVERIFIED ON macOS. Extract the ZIP and open the .app bundle. Finder > Make Alias can create a desktop shortcut.\nAd-hoc signed only, NOT Developer ID signed or notarized. Gatekeeper may prevent launch.\nDo not disable system-wide security. This build needs a Mac volunteer to validate launch and desktop behavior.\n',
    }
    (folder / 'README.txt').write_text(f'WangXian Desktop Pet - Stage {stage} local test build\nOpen START_HERE.html for the illustrated offline guide.\nNOT A NEW PUBLIC RELEASE. Device validation pending; see TEST_CHECKLIST.md.\n\n' + instructions[target] + '\nRight-click a character: pause/resume, reset positions, Settings > pet size (100-200%) / automatic interactions, Interactions > eye contact / hug, Hide > right-click the screen-edge rabbit > Show pets, Help > offline user guide, exit.\nWWX left / LWJ right, within 320px; independent 30-second cooldown per interaction, plus a 5-second shared rest. Automatic and manual triggers follow the same rules. Cooldowns start on completion/cancellation and continue while paused or hidden.\nPet size, pause and automatic interactions are saved locally; large sizes are limited to fit the display.\nManual update checking requires internet; no automatic installation.\n')
    (folder / 'START_HERE.html').write_text(render_user_guide(ROOT, target, project_version(), build_id), encoding='utf-8')
    shutil.copy2(ROOT / 'assets/characters/icon/hiding_icon.png', folder / 'hiding_icon.png')
    shutil.copy2(ROOT / 'assets/characters/icon/icon.png', folder / 'icon.png')
    if target == 'linux':
        shutil.copy2(ROOT / 'tools/launchers/create_shortcut.py', folder / 'create-shortcut.py')
        shutil.copy2(ROOT / 'run.sh', folder / 'run.sh')
        (folder / 'run.sh').chmod(0o755)
        (folder / filename).chmod(0o755)
    elif target == 'windows':
        for launcher in (ROOT / 'tools/launchers').glob('*.cmd'):
            (folder / launcher.name).write_bytes(launcher.read_text().replace('\n', '\r\n').encode())
    archive = destination / (package_name + '.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for path in sorted(folder.rglob('*')):
            if not path.is_file() or (target == 'macos' and path.name == filename):
                continue
            relative = package_name + '/' + path.relative_to(folder).as_posix()
            z.write(path, relative)
        if target == 'macos':
            with zipfile.ZipFile(folder / filename) as app:
                for member in app.infolist():
                    # Preserve the app's modes, signatures, structure and any symlinks.
                    data = app.read(member)
                    member.filename = package_name + '/' + member.filename
                    z.writestr(member, data)
    validate_archive(archive, target)
    archive.with_suffix('.zip.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n')
    print('VERIFIED PACKAGE:', archive, flush=True)
    return archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=int, choices=[1, 2, 3, 4], default=1)
    parser.add_argument('--platform', choices=['all', *TARGETS], default='all')
    parser.add_argument('--godot', type=Path, default=ROOT / '.tools/godot/Godot_v4.6.1-stable_linux.x86_64')
    args = parser.parse_args()
    engine = args.godot.resolve()
    if not subprocess.check_output([str(engine), '--version'], text=True).startswith('4.6.1.stable'):
        raise ValueError('Use pinned Godot 4.6.1')
    subprocess.run([str(engine), '--headless', '--editor', '--path', str(ROOT), '--import', '--quit'], cwd=ROOT, check=True)
    digest = fingerprint()
    build_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + digest[:8]
    destination = ROOT / f'dist/stage{args.stage}' / build_id
    destination.mkdir(parents=True)
    targets = list(TARGETS) if args.platform == 'all' else [args.platform]
    packages = {target: str(build(target, engine, destination, build_id, digest, args.stage)) for target in targets}
    if fingerprint() != digest:
        raise ValueError('Build inputs changed while exporting; do not distribute this test batch')
    (destination / 'packages.json').write_text(json.dumps(packages, indent=2) + '\n')
    (ROOT / f'dist/stage{args.stage}/latest.json').write_text(json.dumps({'build_id': build_id, 'packages': packages}, indent=2) + '\n')

if __name__ == '__main__':
    main()
