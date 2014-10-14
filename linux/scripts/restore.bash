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
	select opt in backup/TA-Backup*.zip Quit ; do
		let restore_restoreIndex+=1
		restore_restoreChosen=$REPLY
	done

	if [[ "$opt" == "Quit" ]]; then
		onRestoreCancelled
	fi

	cat <<TODO
	# FIXME:
	tools\find "[!restore_restoreChosen!]" < tmpbak\restore_list > tmpbak\restore_item
	for /f "tokens=2" %%T in (tmpbak\restore_item) do (
		set restore_restoreFile=%%T 
	)
	if "!restore_restoreFile!" == "" goto restoreChoose
	 
	echo.
	%CHOICE% /c:yn %CHOICE_TEXT_PARAM% "Are you sure you want to restore '!restore_restoreFile!'?"
	if "!errorlevel!" == "2" goto onRestoreCancelled
	 
	echo.
	echo =======================================
	echo  EXTRACT BACKUP
	echo =======================================
	tools\zip.exe x -y backup\!restore_restoreFile! -otmpbak
	if NOT "!errorlevel!" == "0" goto onRestoreFailed
	if exist tmpbak\TA.blk (
		set /p partition=<tmpbak\TA.blk
	) else (
		tools\adb.exe shell su -c "%BB% ls -l %PARTITION_BY_NAME% | %BB% awk '{print \$11}'">tmpbak\restore_defaultTA
		set /p restore_defaultTA=<tmpbak\restore_defaultTA
		tools\adb.exe shell su -c "if [ -b '!restore_defaultTA!' ]; then echo '1'; else echo '0'; fi">tmpbak\restore_defaultTAvalid
		set /p restore_defaultTAvalid=<tmpbak\restore_defaultTAvalid
		if "!restore_defaultTAvalid!" == "1" (
			set partition=%PARTITION_BY_NAME%
		) else (
			set partition=/dev/block/mmcblk0p1
		)
	)

	echo.
	echo =======================================
	echo  INTEGRITY CHECK
	echo =======================================
	set /p restore_savedBackupMD5=<tmpbak\TA.md5
	verify > nul
	call scripts\string-util.bat strlen restore_savedBackupMD5Len restore_savedBackupMD5
	set /a restore_savedBackupMD5TrailingSpaces=!restore_savedBackupMD5Len!-32
	for /f "tokens=* delims= " %%a in ("!restore_savedBackupMD5!") do set restore_savedBackupMD5=%%a
	for /l %%a in (1,1,100) do if "!restore_savedBackupMD5:~-1!"==" " set restore_savedBackupMD5=!restore_savedBackupMD5:~0,-!restore_savedBackupMD5TrailingSpaces!
	tools\md5.exe -l -n tmpbak\TA.img>tmpbak\restore_backupMD5
	if NOT "!errorlevel!" == "0" goto onRestoreFailed
	set /p restore_backupMD5=<tmpbak\restore_backupMD5
	verify > nul
	if NOT "!restore_savedBackupMD5!" == "!restore_backupMD5!" (
		echo FAILED - Backup is corrupted.
		goto onRestoreFailed
	) else (
		echo OK
	)

	echo.
	echo =======================================
	echo  COMPARE TA PARTITION WITH BACKUP
	echo =======================================
	tools\adb.exe shell su -c "%BB% md5sum !partition! | %BB% awk {'print \$1'}">tmpbak\restore_currentPartitionMD5
	set /p restore_currentPartitionMD5=<tmpbak\restore_currentPartitionMD5
	verify > nul
	if "!restore_currentPartitionMD5!" == "!restore_savedBackupMD5!" (
		echo TA partition already matches backup, no need to restore.
		goto onRestoreCancelled
	) else (
		echo OK
	)

	echo.
	echo =======================================
	echo  BACKUP CURRENT TA PARTITION
	echo =======================================
	tools\adb.exe shell su -c "%BB% dd if=!partition! of=/sdcard/revertTA.img && %BB% sync && %BB% sync && %BB% sync && %BB% sync"
	if NOT "!errorlevel!" == "0" goto onRestoreFailed
	tools\adb.exe shell su -c "%BB% ls -l /sdcard/revertTA.img | %BB% awk {'print \$5'}">tmpbak\restore_revertTASize
	set /p restore_revertTASize=<tmpbak\restore_revertTASize
	verify > nul

	echo.
	echo =======================================
	echo  PUSH BACKUP TO SDCARD
	echo =======================================
	tools\adb.exe push tmpbak\TA.img sdcard/restoreTA.img
	if NOT "!errorlevel!" == "0" goto onRestoreFailed

	echo.
	echo =======================================
	echo  INTEGRITY CHECK
	echo =======================================
	tools\adb.exe shell su -c "%BB% ls -l /sdcard/restoreTA.img | %BB% awk {'print \$5'}">tmpbak\restore_pushedBackupSize
	tools\adb.exe shell su -c "%BB% md5sum /sdcard/restoreTA.img | %BB% awk {'print \$1'}">tmpbak\restore_pushedBackupMD5
	if NOT "!errorlevel!" == "0" goto onRestoreFailed
	set /p restore_pushedBackupSize=<tmpbak\restore_pushedBackupSize
	set /p restore_pushedBackupMD5=<tmpbak\restore_pushedBackupMD5
	verify > nul
	if NOT "!restore_savedBackupMD5!" == "!restore_pushedBackupMD5!" (
		echo FAILED - Backup has gone corrupted while pushing. Please try again.
		goto onRestoreFailed
	) else (
		if NOT "!restore_revertTASize!" == "!restore_pushedBackupSize!" (
			echo FAILED - Backup and TA partition sizes do not match.
			goto onRestoreFailed
		) else (
			echo OK
		)
	)

	echo.
	echo =======================================
	echo  SERIAL CHECK
	echo =======================================
	if NOT exist tmpbak\TA.serial (
		tools\adb.exe shell su -c "%BB% cat /sdcard/restoreTA.img | %BB% grep -m 1 -o !restore_serialno!">tmpbak\restore_backupSerial
		if NOT "!errorlevel!" == "0" goto unknownDevice
		copy tmpbak\restore_backupSerial tmpbak\TA.serial > nul 2>&1
	)
	set /p restore_backupSerial=<tmpbak\TA.serial
	verify > nul
	if NOT "!restore_serialno!" == "!restore_backupSerial!" (
		goto otherDevice
	)
	echo OK
	goto validDevice
TODO
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
		echo *** Restore successful. ***
		echo *** You must restart the device for the restore to take effect. ***
		echo
		%CHOICE% /c:yn %CHOICE_TEXT_PARAM% "Do you want to restart the device?"
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
		"2") echo *** Restore cancelled. *** ;;
		"3") echo *** Restore unsuccessful. *** ;;
		"4")
			echo *** DO NOT SHUTDOWN OR RESTART THE DEVICE!!! ***
			echo *** Reverting restore has failed! Contact DevShaft @XDA-forums for guidance. ***
			;;
		"5") echo *** Revert successful. Try to restore again. *** ;;
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

