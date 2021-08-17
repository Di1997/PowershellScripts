$adb = "${Env:ProgramFiles(x86)}\Android\android-sdk\platform-tools\adb.exe"
$out = & $adb shell "ip addr show wlan0 | grep 'inet ' | cut -d' ' -f6|cut -d/ -f1"

if($out -eq $null) {
	return "IP address of the device is empty. Device is not connected to WiFi?"
}

& $adb tcpip 5555
& $adb connect "$($out):5555"

return "IP address of the device: $out"

function _GetParams() {
	return @{
		Name = "ADB connect";
		Description = "Connects ADB device";
	}
}