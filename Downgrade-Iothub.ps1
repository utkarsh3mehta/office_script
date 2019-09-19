<#
.Synopsis
Down grade Iot Hubs

.Description
Want to smartly lower your cost of your iothubs units? Run this script and save at least $20.

# Presequisites: Az modules, automation variable LAWebhookUri
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

            $alertList = Get-AzMetricAlertRuleV2 -ResourceGroupName $iotResourceGroup | Where-Object {$_.TargetResourceId -eq $iotResourceId -and $_.Criteria.MetricName -eq "dailyMessageQuotaUsed"}

            if($alertList -eq $null) {
                Write-Error "No alert configured on this Iot Hub. Please enable alert first."
                # Send Mail
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
                            # Send mail
                            Continue
                        }

                        try {
                            Write-Verbose "Updating the Iot Hub units." -Verbose
                            Set-AzIotHub -ResourceGroupName $iotResourceGroup -Name $iotName -SkuName $tier_name -Units $final_y
                        } catch {
                            Write-Error "Error while updating the Iot Hub units."
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
    $Username ="azure_64412a82eb59ccae2e465f540642070a@azure.com"
    $Password = ConvertTo-SecureString "8J6pFV65g0e33nu" -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)
    $MSMTPServer = "smtp.sendgrid.net"
    $To = "DLOTISGlobalIOTSupport@utc.com"
    $Cc = "Taskal.Samal@otis.com"
    $Body = "Error with creating header for sending an API request. Please check the IotHub downgrade runbook.`nPossible error: Client ID and key do not match."
    $Subject = "Downgrade Iot Hub Runbook: API Header not created"
    Send-MailMessage -From "IotDowngrade@otis.com" -To $To -Cc $Cc -Subject $Subject -Body $Body  -SmtpServer $MSMTPServer -Credential $credential -Usessl -Port 587
}