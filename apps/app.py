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
        self.activesrc = {
            'READ'  : {
                'file'  : 'cache_read_req.csv',
                'code'  : None
            },
            'WRITE' : {
                'file'  : 'cache_write.csv',
                'code'  : None
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
        return data[idx - 1:]

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
                            t.sendall(data)
                            resp = t.recv(1024)
                            if not resp:
                                break
                            conn.sendall(resp)
    
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
            with open(self.activesrc[program]['file']) as f:
                code = f.read().splitlines()
                self.activesrc[program]['code'] = []
                for c in code:
                    self.activesrc[program]['code'].append([ int(x) for x in c.split(",") ])
                f.close()
        activecode = copy.deepcopy(self.activesrc[program]['code'])
        for a in args:
            activecode[a[0]][2] = a[1]
        pktbytes = bytes(ActiveIH(fid=self.fid))
        for i in range(0, len(activecode)):
            pktbytes = pktbytes + bytes(ActiveInstruction(goto=activecode[i][0], opcode=activecode[i][1], arg=activecode[i][2]))
        return pktbytes

    def set(self, key, value):
        args = ()
        pktbytes = self.buildActiveProgram('WRITE', args) + self.buildCommand("set", key, value)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.HOST, self.PORT))
            s.sendall(pktbytes)
            #s.sendall(self.buildCommand("set", key, value))
            data = s.recv(1024)
            return self.parseResponse(data)

    def get(self, key):
        args = ()
        pktbytes = self.buildActiveProgram('READ', args) + self.buildCommand("get", key)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.HOST, self.PORT))
            s.sendall(pktbytes)
            #s.sendall(self.buildCommand("get", key))
            data = s.recv(1024)
            return self.parseResponse(data)

client = ActiveP4RedisClient()

def sighandler(sig, frame):
    print("Exiting")
    sys.exit(0)

signal.signal(signal.SIGINT, sighandler)

if len(sys.argv) > 1 and sys.argv[1] == 'proxy':
    print("proxy mode")
    client.bgProxy()
else:
    #result = client.set("key1", "value1")
    #print(result)
    result = client.get("key1")
    print(result)