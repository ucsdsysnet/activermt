import json
import atexit
import threading
import ctypes
from Queue import Queue
from time import time
from time import sleep
from multiprocessing import Process
from signal import signal, SIGINT, SIGKILL

class Controller:
    def __init__(self):
        self.MEMORY_SIZE = 8192
        self.ENTRY_TIMEOUT_TICK_US = 1
        self.running = True
        self.digest = None
        self.workset = Queue(self.MEMORY_SIZE)
        self.defaultRegValues = p4_pd.register_read_heap_3(0, from_hw)[0]
        self.defaultRegValues.f0 = 0
        self.defaultRegValues.f1 = 0
        p4_pd.gc_params_register()

    def stopWorkers(self):
        self.running = False

    def garbageCollect(self):
        while True:
            if not self.running:
                break
            if self.workset.empty():
                continue
            else:
                index = self.workset.get()
                p4_pd.register_write_heap_3(index, self.defaultRegValues)
                print "purged object at index %d" % index
            sleep(0.001)
        print "stopped garbage collection"

    def getNotification(self):
        self.digest = p4_pd.gc_params_get_digest()
        if self.digest.msg != []:
            msgPtr = self.digest.msg_ptr
            self.digest.msg_ptr = 0
            p4_pd.gc_params_digest_notify_ack(msgPtr)
        return self.digest.msg
 
    """def pollNotifications(self):
        while True:
            if not self.running:
                break
            try:
                digests = self.getNotification()
                for m in digests:
                    mem_idx = m.as_id & 0x1FFF
                    if self.workset.full():
                        continue
                    else:
                        self.workset.put(mem_idx)
            except:
                print "An error occurred while polling"
        print "stopped polling for digests"
    """

    def pollNotifications(self):
        while True:
            try:
                digests = self.getNotification()
                for m in digests:
                    mem_idx = m.as_id & 0x1FFF
                    p4_pd.register_write_heap_3(mem_idx, self.defaultRegValues)
            except:
                print "An error occurred while polling"
            sleep(0.000001)

    def unregisterGC(self):
        print "unregistering garbage collector"
        try:
            p4_pd.gc_params_digest_notify_ack(self.digest.msg_ptr)
            p4_pd.gc_params_digest_deregister()
        except:
            pass

    def updateMemory(self):
        entryAge = {}
        while True:
            print "polling and updating heap"
            then = time()
            defaultRegValues = p4_pd.register_read_heap_1(0, from_hw)[0]
            defaultRegValues.f0 = 0
            defaultRegValues.f1 = 0
            for index in range(0, self.MEMORY_SIZE):
                counter = p4_pd.counter_read_hit_3(index, from_hw)
                hits = counter.packets
                if hits == 0:
                    continue
                if index not in entryAge:
                    entryAge[index] = time()
                age = int((time() - entryAge[index]) * 1E6)
                updatedHits = max(hits - self.ENTRY_TIMEOUT_TICK_US * age, 0)
                if updatedHits == 0:
                    print "entry %d timed out, resetting..." % index
                    p4_pd.register_write_heap_3(index, defaultRegValues)
                counter.packets = updatedHits
                p4_pd.counter_write_hit_3(index, counter)
                entryAge[index] = time()
            now = time()
            elapsed = now - then
            print "scan for heap 3 finished after %f seconds" % elapsed
            sleep(0.01)

ctrl = Controller()

"""procAging = Process(target=ctrl.updateMemory)
procAging.start()
procAging.join()"""

"""then = time()
ctrl.garbageCollect(1)
now = time()
elapsed = now - then
print "garbage collection finished after %f seconds" % elapsed"""

atexit.register(ctrl.unregisterGC)

"""worker = threading.Thread(target=ctrl.garbageCollect)
listener = threading.Thread(target=ctrl.pollNotifications)

def onInterrupt(sig, frame):
    global ctrl
    print "exiting..."
    ctrl.stopWorkers()

signal(SIGINT, onInterrupt)

worker.start()
listener.start()

print "press any key to abort"
input()

ctrl.stopWorkers()"""

ctrl.pollNotifications()