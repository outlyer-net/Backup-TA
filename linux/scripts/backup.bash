
#####################
## BACKUP
#####################
inspectPartition() {
	if [[ $backup_taPartitionName == "-1" ]] ; then
		return
	fi
	echo "--- $1 ---"
	echo -n "Searching for Operator Identifier..."
	backup_matchOP_ID=$( $ADB shell su -c "$BB cat /dev/block/$1 | $BB grep -s -m 1 -c 'OP_ID='" | _dos2unix )
	if [[ $backup_matchOP_ID == "1" ]]; then
		echo "+"
	else
		echo "-" ;
	fi
	echo -n "Searching for Operator Name..."
	backup_matchOP_Name=$( $ADB shell su -c "$BB cat /dev/block/$1 | $BB grep -s -m 1 -c 'OP_NAME='" | _dos2unix )
	if [[ "$backup_matchOP_Name" == "1" ]]; then
		echo "+"
	else
		echo "-"
	fi
	echo -n "Searching for Rooting Status..."
	backup_matchRootingStatus=$( $ADB shell su -c "$BB cat /dev/block/$1 | $BB grep -s -m 1 -c 'ROOTING_ALLOWED='" | _dos2unix )
	if [[ "$backup_matchRootingStatus" == "1" ]]; then
		echo "+"
	else
		echo "-"
	fi
	echo -n "Searching for S1 Boot..."
	backup_matchS1_Boot=$( $ADB shell su -c "$BB cat /dev/block/$1 | $BB grep -s -m 1 -c -i 'S1_Boot'" | _dos2unix )
	if [[ "$backup_matchS1_Boot" == "1" ]]; then
		echo "+"
	else
		echo "-"
	fi
	echo -n "Searching for S1 Loader..."
	backup_matchS1_Loader=$( $ADB shell su -c "$BB cat /dev/block/$1 | $BB grep -s -m 1 -c -i 'S1_Loader'" | _dos2unix )
	if [[ "$backup_matchS1_Loader" == "1" ]]; then
		echo "+"
	else
		echo "-"
	fi
	echo -n "Searching for S1 Hardware Configuration..."
	backup_matchS1_HWConf=$( $ADB shell su -c "$BB cat /dev/block/$1 | $BB grep -s -m 1 -c -i 'S1_HWConf'" | _dos2unix )
	if [[ "$backup_matchS1_HWConf" == "1" ]]; then
		echo "+"
	else
		echo "-"
	fi

	if [[ "$backup_matchOP_ID" == "1" ]]; then
		if [[ "$backup_matchOP_Name" == "1" ]]; then
			if [[ "$backup_matchRootingStatus" == "1" ]]; then
				if [[ "$backup_matchS1_Boot" == "1" ]]; then
					if [[ "$backup_matchS1_Loader" == "1" ]]; then
						if [[ "$backup_matchS1_HWConf" == "1" ]]; then
							if [[ "$backup_taPartitionName" == "" ]]; then
								backup_taPartitionName=$1
							else
								backup_taPartitionName=-1
							fi
						fi
					fi
				fi
			fi
		fi
	fi
	echo
}

