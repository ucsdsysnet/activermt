import socket

class ActiveP4RedisClient:
    
    def __init__(self) -> None:
        self.OK = 0
        self.ERROR = 1
        self.UNKNOWN = 2
        self.HOST = "127.0.0.1"
        self.PORT = 6379

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
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.HOST, self.PORT))
            s.sendall(self.buildCommand("set", key, value))
            data = s.recv(1024)
            return self.parseResponse(data)

    def get(self, key):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.HOST, self.PORT))
            s.sendall(self.buildCommand("get", key))
            data = s.recv(1024)
            return self.parseResponse(data)

client = ActiveP4RedisClient()

result = client.set("key1", "value1")
print(result)

result = client.get("key1")
print(result)