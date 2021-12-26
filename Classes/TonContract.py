import re
import time


class TonContract:
    def __init__(self, lite_client, contract_type, address):
        self.lc = lite_client
        self.type = contract_type
        self.address = address
        self.value = None
        self.params = {
            "pow": {
                "seed": None,
                "complexity": None,
                "iterations": None,
                "refreshed": None
            }
        }

    def get_value_grams(self):
        if self.value is None:
            return None
        else:
            return int(self.value) / 10 ** 9

    def get_shortname(self):
        return self.address[0:8]

    def get_pow_string(self):
        if self.params["pow"]["seed"]:
            return "{} {} {}".format(
                self.params["pow"]["seed"],
                self.params["pow"]["complexity"],
                self.params["pow"]["iterations"]
            )
        else:
            return None


    def get_array(self):
        return {
            "address": self.address,
            "pow_string": self.get_pow_string(),
            "complexity": self.get_pow_complexity(),
            "refreshed": self.params["pow"]["refreshed"]
        }

    def get_pow_complexity(self):
        if self.params["pow"]["complexity"]:
            return (2 ** 256) / self.params["pow"]["complexity"]
        else:
            return None

    def refresh_all(self):
        self.refresh_value()
        if self.type == "powGiver":
            self.refresh_params_pow()

    def refresh_value(self):
        [success, output] = self.lc.exec("getaccount {}".format(self.address))
        self.value = self.lc.parse_output(output, ["balance","grams","value"])

    def refresh_params_pow(self):
        [success, output] = self.lc.exec("runmethod {} get_pow_params".format(self.address))
        if output:
            output = self.lc.parse_output(output, "result")
            if output:
                output = re.match(r'^\s+?\[\s*(.+) ]', output, re.M | re.I)
                if output:
                    output = output[1].split()
                    if self.params["pow"]["seed"] != int(output[0]):
                        self.params["pow"]["seed"] = int(output[0])
                        self.params["pow"]["complexity"] = int(output[1])
                        self.params["pow"]["iterations"] = int(output[2])
                        self.params["pow"]["refreshed"] = int(time.time())

    # end define
# end class
