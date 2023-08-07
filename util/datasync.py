#!/usr/bin/python3

import os
import sys
import glob
import subprocess

REMOTE_LOCATION = "r4das@trolley.sysnet.ucsd.edu:~/activep4-data/"

BASE_DIR = os.path.realpath(os.environ['ACTIVEP4_SRC'])

assert BASE_DIR is not None

IGNORED_DIRS = ['ref', 'sde', 'legacy', 'config']

csv_files = glob.glob("{}/**/*.csv".format(BASE_DIR), recursive=True)

dirs_containing_csv = set()
sync_set = {}

for csv_file in csv_files:
    dirname = os.path.dirname(csv_file)
    relative_dirname = dirname[len(BASE_DIR):]
    path_rel = relative_dirname.split(os.sep)
    root_dir = path_rel[1]
    if root_dir in IGNORED_DIRS:
        continue
    dirs_containing_csv.add(root_dir)
    if root_dir not in sync_set:
        sync_set[root_dir] = []
    sync_set[root_dir].append(csv_file)

for dirname in dirs_containing_csv:
    print("Syncing {}".format(dirname))
    subprocess.run(["rsync", "-zarvm", "--include", "*/", "--include", "*.csv", "--exclude", "*", os.path.realpath(dirname), REMOTE_LOCATION])
