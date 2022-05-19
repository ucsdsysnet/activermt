from threading import Thread
from threading import Lock
from time import sleep
import logging
import sys
import cmd
import os

clear_all()

MEMSIZE = 65536
CMS_WIDTH = 4
POLL_INTERVAL_SEC = 1
MAX_FID = 8

class CacheManager(Thread):
    def __init__(self, memoryLimit):
        Thread.__init__(self)
        self.mutex = Lock()
        self.memLimit = memoryLimit
        logging.basicConfig(filename='cache.log', encoding='utf-8', level=logging.DEBUG, format='%(asctime)s %(message)s', datefmt='[%m/%d/%Y %I:%M:%S %p]')
        self.activeSet = set()
        self.entries = []
        self.routes = {
            '10.0.0.1'      : 0,
            '10.0.0.2'      : 4,
            '192.168.0.1'   : 0,
            '192.168.1.1'   : 4
        }
        self.varentries = {
            'getalloc'          : [],
            'add_pagemask'      : [],
            'add_pageoffset'    : []   
        }
        for i in range(0, CMS_WIDTH):
            self.varentries[ 'cmsprep_%d' % (i + 1) ] = []
            self.varentries[ 'cms_addrmask_%d' % (i + 1) ] = []
            self.varentries[ 'cms_addroffset_%d' % (i + 1) ] = []
        self.allocationID = 0
        self.running = False
        self.pktCounts = {}
        self.dpmap = {}
        self.loadPortMappings()
        print("Initialized cache manager")

    def terminate(self):
        self.running = False

    def loadPortMappings(self):
        mapping_file = os.environ['OPERA_MAPPING_PATH'] if 'OPERA_MAPPING_PATH' in os.environ else '/tmp/dp_mappings_identity.csv'
        print("using mapping file: %s" % mapping_file)
        with open(mapping_file, 'r') as f:
            lines = f.read().strip().splitlines()
            for l in lines:
                row = l.split(",")
                self.dpmap[int(row[0])] = int(row[1])
            f.close()

    def addGenericTableEntry(self, table, action, matchargs, actionargs=None, isVarEntry=False):
        self.mutex.acquire()
        tableSpec = getattr(p4_pd, '%s_table_add_with_%s' % (table, action))
        matchSpec = getattr(p4_pd, '%s_match_spec_t' % table)
        if actionargs is None:
            hdl = tableSpec(
                matchSpec(*matchargs)
            )
        else:
            actionSpec = getattr(p4_pd, '%s_action_spec_t' % action)
            hdl = tableSpec(
                matchSpec(*matchargs),
                actionSpec(*actionargs)
            )
        if isVarEntry:
            self.varentries[table].append(hdl)
        else:
            self.entries.append(hdl)
        self.mutex.release()

    def addStaticEntries(self):
        for ipaddr in self.routes:
            self.addGenericTableEntry('forward', 'setegr', (ipv4Addr_to_i32(ipaddr), 32), (self.dpmap[self.routes[ipaddr]],))
        self.addGenericTableEntry('cachekey', 'readkey', (0,))
        self.addGenericTableEntry('cachekey', 'writekey', (1,))
        self.addGenericTableEntry('cachevalue', 'readvalue', (0, 0))
        self.addGenericTableEntry('cachevalue', 'writevalue', (0, 1))
        self.addGenericTableEntry('keyeq', 'cmpkey', (0,))
        self.addGenericTableEntry('cachehitmiss', 'cachemiss', (0, 0))
        self.addGenericTableEntry('route', 'rts', (0, 0))
        self.addGenericTableEntry('objhashing', 'hashobj', (0,))
        self.addGenericTableEntry('objhashing', 'hashobj', (1,))
        self.addGenericTableEntry('storecms', 'storecmscount', (0,))
        for i in range(0, CMS_WIDTH):
            self.addGenericTableEntry('cmscount_%d' % (i + 1), 'cms_count_%d' % (i + 1), (0, ), None)
        conn_mgr.complete_operations()

    def allocateMemory(self, fid, memStart, memBlockSize):
        self.addGenericTableEntry('getalloc', 'return_allocation', (fid, 1), (self.allocationID, hex_to_i16(memStart), hex_to_i16(memStart + memBlockSize - 1)), True)
        self.addGenericTableEntry('add_pagemask', 'applymask', (fid,), (hex_to_i16(memBlockSize - 1),), True)
        self.addGenericTableEntry('add_pageoffset', 'addoffset', (fid,), (hex_to_i16(memStart),), True)
        for i in range(0, CMS_WIDTH):
            self.addGenericTableEntry('cmsprep_%d' % (i + 1), 'hashcms_%d' % (i + 1), (fid, 0), None, True)
            self.addGenericTableEntry('cms_addrmask_%d' % (i + 1), 'applypagemask_%d' % (i + 1), (fid,), (hex_to_i16(memBlockSize - 1),), True)
            self.addGenericTableEntry('cms_addroffset_%d' % (i + 1), 'applypageoffset_%d' % (i + 1), (fid,), (hex_to_i16(memStart),), True)

    def onActiveSetChange(self):
        if len(self.activeSet) == 0:
            return
        self.allocationID = self.allocationID + 1
        for tbl in self.varentries:
            tableSpec = getattr(p4_pd, '%s_table_delete' % tbl)
            for hdl in self.varentries[tbl]:
                tableSpec(hdl)
            self.varentries[tbl] = []
        memBlockSize = self.memLimit / len(self.activeSet)
        memStart = 0
        for fid in self.activeSet:
            self.allocateMemory(fid, memStart, memBlockSize)
            memStart = memStart + memBlockSize
            logging.info('Allocated %d memory to %d' % (memBlockSize, fid))
        conn_mgr.complete_operations()
    
    def run(self):
        self.running = True
        while self.running:
            prevActive = self.activeSet.copy()
            currActive = set()
            for fid in range(1, MAX_FID + 1):
                self.mutex.acquire()
                try:
                    cnt = p4_pd.counter_read_active_traffic(fid, from_hw)
                except:
                    self.terminate()
                    print('Exception in switch driver')
                self.mutex.release()
                if fid not in self.pktCounts:
                    self.pktCounts[fid] = 0
                dpkt = cnt.packets - self.pktCounts[fid]
                self.pktCounts[fid] = cnt.packets
                if dpkt != 0:
                    currActive.add(fid)
            if currActive != prevActive:
                logging.info('Active set changed to {%s}' % ",".join([str(x) for x in currActive]))
                self.activeSet = currActive.copy()
                self.onActiveSetChange()
            sleep(POLL_INTERVAL_SEC)
        print('Exiting manager ...')

class ManagerPrompt(cmd.Cmd):
    intro = "Cache Manager. Type help or ? to list commands.\n"
    prompt = "(cache-test) "

    def __init__(self, mgr):
        cmd.Cmd.__init__(self)
        self.mgr = mgr
        print("Initialized prompt")

    def do_setmemlimit(self, arg):
        'Sets the memory limit'
        args = map(str, arg.split())
        memsize = int(args[0])
        self.mgr.memLimit = memsize
        print('Set the memory limit to %d' % memsize)

    def do_setmem(self, arg):
        'Set memory for an application'
        args = map(str, arg.split())
        fid = int(args[0])
        memStart = int(args[1])
        memBlk = int(args[2])
        self.mgr.allocateMemory(fid, memStart, memBlk)
        print('Memory allocation complete')

    def do_quit(self, arg):
        'Quit the CLI and monitor'
        self.mgr.terminate()
        sleep(1)
        sys.exit(0)

mgr = CacheManager(MEMSIZE)

mgr.addStaticEntries()
mgr.start()

ManagerPrompt(mgr).cmdloop()