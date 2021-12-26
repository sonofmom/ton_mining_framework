#!/usr/bin/env python3
#
import sys
import os
import getopt
import json
import subprocess
import time
import threading
from Classes import GracefulKiller
import numpy as np
import re

GracefulKiller = GracefulKiller.GracefulKiller()

stats = {
    'run_time': 0,
    'runs': 0,
    'hits': 0,
    'hashes': 0,
    'speed': 0
}

run_args = {
    'engine': None,
    'exec': None,
    'platform': None,
    'device': None,
    'threads': None,
    'time': None,
    'vectors': None,
    'vdiv': None,
    'complexity': None,
    'miner': None,
    'giver': None
}


def parse_args(argv):
    global run_args

    opts, args = getopt.getopt(argv, "h", ["engine=", "exec=", "platform=", "device=", "threads=", "time=", "vectors=", "vdiv=", "miner=", "giver=", "complexity="])
    for opt, arg in opts:
        if opt == '-h':
            print_usage()
            sys.exit(0)
        elif opt in ("--engine"):
            if arg in ("cuda", "opencl", "cpu"):
                run_args['engine'] = arg
            else:
                print("ERROR: Engine must be one of: cuda, opencl or cpu")
                sys.exit(1)
        elif opt in ("--exec"):
            if arg:
                run_args['exec'] = arg
        elif opt in ("--platform"):
            if arg:
                run_args['platform'] = int(arg)
        elif opt in ("--device"):
            if arg:
                run_args['device'] = int(arg)
        elif opt in ("--threads"):
            if arg:
                run_args['threads'] = int(arg)
        elif opt in ("--time"):
            if arg:
                run_args['time'] = int(arg)
        elif opt in ("--vectors"):
            if arg:
                run_args['vectors'] = int(arg)
        elif opt in ("--vdiv"):
            if arg:
                run_args['vdiv'] = int(arg)
        elif opt in ("--miner"):
            if arg:
                run_args['miner'] = arg
        elif opt in ("--giver"):
            if arg:
                run_args['giver'] = arg
        elif opt in ("--complexity"):
            if arg:
                run_args['complexity'] = int(arg)

    if run_args['engine'] is None:
        print("ERROR: --engine parameter is mandatory and must be one of: cuda, opencl or cpu.")
        sys.exit(1)

    if not run_args['exec'] or not os.access(run_args['exec'], os.X_OK):
        print("ERROR: Parameter --exec is mandatory and must point to executable!")
        sys.exit(1)

    if run_args['engine'] in ("cuda","cpu") and (run_args['time'] is None or run_args['threads'] is None):
        print("ERROR: --time and --threads parameters are mandatory for {} engine!".format(run_args['engine']))
        sys.exit(1)

    if run_args['engine'] in ("cuda","opencl") and run_args['device'] is None:
        print("ERROR: --device parameter is mandatory for {} engine!".format(run_args['engine']))
        sys.exit(1)

    if run_args['engine'] == "opencl" and (run_args['platform'] is None
                                               or run_args['device'] is None
                                               or run_args['vectors'] is None
                                               or run_args['vdiv'] is None):
        print("ERROR: --platform, --device, --vectors and --vdiv parameters are mandatory for {} engine!".format(run_args['engine']))
        sys.exit(1)

    if  run_args['miner'] is None \
        or run_args['giver'] is None \
        or run_args['complexity'] is None:
        print("ERROR: --miner, --giver and --complexity parameters are mandatory!")
        sys.exit(1)

    return

def print_usage():
    print('Usage:')
    print('.....')

def get_random_seed():
    return int.from_bytes(np.random.bytes(16), byteorder='big', signed=False)


def t_runner_cpu():
    global run_args, stats, GracefulKiller
    target_file = "/tmp/cpu_solved.boc"
    start_time = None

    mp = None
    while True:
        if GracefulKiller.kill_now:
            if mp and mp.poll() == None:
                mp.terminate()

            return

        if not mp:
            seed = get_random_seed()
            args = [
                run_args['exec'],
                "-vv",
                "-w" + str(run_args['threads']),
                "-t" + str(run_args['time']),
                run_args['miner'],
                str(seed),
                str(run_args['complexity']),
                str(100000000000),
                str(run_args['giver']),
                target_file
            ]

            mp = subprocess.Popen(args,
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT)
            start_time = time.time()

        if mp.poll() is not None:
            stats["runs"] += 1
            stats["run_time"] += time.time() - start_time
            if os.access(target_file, os.W_OK):
                stats["hits"] += 1
                os.unlink(target_file)

            [out, err] = mp.communicate()
            out = out.decode("utf-8")
            #print("\n{}".format(out))

            hashes = re.match(r'.+hashes computed: (\d+).+', out, re.MULTILINE | re.DOTALL)
            if hashes:
                stats["hashes"] += int(hashes[1])

            speed = re.match(r'.+speed: (.+) hps.+', out, re.MULTILINE | re.DOTALL)
            if speed:
                stats["speed"] += float(speed[1])

            mp = None

        time.sleep(1)

