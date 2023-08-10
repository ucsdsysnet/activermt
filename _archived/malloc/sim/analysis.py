#!/usr/bin/python3

import os
import sys
import json
import time

from multiprocessing import Process

from memory_allocation import *

class Analysis:

    INSTR_SET_PATH = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..', 'config', 'opcode_action_mapping.csv')
    IG_ONLY_INSTR = ('SET_DST', 'RTS', 'CRTS')
    MEM_PFX = 'MEM_'
    MAX_RETRIES = 3

    def __init__(self, appconfig, wlConfig, schemes, numRepeats=1, numEpochs=100):
        logging.basicConfig(level=logging.INFO, filename='allocation_simulation.log', filemode='w', format='%(asctime)s - %(levelname)s - %(message)s')
        self.numRepeats = numRepeats
        self.numEpochs = numEpochs
        self.instruction_set = None
        self.appconfig = appconfig
        self.wlConfig = wlConfig
        self.schemes = schemes
        self.readInstructionSet()
        self.configureApplications()

    def configureApplications(self):
        for app in appconfig:
            source_path = appconfig[app]['source'].replace('apo', 'ap4')
            memidx_path = appconfig[app]['source'].replace('apo', 'memidx.csv')
            application_demand = appconfig[app]['demand']
            with open(memidx_path) as f:
                data = f.read().splitlines()
                memidx = [ int(x) for x in data[0].split(",") ]
                iglim = int(data[1])
                self.appconfig[app]['iglim'] = iglim
                self.appconfig[app]['memidx'] = memidx
                self.appconfig[app]['mindemand'] = [application_demand] * len(memidx)
                f.close()
            with open(source_path) as f:
                data = f.read().strip().splitlines()
                self.appconfig[app]['length'] = len(data)
                f.close()
            logging.info("Configured application {} w/ {} instructions, {} memory accesses, {} igLim.".format(app, self.appconfig[app]['length'], self.appconfig[app]['memidx'], self.appconfig[app]['iglim']))
        # for app in appconfig:
        #     bytecode_path = appconfig[app]['source']
        #     application_demand = appconfig[app]['demand']
        #     assert(os.path.exists(bytecode_path))
        #     bytecode = self.readProgram(bytecode_path)
        #     progLen = len(bytecode) - 1
        #     self.appconfig[app]['bytecode'] = bytecode
        #     self.appconfig[app]['length'] = progLen
        #     igLim = -1
        #     memidx = []
        #     for i in range(len(bytecode)):
        #         pnemonic = self.instruction_set[bytecode[i]['opcode']][0]
        #         if pnemonic in self.IG_ONLY_INSTR:
        #             igLim = i
        #         if pnemonic.startswith(self.MEM_PFX):
        #             memidx.append(i)
        #     self.appconfig[app]['iglim'] = igLim
        #     self.appconfig[app]['memidx'] = memidx
        #     self.appconfig[app]['mindemand'] = [application_demand] * len(memidx)
        #     logging.info("Configured application {} w/ {} instructions, {} memory accesses, {} igLim.".format(app, progLen, memidx, igLim))
        logging.info("Configured {} applications.".format(len(self.appconfig)))

    def readInstructionSet(self):
        assert(os.path.exists(self.INSTR_SET_PATH))
        if self.instruction_set is not None:
            return
        with open(self.INSTR_SET_PATH, 'r') as f:
            opcode = 0
            self.instruction_set = {}
            for line in f.readlines():
                info = line.split(',')
                pnemonic = info[0].strip()
                action_id = info[1].strip()
                condition = None if len(info) < 3 else (True if info[2] == '1' else False)
                self.instruction_set[opcode] = (pnemonic, action_id, condition)
                opcode += 1
            f.close()
        assert(self.instruction_set is not None)
        logging.info("Read instruction set w/ {} instructions.".format(len(self.instruction_set)))

    def readProgram(self, program_path):
        assert(os.path.exists(program_path))
        bytecode = []
        with open(program_path, 'rb') as f:
            program = list(f.read())
            i = 0
            while i < len(program):
                bytecode.append({
                    'opcode'    : program[i + 1],
                    'goto'      : program[i]
                })
                i += 2
            f.close()
        assert(bytecode is not None)
        return bytecode

    def run(self, data_dir=os.getcwd(), local=True, config_name=None, parallel=True):
        if not os.path.exists(data_dir):
            os.makedirs(data_dir)
        # if self.numRepeats == 1:
        # comparison mode.
        logging.info("Running w/ {} schemes.".format(len(self.schemes)))
        if config_name is not None:
            output_dir = "results_{}".format(config_name)
        else:
            output_dir = "results"
        output_path = os.path.join(data_dir, output_dir)
        assert(not os.path.exists(output_path))
        os.makedirs(output_path)
        threads = []
        for rep in range(self.numRepeats):
            print("Running repetition {}.".format(rep))
            output_path_iter = os.path.join(output_path, "{}".format(rep))
            assert not os.path.exists(output_path_iter)
            os.makedirs(output_path_iter)
            if parallel:
                th = Process(target=self.runSchemeSetIteration, args=(rep, output_path_iter, local, ))
                th.start()
                threads.append(th)
            else:
                ts_start = time.time()
                self.runSchemeSetIteration(rep, output_path_iter, local)
                ts_end = time.time()
                ts_elapsed = ts_end - ts_start
                print("Iteration {} took {} seconds.".format(rep, ts_elapsed))
        for th in threads:
            th.join()
        logging.info("Completed {} simulation iterations.".format(self.numRepeats))
        # else:
        #     # repetition mode.
        #     output_dir = "results_{}_n_{}_wl_{}_fit_{}_constr_{}".format(("local" if local else "global"), self.numEpochs, self.wlConfig['type'], self.wlConfig['fit'], self.wlConfig['constr'])
        #     output_path = os.path.join(data_dir, output_dir)
        #     assert(not os.path.exists(output_path))
        #     os.makedirs(output_path)
        #     threads = []
        #     for iter in range(self.numRepeats):
        #         th = Process(target=self.runSimulation, args=(iter, output_path, local, ))
        #         th.start()
        #         threads.append(th)
        #     for th in threads:
        #         th.join()
        #     logging.info("Completed {} simulation iterations.".format(self.numRepeats))

    def runSchemeSetIteration(self, iter, output_path, local):
        simulator = Simulation(self.numEpochs, locallyOptimize=local)
        # generate once for each set of schemes.
        simulator.generate(
            self.appconfig, 
            wlType=self.wlConfig['type'], 
            arrivalType=self.wlConfig['arrival']['type'], 
            arrivalRate=self.wlConfig['arrival']['rate'], 
            departureType=self.wlConfig['departure']['type'], 
            departureRate=self.wlConfig['departure']['rate']
        )
        for scheme in self.schemes:
            logging.info("[iter {}] Running scheme {}.".format(iter, scheme))
            scheme_idx = self.schemes.index(scheme)
            # [schemes] (12 total)
            #   obj     : fit (utilization) or number of reallocations.
            #   fit     : first-fit (first-available), best-fit (least-accommodating) or worst-fit (most-accommodating).
            #   constr  : least-constrained (allow re-circulations to find a better allocation) or most-constrained (do not add more re-circulations).
            allocator_metric = Allocator.METRIC_COST if scheme['obj'] == 'fit' else Allocator.METRIC_REALLOC
            allocator_optimize = (scheme['fit'] != 'ff')
            allocator_minimize = (scheme['fit'] == 'wf' and scheme['obj'] == 'fit') or (scheme['obj'] == 'realloc')
            allocator_granularity = 368 if 'granularity' not in scheme else scheme['granularity']
            logging.info("[iter {}] Running allocator w/ metric={}, optimize={}, minimize={}.".format(iter, allocator_metric, allocator_optimize, allocator_minimize))
            retries = 0
            success = False
            while not success and retries < self.MAX_RETRIES:
                # try:
                allocator = Allocator(metric=allocator_metric, optimize=allocator_optimize, minimize=allocator_minimize, granularity=allocator_granularity)
                simulator.resetEvents()
                simulator.setAllocator(allocator)
                simulator.run(constr_type=scheme['constr'])
                output_path_iter = os.path.join(output_path, "{}".format(scheme_idx))
                # assert(not os.path.exists(output_path_iter))
                if not os.path.exists(output_path_iter):
                    os.makedirs(output_path_iter)
                simulator.saveResults(output_path_iter)
                logging.info("[iter {}] Saved results to {}.".format(iter, output_path_iter))
                success = True
                # except Exception as e:
                #     logging.error("[iter {}] Exception occurred: {}".format(iter, e))
                #     retries += 1
                #     print("[iter {}] Exception occurred running scheme {}: {}, Retrying ... ".format(iter, scheme_idx, e))
            assert success,"Experiment {} failed after {} retries.".format(iter, self.MAX_RETRIES)

    def runSimulation(self, iter, output_path, local):
        allocator_metric = Allocator.METRIC_COST
        allocator_optimize = self.wlConfig['fit'] != 'ff'
        allocator_minimize = True if self.wlConfig['fit'] == 'wf' else False
        allocator_granularity = 368 if 'granularity' not in self.wlConfig else self.wlConfig['granularity']
        allocator = Allocator(metric=allocator_metric, optimize=allocator_optimize, minimize=allocator_minimize, granularity=allocator_granularity)
        simulator = Simulation(self.numEpochs, allocator, locallyOptimize=local)
        simulator.generate(self.appconfig, wlType=self.wlConfig['type'], arrivalType=self.wlConfig['arrival']['type'], arrivalRate=self.wlConfig['arrival']['rate'], departureType=self.wlConfig['departure']['type'], departureRate=self.wlConfig['departure']['rate'])
        logging.info("Running simulation {} w/ {} epochs, {} workload, {} arrival, {} departure, {} fit.".format(
            iter, self.numEpochs, self.wlConfig['type'], self.wlConfig['arrival']['type'], self.wlConfig['departure']['type'], self.wlConfig['fit']
        ))
        simulator.run()
        output_path_iter = os.path.join(output_path, "{}".format(iter))
        assert(not os.path.exists(output_path_iter))
        os.makedirs(output_path_iter)
        simulator.saveResults(output_path_iter)
        logging.info("Saved results to {}.".format(output_path_iter))

