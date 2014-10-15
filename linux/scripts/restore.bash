set restore_dryRun=

hardbrickConfirmation() {
	echo "This restore may hard-brick your device. Are you sure you want to restore the TA Partition?"
	select opt in Yes No ; do
		case $REPLY in
			1) return 0 ;;
			2) return 2 ;;
			*) continue
		esac
	done
}

#####################
## RESTORE DRY
#####################
restoreTAdry() {
	restore_dryRun=1
	restoreTA
}

#####################
## RESTORE
#####################
restoreTA() {
	echo
	wakeDevice # adb.bash
	echo
	if [[ "$restore_dryRun" == "1" ]]; then
		echo --- Restore dry run ---
	fi
	local restore_serialno=$( $ADB get-serialno )
	#verify > nul

	echo
	echo =======================================
	echo  CHOOSE BACKUP TO RESTORE
	echo =======================================
	restoreChoose
}

restoreChoose() {
	# This block is part of restore() in Windows
	#:> tmpbak/restore_list
	local restore_restoreIndex=0
	#for /f "tokens=*" %%D in ('dir/b/o backup\TA-Backup*.zip') do (

	echo Please make your decision:
	_PS3=$PS3
	local numfiles=$( ls -l backup/TA-backup*.zip 2>/dev/null | wc -l )
	PS3='['
	for (( i=1; i<=$numfiles; ++i )); do
		PS3+="$i,"
	done
	local numopts=
	let 'numopts=numfiles+1'
	PS3+="$numopts]"
	cd backup
	select opt in TA-backup*.zip Quit ; do
		if [[ (!( "$REPLY" =~ ^[0-9]+$ )) || ( $REPLY -gt $numopts ) ]]; then
			continue
		fi
		let restore_restoreIndex+=1
		restore_restoreChosen=$REPLY
		break
	done
	cd ..
	PS3=$_PS3

	if [[ "$opt" == "Quit" ]]; then
		onRestoreCancelled
		return 2
	fi

	restore_restoreFile=$opt # Filename

	echo
	echo "Are you sure you want to restore '$restore_restoreFile'?"
	select opt in Yes No ; do
		case $REPLY in
			1) break ;;
			2) onRestoreCancelled ; return 2 ;;
			*) continue ;;
		esac
	done
	 
	echo
	echo =======================================
	echo  EXTRACT BACKUP
	echo =======================================
	$UNZIP -o "backup/$restore_restoreFile" -d tmpbak
	if [[ $? -ne 0 ]]; then
		onRestoreFailed
		return 3
	fi
	if [[ -f tmpbak/TA.blk ]]; then
		partition=$( cat tmpbak/TA.blk | _dos2unix )
	else
		restore_defaultTA=$( $ADB shell su -c "$BB ls -l $PARTITION_BY_NAME | $BB awk '{print \\\$11}'" | _dos2unix )
		restore_defaultTAvalid=$( $ADB shell su -c "if [ -b '$restore_defaultTA' ]; then echo '1'; else echo '0'; fi" | _dos2unix )
		if [[ "$restore_defaultTAvalid" == "1" ]]; then
			partition=$PARTITION_BY_NAME
		else
			partition=/dev/block/mmcblk0p1
		fi
	fi

	echo
	echo =======================================
	echo  INTEGRITY CHECK
	echo =======================================
	restore_savedBackupMD5=$( cat tmpbak/TA.md5 | _dos2unix )
	#verify > nul
	restore_savedBackupMD5Len=$( echo -n "$restore_savedBackupMD5" | wc -c )
	restore_savedBackupMD5=${restore_savedBackupMD5:0:32}

	restore_backupMD5=$( md5sum tmpbak/TA.img | awk '{print $1}' )
	if [[ $? -ne 0 ]]; then
		onRestoreFailed
		return 3
	fi
	#verify > nul
	if [[ "$restore_savedBackupMD5" != "$restore_backupMD5" ]]; then
		echo FAILED - Backup is corrupted.
		onRestoreFailed
		return 3
	else
		echo OK
	fi

	echo
	echo =======================================
	echo  COMPARE TA PARTITION WITH BACKUP
	echo =======================================
	restore_currentPartitionMD5=$( $ADB shell su -c "$BB md5sum $partition | $BB awk {'print \\\$1'}" | _dos2unix )
	#verify > nul
	if [[ "$restore_currentPartitionMD5" == "$restore_savedBackupMD5" ]]; then
		echo TA partition already matches backup, no need to restore.
		onRestoreCancelled
		return 2
	else
		echo OK
	fi

	echo
	echo =======================================
	echo  BACKUP CURRENT TA PARTITION
	echo =======================================
	$ADB shell su -c "$BB dd if=$partition of=/sdcard/revertTA.img && $BB sync && $BB sync && $BB sync && $BB sync"
	if [[ $? -ne 0 ]]; then
		onRestoreRevertFailed
		return 4
	fi

	restore_revertTASize=$( $ADB shell su -c "$BB ls -l /sdcard/revertTA.img | $BB awk {'print \\\$5'}" | _dos2unix )
	#verify > nul

	echo
	echo =======================================
	echo  PUSH BACKUP TO SDCARD
	echo =======================================
	$ADB push tmpbak/TA.img sdcard/restoreTA.img
	if [[ $? -ne 0 ]]; then
		onRestoreFailed
		return 3
	fi

	echo
	echo =======================================
	echo  INTEGRITY CHECK
	echo =======================================
	restore_pushedBackupSize=$( $ADB shell su -c "$BB ls -l /sdcard/restoreTA.img | $BB awk {'print \\\$5'}" | _dos2unix )
	restore_pushedBackupMD5=$( $ADB shell su -c "$BB md5sum /sdcard/restoreTA.img | $BB awk {'print \\\$1'}" | _dos2unix )
	if [[ $? -ne 0 ]]; then
		onRestoreFailed
		return 3
	fi
	#verify > nul
	if [[ "$restore_savedBackupMD5" != "$restore_pushedBackupMD5" ]]; then
		echo FAILED - Backup has gone corrupted while pushing. Please try again.
		onRestoreFailed
		return 3
	else
		if [[ "$restore_revertTASize" != "$restore_pushedBackupSize" ]]; then
			echo FAILED - Backup and TA partition sizes do not match.
			onRestoreFailed
			return 3
		else
			echo OK
		fi
	fi

	echo
	echo =======================================
	echo  SERIAL CHECK
	echo =======================================
	if [[ ! -f tmpbak/TA.serial ]]; then
		restore_backupSerial=$( $ADB shell su -c "$BB cat /sdcard/restoreTA.img | $BB grep -m 1 -o $restore_serialno" )
		if [[ $? -ne 0 ]]; then
			if ! unknownDevice ; then
				restore_backupSerial=
				return 2
			fi
		fi
		restore_backupSerial=$( echo "$restore_backupSerial" | _dos2unix )
		echo $restore_backupSerial | _unix2dos > tmpbak/TA.serial
	fi
	#verify > nul
	if [[ "$restore_serialno" != "$restore_backupSerial" ]]; then
		if ! otherDevice ; then
			return 2
		fi
	fi
	echo OK
	validDevice
}

