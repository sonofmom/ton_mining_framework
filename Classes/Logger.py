import os
import Libraries.tools.general as gt
import time


class Logger:
    def __init__(self):
        self.logpath = None
        self.console = True

    def config(self, workpath, console):
        self.console = console
        if workpath:
            self.logpath = workpath + "/log"

            if not os.path.exists(self.logpath):
                os.mkdir(self.logpath)

    # List of valid facilities:
    #
    # * `main`
    # * `poller`
    # * `worker`
    # * `service`
    #
    def log(self, facility, id, level, message):
        logfile = None
        if facility in ("main","poller","worker","service") and self.logpath:
            logfile = "{}/{}.log".format(self.logpath,facility)

        if self.console:
            print("{} [{}|{}]: ({}) {}".format(gt.get_datetime_string(time.time()),
                                                    facility,
                                                    id,
                                                    level,
                                                    message))
            print(message)

        if logfile:
            with open(logfile, 'a+') as fd:
                fd.write("{} {} [{}|{}|{}]: ({}) {}\n".format(int(time.time()),
                                                            gt.get_datetime_string(time.time()),
                                                            os.getpid(),
                                                            facility,
                                                            id,
                                                            level,
                                                            message))
                fd.close()
