"""Launch the exported app, exercise only its windows, then exit via its menu."""
from pathlib import Path
import subprocess
import time
import sys

root = Path(__file__).resolve().parents[1]
from release_metadata import release_metadata
engine = root / 'dist' / release_metadata()['package'] / 'CPPet.x86_64'
probe = root / 'tools/x11_probe.py'
log = root / 'dist/desktop-smoke.log'
with log.open('w') as output:
    preview = '--preview' in sys.argv
    app = subprocess.Popen([str(engine), '--display-driver', 'x11', '--', *([] if preview else ['--paused'])], cwd='/tmp', stdout=output, stderr=subprocess.STDOUT)
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
            for args in [('A', '--alpha'), ('A',), ('B',), ('A', '--menu'), ('A', '--exit-menu')]:
                subprocess.run(['python3', str(probe), *args], check=True)
            assert app.wait(timeout=10) == 0
    finally:
        if app.poll() is None:
            app.terminate()
            app.wait(timeout=10)
print('Captured interaction previews' if preview else 'PASS: exported app alpha, hit regions, both drags, focus, menu and whole-process exit')
