#!/bin/bash
#
# Load OPENOCD source

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

SOC_FAMILY="stm32mp1"
SOC_NAME="stm32mp15"
SOC_VERSIONS=( "stm32mp157c" "stm32mp157f" )

DEFAULT_OPENOCD_VERSION=0.10.0

if [ -n "${ANDROID_BUILD_TOP+1}" ]; then
  TOP_PATH=${ANDROID_BUILD_TOP}
elif [ -d "device/stm/${SOC_FAMILY}-openocd" ]; then
  TOP_PATH=$PWD
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  exit 1
fi

\pushd ${TOP_PATH} >/dev/null 2>&1

OPENOCD_PATH="${TOP_PATH}/device/stm/${SOC_FAMILY}-openocd"
COMMON_PATH="${TOP_PATH}/device/stm/${SOC_FAMILY}"

OPENOCD_CONFIG_FILE="android_openocd.config"
OPENOCD_PATCH_PATH="${OPENOCD_PATH}/source/patch"

OPENOCD_CONFIG_STATUS_PATH="${COMMON_PATH}/configs/openocd.config"

#######################################
# Variables
#######################################
nb_states=2
force_load=0

optee_version=${DEFAULT_OPENOCD_VERSION}

is_err=0
error_str=""
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
  echo "Usage: `basename $0` [Options]"
  empty_line
  echo "  This script allows loading the OpenOCD source"
  empty_line
  echo "Options:"
  echo "  -h / --help: print this message"
  echo "  -v / --version: get script version"
  echo "  -f / --force: force openocd load"
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
  echo -ne "  [${action_state}/${nb_states}]: $1 \033[0K\r"
  action_state=$((action_state+1))
}

#######################################
# Check OPENOCD status within the status file
# Globals:
#   I OPENOCD_CONFIG_STATUS_PATH
# Arguments:
#   None
# Returns:
#   1 if OPENOCD is already loaded
#   0 if OPENOCD is not already loaded
#######################################
check_openocd_status()
{
  local openocd_status
  local openocd_config_status_path

  openocd_config_status_path=${OPENOCD_CONFIG_STATUS_PATH}

  \ls ${openocd_config_status_path}  >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    openocd_status=`grep OPENOCD ${openocd_config_status_path}`
    if [[ ${openocd_status} =~ "LOADED" ]]; then
      return 1
    fi
  fi
  return 0
}

#######################################
# Apply selected patch in current target directory
# Globals:
#   I OPENOCD_PATCH_PATH
#   I openocd_version
# Arguments:
#   $1: patch
# Returns:
#   None
#######################################
apply_patch()
{
  local loc_patch_path

  loc_patch_path=${OPENOCD_PATCH_PATH}/
  loc_patch_path+="${openocd_version}/"
  loc_patch_path+=$1
  if [ "${1##*.}" != "patch" ];then
    loc_patch_path+=".patch"
  fi

  \git am ${loc_patch_path} &> /dev/null
  if [ $? -ne 0 ]; then
    return 1
  fi

  return 0
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
while getopts "hvf-:" option; do
  case "${option}" in
    -)
      # Treat long options
      case "${OPTARG}" in
        help)
          usage
          popd >/dev/null 2>&1
          exit 0
          ;;
        version)
          echo "`basename $0` version ${SCRIPT_VERSION}"
          \popd >/dev/null 2>&1
          exit 0
          ;;
        force)
          force_load=1
          ;;
        *)
          usage
          popd >/dev/null 2>&1
          exit 1
          ;;
      esac;;
    # Treat short options
    h)
      usage
      popd >/dev/null 2>&1
      exit 0
      ;;
    v)
      echo "`basename $0` version ${SCRIPT_VERSION}"
      \popd >/dev/null 2>&1
      exit 0
      ;;
    f)
      force_load=1
      ;;
    *)
      usage
      popd >/dev/null 2>&1
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

