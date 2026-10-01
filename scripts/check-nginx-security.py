"""Check capability-safe logs on an isolated localhost container; no BMS access."""
import argparse
import json
import subprocess
import time
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--image', default='thip-kpi-bms:ci')
parser.add_argument('--port', type=int, default=18082)
args = parser.parse_args()
container = subprocess.check_output(['docker', 'run', '-d', '-p', f'127.0.0.1:{args.port}:8080', args.image], text=True).strip()
try:
    canaries = ['SYNTHETIC_SESSION_CANARY', 'SYNTHETIC_MARKET_CANARY', 'SYNTHETIC_REFERER_CANARY']
    request = urllib.request.Request(f'http://127.0.0.1:{args.port}/?bms-session-id={canaries[0]}&marketplace-token={canaries[1]}', headers={'Referer': f'https://synthetic.invalid/?bms-session-id={canaries[2]}'})
    for _ in range(40):
        try:
            with urllib.request.urlopen(request, timeout=2) as response:
                assert response.status == 200
            break
        except (OSError, AssertionError):
            time.sleep(.1)
    else:
        raise AssertionError('Local test container did not respond')
    logs = subprocess.check_output(['docker', 'logs', container], stderr=subprocess.STDOUT, text=True)
    assert '"GET /index.html HTTP/1.1"' in logs or '"GET / HTTP/1.1"' in logs, 'Safe request log missing'
    assert not any(canary in logs for canary in canaries), 'Synthetic credential canary leaked into logs'
    print(json.dumps({'safe_access_log': True, 'credential_canary_absent': True, 'local_container_only': True}))
finally:
    subprocess.run(['docker', 'rm', '-f', container], check=True, stdout=subprocess.DEVNULL)
