<#

.Presequisites
1. Automation variable "LAWebhookUri"
2. Az modules such as
a. Az.Accounts
b. Az.IotHub
c. Az.Monitor
d. Az.Resources

.Synopsis
Smartly down grade Iot Hubs.

.Description
Want to smartly lower your cost of your iothubs units? Run this script and save at least $20. Get email alerts for all Iot Hubs where a possible issue might have occured.
This script is supposed to be run as an Azure Runbook inside an Azure automation account.

.Inputs
(Line no: 42) ClientId: The client ID that will be used for creating the authorization header for API call
(Line no: 43) ClientKey: The client key that will be used for creating the authorization header for API call
(Line no: 44) SMTPUsername: The username of your SMTP server
(Line no: 45) SMTPPassword: The password of your SMTP server
(Automation variable) LAWebhookURI: The URI of the webhook your autoscale logic app.

.Outputs
An email is triggered for any of the following causes:
1. When there is no alert configured for an IotHub
2. When there is not properly configured alert for an IotHub
3. When downgrading the Iothub faced an error
4. When the authorization header is not properly created
#>

Write-Verbose "Connecting to the subscription." -Verbose
# Get connection credentials
$Conn = Get-AutomationConnection -Name 'AzureRunAsConnection'
Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint -Subscription $Conn.SubscriptionId
Write-Verbose "Connected to the subscription." -Verbose

#Declaring variables
$subId = $Conn.SubscriptionId
$tenantId = $Conn.TenantID
$clientId = $env:ClientId
$key =$env:ClientKey
$smtpusername = $env:SMTPUsername
$smtppassword = ConvertTo-SecureString $env:SMTPPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($smtpusername, $smtppassword)
$MSMTPServer = "smtp.sendgrid.net"
$To = "your@emailid.com"
$Cc = "someimportantperson@emailid.com"
$LAWebhookUri = Get-AutomationVariable -Name 'LAWebhookUri'

# Creating the URL for getting an access token
$authUrl = "https://login.windows.net/${tenantId}"
$AuthContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]$authUrl

# Creating API header
$cred = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential $clientId,$key
$authenticationTask = $AuthContext.AcquireTokenAsync("https://management.core.windows.net/",$cred)
$authenticationTask.Wait()
$authenticationResult = $authenticationTask.Result
$authHeader = @{
    'Content-Type'='application/json'
    'Authorization'=$authenticationResult.CreateAuthorizationHeader()
}

