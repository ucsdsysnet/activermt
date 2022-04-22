################################################################################
# BAREFOOT NETWORKS CONFIDENTIAL & PROPRIETARY
#
# Copyright (c) 2018-2019 Barefoot Networks, Inc.

# All Rights Reserved.
#
# NOTICE: All information contained herein is, and remains the property of
# Barefoot Networks, Inc. and its suppliers, if any. The intellectual and
# technical concepts contained herein are proprietary to Barefoot Networks,
# Inc.
# and its suppliers and may be covered by U.S. and Foreign Patents, patents in
# process, and are protected by trade secret or copyright law.
# Dissemination of this information or reproduction of this material is
# strictly forbidden unless prior written permission is obtained from
# Barefoot Networks, Inc.
#
# No warranty, explicit or implicit is provided, unless granted under a
# written agreement with Barefoot Networks, Inc.
#
#
###############################################################################


"""
PTF foundational class for a P4_16 program, using BRI

This class needs to be customized for a given program for now by:
   1. Adding "shortcuts" for the tables that will be accessed by the tests (and
      thus have to be cleaned as a result).
   2. Adding proper annotations for the fields that are MAC, IPv4 or IPv6
      addresses

All individual tests can be  subclassed from either from the this base class
(P4ProgramTest) or its subclasses if necessary.

The easiest way to write a test for a program my_program.p4 is:
   1. Copy this file into the ptf-tests directory as my_program.py
   2. Customize the setUp() method with the lists of tables the test will need
   3. Create individual test files that start with the line

      from my_program import *

   4. Subclass individual test classes from P4ProgramTest
   5. Only define runTest() method for those classes
"""


######### STANDARD MODULE IMPORTS ########
from __future__ import print_function
import unittest
import logging
import grpc
import pdb
import copy
from scapy.all import *

######### PTF modules for BFRuntime Client Library APIs #######
import ptf
from ptf.testutils import *
from bfruntime_client_base_tests import BfRuntimeTest
import bfrt_grpc.bfruntime_pb2 as bfruntime_pb2
import bfrt_grpc.client as gc

