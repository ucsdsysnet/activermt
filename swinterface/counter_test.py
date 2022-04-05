import time

MULFACTORGIGA = 1024 * 1024 * 1024

currDataRate = 0
lastCount = 0
then = time.time()
while True:
    cnt = p4_pd.counter_read_traffic(2, from_hw)
    now = time.time()
    elapsed = now - then
    then = now
    datarate = (cnt.bytes - lastCount) / elapsed
    drateGbps = round(datarate * 8 / 1E9)
    lastCount = cnt.bytes
    #print("data rate is %d Gbps" % drateGbps)
    if drateGbps != currDataRate:
        print("data rate changed to %d Gbps" % drateGbps)
        currDataRate = drateGbps
    time.sleep(1)

#print("%f seconds elapsed" % elapsed)