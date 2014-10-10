#!/bin/bash
declare -r VERSION=9.11

# TODO: Use bundled adb
#ADB=./linux/tools/adb
ADB="adb"
ZIP=zip
SCRIPTS=./linux/scripts
TOOLS=./tools

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

	menu_dispose
	backup_dispose
	restore_dispose
	convert_dispose

	if [[ -d tmpbak ]]; then
		rm -rf tmpbak
	fi

	busybox_dispose

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

source "$SCRIPTS/busybox.bash"
source "$SCRIPTS/root.bash"
source "$SCRIPTS/menu.bash"
source "$SCRIPTS/backup.bash"

cd "$(dirname "$0")"
if [[ ! -d tmpbak ]]; then
	mkdir tmpbak
fi
#./scripts/license.bash showLicense
initialize
wakeDevice
pushBusyBox # busybox.bash
if ! check_hasRoot ; then # root.bash
	exit 1
fi
showMenu

