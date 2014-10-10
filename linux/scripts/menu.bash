
menu_Depth=0

#####################
## MENU
#####################
showMenu() {
	local menu_currentIndex=1
	local menu_choices=1
	clear
	echo
	cat <<-EOF
	[ ------------------------------------------------------------ ]
	[  Backup TA v$VERSION for Sony Xperia                             ]
	[ ------------------------------------------------------------ ]
	EOF

	choices=( "Backup" "Restore" "Restore dry-run" "Convert TA.img" "Quit" )
	echo "Please make your decision: "
	let menu_Depth+=1
	_PS3="$PS3"
	PS3="#[1,2,3,4,5]? "
	select opt in "${choices[@]}" ; do
		let menu_Depth+=1
		PS3="#[1,2]? "
		case $REPLY in
			1) _do_backup ;;
			2) _do_restore ;;
			3) _do_dry_run ;;
			4) _do_convert_ta_img ;;
			5) break $menu_Depth ;;
		esac
		PS3="#[1,2,3,4,5]? "
	done
	menu_Depth=0
	PS3="$_PS3"
}

_do_backup() {
	echo
	echo =======================================
	echo  BACKUP
	echo =======================================
	echo When you continue Backup TA will perform a backup of the TA partition.
	echo First it will look for the TA partition by its name. When it can not
	echo be found this way it will ask you to perform an extensive search.
	echo The extensive search will inspect many of the partitions on your device,
	echo in the hope to find it and continue with the backup process.
	echo

	echo "Are you sure you want to continue?"
	select opt in Yes No ; do
		case $REPLY in
			1) # Yes
				backupTA ;;
			2) # No
				;;
			*) continue ;;
		esac
		break
	done
	showMenu
}

_do_restore() {
	echo
	echo =======================================
	echo  RESTORE
	echo =======================================
	echo When you continue Backup TA will perform a restore of a TA partition
	echo backup. There will be many integrity checks along the way to make sure
	echo a restore will either complete successfully, revert when something goes
	echo wrong while restoring or fail before the restore begins because of an
	echo invalid backup. There is always a risk when writing to an important
	echo partition like TA, but with these safeguards that risk is kept to an
	echo absolute minimum. 
	echo

	echo "Are you sure you want to continue?"
	select opt in Yes No ; do
		case $REPLY in
			1) # Yes
				restoreTA ;;
			2) # No
				;;
			*) continue ;;
		esac
		break
	done
	showMenu
}

_do_dry_run() {
	echo
	echo =======================================
	echo  RESTORE DRY-RUN
	echo =======================================
	echo When you continue Backup TA will perform the restore of a TA partition
	echo in 'dry-run' mode. This mode performs the restore just like the regular
	echo restore with the exception that it will not do an actual restore of the 
	echo backup to the device. It will however perform every integrity check, so 
	echo you can test beforehand if your backup is invalid or corrupted.
	echo

	echo "Are you sure you want to continue?"
	select opt in Yes No ; do
		case $REPLY in
			1) # Yes
				restoreTAdry ;;
			2) # No
				;;
			*) continue ;;
		esac
		break
	done
	showMenu
}

_do_convert_ta_img() {
	echo
	echo =======================================
	echo  CONVERT TA.IMG
	echo =======================================
	echo When you continue Backup TA will ask you to copy your TA.img file to a location
	echo and then convert this backup to make it compatible with the latest version
	echo of Backup TA.
	echo

	echo "Are you sure you want to continue?"
	select opt in Yes No ; do
		case $REPLY in
			1) # Yes
				convertRawTA ;;
			2) # No
				;;
			*) continue ;;
		esac
		break
	done
	showMenu
}

menu_dispose() {
	# Nothing to do
	true
}