otherDevice() {
	echo The backup appears to be from another device.
	invalidConfirmation
}

unknownDevice() {
	echo It is impossible to determine the origin for this backup. The backup could be from another device.
	invalidConfirmation
}

invalidConfirmation() {
	if ! hardbrickConfirmation ; then
		onRestoreCancelled
		return 2
	else
		validDevice
	fi
}

validDevice() {
	echo
	echo =======================================
	echo  RESTORE BACKUP
	echo =======================================
	if [[ "$restore_dryRun" != "1" ]]; then
		$ADB shell su -c "$BB dd if=/sdcard/restoreTA.img of=$partition && $BB sync && $BB sync && $BB sync && $BB sync"
		if [[ $? -ne 0 ]]; then
			onRestoreFailed
		fi
	else
		echo --- dry run ---
	fi
	$ADB shell su -c "rm /sdcard/restoreTA.img"

	echo
	echo =======================================
	echo  COMPARE NEW TA PARTITION WITH BACKUP
	echo =======================================
	if [[ "$restore_dryRun" != "1" ]]; then
		restore_restoredMD5=$( $ADB shell su -c "$BB md5sum $partition | $BB awk {'print \\\$1'}" | _dos2unix )
		#verify > nul
	else
		restore_restoredMD5=$restore_pushedBackupMD5
	fi
	if [[ "$restore_currentPartitionMD5" == "$restore_restoredMD5" ]]; then
		echo TA partition appears unchanged, try again.
		onRestoreFailed
	elif [[ "$restore_restoredMD5" != "$restore_savedBackupMD5" ]]; then
		echo TA partition seems corrupted. Trying to revert restore now...
		onRestoreCorrupt
	else
		echo OK
	fi
	onRestoreSuccess
}

