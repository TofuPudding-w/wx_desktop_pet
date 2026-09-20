"""Real two-hour exported-app soak. Writes a pending/final report to dist/."""
import json
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
package = root / 'dist/CPPet-v0.1.0-Linux-x64'
report_path = root / 'dist/soak-result.json'
telemetry = root / 'dist/soak-telemetry.json'
log_path = root / 'dist/soak.log'
duration = 7200
started = time.monotonic()
peak_rss_kib = 0
report = {'status': 'running', 'required_seconds': duration}
report_path.write_text(json.dumps(report, indent=2))
with log_path.open('w') as log:
    app = subprocess.Popen([str(package / 'CPPet.x86_64'), '--display-driver', 'x11', '--', '--soak', f'--quit-after={duration}', f'--telemetry={telemetry}'], cwd='/tmp', stdout=log, stderr=subprocess.STDOUT)
    try:
        while app.poll() is None and time.monotonic() - started < duration + 180:
            try:
                status = Path(f'/proc/{app.pid}/status').read_text()
                rss = next(int(line.split()[1]) for line in status.splitlines() if line.startswith('VmRSS:'))
                peak_rss_kib = max(peak_rss_kib, rss)
            except (FileNotFoundError, StopIteration):
                pass
            report.update(elapsed_wall_seconds=round(time.monotonic() - started, 1), peak_rss_kib=peak_rss_kib)
            report_path.write_text(json.dumps(report, indent=2))
            time.sleep(5)
        if app.poll() is None:
            app.terminate()
            app.wait(timeout=10)
        snapshot = json.loads(telemetry.read_text()) if telemetry.exists() else {}
        output = log_path.read_text()
        passed = app.returncode == 0 and snapshot.get('elapsed_seconds', 0) >= duration and snapshot.get('completed', 0) >= 100 and 'ERROR:' not in output
        report.update(status='passed' if passed else 'failed', exit_code=app.returncode, telemetry=snapshot)
    finally:
        if app.poll() is None:
            app.terminate()
            app.wait(timeout=10)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False))
print(json.dumps(report, indent=2, ensure_ascii=False))
raise SystemExit(0 if report['status'] == 'passed' else 1)
