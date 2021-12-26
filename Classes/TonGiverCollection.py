import re
import Classes.TonContract as TonContract
import Libraries.tools.general as toolbox
import time

class TonGiverCollection:
    def __init__(self, lite_client, givers):
        self.lc = lite_client
        self.members = []
        for giver in givers:
            self.members.append(TonContract.TonContract(self.lc, "powGiver", giver))

    def refresh(self, logfile=None):
        for giver in self.members:
            previous_params = giver.get_pow_string()
            previous_difficulty = giver.get_pow_complexity()
            giver.refresh_params_pow()
            if previous_params and previous_params != giver.get_pow_string() and logfile:
                with open(logfile, "a") as fo:
                    fo.write(toolbox.get_datetime_string(time.time()) + ";" + str(time.time()) + ";" + giver.get_shortname() + ";" + str(previous_difficulty) + "\n")

        return self

    def rank(self):
        self.members.sort(key=lambda contract: contract.get_pow_complexity(), reverse=False)
        return self

    # end define
# end class
