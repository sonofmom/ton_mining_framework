#!/usr/bin/env python3
#
import sys
import os
import getopt
from Classes import OpenCLInfo
from Classes import MinerProc as MinerProc
import json

OpenCLInfo = OpenCLInfo.OpenCLInfo()

run_args = {
    'debug': False,
    'mode': 'work',
    'platform': None,
    'devices': [],
    'vectors': None,
    'vdiv': None,
    'seed': None,
    'complexity': None,
    'miner': None,
    'verbose': False,
    'depth': 0
}

def parse_args(argv):
    global run_args

    opts, args = getopt.getopt(argv, "hdbtiv", ["platform=", "devices=", "vectors=", "vdiv=", "miner=", "seed=", "complexity=", "depth="])
    for opt, arg in opts:
        if opt == '-h':
            print_usage()
            sys.exit(0)
        elif opt == "-v":
            run_args['verbose'] = True
        elif opt == "-d":
            run_args['debug'] = True
        elif opt == "-b":
            run_args['mode'] = "benchmark"
        elif opt == "-t":
            run_args['mode'] = "test"
        elif opt in ("-i"):
            run_args['mode'] = "info"
        elif opt in ("--platform"):
            if int(arg) < len(OpenCLInfo.get_platforms()):
                run_args['platform'] = int(arg)
            else:
                print("ERROR: Platform with ID {} does not exist".format(arg))
                sys.exit(1)
        elif opt in ("--devices"):
            if arg:
                run_args['devices'] = list(map(int, arg.split(',')))
        elif opt in ("--depth"):
            if arg:
                run_args['depth'] = int(arg)
        elif opt in ("--vectors"):
            if arg:
                run_args['vectors'] = int(arg)
        elif opt in ("--vdiv"):
            if arg:
                run_args['vdiv'] = int(arg)
        elif opt in ("--miner"):
            if arg:
                run_args['miner'] = arg
        elif opt in ("--seed"):
            if arg:
                run_args['seed'] = int(arg)
        elif opt in ("--complexity"):
            if arg:
                run_args['complexity'] = int(arg)

    if run_args['mode'] == "info":
        return

    if run_args['mode'] == "work" and (not run_args["complexity"] or not run_args["seed"] or not run_args["miner"]):
        print_usage()
        sys.exit(1)

    if  run_args['platform'] is None \
        or run_args['devices'] is None \
        or run_args['vectors'] is None \
        or run_args['vdiv'] is None:
        print_usage()
        sys.exit(1)

    if len(run_args['devices']) >1:
        print("ERROR: Only one device can be specified for mining")
        sys.exit(1)

    if max(run_args['devices']) >= len(OpenCLInfo.get_devices(run_args['platform'])):
        print("ERROR: One or more of specified devices do not exist on platform {}".format(run_args['platform']))
        sys.exit(1)

    return

def print_usage():
    print('Usage:')
    print('.....')

def run():
    global run_args, GracefulKiller

    if run_args["debug"]:
        os.environ['PYOPENCL_NO_CACHE'] = '1'
        os.environ['CL_PROGRAM_BUILD_LOG'] = '1'
        os.environ['PYOPENCL_COMPILER_OUTPUT'] = '1'

    if run_args["mode"] == "info":
        OpenCLInfo.print("full")
        sys.exit(0)

    if run_args["mode"] == "benchmark":
        int32s = 4294967295
        vector_loops = int((int32s - (int32s % run_args['vdiv'])) / run_args['vdiv'])
        speed = 0
        print('=' * 80)
        print('Benchmarks [{} vectors, {} loops per vector]'.format(run_args['vectors'], vector_loops))
        print('=' * 80)
        for device in run_args["devices"]:
            miner = MinerProc.MinerProc(run_args['platform'], device, run_args['vectors'], run_args['vdiv'])
            speed += miner.benchmark()

        if (len(run_args["devices"]) > 1):
            print('-' * 80)
            print("Combined Speed: {} GH/s".format(speed))

        sys.exit(0)

    if run_args["mode"] == "test":
        int32s = 4294967295
        vector_loops = int((int32s - (int32s % run_args['vdiv'])) / run_args['vdiv'])
        print('=' * 80)
        print('Test [{} vectors, {} loops per vector]'.format(run_args['vectors'], vector_loops))
        print('=' * 80)
        for device in run_args["devices"]:
            miner = MinerProc.MinerProc(run_args['platform'], device, run_args['vectors'], run_args['vdiv'])
            miner.test(run_args["depth"])

        sys.exit(0)

    if run_args["mode"] == "work":
        miner  = MinerProc.MinerProc(run_args['platform'], run_args['devices'][0], run_args['vectors'], run_args['vdiv'])

        if run_args["verbose"]:
            int32s = 4294967295
            vector_loops = int((int32s - (int32s % run_args['vdiv'])) / run_args['vdiv'])
            print('=' * 80)
            print('Mine [{} vectors, {} loops per vector]'.format(run_args['vectors'], vector_loops))
            print('=' * 80)
            miner.print_device_info()
            print(' Miner     : {}'.format(run_args['miner']))
            print(' Seed      : {}'.format(run_args['seed']))
            print(' Complexity: {}'.format(run_args['complexity']))

        result = miner.run(run_args['miner'], run_args['seed'], run_args['complexity'])
        result["hashes"] = int(result["hashes"])
        if result["solution"]:
            result["solution"] = result["solution"].hex()

        print(json.dumps(result))
        if result["solution"]:
            sys.exit(0)
        else:
            sys.exit(1)

    sys.exit(0)

if __name__ == '__main__':
    parse_args(sys.argv[1:])
    run()