backupTA() {
	echo
	if [[ ! -d backup ]]; then
		mkdir backup
	fi
	wakeDevice
	echo
	echo =======================================
	echo  FIND TA PARTITION
	echo =======================================
	backup_defaultTA=$( $ADB shell su -c "$BB ls -l $PARTITION_BY_NAME | $BB awk '{print \\\$11}'" | _dos2unix )
	backup_defaultTAvalid=$( $ADB shell su -c "if [ -b '$backup_defaultTA' ]; then echo '1'; else echo '0'; fi" | _dos2unix )
	if [[ "$backup_defaultTAvalid" == "1" ]]; then
		partition=$backup_defaultTA
		echo Partition found^^!
	else
		echo Partition not found by name.
		echo
		echo "Do you want to perform an extensive search for the TA?"
		select opt in Yes No ; do
			case $REPLY in
				1) break ;;
				2) onBackupCancelled ; return ;;
				*) continue ;;
			esac
		done

		echo
		echo =======================================
		echo  INSPECTING PARTITIONS
		echo =======================================
		backup_taPartitionName=
		backup_potentialPartitions=$( $ADB shell su -c "$BB cat /proc/partitions | $BB awk '{if (\\\$3<=9999 && match (\\\$4, \"'\"mmcblk\"'\")) print \\\$4}'" | _dos2unix )
		for partition in $backup_potentialPartitions ; do
			inspectPartition $partition
		done
		
		if [[ "$backup_taPartitionName" != "" ]]; then
			if [[ "$backup_taPartitionName" != "-1" ]]; then
				echo Partition found^^!
				partition=/dev/block/$backup_taPartitionName
			else
				echo "*** More than one partition match the TA partition search criteria. ***"
				echo "*** Therefore it is not possible to determine which one or ones to use. ***"
				echo "*** Contact DevShaft @XDA-forums for support. ***"
				onBackupCancelled
				return
			fi
		else
			echo "*** No compatible TA partition found on your device. ***"
			onBackupCancelled
			return
		fi
		
	fi

	echo
	echo =======================================
	echo  BACKUP TA PARTITION
	echo =======================================
	backup_currentPartitionMD5=$( $ADB shell su -c "$BB md5sum $partition | $BB awk {'print \\\$1'}" | _dos2unix )
	$ADB shell su -c "$BB dd if=$partition of=/sdcard/backupTA.img"

	echo
	echo =======================================
	echo  INTEGRITY CHECK
	echo =======================================
	backup_backupMD5=$( $ADB shell su -c "$BB md5sum /sdcard/backupTA.img | $BB awk {'print \\\$1'}" | _dos2unix )
	#verify >/dev/null # XXX: Windows-specific, controls correct file writing
	if [[ "$backup_currentPartitionMD5" != "$backup_backupMD5" ]]; then
		echo FAILED - Backup does not match TA Partition. Please try again.
		onBackupFailed
		return
	else
		echo OK
	fi

	echo
	echo =======================================
	echo  PULL BACKUP FROM SDCARD
	echo =======================================
	if ! $ADB pull /sdcard/backupTA.img tmpbak/TA.img ; then
		onBackupFailed
		return
	fi

	echo
	echo =======================================
	echo  INTEGRITY CHECK
	echo =======================================
	backup_backupPulledMD5=$( md5sum tmpbak/TA.img | awk '{print $1}' )
	if [[ $? -ne 0 ]]; then
		return $backupFailed
	fi
	#verify >/dev/null
	if [[ "$backup_currentPartitionMD5" != "$backup_backupPulledMD5" ]]; then
		echo FAILED - Backup has gone corrupted while pulling. Please try again.
		onBackupFailed
		return
	else
		echo OK
	fi

	echo
	echo =======================================
	echo  PACKAGE BACKUP
	echo =======================================
	$ADB get-serialno | _unix2dos > tmpbak/TA.serial
	echo $partition | _unix2dos > tmpbak/TA.blk
	echo $backup_backupPulledMD5 | _unix2dos > tmpbak/TA.md5
	echo $VERSION | _unix2dos > tmpbak/TA.version
	#$ADB shell su -c "$BB date +%%Y%%m%%d.%%H%%M%%S">tmpbak\TA.timestamp
	backup_timestamp=$( date +%Y%m%d.%H%M%S )
	# In Windows this file is terminated with 0x0D 0x0D 0x0A (CR CR LF)
	echo $backup_timestamp | _unix2dos | sed -e 's/\r/\r\r/' > tmpbak/TA.timestamp
	cd tmpbak
	$ZIP "../backup/TA-backup-${backup_timestamp}.zip" TA.img TA.md5 TA.blk TA.serial TA.timestamp TA.version
	if [[ $? -ne 0 ]]; then
		onBackupFailed
		return
	fi

	exitBackup 1
}

#####################
## BACKUP CANCELLED
#####################
onBackupCancelled() {
	exitBackup 2
}

#####################
## BACKUP FAILED
#####################
onBackupFailed() {
	exitBackup 3
}

#####################
## EXIT BACKUP
#####################
exitBackup() {
	backup_dispose $1
	echo
	case "$1" in
		1) echo "*** Backup successful. ***" ;;
		2) echo "*** Backup cancelled. ***" ;;
		3) echo "*** Backup unsuccessful. ***" ;;
	esac
	echo
	_pause
}

#####################
## DISPOSE BACKUP
#####################
backup_dispose() {
	set backup_currentPartitionMD5=
	set backup_backupMD5=
	set backup_backupPulledMD5=
	set backup_defaultTA=
	set backup_defaultTAvalid=
	set backup_matchOP_ID=
	set backup_matchOP_Name=
	set backup_matchRootingStatus=
	set backup_matchS1_Boot=
	set backup_matchS1_Loader=
	set backup_matchS1_HWConf=
	set backup_taPartitionName=
	set backup_TAByName=
	set partition=

	if [[ "$1" == "1" ]] ; then rm tmpbak/backup_*.* >/dev/null 2>&1 ; fi
	if [[ "$1" == "1" ]] ; then rm tmpbak/TA.* >/dev/null 2>&1 ; fi
	$ADB shell rm /sdcard/backupTA.img >/dev/null 2>&1
}

