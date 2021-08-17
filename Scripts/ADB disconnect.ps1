$adb = "${Env:ProgramFiles(x86)}\Android\android-sdk\platform-tools\adb.exe"
& $adb usb

function _GetParams() {
	return @{
		Name = "ADB usb";
		Description = "Disconnects ADB device";
	}
}