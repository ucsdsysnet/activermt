import socket
import copy
import threading
import sys
import signal

from active_app_base import *

class ActiveP4RedisClient(ActiveApplication):
    
    def __init__(self, active_enable=True, proxy_host="127.0.0.1", debug=False) -> None:
        self.OK = 0
        self.ERROR = 1
        self.UNKNOWN = 2
        self.ACTIVE_EN = active_enable
        self.DEBUG = debug
        self.HOST = proxy_host
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
            },
            'DUMMY' : {
                'file'  : [ 'dummy.apo', 'dummy.args.csv' ],
                'code'  : None,
                'args'  : {}
            }
        }
        self.th = None
        self.seq = 0

    def runProxy(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(("0.0.0.0", self.PORT))
            s.listen()
            while True:
                conn, addr = s.accept()
                with conn:
                    print(addr)
                    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as t:
                        t.connect((self.REDIS_HOST, self.REDIS_PORT))
                        while True:
                            data = conn.recv(1024)
                            if self.DEBUG:
                                print(data)
                            if not data:
                                break
                            # modify data from client
                            if self.ACTIVE_EN:
                                data = self.filterActiveProgram(data)
                                if self.DEBUG:
                                    print(data)
                                t.sendall(data[1])
                            else:
                                t.sendall(data)
                            resp = t.recv(1024)
                            if not resp:
                                break
                            if self.ACTIVE_EN:
                                conn.sendall(data[0] + resp)
                            else:
                                conn.sendall(resp)
    
    def bgProxy(self, bind_addr=None):
        if bind_addr is not None:
            self.HOST = bind_addr
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

    def set(self, key, value):
        args = [
            ('KEY', key),
            ('VALUE', value),
            ('MASK', self.mask),
            ('OFFSET', self.offset)
        ]
        if self.ACTIVE_EN:
            pktbytes = self.buildActiveProgram('WRITE', args) + self.buildCommand("set", key, value)
        else:
            pktbytes = self.buildCommand("set", key, value)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.HOST, self.PORT))
            s.sendall(pktbytes)
            data = s.recv(1024)
            if self.ACTIVE_EN:
                data = self.filterActiveProgram(data)
                return self.parseResponse(data[1])
            else:
                return self.parseResponse(data)

    def get(self, key):
        args = [
            ('KEY', key),
            ('MASK', self.mask),
            ('OFFSET', self.offset)
        ]
        if self.ACTIVE_EN:
            #pktbytes = self.buildActiveProgram('READ', args) + self.buildCommand("get", key)
            pktbytes = self.buildActiveProgram('DUMMY', args) + self.buildCommand("get", key)
        else:
            pktbytes = self.buildCommand("get", key)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.HOST, self.PORT))
            s.sendall(pktbytes)
            data = s.recv(1024)
            if self.ACTIVE_EN:
                data = self.filterActiveProgram(data)
                return self.parseResponse(data[1])
            else:
                return self.parseResponse(data)

def sighandler(sig, frame):
    print("Exiting")
    sys.exit(0)

signal.signal(signal.SIGINT, sighandler)

isActiveEnabled = True
isDebugEnabled = True

if len(sys.argv) > 1:
    if sys.argv[1] == 'proxy':
        client = ActiveP4RedisClient(active_enable=isActiveEnabled, debug=isDebugEnabled)
        print("proxy mode")
        bind_addr = sys.argv[2] if len(sys.argv) > 2 else None
        client.bgProxy(bind_addr)
    else:
        client = ActiveP4RedisClient(active_enable=isActiveEnabled, proxy_host=sys.argv[1], debug=isDebugEnabled)
        # result = client.set("key1", "value1")
        # print(result)
        result = client.get("key01")
        print(result)
else:
    print("Using localhost proxy")
    client = ActiveP4RedisClient(active_enable=isActiveEnabled, debug=isDebugEnabled)
    # result = client.set("key1", "value1")
    # print(result)
    result = client.get("key01")
    print(result)