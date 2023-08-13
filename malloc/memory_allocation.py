import os
import sys
import copy
import time
import logging

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'activermt', 'controlplane'))

from allocator import ActiveFunction
from allocator import Allocator

"""
    A single event (arrival/departure) in an epoch in the simulator. This class is used to represent the state of the allocator post the event.
"""
class ApplicationEvent:

    def __init__(self, epoch, program, arrival=True):
        self.isArrival = arrival
        self.epoch = epoch
        self.fid = 0
        self.program = program
        self.failed = False
        self.enumTime = 0
        self.searchTime = 0
        self.ppTime = 0
        self.allocationTime = 0
        self.applyTime = 0
        self.allocatedStages = []
        self.numAllocatedBlocks = 0
        self.costMetricValue = 0
        self.reallocationCost = 0
        self.numReallocatedApps = 0
        self.numElasticApps = 0
        self.allocationMatrix = None # overall allocator state after the event.
        self.memoryUtilization = 0 # overall memory utilization after the event.

    def __str__(self):
        return "Arrival: epoch = {}, program = {}, allocationTime = {}, allocatedStages = {}, numAllocatedBlocks = {}, costMetricValue = {}, memoryUtilization = {}".format(
            self.epoch, self.program, self.allocationTime, self.allocatedStages, self.numAllocatedBlocks, self.costMetricValue, self.memoryUtilization
        )

