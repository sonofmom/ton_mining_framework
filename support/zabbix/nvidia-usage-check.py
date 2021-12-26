#!/usr/bin/env python3
#
import re
import subprocess

def run():
    args = [
        "/usr/bin/nvidia-smi",
        "--query-gpu=timestamp,name,pci.bus_id,utilization.gpu,power.limit,power.draw",
        "--format=csv"
    ]
    process = subprocess.run(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             timeout=20)
    output = process.stdout.decode("utf-8").splitlines()[1:]
    power_limit = 0
    power_draw = 0

    for device in output:
        device = device.split(",")
        match = re.match(r' (\d+\.\d+) W', device[4], re.M | re.I)
        power_limit += float(match[1])
        match = re.match(r' (\d+\.\d+) W', device[5], re.M | re.I)
        power_draw += float(match[1])

    print(round((power_draw / power_limit)*100))


if __name__ == '__main__':
    run()
