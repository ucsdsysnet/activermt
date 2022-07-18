#!/usr/bin/python3

import shutil
import glob
import re
import os

class EvaluationRefactor:

    def __init__(self):
        self.tree = [ 'elasticity', 'sharing', 'algorithm', 'params', 'repetitions' ]
        self.analysis = ['overlap', 'proportions', 'sequence', 'attempts', 'utilization', 'execution', 'allocations']
        self.treeOptions = {
            'elasticity'    : ['elastic', 'inelastic'],
            'sharing'       : ['shared', 'exclusive'],
            'algorithm'     : ['heuristic', 'randomized']
        }
        self.treeDefaults = {
            'elasticity'    : 'inelastic',
            'sharing'       : 'exclusive',
            'algorithm'     : 'heuristic'
        }
        self.paramRegex = {
            'iterations'    : re.compile('i[0-9]+'),
            'repetitions'   : re.compile('r[0-9]+'),
            'skewness'      : re.compile('p[0-9.]+')
        }

    def refactorMove(self, info, filename):
        paramIter = None
        paramSkew = None
        reps = None
        for col in info:
            matchIter = self.paramRegex['iterations'].match(col)
            matchReps = self.paramRegex['repetitions'].match(col)
            matchSkew = self.paramRegex['skewness'].match(col)
            paramIter = col if matchIter is not None else paramIter
            paramSkew = col if matchSkew is not None else paramSkew
            reps = col if matchReps is not None else reps
        pfx = 'evals'
        for i in range(0, len(self.tree)):
            if self.tree[i] in self.treeOptions:
                option = None
                for opt in self.treeOptions[self.tree[i]]:
                    if opt in info:
                        option = opt
                        break
                option = self.treeDefaults[self.tree[i]] if option is None else option
                try:
                    dirPath = os.path.join(pfx, option)
                    pfx = dirPath
                    if not os.path.exists(dirPath):
                        os.makedirs(dirPath)
                except OSError as error:
                    print(error)
            elif self.tree[i] == 'params' and paramIter is not None and paramSkew is not None:
                dirPath = os.path.join(pfx, "%s_%s" % (paramIter, paramSkew))
                pfx = dirPath
                try:
                    if not os.path.exists(dirPath):
                        os.makedirs(dirPath)
                except OSError as error:
                    print(error)
            elif self.tree[i] == 'repetitions' and reps is not None:
                dirPath = os.path.join(pfx, reps)
                pfx = dirPath
                try:
                    if not os.path.exists(dirPath):
                        os.makedirs(dirPath)
                except OSError as error:
                    print(error)
        dstPath = os.path.join(pfx, filename)
        shutil.move(filename, dstPath)
        print('%s -> %s' % (filename, dstPath))

refactorer = EvaluationRefactor()

artifacts = ['fig', 'png', 'mat']

for a in artifacts:
    files = glob.glob('*.%s' % a)
    for file in files:
        info = file.replace('.%s' % a, '').split('_')
        refactorer.refactorMove(info, file)