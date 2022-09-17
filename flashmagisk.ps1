$device="dipper"
#Get latest zip link
$request=Invoke-WebRequest https://mirror.kumi.systems/lineageos/full/$device/ -UseBasicParsing
$lastday=$request.Links | select href -ExpandProperty href -Last 1
$lastbuild=Invoke-WebRequest https://mirror.kumi.systems/lineageos/full/$device/$lastday -UseBasicParsing
$zipfolder=$lastbuild.Links | select href -ExpandProperty href
$zipurl=$zipfolder | select-string .zip


#Download and extract zip
write-host "Downloading latest lineageos ($lastday) for $device..."
Start-BitsTransfer -Source "https://mirror.kumi.systems/lineageos/full/$device/$lastday/$zipurl" -Destination "$PSScriptRoot\latestlos.zip"
write-host "Done"

write-host "Extracting boot.img from zip into but.img (boot.img files are hidden on android filesystem)"
Add-Type -Assembly System.IO.Compression.FileSystem
$Path="$PSScriptRoot\latestlos.zip"
$zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
$bootobject=$zip.Entries | where Name -eq boot.img
[System.IO.Compression.ZipFileExtensions]::ExtractToFile($bootobject, "$PSScriptRoot\but.img", $true)

#1st ADB/FASTBOOT
write-host "Deleting old img files, ignore errors"
adb shell rm /sdcard/but.img
adb shell rm /sdcard/Download/*.img
write-host "Pushing but.img..."
adb push "$PSScriptRoot\but.img" /sdcard/
write-host "but.img pushed to /sdcard/, waiting for you to patch it using magisk app.."
read-host


#2nd ADB/FASTBOOT
$patchedbootfile=adb shell ls /sdcard/Download/*.img 
write-host "Pulling patched file..."
adb pull $patchedbootfile $PSScriptRoot\patchedbut.img

#Cleanup again
write-host "Deleting old img files, ignore errors"
adb shell rm /sdcard/but.img
adb shell rm /sdcard/Download/*.img

adb reboot bootloader
do {
write-host "Waiting for fastboot..."
Start-Sleep 1
} Until (fastboot devices | select-string fastboot)
write-host "Fastboot online"
fastboot flash boot $PSScriptRoot\patchedbut.img
fastboot reboot

#Cleanup on windows too
Remove-Item $PSScriptRoot\but.img
Remove-Item $PSScriptRoot\patchedbut.img
Remove-Item $PSScriptRoot\latestlos.zip

write-host "DONE! Press any key to exit"
read-host