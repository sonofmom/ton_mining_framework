#!/usr/bin/python3
import pyopencl as cl

class OpenCLInfo:
    platforms =[]
    def __init__(self):
        self.platforms = cl.get_platforms()

    def print(self, verbosity):
        print('=' * 80)
        print('OpenCL Information')
        print('=' * 80)
        for pi,platform in enumerate(self.platforms):
            if verbosity == "full":
                print('Platform {}: {} / {} / {} / {}'.format(pi,platform.name,platform.vendor,platform.version,platform.profile))
            else:
                print('Platform {}: {}'.format(pi,platform.name))
            print('-' * 80)

            for di,device in enumerate(platform.get_devices()):
                print('  Device {}: {}'.format(di,device.name))
                if verbosity == "full":
                    print('    Type:                  {}'.format(cl.device_type.to_string(device.type)))
                    print('    Max Clock Speed:       {} Mhz'.format(device.max_clock_frequency))
                    print('    Max Compute Units:     {}'.format(device.max_compute_units))
                    print('    Local Memory:          {0:.0f} KB'.format(device.local_mem_size / 1024))
                    print('    Constant Memory:       {0:.0f} KB'.format(device.max_constant_buffer_size / 1024.0))
                    print('    Global Memory:         {0:.0f} MB'.format(device.global_mem_size / (1024*1024)))
                    print('    Max Alloc Size:        {0:.0f} MB'.format(device.max_mem_alloc_size / (1024*1024)))
                    print('    Max Work Group Size:   {0:.0f}'.format(device.max_work_group_size))
                    print('')

    def get_platforms(self):
        return self.platforms

    def get_devices(self, platform_id):
        return self.platforms[platform_id].get_devices()
