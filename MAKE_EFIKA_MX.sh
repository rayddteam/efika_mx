#!/bin/sh

# Directory where is project files located
SRCDIR=/usr/home/ray/work/FreeBSD/Projects/Efika_MX/src/efika_mx/
# Where to store build temporary files
OBJDIR=/usr/obj/emx/
# Beware, if DESTDIR will be wrong you may break current setup on your build
# machine, since i386/amd64 machines can't run ARM binaries.
# System will be installed into directory specified in DESTDIR
# Note: DESTDIR will be assigned to DSTDIR later, at install stages.
DSTDIR=/usr/obj/emx/ARMV6
# Where to install U-Boot image of kernel
TFTPDIR="${DSTDIR}/boot/kernel/"

TARGET=arm
TARGET_ARCH=armv6
TARGET_CPUTYPE=armv6
KERNCONF=EFIKA_MX

KERNOBJDIR="${OBJDIR}/${TARGET}.${TARGET_ARCH}/${SRCDIR}/sys/${KERNCONF}"

export TARGET
export TARGET_ARCH
export TARGET_CPUTYPE
# Hope someday somebody fix aicasm to not break builds for special case :)
export WITHOUT_AICASM=yes

echo -n "Start at "; date

mkdir -p ${DSTDIR} || (echo "Can't create ${DSTDIR}"; exit 1;)
mkdir -p ${OBJDIR} || (echo "Can't create ${OBJDIR}"; exit 1;)
mkdir -p ${TFTPDIR} || (echo "Can't create ${TFTPDIR}"; exit 1;)

# Uncomment next line if don't want to rebuild everithing
#FLAGS=-DNO_CLEAN

# If you want to build just kernel uncomment next line,
# and comment out buildworld line
#make KERNCONF=${KERNCONF} ${FLAGS} toolchain || exit 1
make KERNCONF=${KERNCONF} ${FLAGS} buildworld || exit 1
make KERNCONF=${KERNCONF} ${FLAGS} buildkernel || exit 1

echo "Ready to install? (It will require input of your password for sudo)"
read _INPUT
# Check if auditdistd user exists
pw user show auditdistd > /dev/null 2>&1 && \
    AUDITDISTD_USER_EXIST=1 || AUDITDISTD_USER_EXIST=0
if [ ${AUDITDISTD_USER_EXIST} -eq 0 ]; then
	echo "Trying to add auditdistd user, required to 10-CURRENT build"
	pw useradd auditdistd -u 78 -g 77 -w no -d/var/empty \
	    -s /usr/sbin/nologin -c "Auditdistd unprivileged user"
fi


make DESTDIR=${DSTDIR} ${FLAGS} KERNCONF=${KERNCONF} installkernel || exit 1
make DESTDIR=${DSTDIR} ${FLAGS} installworld || exit 1
make DESTDIR=${DSTDIR} ${FLAGS} distribution || exit 1

uboot_mkimage -A ARM -O Linux -T kernel -C none		\
    -a 0x90100000 -e 0x90100100				\
    -n "FreeBSD kernel"					\
    -d "${DSTDIR}/boot/kernel/kernel" "${TFTPDIR}/kernel.uboot"

echo -n "Done at "; date
