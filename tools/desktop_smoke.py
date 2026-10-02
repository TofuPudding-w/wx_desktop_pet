"""Launch the exported app, exercise only its windows, then exit via its menu."""
from pathlib import Path
import subprocess
import time
import sys
import argparse

root = Path(__file__).resolve().parents[1]
from release_metadata import release_metadata
parser = argparse.ArgumentParser()
parser.add_argument('--binary', type=Path)
parser.add_argument('--preview', action='store_true')
parser.add_argument('--controls', action='store_true')
args = parser.parse_args()
engine = args.binary.resolve() if args.binary else root / 'dist' / release_metadata()['package'] / 'CPPet.x86_64'
probe = root / 'tools/x11_probe.py'
log = root / 'dist/desktop-smoke.log'
tree = subprocess.check_output(['xwininfo', '-root', '-tree'], text=True, timeout=10)
if '"CP Pet ' in tree:
    raise SystemExit('Close existing desktop pets before running the isolated native check')
with log.open('w') as output:
    preview = args.preview
    controls = args.controls
    app = subprocess.Popen([str(engine), '--display-driver', 'x11', '--', '--no-settings', *([] if preview else ['--paused'])], cwd='/tmp', stdout=output, stderr=subprocess.STDOUT)
    try:
        for _ in range(300):
            if app.poll() is not None:
                raise RuntimeError(f'App exited early: {app.returncode}')
            try:
                tree = subprocess.check_output(['xwininfo', '-root', '-tree'], text=True, stderr=subprocess.PIPE)
            except subprocess.CalledProcessError:
                # A desktop window can disappear during X11 tree enumeration.
                time.sleep(.1)
                continue
            if '"CP Pet B"' in tree:
                time.sleep(1)
                break
            time.sleep(.1)
        else:
            raise RuntimeError('Two native windows did not appear')
        if preview:
            time.sleep(1)
            subprocess.run(['python3', str(probe), 'A', '--capture'], check=True)
            time.sleep(2)
            subprocess.run(['python3', str(probe), 'B', '--capture'], check=True)
        else:
            for size in [150, 200, 100]:
                for arguments in [('A', '--menu'), ('A', '--settings-menu'), ('A', '--size-menu'), ('A', f'--size{size}-menu'), ('A', '--alpha'), ('A',), ('B',)]:
                    subprocess.run(['python3', str(probe), *arguments], check=True)
                tree = subprocess.check_output(['xwininfo', '-root', '-tree'], text=True)
                expected = f'{int(320*size/100)}x{int(384*size/100)}'
                assert any(expected in line and '"CP Pet A"' in line for line in tree.splitlines()), tree
            if controls:
                import re
                def mapped_pets():
                    tree = subprocess.check_output(['xwininfo', '-root', '-tree'], text=True)
                    mapped = []
                    for wid, name in re.findall(r'(0x[0-9a-f]+) "(CP Pet (?:A|B|Hug|Hidden))"', tree):
                        info = subprocess.check_output(['xwininfo', '-id', wid], text=True)
                        if 'Map State: IsViewable' in info:
                            mapped.append(name)
                    return sorted(mapped)
                for arguments in [('A', '--menu'), ('A', '--reset-menu'), ('A', '--menu'), ('A', '--hide-menu')]:
                    subprocess.run(['python3', str(probe), *arguments], check=True)
                assert mapped_pets() == ['CP Pet Hidden'], 'Only restore icon should be visible'
                for arguments in [('Hidden', '--alpha'), ('Hidden', '--icon-input'), ('Hidden',), ('Hidden', '--menu'), ('Hidden', '--restore-menu')]:
                    subprocess.run(['python3', str(probe), *arguments], check=True)
                time.sleep(.5)
                assert mapped_pets() == ['CP Pet A', 'CP Pet B'], 'Manual restore failed'
                print('PASS: hide replaces pets with draggable icon; icon menu restores both', flush=True)
                for arguments in [('A', '--menu'), ('A', '--hide-menu'), ('Hidden', '--menu'), ('Hidden', '--exit-hidden-menu')]:
                    subprocess.run(['python3', str(probe), *arguments], check=True)
            else:
                for arguments in [('A', '--menu'), ('A', '--exit-menu')]:
                    subprocess.run(['python3', str(probe), *arguments], check=True)
            assert app.wait(timeout=10) == 0
    finally:
        if app.poll() is None:
            app.terminate()
            app.wait(timeout=10)
print('Captured interaction previews' if preview else 'PASS: exported app alpha, hit regions, both drags, focus, menu and whole-process exit')
