#!/bin/bash
#
# Build OPENOCD

# Copyright (C)  2019. STMicroelectronics
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#######################################
# Constants
#######################################
SCRIPT_VERSION="1.1"

SOC_FAMILY="stm32mp2"
SOC_NAME="stm32mp25"
SOC_VERSIONS=( "stm32mp257f" )

if [ -n "${ANDROID_BUILD_TOP+1}" ]; then
  TOP_PATH=${ANDROID_BUILD_TOP}
elif [ -d "device/stm/${SOC_FAMILY}-openocd" ]; then
  TOP_PATH=$PWD
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  exit 1
fi

# Check libusb and libtool packages are present
dpkg -s libusb-1.0-0 >/dev/null 2>&1 || {
  echo "ERROR: libusb-1.0-0 package not present ! Please install it..."
  exit 1
}

dpkg -s libtool >/dev/null 2>&1 || {
  echo "ERROR: libtool package not present ! Please install it..."
  exit 1
}

\pushd ${TOP_PATH} >/dev/null 2>&1

OPENOCD_BUILDCONFIG=android_openocdbuild.config

OPENOCD_SOURCE_PATH=${TOP_PATH}/device/stm/${SOC_FAMILY}-openocd/source
OPENOCD_PREBUILT_PATH=${TOP_PATH}/device/stm/${SOC_FAMILY}-openocd/prebuilt

OPENOCD_CONFIGURE_OPTION="--enable-stlink"

#######################################
# Variables
#######################################
nb_states=0
do_install=0
do_onlyclean=0
do_onlydistclean=0
do_force=0

verbose="--silent"
verbose_level=0

# By default redirect stdout and stderr to /dev/null
redirect_out="/dev/null"

#######################################
# Functions
#######################################

#######################################
# Add empty line in stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
empty_line()
{
  echo
}

#######################################
# Print script usage on stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
usage()
{
  echo "Usage: `basename $0` [Options] [Command]"
  empty_line
  echo "  This script allows building the OpenOCD source"
  empty_line
  echo "Options:"
  echo "  -h / --help: print this message"
  echo "  -i / --install: update prebuilt images"
  echo "  -v / --version: get script version"
  echo "  -f / --force: force Openocd Makefile rebuild"
  echo "  --verbose=<level>: enable verbosity (1 or 2 depending on level of verbosity required)"
  empty_line
  echo "Command: Optional, only one command at a time supported"
  echo "  clean: execute make clean on targeted module (remove only built objects)"
  echo "  distclean: execute make distclean on targeted module (remove all generated files)"
  empty_line
}

#######################################
# Print error message in red on stderr
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
error()
{
  echo "$(tput setaf 1)ERROR: $1$(tput sgr0)" >&2
}

#######################################
# Print warning message in orange on stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
warning()
{
  echo "$(tput setaf 3)WARNING: $1$(tput sgr0)"
}

#######################################
# Print message in blue on stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
blue()
{
  echo "$(tput setaf 6)$1$(tput sgr0)"
}

#######################################
# Print message in green on stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
green()
{
  echo "$(tput setaf 2)$1$(tput sgr0)"
}

#######################################
# Clear current line in stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
clear_line()
{
  echo -ne "\033[2K"
}

#######################################
# Print state message on stdout
# Globals:
#   I nb_states
#   I/O action_state
# Arguments:
#   None
# Returns:
#   None
#######################################
action_state=1
state()
{
  clear_line
  echo "$(tput setaf 6)  [${action_state}/${nb_states}]: $1 $(tput sgr0)"
  action_state=$((action_state+1))
}

#######################################
# Check if item is available in list
# Globals:
#   None
# Arguments:
#   $1 = list of possible items
#   $2 = item which shall be tested
# Returns:
#   0 if item found in list
#   1 if item not found in list
#######################################
in_list()
{
  local list="$1"
  local checked_item="$2"

  for item in ${list}
  do
    if [[ "$item" == "$checked_item" ]]; then
      return 0
    fi
  done

  return 1
}

