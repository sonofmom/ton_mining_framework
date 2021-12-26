## TON Miner framework
This is a ton miner framework with centralized server that allows to distribute giver 
params to workers and mine solo without connecting to a pool.

Solution is divided in two components:

* server.py provides almost real time PoW giver params to slaves / miners, it also serves targets (wallets) to mine on.
* miner.py actual miner process that is run on nodes with GPUs

If you do not want to join a pool and have sufficient hashing power to run solo (250+ GH/s now) you can use this suite.

## Prerequesites
* TON Node binaries https://github.com/newton-blockchain/ton
* Valid lite-client config file or key. Make sure you can connect to lite-server from shell before attempting anything else.
* OpenCL installed
* Properly adjusted config files, see templates in support/configs

## Tests
#### Server
Try to open HTTP connection to IP/Port defined in server config file, if you see JSON data then all is OK

#### Miner
To see information about OpenCL devices / platforms, type:
`./miner-process.py -i`

To make a test run on your cards, type:
`./miner-process.py -t --platform 0 --device 0 --vectors 1 --vdiv 100`

Where `platform` and `device` must be set according to your configuration. This will run a easy test and hopefully find a valid solution, informing you about it. If no solution has been found, rerun


