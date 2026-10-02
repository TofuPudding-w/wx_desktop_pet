"""Live desktop soak with isolated evidence, heartbeats and explicit completion gates."""
import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
from pathlib import Path
import subprocess
import shutil
import time
import uuid

from release_metadata import ROOT, release_metadata


def write_json(path, data):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    temporary.replace(path)


def completion_failures(snapshot, exit_code, wall_seconds, duration, log):
    reasons = []
    if exit_code != 0:
        reasons.append(f'process exit code: {exit_code}')
    if wall_seconds < duration:
        reasons.append('real elapsed time below required duration')
    if snapshot.get('elapsed_seconds', 0) < duration:
        reasons.append('application elapsed time below required duration')
    if snapshot.get('completed', 0) < max(1, int(duration / 72)):
        reasons.append('too few completed interactions')
    pets = snapshot.get('pets', [])
    if len(pets) != 2 or {pet.get('id') for pet in pets} != {'A', 'B'}:
        reasons.append('missing or incorrect pet telemetry')
    if 'ERROR:' in log or 'SCRIPT ERROR:' in log:
        reasons.append('engine or script error in log')
    return reasons


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--seconds', type=int, default=7200,
                        help='Default 7200; shorter runs are smoke tests, never two-hour acceptance.')
    parser.add_argument('--binary', type=Path, help='Test an isolated stage build instead of the release folder')
    args = parser.parse_args()
    if args.seconds < 60:
        parser.error('duration must be at least 60 seconds')
    duration = args.seconds
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    lock = (dist / '.soak.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        parser.error('another soak runner is already active')
    metadata = release_metadata()
    binary = args.binary.resolve() if args.binary else dist / metadata['package'] / 'CPPet.x86_64'
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
    evidence = dist / 'soak-runs' / run_id
    evidence.mkdir(parents=True)
    telemetry = evidence / 'telemetry.json'
    report_path = evidence / 'result.json'
    log_path = evidence / 'app.log'
    samples_path = evidence / 'samples.jsonl'
    latest = dist / 'soak-result.json'
    report = {'status': 'running', 'run_id': run_id, 'required_seconds': duration,
              'two_hour_acceptance': False, 'started_utc': datetime.now(timezone.utc).isoformat(),
              'binary': str(binary), 'binary_sha256': digest,
              'source_head_at_test': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'evidence_directory': str(evidence), 'failures': [], 'samples': 0, 'peak_rss_kib': 0}

    def save():
        write_json(report_path, report)
        write_json(latest, report)

    app = None
    snapshot = {}
    started = time.monotonic()
    last_heartbeat = started
    last_progress = started
    last_completed = -1
    previous_telemetry_time = -1
    rss_samples = []
    save()
    try:
        with log_path.open('w') as output, samples_path.open('w') as samples:
            launcher = [shutil.which('stdbuf'), '-oL', '-eL'] if shutil.which('stdbuf') else []
            app = subprocess.Popen(launcher + [str(binary), '--display-driver', 'x11', '--', '--soak', '--trace-input',
                                    f'--quit-after={duration}', f'--telemetry={telemetry}'],
                                   cwd='/tmp', stdout=output, stderr=subprocess.STDOUT)
            report['pid'] = app.pid
            print(json.dumps({'status': 'started', 'pid': app.pid, 'evidence_directory': str(evidence)}), flush=True)
            while app.poll() is None:
                now = time.monotonic()
                elapsed = now - started
                rss = None
                try:
                    proc_status = Path(f'/proc/{app.pid}/status').read_text()
                    rss = next(int(line.split()[1]) for line in proc_status.splitlines() if line.startswith('VmRSS:'))
                    rss_samples.append(rss)
                    report['peak_rss_kib'] = max(report['peak_rss_kib'], rss)
                except (OSError, StopIteration):
                    pass
                try:
                    candidate = json.loads(telemetry.read_text())
                    if candidate.get('elapsed_seconds', -1) > previous_telemetry_time:
                        snapshot = candidate
                        previous_telemetry_time = snapshot['elapsed_seconds']
                        last_heartbeat = now
                        if snapshot.get('completed', 0) != last_completed:
                            last_completed = snapshot.get('completed', 0)
                            last_progress = now
                except (OSError, json.JSONDecodeError):
                    pass
                if now - last_heartbeat > 90:
                    report['failures'].append('no fresh valid application heartbeat for 90 seconds')
                if now - last_progress > 180:
                    interrupted = snapshot.get('paused') or snapshot.get('menu_open')
                    reason = 'unattended test interrupted by open menu or pause' if interrupted else 'no interaction completion progress for 180 seconds'
                    report['failures'].append(reason)
                if elapsed > duration + 180:
                    report['failures'].append('application did not exit before watchdog deadline')
                report.update(elapsed_wall_seconds=round(elapsed, 2), telemetry=snapshot)
                report['samples'] += 1
                samples.write(json.dumps({'wall_seconds': round(elapsed, 2), 'rss_kib': rss,
                                          'telemetry': snapshot}) + '\n')
                samples.flush()
                save()
                if report['failures']:
                    break
                time.sleep(5)
            if app.poll() is None:
                app.terminate()
                app.wait(timeout=10)
        try:
            snapshot = json.loads(telemetry.read_text())
        except (OSError, json.JSONDecodeError):
            pass
        elapsed = time.monotonic() - started
        report['failures'].extend(completion_failures(snapshot, app.returncode, elapsed, duration, log_path.read_text()))
        if hashlib.sha256(binary.read_bytes()).hexdigest() != digest:
            report['failures'].append('tested executable changed during the run')
        report.update(status='failed' if report['failures'] else 'passed', exit_code=app.returncode,
                      elapsed_wall_seconds=round(elapsed, 2), telemetry=snapshot,
                      finished_utc=datetime.now(timezone.utc).isoformat(),
                      final_rss_kib=rss_samples[-1] if rss_samples else None)
        report['two_hour_acceptance'] = report['status'] == 'passed' and duration >= 7200
    except BaseException as error:
        report['status'] = 'failed'
        report['failures'].append(f'{type(error).__name__}: {error}')
        raise
    finally:
        if app is not None and app.poll() is None:
            app.terminate()
            try:
                app.wait(timeout=10)
            except subprocess.TimeoutExpired:
                app.kill()
                app.wait()
        save()
        lock.close()
    print(json.dumps(report, indent=2, ensure_ascii=False), flush=True)
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
