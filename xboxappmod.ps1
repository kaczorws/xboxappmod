# Xbox App Settings Mod Script
# v 1.0
# Date: 13/04/2018
# Author: Pawel 'kaczorws' Koscielny

# Putting everything in Try-Catch statement to catch potential errors
Try {

#Custom termination function
function TerminateWithExplanation ([string]$explanation) {
    Write-Host -ForegroundColor Red $explanation
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
    exit
}


#Function to verify if two files are the same
function Compare2Files ($file1, $file2, $filetype) {
    $CompareResultList = Compare-Object $file1 $file2 | Select-Object SideIndicator
    If ($CompareResultList) {
        TerminateWithExplanation "Verification fail! Error occured during copy of $filetype file!"        
    } else {
        Write-Host -ForegroundColor Green "$filetype file verified succesfully."
    }
}


#Terminate if XboxApp process is already running
If (Get-Process -Name XboxApp -ErrorAction SilentlyContinue) {
    $XboxProcess = Get-Process -Name XboxApp
    $XboxProcessThreads = $XboxProcess.Threads | Select-Object WaitReason | %{$_ -match "Suspended"}
    If (!($XboxProcessThreads -contains $true)) {
        TerminateWithExplanation "XboxApp process detected - script will now end. Please close the Xbox Application and re-run the script."        
    } 
}


#Terminate if Xbox App setings file does not exist
$XboxConfigPath = $env:LOCALAPPDATA + "\Packages\" + (Get-AppxPackage -Name "Microsoft.XboxApp" | Select -ExpandProperty Name) + "_" + (Get-AppxPackage -Name "Microsoft.XboxApp" | Select -ExpandProperty PublisherId) + "\LocalState\settings.json"
if (!(Test-Path -Path $XboxConfigPath )) {
    TerminateWithExplanation "Xbox App settings file not detected - make sure that you're logged to Xbox App using Xbox Live/Microsoft account and have been using streaming to PC at least once. Exiting now."
}


#Terminate if Xbox App setings file is corrupted or Microsoft modified the structure
#Looking for section "GAME_STREAMING_VERY_HIGH_QUALITY_SETTINGS":"12000000,1080,60,"
$XboxConfigFile = Get-Content $XboxConfigPath
$XboxConfigFileCorrupted = $XboxConfigFile -match "GAME_STREAMING_VERY_HIGH_QUALITY_SETTINGS[`"][:][`"](\d+)[,]\d+[,](\d+)[,]"
If (!($XboxConfigFileCorrupted -contains $true)) {
    TerminateWithExplanation "Xbox App settings file corrupted or Microsoft modified the structure. Please check for new version of the script."        
}


#Terminate if config file does not exist
$ConfigPath = $PSScriptRoot + "\config.xml"
if (!(Test-Path -Path $ConfigPath )) {
    TerminateWithExplanation "Config file not detected! Exiting."
}


#Terminate if config file is corrupted
try {
    $ConfigFile = [XML](Get-Content -ErrorAction SilentlyContinue $ConfigPath)
} catch {
    if ($_) {
        TerminateWithExplanation "Config file corrupted! Exiting."
    }
}


#Assign variables from config file
$HostsBlocker = $ConfigFile.settings.hostsblocker
$QualitySetting = $ConfigFile.settings.quality
$DisplayResolution = $ConfigFile.settings.resolution
$FrameRate = $ConfigFile.settings.framerate


#Terminate if config file is corrupted
If (!$HostsBlocker -or !$QualitySetting -or !$FrameRate) {
    TerminateWithExplanation "Config file corrupted! Exiting."
}


#Check if blocker entry is present in hosts file, backup and modify hosts file if not
$HostsPath = $env:SystemRoot + "\System32\Drivers\etc\hosts"
$HostsBackupPath = $PSScriptRoot + "\hosts.bak"
$HostsFile = Get-Content $HostsPath
$HostsBlockerToAppend = "`r`n" + $HostsBlocker
$HostsBlockerPresent = $HostsFile | %{$_ -match "^$HostsBlocker"}
if ($HostsBlockerPresent -contains $true) {
    Write-Host -ForegroundColor Yellow "Hosts file already modified, skipping modification!"
} else {
    Write-Host -NoNewLine "Backing up original hosts file..."
        Copy-Item -ErrorAction Stop $HostsPath -Destination $HostsBackupPath
    Write-Host -ForegroundColor Green "DONE!"
    Compare2Files (Get-Content $HostsPath) (Get-Content $HostsBackupPath) "Hosts backup"
    Write-Host -NoNewLine "Adding `"$HostsBlocker`" to hosts file..."
        Add-Content -ErrorAction Stop -Value $HostsBlockerToAppend -Path $HostsPath
    Write-Host -ForegroundColor Green "DONE!"
}


