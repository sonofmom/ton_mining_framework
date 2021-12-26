import sys
import os
import time

def get_giver_db_file(path, name):
    return path + "/" + name + ".rrd"

def check_path_writable(path):
    if os.path.exists(path) and os.path.isdir(path) and os.access(path, os.W_OK):
        return True
    else:
        return False

def check_file_exists(file):
    if os.path.exists(file) and os.path.isfile(file) and os.access(file, os.W_OK):
        return True
    else:
        return False

def get_datetime_string(timestamp=time.time()):
    return time.strftime("%d.%m.%Y %H:%M:%S", time.localtime(timestamp))

def console_log(message):
    print("{}: {}".format(get_datetime_string(time.time()), message))



