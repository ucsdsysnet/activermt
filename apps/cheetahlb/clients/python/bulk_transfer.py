import socket
import os
import sys
import signal

sys.path.append(os.path.join(os.environ['ACTIVEP4_SRC'], 'apps', '_common'))

from active_app_base import *

class ActiveP4AggClient(ActiveApplication):

    def __init__(self, active_enable=True, debug=False):
        self.ACTIVE_EN = active_enable
        self.DEBUG = debug
        self.PORT = 1234
        self.datasize = int(100)
        self.fid = 1
        self.th = None

    def send(self, hostname, filename):
        with open(filename, 'w') as out:
            data = []
            for i in range(0, self.datasize):
                data.append('record %d' % i)
            out.write("\n".join(data))
            out.close()
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((hostname, self.PORT))
            with open(filename) as f:
                #data = bytes(f.read(), 'utf-8')
                data = f.read().splitlines()
                for d in data:
                    row = bytes(d, 'utf-8')
                    s.sendall(row)
                f.close()
            s.close()
            #data = s.recv(1024)

    def recv(self, bind_addr="0.0.0.0"):
        print('[Listening on %d]' % self.PORT)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind((bind_addr, self.PORT))
            s.listen()
            while True:
                conn, addr = s.accept()
                with conn:
                    print(addr)
                    while True:
                        data = conn.recv(1024)
                        if not data:
                            break
                    conn.sendall(b'')
                print('connection terminated')

def sighandler(sig, frame):
    print("Exiting")
    sys.exit(0)

signal.signal(signal.SIGINT, sighandler)

isActiveEnabled = True
isDebugEnabled = True

client = ActiveP4AggClient()

if len(sys.argv) < 2:
    print('Usage: %s <hostname>|receiver' % sys.argv[0])
    sys.exit(1)

if sys.argv[1] == 'receiver':
    client.recv(bind_addr="10.0.2.2")
elif len(sys.argv) < 3:
    print('Usage: %s <hostname> <filename>' % sys.argv[0])
else:
    client.send(sys.argv[1], sys.argv[2])