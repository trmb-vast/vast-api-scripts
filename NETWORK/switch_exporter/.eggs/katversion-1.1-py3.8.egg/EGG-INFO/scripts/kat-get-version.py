#!python

################################################################################
# Copyright (c) 2014-2020, National Research Foundation (Square Kilometre Array)
#
# Licensed under the BSD 3-Clause License (the "License"); you may not use
# this file except in compliance with the License. You may obtain a copy
# of the License at
#
#   https://opensource.org/licenses/BSD-3-Clause
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

"""Script to get the current version string of a Python package."""

import os
import argparse

from katversion import get_version


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-p', '--path', dest='path', action='store',
                        help='Path of SCM checkout. If not given the'
                             ' current directory is used.')
    args = parser.parse_args()

    if args.path:
        path = args.path
    else:
        # If path was not given us the current working directory. This is the
        # way git smudge uses this file.
        path = os.getcwd()
    print(get_version(path))
