#!/bin/sh
#
# Copyright (c) 2005 Poul-Henning Kamp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $FreeBSD: releng/8.1/tools/tools/nanobsd/nanobsd.sh 206537 2010-04-13 00:57:54Z imp $
#

set -e

#######################################################################
#
# Pull in the defaut variable settings from:
# 	targets/default/nanobsd.conf
#
#######################################################################

. targets/default/nanobsd.conf

#######################################################################
#
# Pull in all of the function definitions.
#
#######################################################################

for FUNC in `find functions -type f | grep -Ev '(CVS|\.svn|\.swp)'`; do
	. ${FUNC}
done

#######################################################################
#
# All set up to go...
#
#######################################################################


usage () {
	(
	echo "Usage: $0 [-bikqvw] [-a target_arch] -t target_name"
	echo "	-a	target cpu architecture (amd64/arm/i386/sparc64)"
	echo "	-b	suppress builds (both kernel and world)"
	echo "	-i	suppress disk image build"
	echo "	-k	suppress buildkernel"
	echo "	-n	add -DNO_CLEAN to buildworld, buildkernel, etc"
	echo "	-q	make output quiter"
	echo "	-v	make output more verbose"
	echo "	-w	suppress buildworld"
	echo "	-t	nanobsd target to build"
	) 1>&2
	exit 2
}

#######################################################################
# Parse arguments

do_clean=true
do_kernel=true
do_world=true
do_image=true

set +e
args=`getopt bt:a:hiknqvw $*`
if [ $? -ne 0 ] ; then
	usage
	exit 2
fi
set -e

set -- $args
for i
do
	case "$i" 
	in
	-b)
		do_world=false
		do_kernel=false
		shift
		;;
	-k)
		do_kernel=false
		shift
		;;
	-t)
		NANO_TARGET="$2"
		shift
		shift
		;;
	-a)
		NANO_ARCH="$2"
		shift
		shift
		;;
	-h)
		usage
		;;
	-i)
		do_image=false
		shift
		;;
	-n)
		do_clean=false
		shift
		;;
	-q)
		PPLEVEL=$(($PPLEVEL - 1))
		shift
		;;
	-v)
		PPLEVEL=$(($PPLEVEL + 1))
		shift
		;;
	-w)
		do_world=false
		shift
		;;
	--)
		shift
		break
	esac
done


if [ $# -gt 0 ] ; then
	echo "$0: Extraneous arguments supplied"
	usage
fi

if [ "x${NANO_TARGET}" = "x" ]; then
	echo "$0: You must specify a build target"
	usage
fi

if [ "x${NANO_ARCH}" = "x" ]; then
	NANO_ARCH=`uname -p`
fi

case "${NANO_ARCH}"
in
amd64)
	;;
arm)
	;;
i386)
	;;
sparc64)
	;;
*)
	echo "$0: Target architechture is not supported"
	usage
esac


trap "nano_cleanup" EXIT

#######################################################################
#
# Process the target configuration
#
#######################################################################

if [ ! -d targets/${NANO_TARGET} ]; then
	echo "Build target not found" 1>&2
	exit 1
fi

if [ ! -e targets/${NANO_TARGET}/nanobsd.conf ]; then
	echo "Build target nanobsd.conf not found" 1>&2
	exit 1
fi

. targets/${NANO_TARGET}/nanobsd.conf

if [ -e targets/${NANO_TARGET}/${NANO_ARCH}/nanobsd.conf ]; then
	. targets/${NANO_TARGET}/${NANO_ARCH}/nanobsd.conf
fi

#######################################################################
# 
# Sanity Checks for build config.
#
#######################################################################

case "${NANO_IMAGE_TYPE}"
in
disk)
	;;
cd)
	;;
*)
	echo "NANO_IMAGE_TYPE is invalid! Valid values are disk and cd" >&2
	exit 1
esac


#######################################################################
# Setup and Export Internal variables
#
test -n "${NANO_OBJ}" || NANO_OBJ=/usr/obj/nanobsd.${NANO_NAME}/
test -n "${MAKEOBJDIRPREFIX}" || MAKEOBJDIRPREFIX=${NANO_OBJ}
test -n "${NANO_DISKIMGDIR}" || NANO_DISKIMGDIR=${NANO_OBJ}

NANO_WORLDDIR=${NANO_OBJ}/_.w
NANO_MAKE_CONF_BUILD=${MAKEOBJDIRPREFIX}/make.conf.build
NANO_MAKE_CONF_INSTALL=${NANO_OBJ}/make.conf.install

if [ -d ${NANO_TOOLS} ] ; then
	true
elif [ -d ${NANO_SRC}/${NANO_TOOLS} ] ; then
	NANO_TOOLS=${NANO_SRC}/${NANO_TOOLS}
else
	echo "NANO_TOOLS directory does not exist" 1>&2
	exit 1
fi

if $do_clean ; then
	true
else
	NANO_PMAKE="${NANO_PMAKE} -DNO_CLEAN"
fi

export MAKEOBJDIRPREFIX

export NANO_ARCH
export NANO_CODESIZE
export NANO_CONFSIZE
export NANO_CUSTOMIZE
export NANO_DATASIZE
export NANO_DRIVE
export NANO_HEADS
export NANO_IMAGES
export NANO_IMGNAME
export NANO_MAKE_CONF_BUILD
export NANO_MAKE_CONF_INSTALL
export NANO_MEDIASIZE
export NANO_NAME
export NANO_NEWFS
export NANO_OBJ
export NANO_PMAKE
export NANO_SECTS
export NANO_SRC
export NANO_TOOLS
export NANO_WORLDDIR
export NANO_BOOT0CFG
export NANO_BOOTLOADER

#######################################################################
# And then it is as simple as that...

# File descriptor 3 is used for logging output, see pprint
exec 3>&1

NANO_STARTTIME=`date +%s`
pprint 1 "NanoBSD image ${NANO_NAME} build starting"

if $do_world ; then
	if $do_clean ; then
		clean_build
	else
		pprint 2 "Using existing build tree (as instructed)"
	fi
	make_conf_build
	build_world
else
	pprint 2 "Skipping buildworld (as instructed)"
fi

if $do_kernel ; then
	build_kernel
else
	pprint 2 "Skipping buildkernel (as instructed)"
fi

clean_world
make_conf_install
install_world
install_etc
setup_nanobsd_etc
install_kernel

run_command_set "${NANO_CUSTOMIZE}"
run_command_set "${NANO_PKG_POST_CMDS}"

setup_nanobsd
prune_usr
run_command_set "${NANO_LATE_CUSTOMIZE}"
if $do_image ; then
	create_${NANO_ARCH}_${NANO_IMAGE_TYPE}image
else
	pprint 2 "Skipping image build (as instructed)"
fi
run_command_set "${NANO_LAST_ORDERS}"

pprint 1 "NanoBSD image ${NANO_NAME} completed"
