#!/usr/bin/env python3
#
import sys
import os
import getopt
import threading
import json
import time
import subprocess
from Classes import TonGiversProvider
from Classes import TonTargetsProvider
from Classes import GracefulKiller
from Classes import Logger
from Classes import LiteClient
from Libraries.tools import cell as ct


config      = None
bocs_sent   = 0

Logger = Logger.Logger()
GiversProvider = TonGiversProvider.TonGiversProvider(Logger)
TargetsProvider = TonTargetsProvider.TonTargetsProvider(Logger)
GracefulKiller = GracefulKiller.GracefulKiller()
LiteClient = LiteClient.LiteClient(Logger)

def parse_args(argv):
    global config, GiversProvider, TargetsProvider, Logger, LiteClient
    configfile = None
    verbose = None
    logs = True

    opts, args = getopt.getopt(argv, "hvnc:", ["config="])
    for opt, arg in opts:
        if opt == '-h':
            print_usage()
            sys.exit(0)
        elif opt == "-v":
            verbose = True
        elif opt == "-n":
            logs = False
        elif opt in ("-c", "--config"):
            configfile = arg
            if not os.access(configfile, os.R_OK):
                print("Configuration file " + configfile + " could not be opened")
                sys.exit(1)

    if not configfile:
        print_usage()
        sys.exit(1)
    else:
        configfile = open(configfile, 'r')
        config = json.loads(configfile.read())
        configfile.close()

        if not os.access(config["liteClient"]["bin"], os.X_OK):
            print("CONFIG ERROR: Lite Client " + config["liteClient"]["bin"] + " does not exist or is not executable")
            sys.exit(1)

        if config["liteClient"]["mode"] == "cert" and not os.access(config["liteClient"]["certificate"], os.R_OK):
            print("CONFIG ERROR: Lite Server certificate " + config["liteClient"]["certificate"] + " does not exist or is not readable")
            sys.exit(1)

        if config["liteClient"]["mode"] == "config" and not os.access(config["liteClient"]["config"], os.R_OK):
            print("CONFIG ERROR: Lite Server configuration " + config["liteClient"]["config"] + " does not exist or is not readable")
            sys.exit(1)

        if not os.access(config["fift"]["bin"], os.X_OK):
            print("CONFIG ERROR: Fift executable " + config["fift"]["bin"] + " does not exist or is not executable")
            sys.exit(1)

        if not os.access(config["paths"]["work_root"], os.W_OK):
            print("CONFIG ERROR: Work root path  " + config["paths"]["work_root"] + " does not exist or is not writable")
            sys.exit(1)

        if logs:
            Logger.config(config["paths"]["work_root"], verbose)
        else:
            Logger.config(None, verbose)

        GiversProvider.setup(config["giver_server"]["address"],config["giver_server"]["port"])
        GiversProvider.refresh()
        TargetsProvider.setup(config["giver_server"]["address"],config["giver_server"]["port"], config["devices"])
        TargetsProvider.refresh()
        LiteClient.setup(config["liteClient"])

    return

def print_usage():
    print('Usage:')
    print('.....')

def t_givers_poller():
    global config, GiversProvider, GracefulKiller, Logger
    Logger.log('poller', 'givers', 'info', 'Process started')
    while True:
        if GracefulKiller.kill_now:
            Logger.log('poller', 'givers', 'info', 'Terminating process')
            return

        GiversProvider.refresh()
        time.sleep(config["intervals"]["givers_poller"])


def t_targets_poller():
    global config, TargetsProvider, GracefulKiller, Logger
    Logger.log('poller', 'targets', 'info', 'Process started')
    while True:
        if GracefulKiller.kill_now:
            Logger.log('poller', 'targets', 'info', 'Terminating process')
            return

        TargetsProvider.refresh()
        time.sleep(config["intervals"]["targets_poller"])