#Backup of Xbox App settings
Write-Host -NoNewLine "Backing up Xbox App settings file..."
    $XboxConfigBackupPath = $PSScriptRoot + "\settings.json.bak"
    Copy-Item -ErrorAction Stop $XboxConfigPath -Destination $XboxConfigBackupPath
Write-Host -ForegroundColor Green "DONE!"
Compare2Files (Get-Content $XboxConfigPath) (Get-Content $XboxConfigBackupPath) "Xbox settings backup"


#Find matching pattern in settings file and replace it
#Looking for section "GAME_STREAMING_VERY_HIGH_QUALITY_SETTINGS":"12000000,1080,60,"
Write-Host -NoNewLine "Modyfing Xbox App settings file with values: Quality = $QualitySetting, Resolution = $DisplayResolution, Framerate = $FrameRate..."
    $XboxConfigFile = $XboxConfigFile -replace "GAME_STREAMING_VERY_HIGH_QUALITY_SETTINGS[`"][:][`"](\d+)[,]\d+[,](\d+)[,]",("GAME_STREAMING_VERY_HIGH_QUALITY_SETTINGS`":`""+$QualitySetting+"000000,$DisplayResolution,$FrameRate,")
    [IO.File]::WriteAllLines($XboxConfigPath, $XboxConfigFile)
Write-Host -ForegroundColor Green "DONE!"


#Start Xbox App process and wait for it to end
#$XboxConfigApp = "shell:AppsFolder\" + (Get-AppxPackage -Name "Microsoft.XboxApp" | Select -ExpandProperty PackageFamilyName) + "!App"
start xbox:
Write-Host "XboxApp process started, waiting for XboxApp process to end..."
While (Get-Process -Name XboxApp -ErrorAction SilentlyContinue)
{
    #Write-Host "XboxApp process still visible"
    Start-Sleep -Seconds 1

}
Write-Host "XboxApp process has ended."


#Restore hosts file and remove hosts backup
if (!($HostsBlockerPresent -contains $true)) {
    Write-Host -NoNewLine "Restoring original hosts file..."
        $HostsFile = Get-Content $HostsBackupPath
        [IO.File]::WriteAllLines($HostsPath, $HostsFile)
    Write-Host -ForegroundColor Green "DONE!"
    Compare2Files (Get-Content $HostsBackupPath) (Get-Content $HostsPath) "Hosts"
    Write-Host -NoNewLine "Removing hosts backup file..."
        Remove-Item -ErrorAction Stop $HostsBackupPath
    Write-Host -ForegroundColor Green "DONE!"
}


#Restore settings file and remove settings backup
Write-Host -NoNewLine "Restoring Xbox settings file..."
    $XboxConfigFile = Get-Content $XboxConfigBackupPath
    [IO.File]::WriteAllLines($XboxConfigPath, $XboxConfigFile)
Write-Host -ForegroundColor Green "DONE!"
Compare2Files (Get-Content $XboxConfigBackupPath) (Get-Content $XboxConfigPath) "Xbox settings"
Write-Host -NoNewLine "Removing Xbox settings backup file..."
    Remove-Item -ErrorAction Stop $XboxConfigBackupPath
Write-Host -ForegroundColor Green "DONE!"


Write-Host "Ending script."
Start-Sleep -Seconds 2

} Catch {
    #Writing catched errors to a file
    Write-Host -ForegroundColor Red "Error! See file lasterror.txt" 
    $_ | Out-File ($PSScriptRoot + "\lasterror.txt")
}