def t_runner_cuda():
    global run_args, stats, GracefulKiller
    target_file = "/tmp/cuda_solved.boc"
    start_time = None

    mp = None
    while True:
        if GracefulKiller.kill_now:
            if mp and mp.poll() == None:
                mp.terminate()

            return

        if not mp:
            seed = get_random_seed()
            args = [
                run_args['exec'],
                "-vv",
                "-G" + str(run_args['threads']),
                "-g" + str(run_args['device']),
                "-t" + str(run_args['time']),
                run_args['miner'],
                str(seed),
                str(run_args['complexity']),
                str(100000000000),
                str(run_args['giver']),
                target_file
            ]

            mp = subprocess.Popen(args,
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT)
            start_time = time.time()

        if mp.poll() is not None:
            stats["runs"] += 1
            stats["run_time"] += time.time() - start_time
            if os.access(target_file, os.W_OK):
                stats["hits"] += 1
                os.unlink(target_file)

            [out, err] = mp.communicate()
            out = out.decode("utf-8")
            #print("\n{}".format(out))

            hashes = re.match(r'.+hashes computed: (\d+).+', out, re.MULTILINE | re.DOTALL)
            if hashes:
                stats["hashes"] += int(hashes[1])

            speed = re.match(r'.+speed: (.+) hps.+', out, re.MULTILINE | re.DOTALL)
            if speed:
                stats["speed"] += float(speed[1])

            mp = None

        time.sleep(1)


def t_runner_opencl():
    global run_args, stats, GracefulKiller
    start_time = None

    mp = None
    while True:
        if GracefulKiller.kill_now:
            if mp and mp.poll() == None:
                mp.terminate()

            return

        if not mp:
            seed = get_random_seed()
            args = [
                run_args['exec'],
                "--platform",
                str(run_args['platform']),
                "--device",
                str(run_args['device']),
                "--vectors",
                str(run_args['vectors']),
                "--vdiv",
                str(run_args['vdiv']),
                "--miner",
                run_args['miner'],
                "--seed",
                str(seed),
                "--complexity",
                str(run_args['complexity'])
            ]

            mp = subprocess.Popen(args,
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT)
            start_time = time.time()

        if mp.poll() is not None:
            stats["runs"] += 1
            stats["run_time"] += time.time() - start_time

            [out, err] = mp.communicate()
            out = out.decode("utf-8")
            data = json.loads(out)
            stats["hashes"] += data["hashes"]
            stats["speed"] += data["hashes"] / data["opencl_time"]
            if data["solution"]:
                #solution = bytearray.fromhex(data["solution"])
                #solution_hash = hashlib.sha256(bytearray.fromhex("00f2") + solution)
                #print("\n{}".format(solution_hash.hexdigest()))
                stats["hits"] += 1

            mp = None

        time.sleep(1)


def run():
    global stats, run_args, GracefulKiller

    print('=' * 80)
    print('EFFICIENCY BENCH')
    print('=' * 80)
    print(' Engine    : {}'.format(run_args["engine"]))
    print(' Executable: {}'.format(run_args["exec"]))
    if run_args["engine"] == "cpu":
        print(' Threads   : {}'.format(run_args["threads"]))
        print(' Time      : {}'.format(run_args["time"]))
    elif run_args["engine"] == "cuda":
        print(' Device    : {}'.format(run_args["device"]))
        print(' Threads   : {}'.format(run_args["threads"]))
        print(' Time      : {}'.format(run_args["time"]))
    elif run_args["engine"] == "opencl":
        print(' Platform  : {}'.format(run_args["platform"]))
        print(' Device    : {}'.format(run_args["device"]))
        print(' Vsize     : {}'.format(run_args["vectors"]))
        print(' Vdiv      : {}'.format(run_args["vdiv"]))

    print('')
    print(' Miner     : {}'.format(run_args["miner"]))
    print(' Complexity: {}'.format((run_args["complexity"].to_bytes(32, byteorder='big').hex())))
    print('')

    if run_args["engine"] == "cpu":
        t_meter = threading.Thread(target=t_runner_cpu, args=())
        t_meter.start()

    if run_args["engine"] == "cuda":
        t_meter = threading.Thread(target=t_runner_cuda, args=())
        t_meter.start()

    if run_args["engine"] == "opencl":
        t_meter = threading.Thread(target=t_runner_opencl, args=())
        t_meter.start()

    start_time = time.time()
    while 1:
        if GracefulKiller.kill_now:
            print("")
            sys.exit(0)

        elapsed = time.time() - start_time
        hours, rem = divmod(elapsed, 3600)
        minutes, seconds = divmod(rem, 60)

        hps = 0
        hph = 0
        hpd = 0
        hpd_g = 0
        hashrate   = 0.0
        hashrate_e = 0.0
        if stats["hashes"]:
            hashrate = (stats["hashes"] / elapsed) / 1000000000
            if stats["runs"]:
                hashrate_e = (stats["speed"] / stats["runs"]) / 1000000000

        if stats["hits"]:
            hps   = stats["hits"] / elapsed
            hph   = round(hps * 3600,2)
            hpd   = round(hps * 86400,2)
            if hpd and hashrate_e:
                hpd_g = round(hpd / hashrate_e) * 1




        print("    {:0>2}:{:0>2}:{:0>2} Runs: {} Hits: {} Crate: {:.2f} Drate: {:.2f} HpH: {} HpD: {} HpD/G: {:.2f}     ".format(int(hours), int(minutes), int(seconds), stats["runs"], stats["hits"], hashrate, hashrate_e, hph, hpd, hpd_g), end="\r")

        time.sleep(1)

if __name__ == '__main__':
    parse_args(sys.argv[1:])
    run()