#####################
## RESTORE SUCCESS
#####################
onRestoreSuccess() {
	exit_restore 1
}

#####################
## RESTORE CANCELLED
#####################
onRestoreCancelled() {
	exit_restore 2
}

#####################
## RESTORE FAILED
#####################
onRestoreFailed() {
	exit_restore 3
}

#####################
## RESTORE CORRUPT
#####################
onRestoreCorrupt() {
	echo
	echo =======================================
	echo  REVERT RESTORE
	echo =======================================
	if [[ "$restore_dryRun" != "1" ]]; then
		$ADB shell su -c "$BB dd if=/sdcard/revertTA.img of=$partition && $BB sync && $BB sync && $BB sync && $BB sync"
	fi

	echo
	echo =======================================
	echo  REVERT VERIFICATION
	echo =======================================
	if [[ "$restore_dryRun" != "1" ]]; then
		restore_revertedMD5=$( $ADB shell su -c "$BB md5sum $partition | $BB awk {'print \\\$1'}" | _dos2unix )
	else
		restore_revertedMD5=$restore_currentPartitionMD5
	fi
	#verify > nul
	if [[ "$restore_currentPartitionMD5" != "$restore_revertedMD5" ]]; then
		echo FAILED
		onRestoreRevertFailed
	else
		echo OK
		onRestoreRevertSuccess
	fi
}

#####################
## RESTORE REVERT FAILED
#####################
onRestoreRevertFailed() {
	$ADB pull /sdcard/revertTA.img tmpbak/revertTA.img
	exit_restore 4
}

#####################
## RESTORE REVERT SUCCESS
#####################
onRestoreRevertSuccess() {
	exit_restore 5
}

#####################
## EXIT RESTORE
#####################
exit_restore() {
	dispose_restore $1
	echo
	if [[ "$1" == "1" ]]; then
		echo '*** Restore successful. ***'
		echo '*** You must restart the device for the restore to take effect. ***'
		echo
		echo "Do you want to restart the device?"
		select opt in Yes No ; do
			case $REPLY in
				1) break ;;
				2) return ;;
				*) continue ;;
			esac
		done
		$ADB reboot
	fi
	case "$1" in
		"2") echo '*** Restore cancelled. ***' ;;
		"3") echo '*** Restore unsuccessful. ***' ;;
		"4")
			echo '*** DO NOT SHUTDOWN OR RESTART THE DEVICE!!! ***'
			echo '*** Reverting restore has failed! Contact DevShaft @XDA-forums for guidance. ***'
			;;
		"5") echo '*** Revert successful. Try to restore again. ***' ;;
	esac
	echo
	_pause
}

#####################
## DISPOSE RESTORE
#####################
dispose_restore() {
	set restore_dryRun=
	set restore_backupMD5=
	set restore_savedBackupMD5=
	set restore_currentPartitionMD5=
	set restore_pushedBackupMD5=
	set restore_restoredMD5=
	set restore_revertedMD5=
	set restore_backupSerial=
	set restore_serialno=
	set partition=

	if [[ "$1" == "1" ]]; then rm -f tmpbak/restore_*.* >/dev/nulll 2>&1 ; fi
	if [[ "$1" == "1" ]]; then rm -f tmpbak/TA.* >/dev/null 2>&1 ; fi
	$ADB shell rm /sdcard/restoreTA.img >/dev/null 2>&1
	$ADB shell rm /sdcard/revertTA.img >/dev/null 2>&1
}

