
#####################
## CONVERT
#####################
convertRawTA() {
	echo
	echo =======================================
	echo  PROVIDE BACKUP
	echo =======================================
	if [[ ! -d convert-this ]]; then
		mkdir convert-this >/dev/null 2>&1
	fi
	copyTAFile
}

copyTAFile() {
	echo Copy your 'TA.img' file to the $PWD/convert-this/ folder.
	echo
	echo "Are you ready to continue?"
	_PS3=PS3
	PS3="[1,2]"
	select opt in Yes No ; do
		case $REPLY in
			1) break ;;
			2) onConvertCancelled ; return 2 ;;
			*) continue ;;
		esac
	done
	PS3="$_PS3"
	if [[ ! -f convert-this/TA.img ]]; then
		echo
		echo There is no 'TA.img' file found inside the 'convert-this' folder.
		copyTAFile
		return
	fi
	md5sum convert-this/TA.img | awk '{print $1}' | _unix2dos > convert-this/TA.md5
	echo
	echo =======================================
	echo  PACKAGE BACKUP
	echo =======================================
	convert_timestamp=$( date +%Y%m%d.%H%M%S )
	cd convert-this
	"$ZIP" "../backup/TA-backup-$convert_timestamp.zip" TA.img TA.md5
	if [[ $? -ne 0 ]]; then
		onConvertFailed
		return 3
	fi
	cd ..
	exit_convert 1
}

#####################
## CONVERT CANCELLED
#####################
onConvertCancelled() {
	exit_convert 2
}

#####################
## CONVERT FAILED
#####################
onConvertFailed() {
	exit_convert 3
}

#####################
## EXIT CONVERT
#####################
exit_convert() {
	local filename="TA-backup-${convert_timestamp}.zip"
	dispose_convert $1
	echo
	if [[ "$1" == "1" ]]; then
			echo '*** Convert successful ***'
			echo "*** Your new backup is named '$filename' ***"
			echo "*** It can be found at $PWD/backup ***"
	fi
	if [[ "$1" == "2" ]]; then echo '*** Convert cancelled. ***' ; fi
	if [[ "$1" == "3" ]]; then echo '*** Convert unsuccessful. ***' ; fi
	echo
	_pause
}

#####################
## DISPOSE CONVERT
#####################
dispose_convert() {
	convert_timestamp=
	if [[ "$1" == "1" ]]; then
		rm -f tmpbak/convert_* >/dev/null 2>&1
		
		if [[ -d convert-this ]]; then
			rm -f convert-this/*
		fi
	fi
}

