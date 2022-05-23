import json
import atexit
import threading
import ctypes
import math
import random
import cmd
import sys
from Queue import Queue
from time import time
from time import sleep
from multiprocessing import Process
from signal import signal, SIGINT, SIGKILL

MBR_MIN         = 0
MBR_MAX         = 65535
ENABLED         = 0
DISABLED_SOFT   = 1
DISABLED_HARD   = 2

class Controller(threading.Thread):
    def __init__(self, listen = True):
        threading.Thread.__init__(self)
        self.digest = None
        self.hdls = []
        self.num_fids = 4
        self.fids = {}
        for i in range(0, self.num_fids):
            self.fids[i + 1] = 1
        self.TOTAL_BW_KBPS = 3 * 1024 * 1024
        self.CIR_KBPS = self.TOTAL_BW_KBPS / self.num_fids
        self.CBS_KBITS = 3 * self.CIR_KBPS
        self.PIR_CBPS = self.TOTAL_BW_KBPS * 0.8 / self.num_fids
        self.PBS_KBITS = 3 * self.PIR_CBPS
        self.GREEN = 0
        self.YELLOW = 1
        self.RED = 2
        p4_pd.meter_params_register()
        print "Registered listener"
        random.seed(time())
        self.allocate()

    def getNotification(self):
        self.digest = p4_pd.meter_params_get_digest()
        if self.digest.msg != []:
            msgPtr = self.digest.msg_ptr
            self.digest.msg_ptr = 0
            p4_pd.meter_params_digest_notify_ack(msgPtr)
        return self.digest.msg

    def allocate(self):
        for fid in self.fids:
            num_cycles = 1
            cir = 0.8 * self.TOTAL_BW_KBPS / self.num_fids
            cbs = 3 * cir
            pir = self.TOTAL_BW_KBPS / self.num_fids
            pbs = 3 * pir
            hdl = p4_pd.resources_table_add_with_set_quota(
                p4_pd.resources_match_spec_t(
                    as_fid=fid
                ),
                p4_pd.set_quota_action_spec_t(
                    1, 
                    11, 
                    0,
                    num_cycles
                ),
                p4_pd.bytes_meter_spec_t(cir, cbs, pir, pbs, False)
            )
            self.hdls.append(hdl)
        conn_mgr.complete_operations()

    def handle_surge(self, fid, color):
        print "FID %d reached level %d" % (fid, color)
        sleep(1)
        p4_pd.register_write_bloom_meter(fid, 0)
        conn_mgr.complete_operations()

    def run(self):
        while True:
            try:
                digests = self.getNotification()
                for m in digests:
                    print m
                    fid = int(m.as_fid)
                    color = int(m.meta_color)
                    self.handle_surge(fid, color)
            except Exception as ex:
                template = "An exception of type {0} occurred while polling. Arguments:\n{1!r}"
                message = template.format(type(ex).__name__, ex.args)
                print message
                self.unregisterMMU()
                return
            sleep(0.000001)

    def unregisterMMU(self):
        print "unregistering MMU"
        try:
            p4_pd.meter_params_digest_notify_ack(self.digest.msg_ptr)
            p4_pd.meter_params_digest_deregister()
        except:
            pass

class ControllerPrompt(cmd.Cmd):
    intro = "ActiveP4 BMU Controller. Type help or ? to list commands.\n"
    prompt = "(activep4-ctrl) "

    def __init__(self, controller):
        cmd.Cmd.__init__(self)
        self.controller = controller

    def do_something(self, arg):
        'Do something.'
        pass

    def close(self):
        exit()

ctrl = Controller()
atexit.register(ctrl.unregisterMMU)

ctrl.start()
ControllerPrompt(ctrl).cmdloop()

print "controller exited"