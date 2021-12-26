#!/usr/bin/env python3
#
import sys
import os
import getopt
import json
import threading
import time
import Classes.LiteClient as LiteClient
import Classes.TonGiverCollection as TonGiverCollection
from flask import (
    Flask,
    jsonify,
    make_response
)

# Globals
#
config = None
lc = None
tc = None


def init(argv):
    configfile = None
    global config, lc, tc
    # Process input parameters
    opts, args = getopt.getopt(argv, "hc:", ["config="])
    for opt, arg in opts:
        if opt == '-h':
            print_usage()
            sys.exit(0)
        elif opt in ("-c", "--config"):
            configfile = arg
            if not os.access(configfile, os.R_OK):
                print("Configuration file " + configfile + " could not be opened")
                sys.exit(1)
    # end for

    if not configfile:
        print_usage()
        sys.exit(1)

    configfile = open(configfile, 'r')
    config = json.loads(configfile.read())
    configfile.close()
    lc = LiteClient.LiteClient(None)
    lc.setup(config["liteClient"])
    tc = TonGiverCollection.TonGiverCollection(lc, config["powContracts"])

# Create the application instance
app = Flask(__name__)

# Create a URL route in our application for "/"
@app.route('/')
def home():
    global tc
    return "Ready to serve {} givers".format(len(tc.members))


@app.route('/giver/<address>')
def giver(address):
    global tc
    i = next((index for (index, d) in enumerate(tc.members) if d.address == address), None)

    if i is not None:
        return jsonify(tc.members[i].get_array())
    else:
        return make_response(jsonify("Not found"), 404)


@app.route('/givers/<qty>/<sorting>')
def givers_lowest(qty,sorting):
    global tc
    result = []
    for giver in tc.members:
        result.append(giver.get_array())

    if sorting == "desc":
        reverse = True
    else:
        reverse = False

    result.sort(key=lambda contract: contract["complexity"], reverse=reverse)
    return jsonify(result[0:int(qty)])

@app.route('/targets/<miner>')
def targets(miner):
    global tc
    global config

    if not miner in config["targets"]:
        miner = "default"

    return jsonify(config["targets"][miner])

def check_thread_alive(thr):
    thr.join(timeout=0.0)
    return thr.is_alive()


def poller(tc, interval):
    while 1:
        tc.refresh("/tmp/givers.log")
        time.sleep(interval/1000)


def poller_controller(tc, interval):
    poller_thread = threading.Thread(target=poller, args=(tc,interval))
    poller_thread.start()
    while 1:
        if not check_thread_alive(poller_thread):
            print("Thread restart")
            poller_thread = threading.Thread(target=poller, args=(tc, interval))
            poller_thread.start()

        time.sleep(1)


def server():
    global config, lc, tc
    app.run(host=config["server"]["address"], port=config["server"]["port"])


def print_usage():
    print('Usage: ')
    print('server.py --config <configfile>')


if __name__ == '__main__':
    init(sys.argv[1:])
    poller_controller = threading.Thread(target=poller_controller, args=(tc,config["poller"]["interval"]))
    poller_controller.start()
    server()
