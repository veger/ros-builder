#! /bin/bash
#
# Build script to build ROS from source on Ubuntu (and probably Debian)
# The script installs required packages, grabs ROS sources, builds and installs ROS
# 
# The ROS version (among other things) can be provided using the scripts arguments.
#
# See https://github.com/veger/ros-builder for more information

set -e
if [ $EUID -eq 0 ]; then
  echo "${0##*/} must not be run as root" 1>&2
  exit 1
fi

CURRENT_DIR=$(pwd)
CLEANUP=0
BUILD_DIR=
ROS_DISTRO=indigo
VERBOSE=0
NO_UPDATE=0
TWO_STEPS=0
INSTALL_DIR=
INSTALL_TYPE=
INSTALLED_PACKAGES=
LIBRARY_ARCHITECTURE=$(dpkg-architecture -qDEB_BUILD_MULTIARCH)
OS_DISTRO=$(lsb_release -sc)

trap cleanup EXIT

usage() {
  cat << EOF
Usage: ${0##*/} [-hcUv] [-a ARCHITECTURE] [-b BUILD_DIR] [-d ROS_DISTRIBUTION] [-i INSTALL_DIR] [-t INSTALLATION_VARIANT]
Create or update installation directory from source, install dependencies and (re)build ROS
If INSTALL_VARIANT is not provided, it is guessed from the build location (if a build already exists)
    -2 use 2-steps, first building then installing, instead of one. Building without installing is faster (convenient when building fails due to missing packages), but installing afterwards takes additional time.
    -a specify library architecture, for multi-arch systems (current: $LIBRARY_ARCHITECTURE)
    -b specify the build directory (current: build/ros_<ROS_DISTRIBUTION>_catkin_ws/)
    -c cleanup after execution (removes *all* installed packages during *this* execution of the script)
    -d selects which ROS distribution is used (current: $ROS_DISTRO)
    -h displays this help and exit
    -i specify the installation directory (current: $ROS_DISTRO)
    -t type (variant) of installation, most common types are desktop_full, desktop (recommended) or ros-base
       Note that when updating an exiting build with a different type might break the build/installation.
    -U do not update sources, only rebuild ROS installation from existing build directory.
    -v verbose mode. Prints paths that are going to be used and waits until user accepts.
EOF
  exit 0
}

# $1 "keep" to keep packages (i.e. not getting added to INSTALLED_PACKAGES), otherwise first package of list
# $2 list of packages that need to be installed
install() {
  local KEEP=$1
  [ "$KEEP" = "keep" ] && shift
  local PACKAGES_TO_INSTALL=
  for PACKAGE in $*; do
    if [ $(dpkg-query -W --showformat='${Status}\n' $PACKAGE 2>/dev/null | grep -c "install ok installed") -eq 0 ]; then
      PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $PACKAGE"
    fi
  done
  if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "Installing $PACKAGES_TO_INSTALL"
    if [ "$KEEP" != "keep" ]; then
      INSTALLED_PACKAGES="$INSTALLED_PACKAGES $PACKAGES_TO_INSTALL"
    fi
    sudo apt-get install -y $PACKAGES_TO_INSTALL
  fi
}

cleanup() {
  cd $CURRENT_DIR

  if [ -n "$INSTALLED_PACKAGES" ]; then
    echo
    echo
    echo "The following packages have been installed:"
    echo $INSTALLED_PACKAGES
    echo
    if [ $CLEANUP -eq 1 ]; then
      echo "Cleaning up: Removing the installed packages again."
      sudo apt-get -q remove $INSTALLED_PACKAGES
      sudo apt-get -qq autoremove
    else
      echo "Feel free to remove them (if you do not require them for something else)"
    fi
  fi
}

while getopts "2a:b:cd:hi:t:Uv" opt; do
  case "$opt" in
    2)
      TWO_STEPS=1
      ;;
    a)
      LIBRARY_ARCHITECTURE=$OPTARG
      ;;
    b)
      BUILD_DIR=$(readlink -m $OPTARG)
      ;;
    c)
      CLEANUP=1
      ;;
    d)
      ROS_DISTRO=$OPTARG
      ;;
    h|\?)
      usage
      ;;
    i)
      INSTALL_DIR=$(readlink -m $OPTARG)
      ;;
    t)
      INSTALL_TYPE=$OPTARG
      ;;
    U)
      NO_UPDATE=1
      ;;
    v)
      VERBOSE=1
      ;;
  esac
