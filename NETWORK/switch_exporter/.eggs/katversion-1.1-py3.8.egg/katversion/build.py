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

"""Module that customises setuptools to install __version__ inside package."""

import sys
import os
import warnings
from distutils.command.build_py import build_py as DistUtilsBuildPy
# Ensure we override the correct sdist as setuptools monkey-patches distutils
if "setuptools" in sys.modules:
    from setuptools.command.sdist import log, sdist as OriginalSdist
else:
    from distutils.command.sdist import log, sdist as OriginalSdist

from .version import get_version  # noqa: E402 (confused by if-statement above)


def patch_init_py(init_py, version):
    """Patch __init__.py to remove version check and append hard-coded version."""
    # Open top-level __init__.py and read whole file
    log.info("patching %s to bake in version '%s'", init_py, version)
    with open(init_py, 'r+') as init_file:
        lines = init_file.readlines()
        # Search for sentinels indicating version checking block
        try:
            begin = lines.index("# BEGIN VERSION CHECK\n")
            end = lines.index("# END VERSION CHECK\n")
        except ValueError:
            begin = end = len(lines)
        # Delete existing repo version checking block in file. Add a baked-in
        # version string in its place (or at the end), unless already present
        # (this happens in pip sdist installs).
        init_file.seek(0)
        pre_lines = lines[:begin]
        post_lines = lines[end+1:]
        init_file.writelines(pre_lines)
        version_cmd = "__version__ = '{0}'\n".format(version)
        if version_cmd not in pre_lines and version_cmd not in post_lines:
            init_file.write("\n# Automatically added by katversion\n")
            init_file.write(version_cmd)
        init_file.writelines(post_lines)
        init_file.truncate()


class NewStyleDistUtilsBuildPy(DistUtilsBuildPy, object):
    """Turn old-style distutils class into new-style one to allow extension."""
    def run(self):
        DistUtilsBuildPy.run(self)


class AddVersionToInitBuildPy(NewStyleDistUtilsBuildPy):
    """Distutils build_py command that adds __version__ attr to __init__.py."""
    def run(self):
        # First do normal build (via super, so this can call custom builds too)
        super(NewStyleDistUtilsBuildPy, self).run()
        # Obtain distribution package version (set up via setuptools metadata)
        version = self.distribution.get_version()
        # Patch top-level __init__.py in all import packages
        for package, _, build_dir, _ in self.data_files:
            init_py = os.path.join(build_dir, '__init__.py')
            patch_init_py(init_py, version)


class NewStyleSdist(OriginalSdist, object):
    """Turn old-style distutils class into new-style one to allow extension."""
    def make_release_tree(self, base_dir, files):
        OriginalSdist.make_release_tree(self, base_dir, files)


class AddVersionToInitSdist(NewStyleSdist):
    """Distutils sdist command that adds __version__ attr to __init__.py."""
    def make_release_tree(self, base_dir, files):
        # First do normal sdist (via super, so this can call custom sdists too)
        super(NewStyleSdist, self).make_release_tree(base_dir, files)
        # Obtain distribution package version (set up via setuptools metadata)
        version = self.distribution.get_version()
        # We need build_py command for this as sdist is unaware of import packages
        build_py = self.get_finalized_command('build_py')
        # Patch __init__.py in source directories of all import packages
        for package, input_src_dir, _, _ in build_py.data_files:
            output_src_dir = os.path.join(base_dir, input_src_dir)
            # Ensure __init__.py is not hard-linked so that we don't change source
            dest = os.path.join(output_src_dir, '__init__.py')
            if hasattr(os, 'link') and os.path.exists(dest):
                os.unlink(dest)
                self.copy_file(os.path.join(input_src_dir, '__init__.py'), dest)
            # Patch top-level __init__.py
            patch_init_py(dest, version)


def setuptools_entry(dist, keyword, value):
    """Setuptools entry point for setting version and baking it into package."""
    # If 'use_katversion' is False, ignore the rest
    if not value:
        return
    # Enforce the version obtained by katversion, overriding user setting
    version = get_version()
    if dist.metadata.version is not None:
        s = "Ignoring explicit version='{0}' in setup.py, using '{1}' instead"
        warnings.warn(s.format(dist.metadata.version, version))
    dist.metadata.version = version

    # Extend build_py command to bake version string into installed package
    ExistingCustomBuildPy = dist.cmdclass.get('build_py', object)

    class KatVersionBuildPy(AddVersionToInitBuildPy, ExistingCustomBuildPy):
        """First perform existing build_py and then bake in version string."""
    dist.cmdclass['build_py'] = KatVersionBuildPy

    # Extend sdist command to bake version string into source package
    ExistingCustomSdist = dist.cmdclass.get('sdist', object)

    class KatVersionSdist(AddVersionToInitSdist, ExistingCustomSdist):
        """First perform existing sdist and then bake in version string."""
    dist.cmdclass['sdist'] = KatVersionSdist
