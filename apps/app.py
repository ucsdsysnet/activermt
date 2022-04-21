import socket
import copy
import threading
import sys
import signal
from scapy.packet import Packet
from scapy.fields import *

class ActiveIH(Packet):
    name = "ActiveIH"
    fields_desc = [
        IntField("ACTIVEP4", 0x12345678),
        ShortField("flags", 0),
        ShortField("fid", 0),
        ShortField("acc", 0),
        ShortField("acc2", 0),
        ShortField("data", 0),
        ShortField("data2", 0)
    ]

class ActiveInstruction(Packet):
    name = "ActiveInstruction"
    fields_desc = [
        ByteField("goto", 0), # also has flags
        ByteField("opcode", 0),
        ShortField("arg", 0)
    ]

class ActiveP4RedisClient:
    
    def __init__(self) -> None:
        self.OK = 0
        self.ERROR = 1
        self.UNKNOWN = 2
        self.HOST = "127.0.0.1"
        self.PORT = 6378
        self.REDIS_HOST = "127.0.0.1"
        self.REDIS_PORT = 6379
        self.fid = 1
        self.mask = 0xFFFF
        self.offset = 0x0
        self.activesrc = {
            'READ'  : {
                'file'  : [ 'cacheread.apo', 'cacheread.args.csv' ],
                'code'  : None,
                'args'  : {}
            },
            'WRITE' : {
                'file'  : [ 'cachewrite.apo', 'cachewrite.args.csv' ],
                'code'  : None,
                'args'  : {}
            }
        }
        self.th = None

    def filterActiveProgram(self, data):
        data = data[12:]
        idx = 1
        opcode = 0x0
        while opcode != 0x1:
            opcode = data[idx]
            idx = idx + 4
        return (data[:idx - 1], data[idx - 1:])

    def runProxy(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(("0.0.0.0", 6378))
            s.listen()
            while True:
                conn, addr = s.accept()
                with conn:
                    print(addr)
                    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as t:
                        t.connect((self.REDIS_HOST, self.REDIS_PORT))
                        while True:
                            data = conn.recv(1024)
                            if not data:
                                break
                            # modify data from client
                            data = self.filterActiveProgram(data)
                            t.sendall(data[1])
                            resp = t.recv(1024)
                            if not resp:
                                break
                            conn.sendall(data[0] + resp)
    
    def bgProxy(self):
        self.th = threading.Thread(target=self.runProxy)
        self.th.start()
        self.th.join()

    def buildCommand(self, cmd, key, value=None):
        req = [cmd, key] if value is None else [cmd, key, value]
        buf = [ "*%d" % len(req) ]
        for r in req:
            buf.append("$%d" % len(r))
            buf.append(r)
        reqStr = "\r\n".join(buf) + "\r\n"
        return bytes(reqStr, 'utf-8')

    def parseResponse(self, resp):
        resp = str(resp, 'utf-8')
        if resp[0] == '+':
            tok = resp[1:].split("\r\n")
            return (self.OK, tok[0])
        elif resp[0] == '-':
            tok = resp[1:].split("\r\n")
            print(resp)
            return (self.ERROR, tok[0])
        elif resp[0] == '$':
            tok = resp[1:].split("\r\n")
            return (self.OK, tok[1])
        else:
            print(resp)
            return (self.UNKNOWN, None)

    def buildActiveProgram(self, program, args):
        if program not in self.activesrc:
            return None
        if self.activesrc[program]['code'] == None:
            with open(self.activesrc[program]['file'][0]) as f:
                self.activesrc[program]['code'] = bytes(f.read(), 'utf-8')
                f.close()
            with open(self.activesrc[program]['file'][1]) as f:
                args = f.read().strip().splitlines()
                for a in args:
                    arg = a.split(',')
                    self.activesrc[program]['args'][arg[0]] = int(arg[1])
                f.close()
        activecode = copy.deepcopy(self.activesrc[program]['code'])
        for a in args:
            arg = a[0]
            val = a[1]
            if arg in self.activesrc[program]['args']:
                idx = self.activesrc[program]['args'][arg]
                activecode[idx * 4 + 2] = bytes(chr(val >> 8))
                activecode[idx * 4 + 3] = bytes(chr(val))
        pktbytes = bytes(ActiveIH(fid=self.fid)) + activecode
        return pktbytes

    def set(self, key, value):
        args = [
            ('KEY', key),
            ('VALUE', value),
            ('MASK', self.mask),
            ('OFFSET', self.offset)
        ]
        pktbytes = self.buildActiveProgram('WRITE', args) + self.buildCommand("set", key, value)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.HOST, self.PORT))
            s.sendall(pktbytes)
            #s.sendall(self.buildCommand("set", key, value))
            data = s.recv(1024)
            data = self.filterActiveProgram(data)
            return self.parseResponse(data[1])

    def get(self, key):
        args = [
            ('KEY', key),
            ('MASK', self.mask),
            ('OFFSET', self.offset)
        ]
        pktbytes = self.buildActiveProgram('READ', args) + self.buildCommand("get", key)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.HOST, self.PORT))
            s.sendall(pktbytes)
            #s.sendall(self.buildCommand("get", key))
            data = s.recv(1024)
            data = self.filterActiveProgram(data)
            return self.parseResponse(data[1])

client = ActiveP4RedisClient()

def sighandler(sig, frame):
    print("Exiting")
    sys.exit(0)

signal.signal(signal.SIGINT, sighandler)

if len(sys.argv) > 1 and sys.argv[1] == 'proxy':
    print("proxy mode")
    client.bgProxy()
else:
    result = client.set("key1", "value1")
    print(result)
    result = client.get("key1")
    print(result)