def t_boc_uploader():
    global config, bocs_sent, GracefulKiller, Logger, LiteClient
    Logger.log('service', 'uploader', 'info', 'Process started')
    boc_path = config["paths"]["work_root"] + "/bocs"
    Logger.log('service', 'uploader', 'info', 'Bocs path: {}'.format(boc_path))
    if not os.path.exists(boc_path):
        os.mkdir(boc_path)
        os.mkdir(boc_path + "/done")
        Logger.log('service', 'uploader', 'info', 'Created bocs paths')

    while True:
        if GracefulKiller.kill_now:
            Logger.log('service', 'uploader', 'info', 'Terminating process')
            return

        for entry in os.scandir(boc_path):
            if entry.is_file():
                Logger.log('service', 'uploader', 'info', 'Processing file {}'.format(entry.name))
                [success, output] = LiteClient.exec("sendfile {}".format(entry.path))
                if (success):
                    os.rename(entry.path, "{}/done/{}".format(boc_path,entry.name))
                    bocs_sent += 1
                    Logger.log('service', 'uploader', 'info', 'Upload success')
                    #Logger.log('service', 'uploader', 'info', success)
                    #Logger.log('service', 'uploader', 'info', output)
                else:
                    Logger.log('service', 'uploader', 'warning', 'LiteClient reported no success')

        time.sleep(config["intervals"]["uploader"])

def t_device_worker(device):
    global config, GiversProvider, TargetsProvider, GracefulKiller, Logger
    device_string = '{}/{}'.format(device["params"]["platform"], device["params"]["device"])
    boc_path = config["paths"]["work_root"] + "/bocs"

    giver = None
    target = None
    process_exe = None
    start_time = None

    Logger.log('worker', device_string, 'info', 'Process started')
    while True:
        if GracefulKiller.kill_now:
            Logger.log('worker', device_string, 'info', 'Terminating process')
            if process_exe and process_exe.poll() is None:
                process_exe.terminate()

            return

        if not giver:
            giver = GiversProvider.get_by_params(device["giver"])
            Logger.log('worker', device_string, 'info', 'New giver: {}'.format(giver["address"]))

        if not target:
            target = TargetsProvider.get_target(device["worker_id"])
            Logger.log('worker', device_string, 'info', 'Target: {}'.format(target))

        if not target or not giver:
            Logger.log('worker', device_string, 'info', 'Empty target or giver, will not proceed for now')
            time.sleep(config["intervals"]["worker_loop"])
            continue

        if not process_exe:
            args = [
                os.path.dirname(os.path.abspath(__file__)) + "/" + device["params"]["bin"],
                "--platform",
                str(device["params"]["platform"]),
                "--device",
                str(device["params"]["device"]),
                "--vectors",
                str(device["params"]["vectors"]),
                "--vdiv",
                str(device["params"]["vdiv"]),
                "--miner",
                target,
                "--seed",
                str(giver["seed"]),
                "--complexity",
                str(giver["check"])
            ]

            start_time = time.time()
            process_exe = subprocess.Popen(args,
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT)

        if process_exe and process_exe.poll() is None and GiversProvider.check_changed(giver):
            Logger.log('worker', device_string, 'info', 'Giver params changed, terminating process after {:d} seconds.'.format(round(time.time() - start_time)))
            process_exe.terminate()
            time.sleep(2)
            process_exe = None
            giver = None
            target = None

        if process_exe and process_exe.poll() is not None:
            runtime = round(time.time() - start_time)
            out, err = process_exe.communicate()

            result = None
            if out:
                out = out.decode("utf-8")
                try:
                    result = json.loads(out)
                    if result:
                        speed = (result["hashes"] / result["opencl_time"]) / 1000000000
                        if result["solution"]:
                            Logger.log('worker', device_string, 'info',
                                       'Solution found after {} seconds. Speed: {:.2f} GH/s'.format(runtime, speed))
                            ct.mk_solution_boc(giver["address"], result["solution"],
                                               "{}/{}_mined.boc".format(boc_path, time.time()))
                        else:
                            Logger.log('worker', device_string, 'info',
                                       'Terminated without result after {} seconds. Speed: {:.2f} GH/s'.format(runtime,
                                                                                                               speed))
                    else:
                        Logger.log('worker', device_string, 'alert',
                                   'Returned nothing after {} seconds.'.format(runtime))
                except ValueError as e:
                    Logger.log('worker', device_string, 'alert',
                               'Exited with error \'{}\' after {} seconds.'.format(out.strip(),runtime))
            else:
                Logger.log('worker', device_string, 'alert', 'Returned nothing after {} seconds.'.format(runtime))

            process_exe = None
            giver = None
            target = None

        time.sleep(config["intervals"]["worker_loop"])