if($authHeader -ne $null) {
    
    # Creating variables
    $endTime = (Get-Date).ToString("yyyy-MM-ddT18:30:00.000Z")
    $startTime = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddT18:30:00.000Z")

    $rgList = Get-AzResourceGroup

    foreach($rg in $rgList) {

        $iothubList = Get-AzResource -ResourceGroupName $rg | Where-Object {$_.ResourceType -eq "Microsoft.Devices/IotHubs"}

        if($iothubList -ne $null) {
            Write-Verbose ("Resource Group: "+$rg) -Verbose
        }

        foreach($resource in $iothubList) {

            $iotName = $resource.Name
            Write-Verbose ("Iot Hub name: "+$iotName) -Verbose
            $iotResourceGroup = $resource.ResourceGroupName
            $iotResourceId = $resource.ResourceId

            $alertList = Get-AzMetricAlertRuleV2 -ResourceGroupName $iotResourceGroup | Where-Object {$_.TargetResourceId -eq $iotResourceId -and $_.Criteria.MetricName -eq "dailyMessageQuotaUsed" -and $_.Enabled -eq "True"}

            if($alertList -eq $null) {
                Write-Error "No alert configured on this Iot Hub. Please enable alert first."
                $Body = "Hi team,`n`nThere is no daily message quota alert configured for Iot Hub $iotName in resource group $iotResourceGroup.`nPlease create an alert, or else the down-grade script will skip this Iot Hub."
                $Subject = "Downgrade Iot Hub Runbook: No alert configured for Iot Hub $iotName"
                Send-MailMessage -From "IotDowngrade@otis.com" -To $To -Cc $Cc -Subject $Subject -Body $Body  -SmtpServer $MSMTPServer -Credential $credential -Usessl -Port 587
                Continue
            } else {

                [int]$y = $resource.Sku.capacity

                if($y -gt 1) {

                    $err = $true
                    $tier_name = $resource.Sku.name

                    if($tier_name -eq 'S1'){$tier_limit = 400000}
                    elseif($tier_name -eq 'S2'){$tier_limit = 6000000}
                    elseif($tier_name -eq 'S3'){$tier_limit = 30000000}
                    elseif($tier_name -eq 'B1'){$tier_limit = 400000}
                    elseif($tier_name -eq 'B2'){$tier_limit = 6000000}
                    elseif($tier_name -eq 'B3'){$tier_limit = 30000000}
                    elseif($tier_name -eq 'F1'){$tier_limit = 8000}

                    $pastInfo = Invoke-RestMethod -Method Get -Headers $authHeader -Uri "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.Devices/IotHubs/$iotName/providers/microsoft.Insights/metrics?timespan=$startTime/$endTime&interval=FULL&metricnames=dailyMessageQuotaUsed&aggregation=maximum&metricNamespace=Microsoft.Devices/IotHubs&validatedimensions=false&api-version=2018-01-01"
                    $x = $pastInfo.value.timeseries.data.maximum
                    Write-Verbose "Maximum count since the last 7 days: $x" -Verbose
                    $totalMessages = $y * $tier_limit

                    if(($x % $tier_limit) -le ($tier_limit / 2)) {
                        $buffer = $x
                    } else {
                        $buffer = $x + $tier_limit
                    }

                    if($x -ge $totalMessages) {
                        Write-Error "What??? Please increase your Iot Hub units."
                        $err = $false
                    }

                    if($err) {

                        $final_y = [math]::Ceiling($buffer / $tier_limit)
                        if($final_y -lt 1) {$final_y=1}
                        Write-Verbose ("Final Unit count: "+$final_y) -Verbose
                        $final_alert = $null

                        foreach($alert in $alertList) {

                            $actionGroupId = $alert.Actions.ActionGroupId
                            $actiongroupResourceGroup = ($actionGroupId -split '/')[4]
                            $actiongroupName = ($actionGroupId -split '/')[-1]
                            $actionGroupInfo = Get-AzActionGroup -ResourceGroupName $actiongroupResourceGroup -Name $actiongroupName

                            if($actionGroupInfo.WebhookReceivers.ServiceUri -eq $LAWebhookUri) {

                                $final_alert = $alert
                                Break
                            }
                        }

                        if($final_alert -eq $null) {

                            Write-Error "No properly configured alert. Please configure one manually."
                            $Body = "Hi team,`n`nThere is no properly configured alert for Iot Hub $iotName in resource group $iotResourceGroup.`n`nPossible problems:`n1.There is no alert that uses the webhook mentioned in the automation variable 'LAWebhookURI'`n`nPlease configure an alert that uses an action group that runs the mentioned webhook. If you don't, the down-grade script will skip this Iot Hub."
                            $Subject = "Downgrade Iot Hub Runbook: No properly configured alert for Iot Hub $iotName"
                            Send-MailMessage -From "IotDowngrade@otis.com" -To $To -Cc $Cc -Subject $Subject -Body $Body  -SmtpServer $MSMTPServer -Credential $credential -Usessl -Port 587
                            Continue
                        }

                        try {

                            Write-Verbose "Updating the Iot Hub units." -Verbose
                            Set-AzIotHub -ResourceGroupName $iotResourceGroup -Name $iotName -SkuName $tier_name -Units $final_y

                        } catch {

                            Write-Error "Error while updating the Iot Hub units."
                            $Body = "Hi Team,`nError while updating the Iot Hub $iotName in the resource group $iotResourceGroup.`n`nPossible causes:`n1. Automation account does not have write permissions on the resource.`n`nTroubleshooting steps:`n1. Check the activity logs in Azure Portal and look for events initiated by omuswhqomsauto"
                            $Subject = "Downgrade Iot Hub Runbook: Error while downgrading $iotName"
                            Send-MailMessage -From "IotDowngrade@otis.com" -To $To -Cc $Cc -Subject $Subject -Body $Body  -SmtpServer $MSMTPServer -Credential $credential -Usessl -Port 587
                            Continue
                        }
                        Write-Verbose "Running the update threshold now." -Verbose
                        .\UpdateThreshold.ps1 -resourceId $iotResourceId -alertresourceid $final_alert.Id
                    }

                } else {

                    Write-Verbose "Everything looks fine for $iotName" -Verbose
                }
            }
        }
    }
} else {

    Write-Error "Error while creating header. Sending mail."
    $Body = "Error with creating header for sending an API request. Please check the IotHub downgrade runbook.`nPossible error: Client ID and key do not match."
    $Subject = "Downgrade Iot Hub Runbook: API Header not created"
    Send-MailMessage -From "IotDowngrade@otis.com" -To $To -Cc $Cc -Subject $Subject -Body $Body  -SmtpServer $MSMTPServer -Credential $credential -Usessl -Port 587
}
