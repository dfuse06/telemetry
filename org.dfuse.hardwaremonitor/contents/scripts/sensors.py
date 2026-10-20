#!/usr/bin/env python3
"""Read local Linux hardware metrics for the Telemetry Plasma widget."""
import glob
import json
import os
import subprocess


def read(path):
    try:
        with open(path, encoding='utf-8') as f:
            return f.read().strip()
    except (OSError, ValueError):
        return None


def number(path):
    try:
        return int(read(path))
    except (TypeError, ValueError):
        return None


def temp(chip):
    for hw in glob.glob('/sys/class/hwmon/hwmon*'):
        if read(hw + '/name') != chip:
            continue
        labels = glob.glob(hw + '/temp*_label')
        if chip == 'k10temp':
            for label in labels:
                if read(label) == 'Tctl':
                    v = number(label.replace('_label', '_input'))
                    if v is not None:
                        return round(v / 1000 * 1.8 + 32, 1)
        for inp in sorted(glob.glob(hw + '/temp*_input')):
            v = number(inp)
            if v is not None:
                return round(v / 1000 * 1.8 + 32, 1)
    return None


def cpu():
    line = (read('/proc/stat') or '').splitlines()
    try:
        vals = [int(x) for x in line[0].split()[1:9]]
        return [sum(vals), vals[3] + vals[4]]
    except (IndexError, ValueError):
        return [0, 0]


def mem():
    d = {}
    for line in (read('/proc/meminfo') or '').splitlines():
        k, _, v = line.partition(':')
        try:
            d[k] = int(v.strip().split()[0])
        except (ValueError, IndexError):
            pass
    total = d.get('MemTotal', 0)
    return round((total - d.get('MemAvailable', 0)) / total * 100) if total else 0


def disk():
    s = os.statvfs('/')
    total = s.f_blocks * s.f_frsize
    avail = s.f_bavail * s.f_frsize
    return round((total - avail) / total * 100) if total else 0


def gpu():
    result = {'gpuName': 'GPU', 'gpuTemp': None, 'gpuLoad': None,
              'vramPercent': None, 'vramUsedGiB': None, 'vramTotalGiB': None}
    # DRM exposes AMD metrics directly, with no third-party binaries required.
    for card in sorted(glob.glob('/sys/class/drm/card[0-9]*')):
        dev = card + '/device'
        vendor = read(dev + '/vendor')
        if vendor not in ('0x1002', '0x8086', '0x10de'):
            continue
        result['gpuName'] = {'0x1002': 'AMD GPU', '0x8086': 'Intel GPU',
                             '0x10de': 'NVIDIA GPU'}[vendor]
        uevent = read(dev + '/uevent') or ''
        for line in uevent.splitlines():
            if line.startswith('DRIVER='):
                result['gpuName'] += ' (' + line.split('=', 1)[1] + ')'
        result['gpuLoad'] = number(dev + '/gpu_busy_percent')
        used = number(dev + '/mem_info_vram_used')
        total = number(dev + '/mem_info_vram_total')
        if used is not None and total and total > 0:
            result['vramPercent'] = round(used / total * 100)
            result['vramUsedGiB'] = round(used / (1024 ** 3), 2)
            result['vramTotalGiB'] = round(total / (1024 ** 3), 2)
        for hw in sorted(glob.glob(dev + '/hwmon/hwmon*')):
            for inp in sorted(glob.glob(hw + '/temp*_input')):
                v = number(inp)
                if v is not None:
                    result['gpuTemp'] = round(v / 1000 * 1.8 + 32, 1)
                    break
            if result['gpuTemp'] is not None:
                break
        # Prefer a discrete GPU with exposed usage counters over an iGPU.
        if result['gpuLoad'] is not None:
            break
    # NVIDIA proprietary driver commonly exposes these through nvidia-smi.
    try:
        p = subprocess.run(['nvidia-smi', '--query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total',
                            '--format=csv,noheader,nounits'], capture_output=True, text=True, timeout=1.5)
        if p.returncode == 0 and p.stdout.strip():
            fields = [x.strip() for x in p.stdout.splitlines()[0].split(',')]
            if len(fields) == 5:
                name, t, load, used, total = fields
                result['gpuName'] = name
                result['gpuTemp'] = round(float(t) * 1.8 + 32, 1) if t.isdigit() else None
                result['gpuLoad'] = int(load) if load.isdigit() else None
                if used.isdigit() and total.isdigit() and int(total) > 0:
                    result['vramPercent'] = round(int(used) / int(total) * 100)
                    result['vramUsedGiB'] = round(int(used) / 1024, 2)
                    result['vramTotalGiB'] = round(int(total) / 1024, 2)
    except (OSError, subprocess.TimeoutExpired, ValueError):
        pass
    return result


def cpu_name():
    for line in (read('/proc/cpuinfo') or '').splitlines():
        if line.startswith('model name'):
            return line.partition(':')[2].strip()
    return 'CPU'


result = {'cpuTemp': temp('k10temp'), 'cpuCounters': cpu(), 'ram': mem(),
          'disk': disk(), 'cpuName': cpu_name(),
          'frequency': round(float(read('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq') or 0) / 1e6, 2)}
result.update(gpu())
print(json.dumps(result))