#######################################
# Initialize number of states
# Globals:
#   I do_install
#   I do_onlyclean
#   I do_onlydistclean
#   I openocd_src
#   O nb_states
# Arguments:
#   None
# Returns:
#   None
#######################################
init_nb_states()
{
  if [ ! -f ${openocd_src}/Makefile ] || [ ${do_force} == 1 ] ;then
    nb_states=$((nb_states+1))
  fi

  if [ ${do_onlyclean} == 1 ]; then
    nb_states=$((nb_states+1))
  elif [ ${do_onlydistclean} == 1 ]; then
    nb_states=$((nb_states+1))
  else
    nb_states=$((nb_states+1))
    if [[ ${do_install} == 1 ]]; then
      nb_states=$((nb_states+1))
    fi
  fi
}

#######################################
# Extract OPECOCD build config
# Globals:
#   I OPENOCD_SOURCE_PATH
#   I OPENOCD_BUILDCONFIG
#   O openocd_src
# Arguments:
#   None
# Returns:
#   None
#######################################
extract_buildconfig()
{
  local l_openocd_value
  local l_line
  local l_src

  while IFS='' read -r l_line || [[ -n $l_line ]]; do
    echo $l_line | grep '^OPENOCD_'  >/dev/null 2>&1

    if [ $? -eq 0 ]; then
      l_line=$(echo "${l_line: 8}")
      l_openocd_value=($(echo $l_line | awk '{ print $1 }'))

      case ${l_openocd_value} in
      "SRC" )
        l_src=($(echo $l_line | awk '{ print $2 }'))
        openocd_src=($(realpath ${l_src}))
        ;;
      esac
    fi
  done < ${OPENOCD_SOURCE_PATH}/${OPENOCD_BUILDCONFIG}
}

#######################################
# Generate OPENOCD makefile
# Globals:
#   I openocd_src
#   I OPENOCD_CONFIGURE_OPTION
# Arguments:
#   None
# Returns:
#   None
#######################################
generate_makefile()
{
  local l_ret

  \pushd ${openocd_src} >/dev/null 2>&1
  # Call bootstrap script which create the configuration setup
  ./bootstrap nosubmodule &>${redirect_out} || {
    error "ERROR during bootstrap execution"
    l_ret=1
  }

  # Configure environment to be ready for building
  ./configure ${verbose} ${OPENOCD_CONFIGURE_OPTION} &>${redirect_out} || {
    error "ERROR during configure execution"
    l_ret=1
  }
  \popd >/dev/null 2>&1

  if [[ $l_ret == 1 ]]; then
    \popd >/dev/null 2>&1
    exit 1
  fi
}

#######################################
# Generate OPENOCD executable
# Globals:
#   I openocd_src
#   I verbose
# Arguments:
#   $1: compilation rule (all or clean)
# Returns:
#   0: if make result ok
#   1: if make result ko
#######################################
generate_openocd()
{
  \make ${verbose} -j8 -C ${openocd_src} $1 &>${redirect_out}

  if [ $? -ne 0 ]; then
    return 1
  fi

  return 0
}

#######################################
# Display error for building OpenOCD
# Globals:
#   I verbose_level
# Arguments:
#   $1: Text to be displayed
# Returns:
#   Exit 1
#######################################
display_building_error()
{
  local error_str

  error_str=$1

  if [[ ${verbose_level} == 0 ]]; then
    error_str+=" Please enable verbose mode to get more information if not already set."
  fi
  error "${error_str}"

  \popd >/dev/null 2>&1
  exit 1
}

