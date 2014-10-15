#!/bin/bash
declare -r VERSION=9.11

BASEDIR="$(dirname "$0")"
ADB="$BASEDIR/linux/tools/adb.x86"
#ADB="adb" # Uncomment to use system's ADB
ZIP=zip
UNZIP=unzip
SCRIPTS="$BASEDIR/linux/scripts"
TOOLS="$BASEDIR/tools"

## TODO: Checks for exit codes after pipes aren't meaningful

##############################################
## Function-replacements (labels in Batch)
##############################################

PARTITION_BY_NAME=/dev/block/platform/msm_sdcc.1/by-name/TA

#####################
## Utils
#####################

_dos2unix() {
	sed -e 's/\r//'
}

_unix2dos() {
	sed -e 's/$/\r/'
}

_pause() {
	read -p "Press [Enter] to continue..."
}

#####################
## INITIALIZE
#####################
initialize() {
	clear
	echo '[ ------------------------------------------------------------ ]'
	printf '%-63s]' "[  Backup TA v$VERSION for Sony Xperia"
	echo
	cat <<-EOF
		[ ------------------------------------------------------------ ]
		[  Initialization                                              ]
		[                                                              ]
		[  Make sure that you have USB Debugging enabled, you do       ]
		[  allow your computer ADB access by accepting its RSA key     ]
		[  (only needed for Android 4.2.2 or higher) and grant this    ]
		[  ADB process root permissions through superuser.             ]
		[ ------------------------------------------------------------ ]
EOF
}

#####################
## DISPOSE
#####################
dispose() {
	echo
	echo =======================================
	echo  CLEAN UP
	echo =======================================
	local partition=
	local choiceTextParam=
	local choice=

	dispose_menu
	dispose_backup
	dispose_restore
	dispose_convert

	if [[ -d tmpbak ]]; then
		rm -rf tmpbak
	fi

	dispose_busybox

	echo "Killing ADB Daemon..."
	$ADB kill-server >/dev/null 2>&1
	echo OK
}

trap dispose EXIT

#################################
## Simple-script replacements
#################################

wakeDevice() {
	echo "Waiting for USB Debugging..."
	$ADB wait-for-device >/dev/null
	echo OK
}

#####################
## CHOICE CHECK
#####################

export ADB SCRIPTS TOOLS VERSION

source "$SCRIPTS/license.bash"
source "$SCRIPTS/busybox.bash"
source "$SCRIPTS/root.bash"
source "$SCRIPTS/menu.bash"
source "$SCRIPTS/backup.bash"
source "$SCRIPTS/restore.bash"
source "$SCRIPTS/convert.bash"

cd "$(dirname "$0")"
if [[ ! -d tmpbak ]]; then
	mkdir tmpbak
fi
showLicense
initialize
wakeDevice
pushBusyBox
# pushBusyBox temporary replacement
#export BB=/data/local/tmp/busybox-backup-ta
if ! check_hasRoot ; then # root.bash
	exit 1
fi
showMenu