def run():
    global bocs_sent, config, GiversProvider, GracefulKiller, Logger

    print('=' * 80)
    print('MINING')
    print('=' * 80)
    Logger.log('main', 'run', 'info', 'Mining process started')
    print('Bootstrap:')
    print('   Starting givers poller.')
    t_gp = threading.Thread(target=t_givers_poller, args=())
    t_gp.start()
    print('   Starting targets poller.')
    t_tp = threading.Thread(target=t_targets_poller, args=())
    t_tp.start()
    print('   Starting boc uploader.')
    t_bup = threading.Thread(target=t_boc_uploader, args=())
    t_bup.start()
    print('   Starting device workers: ', end="")

    device_workers = []
    for idx in range(len(config["devices"])):
        print('{}/{}'.format(config["devices"][idx]["params"]["platform"], config["devices"][idx]["params"]["device"]), end=" ")
        th = threading.Thread(target=t_device_worker, args=(config["devices"][idx],))
        th.start()
        device_workers.append(th)


    print('')


    start_time = time.time()
    while 1:
        if GracefulKiller.kill_now:
            print("Exiting")
            Logger.log('main', 'run', 'info', 'Terminating main loop')
            sys.exit(0)

        if not t_gp.is_alive():
            Logger.log('main', 'run', 'warning', 'Restarting givers poller')
            t_gp = threading.Thread(target=t_givers_poller, args=())
            t_gp.start()

        if not t_tp.is_alive():
            Logger.log('main', 'run', 'warning', 'Restarting targets poller')
            t_tp = threading.Thread(target=t_targets_poller, args=())
            t_tp.start()

        if not t_tp.is_alive():
            Logger.log('main', 'run', 'warning', 'Restarting boc uploader')
            t_bup = threading.Thread(target=t_boc_uploader, args=())
            t_bup.start()

        for idx in range(len(config["devices"])):
            if not device_workers[idx].is_alive():
                Logger.log('main', 'run', 'warning', 'Restarting device {}/{} worker'.format(config["devices"][idx]["params"]["platform"], config["devices"][idx]["params"]["device"]))
                device_workers[idx] = threading.Thread(target=t_device_worker, args=(config["devices"][idx],))
                device_workers[idx].start()

        elapsed = time.time() - start_time
        days, rem = divmod(elapsed, 86400)
        hours, rem = divmod(rem, 3600)
        minutes, seconds = divmod(rem, 60)
        print(" Running for {:0>2} Days, {:0>2}:{:0>2}:{:0>2} with {} successes".format(int(days), int(hours), int(minutes), int(seconds), bocs_sent), end="\r")

        time.sleep(config["intervals"]["main_loop"])

    sys.exit(0)
    #start_time = time.time()

    #ct.mk_solution_boc(
    #                "kf-3WdBalMoDfke_izzGTOSqluRuktUIfRw6BmMN3YGCOVHF",
    #                "4D696E6500613C92E6BAE6FD9629F7A35AA1E02EF2A7017936BE41F9083CAA986A724EB2CA895BCC91B642780A9ECA0EE986A67A801F8FD9B16E7BC9B8D8A9BFDEA3852AEF3203E39EACDA33755876665780BAE9BE8A4D6385B642780A9ECA0EE986A67A801F8FD9B16E7BC9B8D8A9BFDEA3852AEF3203E39E",
    #                "/tmp/play_boc.boc"
    #                )

    threads = []
    for i in range(1):
        t = threading.Thread(target=thr, args=(args,))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    #elapsed_time = time.time() - start_time
    #print("Total Runtime: {} seconds".format(elapsed_time))

if __name__ == '__main__':
    #print('TON OpenCL Miner by SwissCops')
    #print('=' * 80)
    parse_args(sys.argv[1:])
    run()