#######################################
# Install OPENOCD OS
# Globals:
#   I openocd_src
#   I OPENOCD_PREBUILT_PATH
# Arguments:
#   None
# Returns:
#   None
#######################################
install_openocd()
{
  \find ${openocd_src}/ -name "openocd" -print0 | xargs -0 -I {} cp {} ${OPENOCD_PREBUILT_PATH}/
  \cp -rf ${openocd_src}/tcl/* ${OPENOCD_PREBUILT_PATH}/scripts/
}

#######################################
# Main
#######################################

# Check that the current script is not sourced
if [[ "$0" != "$BASH_SOURCE" ]]; then
  empty_line
  error "This script shall not be sourced"
  empty_line
  usage
  \popd >/dev/null 2>&1
  return
fi

# check the options
while getopts "hvif-:" option; do
    case "${option}" in
        -)
            # Treat long options
            case "${OPTARG}" in
                help)
                    usage
                    \popd >/dev/null 2>&1
                    exit 0
                    ;;
                version)
                    echo "`basename $0` version ${SCRIPT_VERSION}"
                    \popd >/dev/null 2>&1
                    exit 0
                    ;;
                verbose=*)
                    verbose_level=${OPTARG#*=}
                    redirect_out="/dev/stdout"
                    if ! in_list "0 1 2" "${verbose_level}"; then
                        error "unknown verbose level ${verbose_level}"
                        \popd >/dev/null 2>&1
                        exit 1
                    fi
                    if [ ${verbose_level} == 2 ];then
                        verbose=
                    fi
                    ;;
                install)
                    do_install=1
                    ;;
                force)
                    do_force=1
                    ;;
                *)
                    usage
                    \popd >/dev/null 2>&1
                    exit 1
                    ;;
            esac;;
        # Treat short options
        h)
            usage
            \popd >/dev/null 2>&1
            exit 0
            ;;
        v)
            echo "`basename $0` version ${SCRIPT_VERSION}"
            \popd >/dev/null 2>&1
            exit 0
            ;;
        i)
            do_install=1
            ;;
        f)
            do_force=1
            ;;
        *)
            usage
            \popd >/dev/null 2>&1
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

if [ $# -gt 1 ]; then
  error "Only one command resquest support. Current commands are : $*"
  \popd >/dev/null 2>&1
  exit 1
fi

# check the options
if [ $# -eq 1 ]; then

  case $1 in
    "clean" )
      do_onlyclean=1
      ;;

    "distclean" )
      do_onlydistclean=1
      ;;
    ** )
      usage
      \popd >/dev/null 2>&1
      exit 0
      ;;
  esac
fi

# Check existence of the OPENOCD build configuration file
if [[ ! -f ${OPENOCD_SOURCE_PATH}/${OPENOCD_BUILDCONFIG} ]]; then
  error "OPENOCD configuration ${OPENOCD_BUILDCONFIG} file not available"
  \popd >/dev/null 2>&1
  exit 1
fi

# Extract OPENOCD build configuration
extract_buildconfig

# Check existence of the OPENOCD source
if [[ ! -f ${openocd_src}/bootstrap ]]; then
  error "OPENOCD source ${openocd_src} not available, please execute load_openocd first"
  \popd >/dev/null 2>&1
  exit 1
fi

# In case clean or disclean command, reset force and install rules, not needed
if [ ${do_onlyclean} == 1 ] || [ ${do_onlydistclean} == 1 ]; then
  do_force=0
  do_install=0
fi

# Initialize number of build states
init_nb_states

# Generate Makefile if not present or force building is requested
if [ ! -f ${openocd_src}/Makefile ] || [ ${do_force} == 1 ] ;then

  state "Generate Makefile for OpenOCD building"
  generate_makefile

fi

if [ ${do_onlyclean} == 1 ]; then

  state "Clean object files and directories"
  generate_openocd clean || display_building_error "Not possible to execute clean command."

elif [ ${do_onlydistclean} == 1 ]; then

  state "Clean all generated files and directories"
  generate_openocd distclean || display_building_error "Not possible to execute distclean command."

else

  # Build OPENOCD
  state "Generate OpenOCD executable"
  generate_openocd || display_building_error "Not possible to compile OpenOCD."

  if [[ ${do_install} == 1 ]]; then
    # Update prebuilt images in required directory
    state "Update prebuilt executable and configuration files"
    install_openocd
  fi

fi

empty_line
\popd >/dev/null 2>&1
exit 0
