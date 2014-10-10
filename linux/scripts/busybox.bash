
#####################
## PUSH BUSYBOX
#####################
pushBusyBox() {
	echo "Pushing Backup TA Tools..."
	$ADB push $TOOLS/busybox /data/local/tmp/busybox-backup-ta >/dev/null 2>&1
	$ADB shell chmod 755 /data/local/tmp/busybox-backup-ta >/dev/null 2>&1
	export BB=/data/local/tmp/busybox-backup-ta
	echo OK
}

#####################
## REMOVE BUSYBOX
#####################
removeBusyBox() {
	echo "Removing Backup TA Tools..."
	$ADB shell rm /data/local/tmp/busybox-backup-ta >/dev/null 2>&1
	export BB=
	echo OK
}

busybox_dispose() {
	removeBusyBox
}

