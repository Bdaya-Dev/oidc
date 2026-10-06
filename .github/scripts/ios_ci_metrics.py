#!/usr/bin/env python3
"""Summarise how loaded the iOS CI simulator host was, and how that showed up
in the browser flows (#469).

Inputs, all optional (a missing file just drops its section):
  --runner-log    `log show` output for the Runner process (the harness's
                  "flutter: " print lines).
  --launch-log    `log show` output for runningboardd launch lines.
  --host-load     host-load.log from the sampler in tests.yaml.

Everything is read AFTER the tests, from the simulator's persisted log store,
so measuring adds no load while the tests run.

Metrics:
  logins            per-module login duration, harness "Starting login" ->
                    "[e2e] <module> -> authResult". A healthy iOS login takes
                    ~3-5s; >10s is counted as delayed, >30s as a stall.
  WebContent launch runningboardd "Executing launch request" for a
                    com.apple.WebKit.WebContent job -> the first line naming
                    that job's uuid with a pid ("Now tracking process").
                    Healthy launches take ~1.5s.
  host              load average (1m), free pages, swapouts.
"""

import argparse
import re
import statistics
import sys
from datetime import datetime


def _ts(line):
    try:
        return datetime.strptime(line[:23], '%Y-%m-%d %H:%M:%S.%f')
    except ValueError:
        return None


def logins(path):
    start, name, rows = None, None, []
    for line in open(path, encoding='utf-8', errors='replace'):
        if 'flutter: ' not in line:
            continue
        ts = _ts(line)
        if ts is None:
            continue
        m = re.search(r'oidc\.conformance\.([\w-]+)\.\w+\] Starting login', line)
        if m:
            start, name = ts, m.group(1)
            continue
        m = re.search(r'\[e2e\] ([\w-]+) -> authResult', line)
        if m and start is not None and m.group(1) == name:
            rows.append(((ts - start).total_seconds(), name, start))
            start = None
    return rows


def launches(path):
    pending, rows = {}, []
    for line in open(path, encoding='utf-8', errors='replace'):
        ts = _ts(line)
        if ts is None:
            continue
        m = re.search(r'\[uuid:([0-9A-F-]{36})\]', line)
        if not m:
            continue
        uuid = m.group(1)
        if ('Executing launch request' in line
                and 'com.apple.WebKit.WebContent' in line):
            pending[uuid] = ts
        # The launched job's own lines carry "...{definition:…}:<pid>]".
        elif uuid in pending and re.search(r'[\]}]:\d+\]', line):
            rows.append(((ts - pending.pop(uuid)).total_seconds(), ts))
    return rows


def host(path):
    load, free, swap = [], [], []
    for line in open(path, encoding='utf-8', errors='replace'):
        m = re.match(r'\{ ([\d.]+) ', line)
        if m:
            load.append(float(m.group(1)))
        m = re.match(r'Pages free:\s+(\d+)', line)
        if m:
            free.append(int(m.group(1)))
        m = re.match(r'Swapouts:\s+(\d+)', line)
        if m:
            swap.append(int(m.group(1)))
    return load, free, swap


def _dist(values):
    if not values:
        return 'n=0'
    v = sorted(values)
    return (f'n={len(v)} median={statistics.median(v):.1f}s '
            f'p90={v[int(len(v) * 0.9)]:.1f}s max={v[-1]:.1f}s')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--runner-log')
    p.add_argument('--launch-log')
    p.add_argument('--host-load')
    a = p.parse_args()
    out = []
    if a.runner_log:
        try:
            rows = logins(a.runner_log)
            d = [r[0] for r in rows]
            out.append(f'logins: {_dist(d)}; >10s: {sum(x > 10 for x in d)}; '
                       f'>30s (stall): {sum(x > 30 for x in d)}')
            for secs, name, start in sorted(rows, reverse=True)[:8]:
                if secs > 10:
                    out.append(f'  {secs:6.1f}s {name} @{start:%H:%M:%S}')
        except OSError as e:
            out.append(f'logins: unreadable ({e})')
    if a.launch_log:
        try:
            rows = launches(a.launch_log)
            d = [r[0] for r in rows]
            out.append(f'WebContent launch: {_dist(d)}; >10s: '
                       f'{sum(x > 10 for x in d)}')
        except OSError as e:
            out.append(f'WebContent launch: unreadable ({e})')
    if a.host_load:
        try:
            load, free, swap = host(a.host_load)
            if load:
                out.append(
                    f'host: load1 median={statistics.median(load):.0f} '
                    f'max={max(load):.0f}; pages free median='
                    f'{statistics.median(free) if free else "?"} '
                    f'min={min(free) if free else "?"}; swapouts end='
                    f'{swap[-1] if swap else "?"}')
        except OSError as e:
            out.append(f'host: unreadable ({e})')
    print('\n'.join('[ios-metrics] ' + line for line in out))


if __name__ == '__main__':
    sys.exit(main())
