# ros-builder

Build script to build [ROS](http://www.ros.org/) from source on Ubuntu (and probably Debian).
The script installs required packages, grabs ROS sources, builds and installs ROS.
Basically as described on the [ROS wiki](http://wiki.ros.org/indigo/Installation/Source) with some minor alterations.

*Note that the compiling ROS requires a lot of dependencies.* So it is likely that the script fails to build ROS due to missing dependencies. This is not a problem, except you need to find teh correct (Ubuntu) packages that fullfills the requirement.

The script does not use [`rosdep`](http://wiki.ros.org/rosdep) to install the required dependencies.
I feel that it installs far too much (unrequired) packages, which I personally do not like.
Big disadvantage is that one has to manually find out what packages are missing, which might take some time.

When rerunning the script (e.g. after installing a missing package) adding `-U` flag prevents updating the sources, which decrease the build times (considerably, depending on your internet speed).

## Installation

The script can be obtained by [downloading ](https://raw.githubusercontent.com/veger/ros-builder/master/ros-builder.sh) it or by cloning this repository.

It does not really matter where to put it, as it is (probably) used only once, it does not make snese to 'install' it by putting it in `/usr/bin`.

Assuming you have the script in the current directory use the following to show the scripts help:

```
$ ./ros-install.sh -h
Usage: ros-builder.sh [-hcUv] [-a ARCHITECTURE] [-b BUILD_DIR] [-d ROS_DISTRIBUTION] [-i INSTALL_DIR] [-t INSTALLATION_VARIANT]
Create or update installation directory from source, install dependencies and (re)build ROS.
If INSTALL_VARIANT is not provided, it is guessed from the build location (if a build already exists).
  -2 use 2-steps, first building then installing, instead of one.
  -a specify library architecture, for multi-arch systems.
  -b specify the build directory.
  -c cleanup after execution (removes *all* installed packages during *this* execution of the script).
  -d selects which ROS distribution is used.
  -h displays this help and exit.
  -i specify the installation directory.
  -t type (variant) of installation, most common types are desktop_full, desktop (recommended) or ros-base
     Note that when updating an exiting build with a different type might break the build/installation.
  -U do not update sources, only rebuild ROS installation from existing build directory.
  -v verbose mode. Prints paths that are going to be used and waits until user accepts.
```
<sup>(Note that the actual help output is slightly more explaining)</sup>

## Tested

The scripts should (might!) work on all Ubuntu (-based) systems with all ROS versions, but it is actually tested with:
 * 64-bit Kubuntu 14.10 with indigo (ros_comm variant)

 Please let me know when you have (sucessfully) use the script on/with any (other) OS, ROS version or variant.