done

if [ -z "$BUILD_DIR" ]; then
  BUILD_DIR=$(readlink -m build/ros_${ROS_DISTRO}_catkin_ws/)
fi
if [ -z "$INSTALL_DIR" ]; then
  INSTALL_DIR=$ROS_DISTRO
fi
INSTALL_DIR=$(readlink -m $INSTALL_DIR)
if [ -d $BUILD_DIR ]; then
  CLEAN_BUILD=0
else
  CLEAN_BUILD=1
fi
if [ -z "$INSTALL_TYPE" ]; then
  if [ -f $BUILD_DIR/$ROS_DISTRO-*-wet.rosinstall ]; then
    INSTALL_TYPE=$(ls $BUILD_DIR/$ROS_DISTRO-*-wet.rosinstall | sed -e "s/.*\/$ROS_DISTRO-\(.*\)-wet.rosinstall/\1/")
  else
    INSTALL_TYPE=desktop
  fi
fi
if [ $CLEAN_BUILD -eq 0 -a ! -f $BUILD_DIR/$ROS_DISTRO-$INSTALL_TYPE-wet.rosinstall ]; then
  # .rosinstall file not found, handle as new/clean installation, instead of an update
  CLEAN_BUILD=1
fi

if [ $VERBOSE -eq 1 ]; then
  cat << EOF
