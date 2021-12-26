import requests
import random
import os

class TonTargetsProvider:
    def __init__(self, logger):
        self.logger = logger
        self.server_address = None
        self.server_port = None
        self.workers = {}

    def setup(self, server_address, server_port, devices):
        self.server_address = server_address
        self.server_port = server_port
        self.logger.log('poller', 'targets', 'info', 'Data source: {}:{}'.format(self.server_address, self.server_port))
        for device in devices:
            self.workers[device["worker_id"]] = None
        self.logger.log('poller', 'targets', 'info', 'Polling targets: {}'.format(", ".join(self.workers.keys())))

        #self.wallets_path = workpath + "/wallets"
        #self.logger.log('poller', 'targets', 'info', 'Wallets path: {}'.format(self.wallets_path))
        #if not os.path.exists(self.wallets_path):
        #    os.mkdir(self.wallets_path)
        #    os.mkdir(self.wallets_path + "/empty")
        #    os.mkdir(self.wallets_path + "/full")
        #    self.logger.log('poller', 'targets', 'info', 'Created wallets path')

    def refresh(self):
        for worker in self.workers.keys():
            response = None
            try:
                response = requests.get("http://{}:{}/targets/{}".format(self.server_address,
                                                                         self.server_port,
                                                                         worker))

            except requests.exceptions.RequestException as e:
                self.logger.log('poller', 'targets', 'alert',
                                'Failure to fetch from data source: {}:{}'.format(self.server_address,
                                                                                  self.server_port))
                print("Error while connecting to targets server: {}".format(e))

            if response.ok:
                data = response.json()
                self.workers[worker] = data[random.randrange(len(data))]

    def get_target(self, worker_id):
        return self.workers[worker_id]


# end class
