import json
from time import time
from time import sleep
from multiprocessing import Process

class Controller:
    def __init__(self):
        self.MEMORY_SIZE = 8192
        self.NUM_PIPES = 4
        self.ENTRY_TIMEOUT = 5.0
        self.registerReads = [
            p4_pd.register_read_heap_1,
            p4_pd.register_read_heap_2,
            p4_pd.register_read_heap_3,
            p4_pd.register_read_heap_4,
            p4_pd.register_read_heap_5,
            p4_pd.register_read_heap_6,
            p4_pd.register_read_heap_7,
            p4_pd.register_read_heap_8,
            p4_pd.register_read_heap_9,
            p4_pd.register_read_heap_10,
            p4_pd.register_read_heap_11
        ]
        self.registerWrites = [
            p4_pd.register_write_heap_1,
            p4_pd.register_write_heap_2,
            p4_pd.register_write_heap_3,
            p4_pd.register_write_heap_4,
            p4_pd.register_write_heap_5,
            p4_pd.register_write_heap_6,
            p4_pd.register_write_heap_7,
            p4_pd.register_write_heap_8,
            p4_pd.register_write_heap_9,
            p4_pd.register_write_heap_10,
            p4_pd.register_write_heap_11
        ]
        self.readMethods = [
            p4_pd.register_range_read_heap_1,
            p4_pd.register_range_read_heap_2,
            p4_pd.register_range_read_heap_3,
            p4_pd.register_range_read_heap_4,
            p4_pd.register_range_read_heap_5,
            p4_pd.register_range_read_heap_6,
            p4_pd.register_range_read_heap_7,
            p4_pd.register_range_read_heap_8,
            p4_pd.register_range_read_heap_9,
            p4_pd.register_range_read_heap_10,
            p4_pd.register_range_read_heap_11
        ]
        self.writeMethods = [
            p4_pd.register_write_heap_1,
            p4_pd.register_write_heap_2,
            p4_pd.register_write_heap_3,
            p4_pd.register_write_heap_4,
            p4_pd.register_write_heap_5,
            p4_pd.register_write_heap_6,
            p4_pd.register_write_heap_7,
            p4_pd.register_write_heap_8,
            p4_pd.register_write_heap_9,
            p4_pd.register_write_heap_10,
            p4_pd.register_write_heap_11
        ]
        self.counterReads = [
            p4_pd.counter_read_hit_1,
            p4_pd.counter_read_hit_2,
            p4_pd.counter_read_hit_3,
            p4_pd.counter_read_hit_4,
            p4_pd.counter_read_hit_5,
            p4_pd.counter_read_hit_6,
            p4_pd.counter_read_hit_7,
            p4_pd.counter_read_hit_8,
            p4_pd.counter_read_hit_9,
            p4_pd.counter_read_hit_10,
            p4_pd.counter_read_hit_11
        ]
        self.counterWrites = [
            p4_pd.counter_write_hit_1,
            p4_pd.counter_write_hit_2,
            p4_pd.counter_write_hit_3,
            p4_pd.counter_write_hit_4,
            p4_pd.counter_write_hit_5,
            p4_pd.counter_write_hit_6,
            p4_pd.counter_write_hit_7,
            p4_pd.counter_write_hit_8,
            p4_pd.counter_write_hit_9,
            p4_pd.counter_write_hit_10,
            p4_pd.counter_write_hit_11
        ]
    
    def doLRU(self):
        while(True):
            count = p4_pd.counter_read_lrucount(0, from_hw)
            purged = 0
            if count.packets > 0:
                then = time()
                print "performing LRU..."
                indices = p4_pd.register_range_read_lruid(0, self.MEMORY_SIZE, from_hw)
                for index in range(0, self.MEMORY_SIZE):
                    for pipe in range(0, self.NUM_PIPES):
                        x = index * self.NUM_PIPES + pipe
                        if indices[x] > 0:
                            minCount = None
                            minStage = None
                            for stage in range(0, 11):
                                regCount = self.counterReads[stage](index, from_hw)
                                if regCount.packets > 0 and (minCount is None or minCount.packets > regCount.packets):
                                    minCount = regCount
                                    minStage = stage
                            print "purging old data from index %d in stage %d" % (index, minStage)
                            values = self.registerReads[minStage](index, from_hw)
                            for pipe in range(0, self.NUM_PIPES):
                                values[pipe].f0 = 0
                                values[pipe].f1 = 0
                            self.registerWrites[minStage](index, values[0])
                            purged = purged + 1
                #now = time()
                elapsed = now - then
                print "%f seconds elapsed in scan" % elapsed
            count.packets = count.packets - purged
            p4_pd.counter_write_lrucount(0, count)
            sleep(0.001)

    def updateMemory(self, regIndex):
        while True:
            print "polling and updating heap %d" % (regIndex + 1)
            #then = time()
            values = self.readMethods[regIndex](0, self.MEMORY_SIZE, from_hw)
            for index in range(0, self.MEMORY_SIZE):
                for pipe in range(0, self.NUM_PIPES):
                    x = index * self.NUM_PIPES + pipe
                    objKey = values[x].f1
                    if objKey != 0:
                        counter = self.counterReads[regIndex](index, from_hw)
                        hits = counter.packets
                        if hits == 0:
                            print "entry %d timed out, resetting..." % index
                            values[x].f1 = 0
                            values[x].f0 = 0
                            self.writeMethods[regIndex](index, values[x])
                        else:
                            #print "entry %d active with hits %d" % (index, hits)
                            counter.packets = counter.packets - 1
                            self.counterWrites[regIndex](index, counter)
            #now = time()
            #elapsed = now - then
            #print "scan for heap %d finished after %f seconds" % (regIndex + 1, elapsed)
            sleep(0.01)

ctrl = Controller()

heapIndex = 2

procs = []

procAging = Process(target=ctrl.updateMemory, args=(heapIndex,))
procLRU = Process(target=ctrl.doLRU)

#procs.append(procAging)
procs.append(procLRU)

for proc in procs:
    proc.start()

for proc in procs:
    proc.join()