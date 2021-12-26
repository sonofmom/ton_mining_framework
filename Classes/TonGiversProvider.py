import requests
import random

class TonGiversProvider:
    def __init__(self, logger):
        self.logger = logger
        self.server_address = None
        self.server_port = None
        self.givers = []

    def setup(self, server_address, server_port):
        self.server_address = server_address
        self.server_port = server_port
        self.logger.log('poller', 'givers', 'info', 'Data source: {}:{}'.format(self.server_address, self.server_port))

    def refresh(self):
        response = None
        try:
            response = requests.get("http://{}:{}/givers/10/asc".format(self.server_address, self.server_port))
        except requests.exceptions.RequestException as e:
            self.logger.log('poller', 'givers', 'alert',
                            'Failure to fetch from data source: {}:{}'.format(self.server_address, self.server_port))
            print("Error while connecting to givers server: {}".format(e))

        if response.ok:
            new_data = []
            for record in response.json():
                params = record["pow_string"].split(' ')
                record["seed"] = int(params[0])
                record["check"] = int(params[1])
                new_data.append(record)

            self.givers = new_data

        return self

    def check_changed(self, giver):
        if giver != self.get_giver_by_address(giver["address"]):
            return True
        else:
            return False


    def get_by_params(self, params):
        if not self.givers:
            return None

        result = self.givers[params["range_start"]:params["range_end"]]
        if params["freshest"]:
            return sorted(result, key=lambda contract: contract["refreshed"], reverse=True)[0].copy()
        else:
            return result[random.randrange(len(result))].copy()

    def get_sorted_list(self, key, sorting):
        if not self.givers:
            return None

        if sorting == "desc":
            reverse = True
        else:
            reverse = False
        return sorted(self.givers, key=lambda contract: contract[key], reverse=reverse)

    def get_giver_by_address(self, address):
        if not self.givers:
            return None

        return next(giver for giver in self.givers if giver["address"] == address)

# end class
