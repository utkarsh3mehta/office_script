<#
.Synopsis
Delete all alerts from a single subscription mentioned in a CSV file.

.Description
Prepare a formatted CSV file and mention it when asked. The script will automatically find and delete the alerts.

.INPUT
Format of input CSV:
-----------
Column 1: 
Header: NAME
Description: Name of the alert
Content type: Text
-----------
Column 2:
Header: RESOURCE GROUP
Description: Resource group of the alert
Content type: Text

.Output
The resource ID of the alert along with a status of 'OK'. This means that the alert has been deleted successfully.
#>


# Check if required modules are present or not
if(!(Get-Module -ListAvailable -Name AzureRm.Profile) -or !(Get-Module -ListAvailable -Name AzureRm.Insights)){
    Write-Host "AzureRm Profile or AzureRm Insight module is not present. Please download the AzureRm modules on your system for this script to run properly." -ForegroundColor Red -BackgroundColor Yellow
    # If not, show error, sleep for 15 seconds and end the script
    Sleep -Seconds 15
    Exit
}

# login to azure portal
Connect-AzureRmAccount

# Connect to the subscription
Set-AzureRmContext -Subscription (Read-Host 'Enter the subscription ID')
# import the alert list
$alertList = Import-Csv -Path (Read-Host 'Enter the path of the CSV file')

# run through the alert list
foreach($alert in $alertList) {
    Write-Host ("Working on RG:"+$alert.'RESOURCE GROUP'+" and alert:"+$alert.NAME) -ForegroundColor Green
    # delete the alert one by one
    Get-AzureRmAlertRule -ResourceGroupName $alert.'RESOURCE GROUP' -Name $alert.NAME | Remove-AzureRmAlertRule -ResourceGroupName $alert.'RESOURCE GROUP' -Verbose
    # to disbale, create a new alert with -DisableAlert switch
}

# to log out of azure portal automatically, uncomment the below line (Remove the hash(#) from the start of the line)
#Logout-AzureRmAccount