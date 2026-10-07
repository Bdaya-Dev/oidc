#!/usr/bin/env python3
"""Experiment (#469): lift the darwin background throttle off the simulator
processes on the browser's launch path.

ios_launch_probe.py found SafariViewService's threads at priority 4 (the
throttled band) and runnable, on a host whose load average sits at 200-500.
A throttled thread only runs when nothing above it wants the CPU, so on that
host a launch it has to drive can wait as long as the load lasts.

Every second this lists the processes on the launch path and, for each one
still at priority <= 4, runs `taskpolicy -B -p <pid>` (remove the background
policy from a running process) via sudo, then records the priority it ended
up at. Output: one line per action in <output dir>/unthrottle.log.

Usage: ios_unthrottle.py <output dir>
Runs until killed.
"""

import os
import re
import subprocess
import sys
import time

TARGETS = re.compile(
    r'/SafariViewService$|com\.apple\.WebKit\.[A-Za-z.]+$|(^|/)xpcproxy_sim$'
    r'|RuntimeRoot/.*/runningboardd$|launchd_sim'
)

out = open(os.path.join(sys.argv[1], 'unthrottle.log'), 'a', buffering=1)
tries = {}  # pid -> attempts, capped so a policy that will not lift is not hammered


def ps():
    try:
        text = subprocess.run(['ps', '-Ao', 'pid=,pri=,comm='],
                              capture_output=True, text=True,
                              timeout=10).stdout
    except (subprocess.SubprocessError, OSError):
        return []
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 2)
        if len(parts) == 3 and TARGETS.search(parts[2]):
            rows.append((parts[0], int(parts[1]), parts[2].rsplit('/', 1)[-1]))
    return rows


while True:
    for pid, pri, name in ps():
        if pri > 4 or tries.get(pid, 0) >= 3:
            continue
        tries[pid] = tries.get(pid, 0) + 1
        r = subprocess.run(['sudo', '-n', 'taskpolicy', '-B', '-p', pid],
                           capture_output=True, text=True)
        after = next((p for i, p, _ in ps() if i == pid), None)
        out.write(f'{time.strftime("%H:%M:%S", time.gmtime())} {name} pid={pid} '
                  f'pri {pri} -> {after} rc={r.returncode} '
                  f'{(r.stderr or r.stdout).strip()[:200]}\n')
    time.sleep(1)
