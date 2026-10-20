#!/usr/bin/env python3
import json, glob, os

def read(path):
    try:
        with open(path) as f: return f.read().strip()
    except (OSError, ValueError): return None

def temp(chip):
    for hw in glob.glob('/sys/class/hwmon/hwmon*'):
        name=read(hw+'/name') or ''
        if name != chip: continue
        for label in glob.glob(hw+'/temp*_label'):
            if chip=='k10temp' and read(label)!='Tctl': continue
            val=read(label.replace('_label','_input'))
            if val:
                try: return round(float(val)/1000*1.8+32,1)
                except ValueError: pass
        if chip!='k10temp':
            val=read(hw+'/temp1_input')
            if val:
                try: return round(float(val)/1000*1.8+32,1)
                except ValueError: pass
    return None

def cpu():
    line=read('/proc/stat') or ''
    vals=[int(x) for x in line.split()[1:9]] if line else []
    return [sum(vals), vals[3]+vals[4]] if len(vals)==8 else [0,0]

def mem():
    d={}
    for line in (read('/proc/meminfo') or '').splitlines():
        k,_,v=line.partition(':')
        try: d[k]=int(v.strip().split()[0])
        except (ValueError,IndexError): pass
    total=d.get('MemTotal',0); used=total-d.get('MemAvailable',0)
    return round(used/total*100) if total else 0

def disk():
    s=os.statvfs('/'); total=s.f_blocks*s.f_frsize; avail=s.f_bavail*s.f_frsize
    return round((total-avail)/total*100) if total else 0

print(json.dumps({'cpuTemp':temp('k10temp'),'gpuTemp':temp('amdgpu'),'cpuCounters':cpu(),'ram':mem(),'disk':disk(),'frequency':round(float(read('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq') or 0)/1e6,2)}))
