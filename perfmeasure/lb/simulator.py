#!/usr/bin/python

import random
import math

class Simulator:
    
    def __init__(self):
        self.LINK_RATE_US = 10E3 / 8
        self.MIN_SW_TIME_US = 0.6
        self.MIN_PKT_SIZE = 264
        self.MTU = 1500
        self.CHAIN_LENGTH = 3
        self.NUM_WORDS = 8192
        self.KEY_WIDTH = 16
        self.flowSizeDist = None
        self.INTER_ARRIVAL_US = 0
        self.SW_DELAY_FACTOR = 2

    def simulateLRUImpact(self, flowDistFile, outputPrefix, expDurationSecs=10, linkRateGbps=10, chainLength=3):
        with open('flowdists/%s' % flowDistFile) as f:
            self.flowSizeDist = f.read().splitlines()[1:]
            self.flowSizeDist = [ int(x) for x in self.flowSizeDist ]
            f.close()
        self.LINK_RATE_US = linkRateGbps * 1E3 / 8
        self.CHAIN_LENGTH = chainLength
        expElapsedUs = 0
        expDurationUsecs = expDurationSecs * 1E6
        KEY_MAX = (2 << self.KEY_WIDTH) - 1
        occupied = [0] * self.CHAIN_LENGTH * self.NUM_WORDS
        fctsCompleted = []
        fctsDelayed = []
        numDroppedFlows = 0
        numCompletedFlows = 0
        numDelayedFlows = 0
        chainTraversals = {}
        for i in range(0, self.CHAIN_LENGTH):
            chainTraversals[i] = 0
        random.seed()
        while expElapsedUs < expDurationUsecs:
            flowId = random.randint(1, KEY_MAX)
            flowSize = self.flowSizeDist[random.randint(0, len(self.flowSizeDist) - 1)]
            flowSize = flowSize + math.ceil(flowSize / self.MTU) * self.MIN_PKT_SIZE
            fct = expElapsedUs + (flowSize / self.LINK_RATE_US) + self.MIN_SW_TIME_US
            memChain = flowId % self.NUM_WORDS
            inserted = False
            for i in range(0, self.CHAIN_LENGTH):
                memIndex = memChain * self.CHAIN_LENGTH + i
                if occupied[ memIndex ] == 0:
                    occupied[ memIndex ] = fct
                    inserted = True
                    numCompletedFlows = numCompletedFlows + 1
                    fctsCompleted.append( (flowSize / self.LINK_RATE_US) + self.MIN_SW_TIME_US )
                    break
            if not inserted:
                for i in range(0, self.CHAIN_LENGTH):
                    memIndex = memChain * self.CHAIN_LENGTH + i
                    if occupied[memIndex] < expElapsedUs:
                        occupied[memIndex] = fct
                        inserted = True
                        numDelayedFlows = numDelayedFlows + 1
                        fctsDelayed.append( (flowSize / self.LINK_RATE_US) + self.SW_DELAY_FACTOR * self.MIN_SW_TIME_US )
                        break
                chainTraversals[i] = chainTraversals[i] + 1
            if not inserted:
                numDroppedFlows = numDroppedFlows + 1
            expElapsedUs = expElapsedUs + (flowSize / self.LINK_RATE_US) + self.INTER_ARRIVAL_US
        print '%d flows completed / %d flows delayed / %d flows dropped' % (numCompletedFlows, numDelayedFlows, numDroppedFlows)
        print 'chain traversal hist', chainTraversals
        with open('data/results_%s_completed_%dG_%dS.csv' % (outputPrefix, linkRateGbps, expDurationSecs), 'w') as out:
            buffer = [ str(x) for x in fctsCompleted ]
            out.write('\n'.join(buffer))
            out.close()
        with open('data/results_%s_delayed_%dG_%dS.csv' % (outputPrefix, linkRateGbps, expDurationSecs), 'w') as out:
            buffer = [ str(x) for x in fctsDelayed ]
            out.write('\n'.join(buffer))
            out.close()
        return [ numCompletedFlows, numDelayedFlows, numDroppedFlows ]

# instance of experiment

dists = {
    'web'       : 'flowDist_fb1.txt',
    'cache'     : 'flowDist_fb2.txt',
    'hadoop'    : 'flowDist_fb3.txt'
}

"""for dist in dists:
    flowSizeDist = []
    with open('flowdists/%s' % dists[dist]) as f:
        flowSizeDist = f.read().splitlines()[1:]
        flowSizeDist = [ int(x) for x in flowSizeDist ]
        f.close()
    print 'mean flowsize for dist %s = %d' % ( dist, sum(flowSizeDist) / len(flowSizeDist) )"""

#linkRates = [ 10, 40, 100 ]
linkRates = [ 3200 ]
expDurationSecs = 1
maxChainLength = 3

sim = Simulator()

sim.simulateLRUImpact('flowDist_fb1_short.txt', 'web', 3200, expDurationSecs, maxChainLength)

"""buffer = []
for dist in dists:
    for speed in linkRates:
        for chainLength in range(0, maxChainLength):
            distFile = dists[dist]
            result = sim.simulateLRUImpact(distFile, dist, expDurationSecs, speed, chainLength + 1)
            result = result + [ dist, speed, chainLength ]
            buffer.append(','.join([ str(x) for x in result ]))

with open('data/results_combined_%ds.csv' % expDurationSecs, 'w') as out:
    out.write('\n'.join(buffer))
    out.close()"""