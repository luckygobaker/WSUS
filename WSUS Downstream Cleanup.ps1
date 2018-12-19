################################################################################
# Script:  WSUS Downstream Cleanup.ps1                                         #
# Purpose: Cleans up the E:\ drive on Downstream servers                       #
# Author:  Jeritt Baker                                                        #
# History: Date         Version	Change notes                                   #
#          ------------ ------- ---------------------------------------------- #
#          12/18/2018   1.0     Initial Release                                #
################################################################################

$scriptname = "WSUS Downstream Cleanup Script"

#Replace the SourceExists with the appropriate script name as PowerShell 6.1 has an issue with accepting a variable for this.
$LogSourceExists = [System.Diagnostics.EventLog]::SourceExists('WSUS Downstream Cleanup Script');
if (-not $LogSourceExists){
    $neweventsource = @{
        Source = "$scriptname"
        LogName = 'Application'
    }
New-EventLog @neweventsource
}

#Verifies script is being run as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $WarningPreference = "Stop"
    Write-Warning -Message "Please relaunch script and run as Administrator"
}

#Syncs the downstream server to verify that it has accurate approved/declined patches for cleanup purposes
(Get-WsusServer).GetSubscription().StartSynchronization()

#Waits to sync to finish, there is currently no way to "watch" the sync process. Oh well.
Start-Sleep -Seconds 350

#The cleanup portion of this long ugly script
Invoke-WsusServerCleanup -CleanupObsoleteComputers -CleanupUnneededContentFiles -CompressUpdates -CleanupObsoleteUpdates -DeclineExpiredUpdates -DeclineSupersededUpdates |
Out-File E:\WsusServerCleanup.log -Force
    
Write-EventLog -LogName 'Application' -EntryType Information -EventID 1500 -Source 'WSUS Cleanup Script' -Message 'Cleanup completed successfully, check the E:\WsusServerCleanup.log for details.'

#Error catching
trap {        
    $email = @{
        From = "help@microcenter.com"
        To = "<jjbaker@microcenter.com>"
        CC = "<jwroberts@microcenter.com>"
        Subject = "$scriptname Error on $env:COMPUTERNAME"
        SMTPServer = "internal-smtp.ad.microcenter.com"
        Body = "$scriptname has ran into an error, see the Application log on $env:COMPUTERNAME for details. Error: $_"
        }
    Send-MailMessage @email

    $event = @{
        LogName = 'Application'
        EntryType = 'Error'
        EventID = '1499'
        Source = "$scriptname"
        Message = "$_"
    }
    Write-EventLog @event 
        
    exit
}