########## Basic Initialization ############
class P4ProgramTest(BfRuntimeTest):
    # The setUp() method is used to prepare the test fixture. Typically
    # you would use it to establich connection to the gRPC Server
    #
    # You can also put the initial device configuration there. However,
    # if during this process an error is encountered, it will be considered
    # as a test error (meaning the test is incorrect),
    # rather than a test failure
    #
    # Here is the stuff we set up that is ready to use
    #  client_id
    #  p4_name
    #  bfrt_info
    #  dev
    #  dev_tgt
    #  allports
    #  tables    -- the list of tables
    #     Individual tables of the program with short names
    #     ipv4_host
    #     ipv4_lpm
    def setUp(self, tableSetUp=None):
        self.client_id = 0

        # Use your own program name below
        self.p4_name   = test_param_get('p4_name', '')

        self.dev       = 0
        self.dev_tgt   = gc.Target(self.dev, pipe_id=0xFFFF)

        print('\n')
        print('Test Setup')
        print('==========')

        BfRuntimeTest.setUp(self, self.client_id, self.p4_name)

        # This is the simple case when you run only one program on the target.
        # Otherwise, you might have to retrieve multiple bfrt_info objects and
        # in that case you will need to specify program name as a parameter
        self.bfrt_info = self.interface.bfrt_info_get()

        print('    Connected to Device: {}, Program: {}, ClientId: {}'.format(
            self.dev, self.p4_name, self.client_id))

        # Create a list of all ports available on the device
        self.swports = []
        for (device, port, ifname) in ptf.config['interfaces']:
            self.swports.append(port)
        self.swports.sort()
        # print('Interfaces:', ptf.config['interfaces'])
        print('    SWPorts:', self.swports)

        # Understand what are we running on
        self.arch   = test_param_get('arch')
        self.target = test_param_get('target')

        if self.arch == 'tofino':
            self.dev_prefix = 'tf1'
            self.dev_config = {
                'num_pipes'         : 4,
                'eth_cpu_port_list' : [64, 65, 66, 67],
                'pcie_cpu_port'     : 320
            }
        elif self.arch == 'tofino2':
            self.dev_prefix = 'tf2'
            self.dev_config = {
                'num_pipes'         : 4,
                'eth_cpu_port_list' : [2, 3, 4, 5],
                'pcie_cpu_port'     : 0
            }

        try:
            self.dev_conf_tbl = self.bfrt_info.table_get('device_configuration')
            conf_tbl_prefix = self.dev_conf_tbl.info.name.split('.')[0]

            # Check that there is no mismatch
            if conf_tbl_prefix != self.dev_prefix:
                print("""
                      ERROR: You requested to run the test on '{}',
                             but the device {} only has '{}' tables in it.

                             Add '--arch {}' parameter to the command line.
                      """.format(self.dev_prefix,
                                 self.dev,
                                 conf_tbl_prefix,
                                 {'tf1':'tofino', 'tf2':'tofino2'}[
                                     conf_tbl_prefix]))
                self.assertTrue(False)
                quit()

            # Get the device configuration (default entry)
            resp = self.dev_conf_tbl.default_entry_get(self.dev_tgt)
            for data, _ in resp:
                self.dev_config = data.to_dict()
                break
        except KeyError:
            # Older SDE (before 9.5.0)
            pass

        #
        # This is a couple of convenient shortcuts, but you can add more
        self.cpu_eth_port  = self.dev_config['eth_cpu_port_list'][0]
        self.cpu_pcie_port = self.dev_config['pcie_cpu_port']

        # print('Device Configuration:')
        # for k in self.dev_config:
        #    print('{:>40s} : {}'.format(k, self.dev_config[k]))

        # Since this class is not a test per se, we can use the setup method
        # for common setup. For example, we can have our tables and annotations
        # ready

        self.tables = []

        # The function table_setup() can be passed in to perform the
        # program-specific test customization as described below
        if tableSetUp is not None:
            tableSetUp()

        # Program-specific customization. This would typically be 'shortcuts'
        # to the tables, used by the program and creating proper annotations for
        # the fields with specialized types, such as MAC, IPv4 or IPv6 addresses
        #
        # Example (from simple_l3.p4):
        #
        # self.ipv4_host = self.bfrt_info.table_get('Ingress.ipv4_host')
        # self.ipv4_host.info.key_field_annotation_add(
        #     'hdr.ipv4.dst_addr', 'ipv4')
        #
        # self.ipv4_lpm = self.bfrt_info.table_get('Ingress.ipv4_lpm')
        # self.ipv4_lpm.info.key_field_annotation_add(
        #     'hdr.ipv4.dst_addr', 'ipv4')
        #
        # self.tables = [ self.ipv4_host, self.ipv4_lpm]

        # Before the test can be started, it needs to ensre that the system is
        # in a known (clean) state
        self.cleanUp()

    # Use tearDown() method to return the DUT to the initial state by cleaning
    # all the configuration and clearing up the connection
    def tearDown(self):
        print('\n')
        print('Test TearDown:')
        print('==============')

        self.cleanUp()

        # Call the Parent tearDown
        BfRuntimeTest.tearDown(self)

    # Use Cleanup Method to clear the tables before and after the test starts
    # (the latter is done as a part of tearDown()
    def cleanUp(self):
        print('\n')
        print('Table Cleanup:')
        print('==============')

        try:
            for t in self.tables:
                print('  Clearing Table {}'.format(t.info.name_get()))

                # Empty list of keys means 'all entries'
                t.entry_del(self.dev_tgt, [])

                # Not all tables support default entry
                try:
                    t.default_entry_reset(self.dev_tgt)
                except:
                    pass
        except Exception as e:
            print('Error cleaning up: {}'.format(e))

    #
    # This is a simple helper method that takes a list of entries and programs
    # them in a specified table
    #
    # Each entry is a tuple, consisting of 3 elements:
    #  key         -- a list of tuples for each element of the key
    #  action_name -- the action to use. Must use full name of the action
    #  data        -- a list (may be empty) of the tuples for each action
    #                 parameter
    #
    def programTable(self, table, entries, target=None):
        if target is None:
            target = self.dev_tgt

        key_list=[]
        data_list=[]
        for k, a, d in entries:
            key_list.append(table.make_key([gc.KeyTuple(*f)   for f in k]))
            data_list.append(table.make_data([gc.DataTuple(*p) for p in d], a))
        table.entry_add(target, key_list, data_list)

#
# Individual tests can now be subclassed from P4ProgramTest
#