ROS distribution:      $ROS_DISTRO
Build location:        $BUILD_DIR
Installation location: $INSTALL_DIR
Installation type:     $INSTALL_TYPE (see http://www.ros.org/reps/rep-0131.html#variants)
Library architecture:  $LIBRARY_ARCHITECTURE
EOF

  echo
  if [ $CLEAN_BUILD -eq 0 ]; then
    if [ $NO_UPDATE -eq 0 ]; then
      echo "Build location already exists, going to update ROS $ROS_DISTRO"
    else
      echo "Build location already exists, only going to rebuild ROS $ROS_DISTRO"
    fi
  else
    echo "Build location does not exist, going to install ROS $ROS_DISTRO"
  fi
  echo

  if [ "$ROS_DISTRO" = "indigo" -a "$INSTALL_TYPE" = "desktop_full" ]; then
    cat << EOF

WARNING: ROS $ROS_DISTRO/$INSTALL_TYPE does not compile completely (yet).
See patches/$INSTALL_TYPE directory for patches that (parially) fix the compilation/linking problem(s).
Apply them manually to $BUILD_DIR to fix (some of) the compilation/linking problems (after the workspace has been initialized, e.g. before restarting/continuing the build after after it has failed).

EOF
  fi

  read -p "Press [Enter] key to start..."
  echo
fi

if [ ! -f /etc/apt/sources.list.d/ros-${OS_DISTRO}.list ]; then
  echo "Adding ROS repository"
  sudo sh -c "echo \"deb http://packages.ros.org/ros/ubuntu $OS_DISTRO main\" > /etc/apt/sources.list.d/ros-${OS_DISTRO}.list"
  wget https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -O - | sudo apt-key add -
  sudo apt-get update
fi

echo "Installing required ROS tools (that are required to 'bootstrap' ROS building)"
install build-essential python-rosinstall-generator python-wstool cmake
  
echo "Installing required boost libraries to build ROS"
# Note libboost version 1.55 is working for utopic/indigo
install libboost-dev libboost-system-dev libboost-filesystem-dev libboost-thread-dev libboost-program-options-dev libboost-regex-dev libboost-signals-dev

echo "Installing other libraries that are required to build ROS"
install libtinyxml-dev libpython-dev python-empy python-nose liblz4-dev libbz2-dev libconsole-bridge-dev

if [ "$INSTALL_TYPE" = "desktop" -o "$INSTALL_TYPE" = "desktop_full" ]; then
  install libpoco-dev libeigen3-dev libqt4-dev python-qt4-dev libshiboken-dev libpyside-dev libcurl4-openssl-dev libboost-python-dev libopencv-dev python-numpy liburdfdom-dev libqhull-dev libassimp-dev libogre-1.9-dev libyaml-cpp-dev

  if [ ! -f /etc/apt/sources.list.d/veger-ubuntu-ppa-${OS_DISTRO}.list ]; then
    echo "Adding Veger repository"
    sudo add-apt-repository -y ppa:veger/ppa
    sudo apt-get update
  fi
  install collada-dom-dev
fi

if [ "$INSTALL_TYPE" = "desktop_full" ]; then
  install libfltk1.3-dev libtheora-dev
  if [ ! -f /etc/apt/sources.list.d/v-launchpad-jochen-sprickerhof-de-ubuntu-pcl-${OS_DISTRO}.list ]; then
    echo "Adding PCL repository"
    sudo add-apt-repository -y ppa:v-launchpad-jochen-sprickerhof-de/pcl
    sudo apt-get update
  fi
  install libpcl-dev
  # Ubuntu vivid has gazebo in its repositories
  if [ "$OS_DISTRO" != "vivid" -a ! -f /etc/apt/sources.list.d/gazebo-${OS_DISTRO}.list ]; then
    echo "Adding Gazebo $OS_DISTRO repository"
    sudo sh -c "echo 'deb http://packages.osrfoundation.org/gazebo/ubuntu $OS_DISTRO main' > /etc/apt/sources.list.d/gazebo-${OS_DISTRO}.list"
    wget http://packages.osrfoundation.org/gazebo.key -O - | sudo apt-key add -
    sudo apt-get update
  fi
  install libgazebo5-dev
fi

if [ $CLEAN_BUILD -eq 1 ]; then
  echo "Creating ROS build workspace"
  [ -d $BUILD_DIR ] && rm -r $BUILD_DIR
  mkdir -p $BUILD_DIR
  cd $BUILD_DIR
  rosinstall_generator $INSTALL_TYPE --rosdistro $ROS_DISTRO --deps --wet-only --tar > $ROS_DISTRO-$INSTALL_TYPE-wet.rosinstall
  wstool init -j8 src $ROS_DISTRO-$INSTALL_TYPE-wet.rosinstall
elif [ $NO_UPDATE -eq 0 ]; then
  echo "Updating ROS build workspace (getting newest versions)"
  cd $BUILD_DIR
  rosinstall_generator $INSTALL_TYPE --rosdistro $ROS_DISTRO --deps --wet-only --tar > $ROS_DISTRO-$INSTALL_TYPE-wet.rosinstall.new
  diff $ROS_DISTRO-$INSTALL_TYPE-wet.rosinstall{,.new}
  if [ $? -ne 0 ]; then
    if [ $VERBOSE -eq 1]; then
      echo "The following is getting udpated:"
      diff -u $ROS_DISTRO-$INSTALL_TYPE-wet.rosinstall{,.new}
      read -p "Press [enter] to continue..."
    fi
    mv $ROS_DISTRO-$INSTALL_TYPE-wet.rosinstall{.new,}
    wstool merge -j8 -t src $ROS_DISTRO-$INSTALL_TYPE-wet.rosinstall
  fi
  wstool update -j8 -t src
fi

echo "(Re)building ROS $ROS_DISTRO installation"
cd $BUILD_DIR
# CMAKE_LIBRARY_ARCHITECTURE is used by find_library (cmake function) to find the paths to required libraries (basically it specifies /usr/lib/<ARCH>)
ARGS=-DCMAKE_LIBRARY_ARCHITECTURE=$LIBRARY_ARCHITECTURE

if [ $TWO_STEPS -eq 1 ]; then
  # It is faster to first build and then install (when building fails a couple of times due to missing dependencies)
  ./src/catkin/bin/catkin_make_isolated -DCMAKE_BUILD_TYPE=Release $ARGS
fi
if [ "$ROS_DISTRO" = "desktop_full" ]; then
  # For some reason actionlib_msgs is installed before std_msgs, which results in an error, so
  echo "First install std_msgs to fix problem with $ROS_DISTRO"
  ./src/catkin/bin/catkin_make_isolated --install --pkg std_msgs --install-space=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release $ARGS
fi
./src/catkin/bin/catkin_make_isolated --install --install-space=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release $ARGS

echo "Installing libraries that are required to run ROS"
install keep python-netifaces

cat << EOF
Finished
To use the newly build ROS distribution, make sure to 'source' it:

  source $INSTALL_DIR/setup.bash


EOF

