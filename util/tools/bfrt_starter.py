#!/usr/bin/python3

import os
import sys
import pdb

#
# This is optional if you use proper PYTHONPATH
#
SDE_INSTALL   = os.environ['SDE_INSTALL']
SDE_PYTHON2   = os.path.join(SDE_INSTALL, 'lib', 'python2.7', 'site-packages')
sys.path.append(SDE_PYTHON2)
sys.path.append(os.path.join(SDE_PYTHON2, 'tofino'))

PYTHON3_VER   = '{}.{}'.format(
    sys.version_info.major,
    sys.version_info.minor)
SDE_PYTHON3   = os.path.join(SDE_INSTALL, 'lib', 'python' + PYTHON3_VER,
                             'site-packages')
sys.path.append(SDE_PYTHON3)
sys.path.append(os.path.join(SDE_PYTHON3, 'tofino'))
sys.path.append(os.path.join(SDE_PYTHON3, 'tofino', 'bfrt_grpc'))

# Here is the most important module
import bfrt_grpc.client as gc

#
# Connect to the BF Runtime Server
#
for bfrt_client_id in range(10):
    try:
        interface = gc.ClientInterface(
            grpc_addr = 'localhost:50052',
            client_id = bfrt_client_id,
            device_id = 0,
            num_tries = 1)
        print('Connected to BF Runtime Server as client', bfrt_client_id)
        break;
    except:
        print('Could not connect to BF Runtime server')
        quit

#
# Get the information about the running program
#
bfrt_info = interface.bfrt_info_get()
print('The target runs the program ', bfrt_info.p4_name_get())

#
# Establish that you are using this program on the given connection
#
if bfrt_client_id == 0:
    interface.bind_pipeline_config(bfrt_info.p4_name_get())

################### You can now use BFRT CLIENT ###########################

# This is just an example. Put in your own code
from tabulate import tabulate

# Print the list of tables in the "pipe" node
dev_tgt = gc.Target(0)

data = []
for name in bfrt_info.table_dict.keys():
    if name.split('.')[0] == 'pipe':
        # pdb.set_trace()
        t = bfrt_info.table_get(name)
        table_name = t.info.name_get()
        if table_name != name:
            continue
        table_type = t.info.type_get()
        try:
            result = t.usage_get(dev_tgt)
            table_usage = next(result)
        except:
            table_usage = 'n/a'
        table_size = t.info.size_get()
        data.append([table_name, table_type, table_usage, table_size])
print(tabulate(data, headers=['Full Table Name','Type','Usage','Capacity']))

############################## FINALLY ####################################

# print("The End")