# check arguments.
if len(sys.argv) < 2:
    print("Usage: {} <config_file>".format(sys.argv[0]))
    sys.exit(1)

config_path = sys.argv[1]

assert(os.path.exists(config_path))

# load the application set.
appconfig = None
appconfig_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'apps.json')
assert(os.path.exists(appconfig_path))
with open(appconfig_path, 'r') as f:
    appconfig = json.load(f)
    f.close()
assert(appconfig is not None)

# load the configuration.
config = None
with open(config_path, 'r') as f:
    config = json.load(f)
    f.close()
assert(config is not None)

# parameters.
workloadType = config['workload']
num_epochs = config['epochs']
num_repeats = config['repeats']
arrivalType = config['arrivals']['type']
arrivalRate = config['arrivals']['rate']
departureType = config['departures']['type']
departureRate = config['departures']['rate']

wlConfig = {
    'type'    : workloadType,
    'arrival' : {
        'type' : arrivalType,
        'rate' : arrivalRate
    },
    'departure' : {
        'type' : departureType,
        'rate' : departureRate
    }
}

# init.
analysis = Analysis(appconfig, wlConfig, config['schemes'], numRepeats=num_repeats, numEpochs=num_epochs)

# run.
analysis.run(data_dir='data', local=config['local'], config_name=os.path.basename(config_path).split('.')[0])