"""
    This class represents a single simulation. Note that events are serialized by the allocator.
"""
class Simulation:

    def __init__(self, numEpochs, allocator=None, locallyOptimize=True):
        self.numEpochs = numEpochs
        self.allocator = allocator # a configured allocator instance.
        self.events = [] # list of tuples (event1, event2, ...).
        self.wl = None # workload as a copy of events.
        self.programs = {}
        self.numEventsPerEpoch = [] # state after the epoch is the state after the last event in the epoch.
        self.localOptimize = locallyOptimize

    def setAllocator(self, allocator):
        self.allocator = allocator

    def resetEvents(self):
        self.events = copy.deepcopy(self.wl)

    # used to replay experiments; assumes each allocation is successful.
    # wlType can be 'mixed' or '<homogeneous>', where <homogeneous> is an application from the applicationSet.
    # arrivalType can be 'sequential' or 'poisson', arrivalRate is the rate of arrival in case of poisson.
    # departureType can be 'sequential' or 'poisson' or None, departureRate is the rate of departure in case of poisson.
    def generate(self, applicationSet, wlType='mixed', arrivalType='sequential', arrivalRate=None, departureType=None, departureRate=None):
        rng = np.random.default_rng()
        allocated = set()
        fid = 0
        for i in range(self.numEpochs):
            events = []
            if departureType == 'poisson':
                assert(departureRate is not None)
                nd = rng.poisson(lam=departureRate)
                while(nd > 0 and len(allocated) > 0):
                    candidate = rng.choice(list(allocated))
                    departure = copy.deepcopy(candidate)
                    departure.isArrival = False
                    allocated.remove(candidate)
                    events.append(departure)
                    nd -= 1
            elif departureType == 'sequential':
                candidate = rng.choice(list(allocated))
                departure = copy.deepcopy(candidate)
                departure.isArrival = False
                allocated.remove(candidate)
                events.append(departure)
            if arrivalType == 'poisson':
                assert(arrivalRate is not None)
                na = rng.poisson(lam=arrivalRate)
                while(na > 0):
                    if wlType == 'mixed':
                        program = rng.choice(list(applicationSet.keys()))
                    else:
                        program = wlType
                    assert(program in applicationSet)
                    arrival = ApplicationEvent(i, applicationSet[program])
                    fid += 1
                    arrival.fid = fid
                    allocated.add(arrival)
                    events.append(arrival)
                    na -= 1
                    self.programs[fid] = applicationSet[program]
            elif arrivalType == 'sequential':
                if wlType == 'mixed':
                    program = rng.choice(list(applicationSet.keys()))
                else:
                    program = wlType
                assert(program in applicationSet)
                arrival = ApplicationEvent(i, applicationSet[program])
                fid += 1
                arrival.fid = fid
                allocated.add(arrival)
                events.append(arrival)
                self.programs[fid] = applicationSet[program]
            self.events.append(tuple(events))
            self.numEventsPerEpoch.append(len(events))
        self.wl = copy.deepcopy(self.events)
        # verify.
        assert (len(self.events) == self.numEpochs)
        assert (len(self.numEventsPerEpoch) == self.numEpochs)
        ws = set()
        for i in range(self.numEpochs):
            assert (len(self.events[i]) == self.numEventsPerEpoch[i])
            for j in range(len(self.events[i])):
                event = self.events[i][j]
                if event.isArrival:
                    assert (event.fid not in ws)
                    ws.add(event.fid)
                else:
                    assert (event.fid in ws)
                    ws.remove(event.fid)
        logging.info("Generated events for {} epochs.".format(self.numEpochs))

    # run the simulation.
    def run(self, constr_type='lc'):
        assert(self.allocator is not None)
        for i in range(self.numEpochs):
            # print("Processing epoch {} w/ {} events ... ".format(i, len(self.events[i])))
            for j in range(len(self.events[i])):
                event = self.events[i][j]
                fid = event.fid
                # logging.debug("Processing event FID {}, arrival {}.".format(event.fid, event.isArrival))
                if event.isArrival:
                    program = ActiveFunction(fid, event.program['memidx'], event.program['iglim'] if (constr_type == 'mc') else -1, event.program['length'], event.program['mindemand'], enumerate=True, allow_filling=(constr_type == 'lc'))
                    (allocation, cost, utilization, allocTime, overallAlloc, allocationMap, enumTime, searchTime, ppTime) = self.allocator.computeAllocation(program, online=self.localOptimize)
                    self.events[i][j].allocationTime = allocTime
                    self.events[i][j].enumTime = enumTime
                    self.events[i][j].searchTime = searchTime
                    self.events[i][j].ppTime = ppTime
                    if allocation is not None and cost < Allocator.WT_OVERFLOW:
                        self.events[i][j].allocatedStages = allocation
                        apply_start = time.time()
                        (changes,_,num_elastic) = self.allocator.enqueueAllocation(overallAlloc, allocationMap)
                        assert self.allocator.applyQueuedAllocation(),"allocation failed to apply."
                        apply_stop = time.time()
                        self.events[i][j].applyTime = apply_stop - apply_start
                        blocks = self.allocator.getAllocationBlocks(fid)
                        numBlocks = 0
                        for sid in blocks:
                            numBlocks += len(blocks[sid])
                        numChanges = 0
                        for tid in changes:
                            numChanges += len(changes[tid])
                        self.events[i][j].numAllocatedBlocks = numBlocks
                        self.events[i][j].costMetricValue = cost
                        self.events[i][j].reallocationCost = numChanges
                        self.events[i][j].numReallocatedApps = len(changes)
                        self.events[i][j].numElasticApps = num_elastic
                        self.events[i][j].memoryUtilization = utilization
                        self.events[i][j].allocationMatrix = copy.deepcopy(self.allocator.allocationMatrix)
                        logging.info("[epoch {}] allocation successful for fid = {} w/ allocation {}".format(i, fid, allocation))
                    else:
                        self.events[i][j].failed = True
                        self.events[i][j].memoryUtilization = self.allocator.getUtilization()
                        self.events[i][j].allocationMatrix = copy.deepcopy(self.allocator.allocationMatrix)
                        logging.info("[epoch {}] allocation failed for fid = {}".format(i, fid))
                else:
                    self.allocator.deallocate(fid)
                    self.events[i][j].memoryUtilization = self.allocator.getUtilization()
                    self.events[i][j].allocationMatrix = copy.deepcopy(self.allocator.allocationMatrix)
                    logging.info("[epoch {}] deallocation successful for fid = {}".format(i, fid))
        # # profiling.
        # E = np.array(self.allocator.profiling['enums'], dtype=np.uint32)
        # np.savetxt("data/debug/enums.csv", E, delimiter=",", fmt='%u')
        # T = np.array(self.allocator.profiling['getCost'], dtype=np.float32)
        # np.savetxt("data/debug/getCost.csv", T, delimiter=",")
        # H = np.histogram(T, bins=100)
        # print("getCost: min = {}, max = {}, avg = {}, std = {}".format(np.min(T), np.max(T), np.average(T), np.std(T)))
        # print("getCost: hist = {}".format(H[0]))
        # print("getCost: bins = {}".format(H[1]))
        # print("sum_hist = {}".format(np.sum(H[0])))
        # print("# invocations = {}".format(len(T)))  

    # save results grouped by 'epoch' or 'event' to file.
    def saveResults(self, path, grouping='epoch'):
        assert(os.path.exists(path))
        for i in range(self.numEpochs):
            numEvents = self.numEventsPerEpoch[i]
            assert(numEvents == len(self.events[i]))
            # if numEvents > 0 and self.events[i][numEvents - 1].allocationTime == -1:
            #     continue
            output_path_epoch = os.path.join(path, '{}'.format(i))
            # assert(not os.path.exists(output_path_epoch))
            if not os.path.exists(output_path_epoch):
                os.mkdir(output_path_epoch)
            output_path_allocation_matrix = os.path.join(output_path_epoch, 'allocation_matrix.csv')
            output_path_summary = os.path.join(output_path_epoch, 'summary.csv')
            output_path_allocations = os.path.join(output_path_epoch, 'allocations.csv')
            output_path_programs = os.path.join(output_path_epoch, 'programs.csv')
            if grouping == 'epoch':
                if numEvents > 0:
                    sum_changes = 0
                    reallocated_prop = 0
                    num_arrivals = 0
                    num_failures = 0
                    allocation_time_avg = 0
                    enum_time_avg = 0
                    search_time_avg = 0
                    pp_time_avg = 0
                    apply_time_avg = 0
                    programs = []
                    for ev in self.events[i]:
                        if ev.isArrival:
                            assert (ev.numElasticApps >= ev.numReallocatedApps),"Elastic apps {} < reallocated apps {}.".format(ev.numElasticApps, ev.numReallocatedApps)
                            sum_changes += ev.reallocationCost
                            reallocated_prop += (ev.numReallocatedApps / ev.numElasticApps) if ev.numElasticApps > 0 else 0
                            allocation_time_avg += ev.allocationTime
                            enum_time_avg += ev.enumTime
                            search_time_avg += ev.searchTime
                            pp_time_avg += ev.ppTime
                            apply_time_avg += ev.applyTime
                            num_arrivals += 1
                            demand = ev.program['mindemand'][0]
                            programs.append((ev.fid, demand))
                        if ev.failed:
                            num_failures += 1
                    reallocated_prop = reallocated_prop / num_arrivals if num_arrivals > 0 else 0
                    allocation_time_avg = allocation_time_avg / num_arrivals if num_arrivals > 0 else 0
                    apply_time_avg = apply_time_avg / num_arrivals if num_arrivals > 0 else 0
                    enum_time_avg = enum_time_avg / num_arrivals if num_arrivals > 0 else 0
                    search_time_avg = search_time_avg / num_arrivals if num_arrivals > 0 else 0
                    pp_time_avg = pp_time_avg / num_arrivals if num_arrivals > 0 else 0
                    assert(num_failures <= numEvents)
                    with open(output_path_allocation_matrix, 'w') as f:
                        f.write("\n".join([ ",".join([ str(x) for x in y ]) for y in self.events[i][-1].allocationMatrix ]))
                        f.close()
                    with open(output_path_summary, 'w') as f:
                        f.write("num_events,utilization,reallocations,changes,failures,reallocated_prop,time_compute,time_apply,time_enum,time_search,time_pp\n")
                        f.write("{},{},{},{},{},{},{},{},{},{},{}\n".format(numEvents, self.events[i][-1].memoryUtilization, self.computeReallocations(i), sum_changes, num_failures,reallocated_prop, allocation_time_avg, apply_time_avg, enum_time_avg, search_time_avg, pp_time_avg))
                        f.close()
                    with open(output_path_allocations, 'w') as f:
                        opdata = []
                        for ev in self.events[i]:
                            if ev.isArrival:
                                opdata.append(",".join([ str(x) for x in ev.allocatedStages ]))
                        f.write("\n".join(opdata))
                        f.close()
                    with open(output_path_programs, 'w') as f:
                        opdata = []
                        for (fid, demand) in programs:
                            opdata.append("{},{}".format(fid, demand))
                        f.write("\n".join(opdata))
                        f.close()
            elif grouping == 'event':
                raise Exception("Not implemented yet.")
            else:
                raise Exception("Invalid grouping type: {}".format(grouping))

    # computes (total/average) reallocation cost for each epoch.
    def computeReallocations(self, epoch, aggregate='sum'):
        assert(self.numEpochs == len(self.events))
        assert(self.numEventsPerEpoch[epoch] == len(self.events[epoch]))
        if self.numEventsPerEpoch[epoch] == 0:
            return 0
        last_valid_epoch = epoch - 1
        while last_valid_epoch > 0 and self.numEventsPerEpoch[last_valid_epoch] == 0:
            last_valid_epoch -= 1
        if last_valid_epoch <= 0:
            return 0
        currentMatrix = None if epoch == 0 else self.events[last_valid_epoch][-1].allocationMatrix
        reallocations = []
        for event in self.events[epoch]:
            if not event.isArrival:
                continue
            if currentMatrix is None:
                reallocations.append(0)
            else:
                wsOld = np.unique(currentMatrix)
                wsNew = np.unique(event.allocationMatrix)
                reallocated = set()
                for fid in wsOld:
                    if fid not in wsNew:
                        continue
                    for i in range(len(currentMatrix)):
                        for j in range(len(currentMatrix[i])):
                            if currentMatrix[i][j] == fid and event.allocationMatrix[i][j] != fid:
                                reallocated.add(fid)
                reallocations.append(len(reallocated))
            currentMatrix = event.allocationMatrix
        if aggregate == 'sum':
            return np.sum(reallocations)
        elif aggregate == 'avg':
            return np.average(reallocations)
        else:
            raise Exception("Invalid aggregate type: {}".format(aggregate))
