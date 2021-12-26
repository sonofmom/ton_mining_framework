#!/usr/bin/python3
#
import pyopencl as cl
import time
import hashlib
from . import MinerWorker as MinerWorker
from Libraries.tools import account as at

class MinerProc:
    def __init__(self, platform_id, device_id, vector_size=1, vector_divider=10000):
        self.platform_id = platform_id
        self.device_id = device_id
        self.platform = cl.get_platforms()[platform_id]
        self.device = self.platform.get_devices()[device_id]
        self.vector_size = vector_size
        self.vector_divider = vector_divider

    def run(self, miner, seed, complexity):
        worker = MinerWorker.MinerWorker(self.platform, self.device, self.vector_size, self.vector_divider)
        worker.set_params(miner, seed, complexity)
        [solution, total_job, opencl_time, work_time] = worker.run()
        return {
            "work_time": work_time,
            "opencl_time": opencl_time,
            "hashes": total_job,
            "solution": solution
        }

    def benchmark(self):
        self.print_device_info()

        [miner, seed, complexity] = self.get_test_params()
        complexity = 892430197711210106497631400399040715519031159701068519104566086

        worker = MinerWorker.MinerWorker(self.platform, self.device, self.vector_size, self.vector_divider)
        worker.set_params(miner, seed, complexity)
        [solution, total_job, opencl_time, work_time] = worker.run()
        speed = (total_job / opencl_time) / 1000000000

        print("  OpenCL Time : {} s".format(opencl_time))
        print("  Hashes      : {}".format(f'{total_job:,}'))
        print("  Device Speed: {} GH/s".format(speed))
        return speed


    def test(self, depth):
        self.print_device_info()
        [miner, seed, complexity] = self.get_test_params()
        if (depth == 1):
            complexity = 3953919893334301279589334030174039261347274288845081144962207220493

        worker = MinerWorker.MinerWorker(self.platform, self.device, self.vector_size, self.vector_divider)
        worker.set_params(miner, seed, complexity)
        [solution, total_job, opencl_time, work_time] = worker.run()

        if not solution:
            print("FAILED: No solution found")
            #print(" Problem  : {}".format((8067578725043956331347821240884004561017575242515748187746557).to_bytes(32, byteorder='big').hex()))
            return None
        else:
            solution_hash = hashlib.sha256(bytearray.fromhex("00f2") + solution)
            problem = (complexity).to_bytes(32, byteorder='big')
            print(" Problem  : {}".format(problem.hex()))
            print(" Solution : {}".format(solution_hash.hexdigest()), end="")
            if (solution_hash.digest() < problem):
                print(" [OK]")
            else:
                print (" [FAILURE]")
            print(" Payload validation")
            miner = at.read_friendly_address(miner)
            data_head    = solution[:4]
            data_flags   = solution[4:5]
            data_time    = solution[5:9]
            data_time_delta= int.from_bytes(data_time, byteorder='big', signed=False) - int(time.time())
            data_time_int= int.from_bytes(data_time, byteorder='big', signed=False)
            data_miner= solution[9:41]
            data_rand1= solution[41:73]
            data_seed= solution[73:89]
            data_rand2= solution[89:121]

            print("   Header : {}".format(data_head.hex()), end=" " * 57)
            if data_head == bytearray.fromhex("4D696E65"):
                print("[OK]")
            else:
                print("[FAILURE]")

            print("   Flags  : {}".format(data_flags.hex()), end=" " * 62)
            if data_flags == (miner["workchain"] * 4 + (miner["given_type"] == "friendly_bounceable")).to_bytes(1, 'big', signed=True):
                print(" [OK]")
            else:
                print(" [FAILURE]")

            print("   Time   : {} Delta: {}".format(data_time.hex(), data_time_delta), end=" " * 45)
            if data_time_delta > 0:
                print(" [OK]")
            else:
                print(" [FAILURE]")

            print("   Miner  : {}".format(data_miner.hex()), end="")
            if data_miner == miner["bytes"]:
                print(" [OK]")
            else:
                print(" [FAILURE]")

            print("   Seed   : {}".format(data_seed.hex()), end=" " * 32)
            if data_seed == (seed).to_bytes(16, byteorder='big'):
                print(" [OK]")
            else:
                print(" [FAILURE]")

            print("   Random : {}".format(data_rand1.hex()), end="")
            if data_rand1 == data_rand2:
                print(" [OK]")
            else:
                print(" [FAILURE]")

    def print_device_info(self):
        print("Device {}/{}: {}".format(self.platform_id, self.device_id, self.device.name))

    def get_test_params(self):
        return ["0QCnq7WQyokKn9FsBitGDmuPQFwneQOIsC9I4YYSPr6YHeSD",
                229760179690128740373110445116482216837,
                213953919893334301279589334030174039261347274288845081144962207220498432]
