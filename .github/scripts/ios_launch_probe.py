#!/usr/bin/env python3
"""Catch a stalled WebKit WebContent launch in the iOS simulator in the act
(#469), and record what the processes on its launch path are doing.

Streams two kinds of line from the simulator's log:
  * runningboardd's "Executing launch request" / "Now tracking process" for
    com.apple.WebKit.WebContent jobs, which open and close a launch;
  * the harness's own "Starting login" / "-> authResult" / "-> RERUN" lines
    from the Runner process, which open and close a login.

When a launch has been pending for STALL_AFTER seconds (and again at
STALL_AGAIN), it writes a probe: per-thread `ps -M` state and a short
`sample` (macOS's call-stack sampler) of each process on the launch path --
the app, SafariViewService, runningboardd, launchd_sim, xpcproxy_sim -- and
the simulator's launchd view of WebContent jobs. A control probe of the same
processes is taken once during a healthy login, so the two can be compared.

Usage: ios_launch_probe.py <simulator udid> <output dir>
Runs until killed.
"""

import os
import re
import subprocess
import sys
import threading
import time

STALL_AFTER = 10
STALL_AGAIN = 40
MAX_STALL_PROBES = 4
SAMPLE_SECONDS = 3
CONTROL_LOGIN = 5  # the Nth login gets the control probe, if healthy
CONTROL_AFTER = 1.5  # seconds into that login, once no launch is pending

PREDICATE = (
    '(process == "runningboardd" AND eventMessage CONTAINS '
    '"com.apple.WebKit.WebContent" AND (eventMessage CONTAINS '
    '"Executing launch request" OR eventMessage CONTAINS '
    '"Now tracking process")) OR (process == "Runner" AND (eventMessage '
    'CONTAINS "Starting login" OR eventMessage CONTAINS "-> authResult" OR '
    'eventMessage CONTAINS "-> RERUN"))'
)

# Matched against the full command path; the app is the only "Runner.app".
WATCH = {
    'Runner': re.compile(r'/Runner\.app/Runner$'),
    'SafariViewService': re.compile(r'/SafariViewService$'),
    'runningboardd': re.compile(r'RuntimeRoot/.*/runningboardd$'),
    'launchd_sim': re.compile(r'/launchd_sim$'),
    'xpcproxy_sim': re.compile(r'(^|/)xpcproxy_sim$'),
    'WebContent': re.compile(r'com\.apple\.WebKit\.WebContent$'),
}

udid, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(out_dir, exist_ok=True)
lock = threading.Lock()
pending = {}  # launch uuid -> monotonic start
probed = {}  # launch uuid -> set of thresholds already probed
state = {'logins': 0, 'login_start': None, 'stall_probes': 0,
         'control_done': False}


def log(msg):
    with open(os.path.join(out_dir, 'probe-events.log'), 'a') as f:
        f.write(f'{time.strftime("%H:%M:%S", time.gmtime())} {msg}\n')


def run(cmd, timeout=20):
    try:
        return subprocess.run(cmd, capture_output=True, text=True,
                              timeout=timeout).stdout
    except (subprocess.SubprocessError, OSError) as e:
        return f'({cmd[0]} failed: {e})\n'


def pids():
    found = {}
    for line in run(['ps', '-Ao', 'pid=,pcpu=,state=,comm=']).splitlines():
        parts = line.split(None, 3)
        if len(parts) < 4:
            continue
        for name, rx in WATCH.items():
            if rx.search(parts[3]):
                found.setdefault(name, []).append((parts[0], parts[1], parts[2]))
    return found


def probe(label):
    stamp = time.strftime('%H%M%S', time.gmtime())
    base = os.path.join(out_dir, f'probe-{stamp}-{label}')
    found = pids()
    with open(base + '-ps.log', 'w') as f:
        f.write(f'probe {label} at {stamp} UTC\n')
        f.write(run(['sysctl', '-n', 'vm.loadavg']))
        for name, rows in found.items():
            for pid, cpu, st in rows:
                f.write(f'\n=== {name} pid={pid} %cpu={cpu} state={st}\n')
                f.write(run(['ps', '-M', '-p', pid]))
        f.write('\n=== simulator launchctl list (WebKit/Safari)\n')
        f.write(''.join(
            l + '\n' for l in run(
                ['xcrun', 'simctl', 'spawn', udid, 'launchctl', 'list']
            ).splitlines() if re.search('WebKit|Safari|xpc', l)))
    # Sample in parallel so every stack is from the same few seconds.
    procs = []
    for name in ('Runner', 'SafariViewService', 'runningboardd',
                 'launchd_sim', 'xpcproxy_sim', 'WebContent'):
        for pid, _, _ in found.get(name, [])[:3]:
            procs.append(subprocess.Popen(
                ['sample', pid, str(SAMPLE_SECONDS), '-mayDie', '-file',
                 f'{base}-sample-{name}-{pid}.log'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    for p in procs:
        try:
            p.wait(timeout=SAMPLE_SECONDS + 30)
        except subprocess.TimeoutExpired:
            p.kill()
    log(f'probe {label} written: {os.path.basename(base)} '
        f'({len(procs)} samples; '
        + ', '.join(f'{n}={[r[1] for r in rows]}' for n, rows in found.items())
        + ')')


def watcher():
    while True:
        time.sleep(1)
        now = time.monotonic()
        todo = None
        with lock:
            for uuid, start in pending.items():
                age = now - start
                done = probed.setdefault(uuid, set())
                for threshold in (STALL_AFTER, STALL_AGAIN):
                    if (age >= threshold and threshold not in done
                            and state['stall_probes'] < MAX_STALL_PROBES):
                        done.add(threshold)
                        state['stall_probes'] += 1
                        todo = f'stall{threshold}s-{uuid[:8]}'
                        break
                if todo:
                    break
            if (todo is None and not state['control_done']
                    and state['logins'] >= CONTROL_LOGIN
                    and state['login_start'] is not None
                    and now - state['login_start'] >= CONTROL_AFTER
                    and not pending):
                state['control_done'] = True
                todo = 'control'
        if todo:
            probe(todo)


threading.Thread(target=watcher, daemon=True).start()
stream = subprocess.Popen(
    ['xcrun', 'simctl', 'spawn', udid, 'log', 'stream', '--style', 'compact',
     '--predicate', PREDICATE],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
for line in stream.stdout:
    m = re.search(r'\[uuid:([0-9A-F-]{36})\]', line)
    with lock:
        if 'Starting login' in line:
            state['logins'] += 1
            state['login_start'] = time.monotonic()
        elif '-> authResult' in line or '-> RERUN' in line:
            state['login_start'] = None
        elif m and 'Executing launch request' in line:
            pending[m.group(1)] = time.monotonic()
        elif m and 'Now tracking process' in line and m.group(1) in pending:
            age = time.monotonic() - pending.pop(m.group(1))
            if age >= STALL_AFTER:
                log(f'launch {m.group(1)[:8]} resolved after {age:.1f}s')
