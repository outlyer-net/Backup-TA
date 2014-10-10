
#####################
## ROOT CHECK
#####################
check_hasRoot() {
	echo "Checking for SU binary..."
	local SU=$( $ADB shell "$BB" ls --color=never /system/bin/su | _dos2unix )
	# Original:
	#  tools\adb shell %BB% ls /system/bin/su>tmpbak\su
	#  ...
	#  if NOT "!su!" == "[1;32m/system/bin/su[0m" (
	# TODO: Include implicit test for execute permission
	if [[ "$SU" != /system/bin/su ]]; then
		SU=$( $ADB shell "$BB" ls --color=never /system/xbin/su | _dos2unix )
		if [[ "$SU" != /system/xbin/su ]]; then
			echo FAILED
		else
			echo OK
		fi
	fi
	echo "Requesting root permissions..."
	local rootPermission=$( $ADB shell su -c "$BB echo true" | _dos2unix )
	if [[ "$rootPermission" != "true" ]]; then
		echo FAILED
		return 1
	fi
	echo OK
}