if [ $# -gt 0 ]; then
  error "Unknown command : $*"
  usage
  popd >/dev/null 2>&1
  exit 1
fi

OPENOCD_CONFIG_PATH=${OPENOCD_PATCH_PATH}/${OPENOCD_CONFIG_FILE}

# Check existence of the OPENOCD configuration file
if [[ ! -f ${OPENOCD_CONFIG_PATH} ]]; then
  clear_line
  error "OPENOCD configuration ${OPENOCD_CONFIG_PATH} file not available"
  \popd >/dev/null 2>&1
  exit 1
fi

# Check OPENOCD status
check_openocd_status
openocd_status=$?

if [[ ${openocd_status} == 1 ]] && [[ ${force_load} == 0 ]]; then
    blue "The OpenOCD has been already loaded successfully"
    echo " If you want to reload it"
    echo "   execute the script with -f/--force option"
    echo "   or remove the file ${OPENOCD_CONFIG_STATUS_PATH}"
  \popd >/dev/null 2>&1
  exit 0
fi

empty_line
echo "Start loading the OpenOCD source"

# Start OPENOCD config file parsing
while IFS='' read -r line || [[ -n $line ]]; do

  echo $line | grep '^OPENOCD_' >/dev/null 2>&1

  if [ $? -eq 0 ]; then

    line=$(echo "${line: 8}")

    unset openocd_value
    openocd_value=($(echo $line | awk '{ print $1 }'))

    case ${openocd_value} in
      "VERSION" )
        openocd_version=($(echo $line | awk '{ print $2 }'))
        ;;
      "GIT_PATH" )
        git_path=($(echo $line | awk '{ print $2 }'))
        state "Loading OpenOCD source"
        if [ -n "${OPENOCD_CACHE_DIR+1}" ]; then
          \git clone -b ${openocd_version} --reference ${OPENOCD_CACHE_DIR} ${git_path} ${openocd_path} >/dev/null 2>&1
        else
          \git clone -b ${openocd_version} ${git_path} ${openocd_path} >/dev/null 2>&1
        fi
        if [ $? -ne 0 ]; then
          is_err=1
          error_str="Not possible to clone module from ${git_path}"
        fi
        ;;
      "GIT_SHA1" )
        git_sha1=($(echo $line | awk '{ print $2 }'))
        \pushd ${openocd_path} >/dev/null 2>&1
        \git checkout ${git_sha1} &> /dev/null
        if [ $? -ne 0 ]; then
          is_err=1
          error_str="Not possible to checkout ${git_sha1} for ${git_path}"
        fi
        \popd  >/dev/null 2>&1
        ;;
      "ARCHIVE_PATH" )
        archive_path=($(echo $line | awk '{ print $2 }'))
        state "Loading OpenOCD source"
        \mkdir -p ${openocd_path} >/dev/null 2>&1
        \pushd ${openocd_path} >/dev/null 2>&1
        \wget ${archive_path}/archive/${openocd_version}.tar.gz >/dev/null 2>&1
        if [ $? -ne 0 ]; then
          is_err=1
          error_str="Not possible to load ${archive_path}/archive/${openocd_version}.tar.gz"
          \rm -rf ${openocd_path}
        fi
        archive_dir=($(basename ${archive_path}))
        \tar zxf ${openocd_version}.tar.gz --strip=1 ${archive_dir}-${openocd_version} >/dev/null 2>&1
        \rm -f ${openocd_version}.tar.gz >/dev/null 2>&1
        \git init >/dev/null 2>&1
        \git commit --allow-empty -m "Initial commit" >/dev/null 2>&1
        \git add . >/dev/null 2>&1
        \git commit -m "v${openocd_version}" >/dev/null 2>&1
        \popd >/dev/null 2>&1
        ;;
      "FILE_PATH" )
        openocd_path=($(echo $line | awk '{ print $2 }'))
        msg_patch=0
        \rm -rf ${openocd_path}
        if [[ ${force_load} == 1 ]]; then
          \rm -f ${OPENOCD_CONFIG_STATUS_PATH}
        fi
        ;;
      "PATCH"* )
        patch_path=($(echo $line | awk '{ print $2 }'))
        if [[ ${msg_patch} == 0 ]]; then
          state "Applying required patches to ${openocd_path}"
          \pushd ${openocd_path} >/dev/null 2>&1
          msg_patch=1
        fi
        apply_patch "${patch_path}"
        if [ $? -ne 0 ]; then
          is_err=1
          error_str="Not possible to apply patch ${loc_patch_path}, please review android_openocd.config"
          \popd >/dev/null 2>&1
        fi
        ;;
    esac
  fi

  # If error detected, display it then exit
  if [[ $is_err == 1 ]]; then
    clear_line
    error "$error_str"
    \popd >/dev/null 2>&1
    exit 1
  fi
done < ${OPENOCD_CONFIG_PATH}

if [[ ${msg_patch} == 1 ]]; then
  \popd >/dev/null 2>&1
fi

echo "OPENOCD LOADED" >> ${OPENOCD_CONFIG_STATUS_PATH}
clear_line
green "The OpenOCD has been successfully loaded in ${openocd_path}"
\popd >/dev/null 2>&1
exit 0

