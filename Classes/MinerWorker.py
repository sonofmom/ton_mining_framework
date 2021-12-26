#!/usr/bin/python3
#
import pyopencl as cl
import numpy as np
import os
import time
import random
from Libraries.tools import account as at

class MinerWorker:
    def __init__(self, platform, device, vector_size=1, vector_divider=1):
        self.int32s = 4294967295
        self.platform = platform
        self.device = device
        self.vector_size = vector_size
        self.vector_divider = vector_divider
        self.vector_loops = int((self.int32s - (self.int32s % vector_divider)) / vector_divider)
        if vector_size > vector_divider:
            self.vector_step = int((vector_size - (vector_size % vector_divider)) / vector_divider)
        else:
            self.vector_step = 1
        self.mf = cl.mem_flags
        self.ctx = cl.Context([self.device])
        self.queue = cl.CommandQueue(self.ctx)
        self.shainit = None
        with open(os.path.dirname(os.path.abspath(__file__)) + "/../Libraries/mining/opencl/miner_sha_init.cl", "r") as fh:
            self.shainit = cl.Program(self.ctx, fh.read()).build()

        self.cruncher = None
        with open(os.path.dirname(os.path.abspath(__file__)) + "/../Libraries/mining/opencl/miner_cruncher_g.cl", "r") as fh:
            self.cruncher = cl.Program(self.ctx, fh.read()).build()


        self.miner = None
        self.seed = None
        self.complexity = None

    def set_params(self, miner, seed, complexity):
        self.miner = at.read_friendly_address(miner)
        self.seed = seed.to_bytes(16, byteorder='big')
        self.complexity = complexity.to_bytes(32, byteorder='big')


    def array_from_bytes(self, bytes):
        step = 4
        result = []
        for i in range(int(len(bytes)/step)):
            rs = i * step
            re = (i+1) * step
            result.append(int.from_bytes(bytes[rs:re], byteorder='big', signed=False))
        return result


    def flip_bytes(self, bytes):
        step = 4
        result = b''
        for i in range(int(len(bytes)/step)):
            rs = i * step
            re = (i+1) * step
            buf = bytes[rs:re]
            result += buf[::-1]
        return result


    def run(self):
        work_start_time = time.time()

        ## Job data initialization
        ##
        data_rand = np.random.default_rng().bytes(24)

        data_head  = bytearray.fromhex("00f2")
        data_head += b'Mine'
        data_head += (self.miner["workchain"] * 4 + (self.miner["given_type"] == "friendly_bounceable")).to_bytes(1, 'big', signed=True)
        data_head += int(work_start_time+900).to_bytes(4, byteorder='big')
        data_head += self.miner["bytes"]
        data_head += data_rand
        data_head += (0).to_bytes(1, 'big')

        global_head = np.array(self.array_from_bytes(data_head), dtype=np.uint32)
        global_init_hash= np.zeros([8]).astype(np.uint32)
        global_init_w= np.zeros([1]).astype(np.uint32)

        buffer_head = cl.Buffer(self.ctx, self.mf.READ_ONLY | self.mf.COPY_HOST_PTR, hostbuf=global_head)
        buffer_init_hash = cl.Buffer(self.ctx, self.mf.WRITE_ONLY, size=global_init_hash.nbytes)
        buffer_init_w = cl.Buffer(self.ctx, self.mf.WRITE_ONLY, size=global_init_w.nbytes)

        self.shainit.init(
            self.queue,
            (1,),
            None,
            buffer_head,
            buffer_init_hash,
            buffer_init_w)

        cl.enqueue_copy(self.queue, global_init_hash, buffer_init_hash)
        cl.enqueue_copy(self.queue, global_init_w, buffer_init_w)
        self.queue.finish()

        global_init_hash = np.array(self.array_from_bytes(self.flip_bytes(global_init_hash.tobytes())), dtype=np.uint32)
        global_init_w = np.array(self.array_from_bytes(self.flip_bytes(global_init_w.tobytes())), dtype=np.uint32)

        data_prefix =np.uint32(random.randint(0, 4000000000))

        ## Globals generation
        ##
        global_head = np.array(self.array_from_bytes(data_head), dtype=np.uint32)
        global_rand = np.array(self.array_from_bytes(data_rand), dtype=np.uint32)
        global_seed = np.array(self.array_from_bytes(self.seed), dtype=np.uint32)
        global_check = np.array(self.array_from_bytes(self.complexity), dtype=np.uint32)

        global_prefix = data_prefix

        global_divider = np.array([np.uint32(self.vector_divider)])
        global_abort   = np.array([np.uint32(0)])
        global_work    = np.empty([self.vector_size]).astype(np.uint32)
        global_solution= np.zeros([14]).astype(np.uint32)

        ## Buffers creation
        ##
        buffer_init_hash = cl.Buffer(self.ctx, self.mf.READ_ONLY | self.mf.COPY_HOST_PTR, hostbuf=global_init_hash)
        buffer_init_w = cl.Buffer(self.ctx, self.mf.READ_ONLY | self.mf.COPY_HOST_PTR, hostbuf=global_init_w)
        #buffer_head = cl.Buffer(self.ctx, self.mf.READ_ONLY | self.mf.COPY_HOST_PTR, hostbuf=global_head)
        buffer_rand = cl.Buffer(self.ctx, self.mf.READ_ONLY | self.mf.COPY_HOST_PTR, hostbuf=global_rand)
        buffer_seed = cl.Buffer(self.ctx, self.mf.READ_ONLY | self.mf.COPY_HOST_PTR, hostbuf=global_seed)
        buffer_check = cl.Buffer(self.ctx, self.mf.READ_ONLY | self.mf.COPY_HOST_PTR, hostbuf=global_check)
        buffer_divider = cl.Buffer(self.ctx, self.mf.READ_ONLY | self.mf.COPY_HOST_PTR, hostbuf=global_divider)
        buffer_prefix = cl.Buffer(self.ctx, self.mf.READ_ONLY | self.mf.COPY_HOST_PTR, hostbuf=global_prefix)
        buffer_abort = cl.Buffer(self.ctx, self.mf.READ_WRITE | self.mf.COPY_HOST_PTR, hostbuf=global_abort)

        buffer_work = cl.Buffer(self.ctx, self.mf.READ_WRITE, size=global_work.nbytes)
        buffer_solution = cl.Buffer(self.ctx, self.mf.WRITE_ONLY, size=global_solution.nbytes)

        opencl_start_time = time.time()
        self.cruncher.crunch(
            self.queue,
            (self.vector_size,),
            None,
            buffer_init_hash,
            buffer_init_w,
            buffer_rand,
            buffer_seed,
            buffer_prefix,
            buffer_check,
            buffer_divider,
            buffer_abort,
            buffer_work,
            buffer_solution)

        copy_work = cl.enqueue_copy(self.queue, global_work, buffer_work, is_blocking=False)
        copy_solution = cl.enqueue_copy(self.queue, global_solution, buffer_solution, is_blocking=False)

        while copy_work.get_info(cl.event_info.COMMAND_EXECUTION_STATUS) != cl.command_execution_status.COMPLETE:
            time.sleep(0.5)

        self.queue.finish()
        opencl_time = time.time() - opencl_start_time

        total_job = global_work.sum()
        solution = self.flip_bytes(global_solution.tobytes())

        if (solution[1] != 0x00000000):
            solution = data_head[2:67] + solution
        else:
            solution = None

        work_time = time.time() - work_start_time

        return [solution, total_job, opencl_time, work_time]
