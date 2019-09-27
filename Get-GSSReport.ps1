$global:authHeader = @{}
$subscription = "subscriptionID1ComesHere","SubscriptionID2ComesHere"
$resourcegroup = "emea-otis-gss-prd-rg","naa-otis-gss-prd-rg"
$starttime = (Get-Date).AddMonths(-2).ToString("yyyy-MM-ddT12:00:00.000Z")
$endtime = (Get-Date).ToString("yyyy-MM-ddT12:00:00.000Z")


Function AuthHeader($subid) {
    if($subid -eq 'subscriptionIDComesHere') {
        $tenantId = "TenantIDComesHere"
        $clientId = "ClientIdComesHere"
        $key = "ClientKeyComesHere"
    } else {
        $tenantId = "TenantIDComesHere"
        $clientId = "ClientIdComesHere"
        $key = "ClientKeyComesHere"
    }

    # Creating the URL for getting an access token
    $authUrl = "https://login.windows.net/${tenantId}"
    $AuthContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]$authUrl

    # Creating API header
    $cred = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential $clientId,$key
    $authenticationTask = $AuthContext.AcquireTokenAsync("https://management.core.windows.net/",$cred)
    $authenticationTask.Wait()
    $authenticationResult = $authenticationTask.Result
    Set-Variable -Name authHeader -Scope Global -Value (@{
        'Content-Type'='application/json'
        'Authorization'=$authenticationResult.CreateAuthorizationHeader()
    })
}

Function RestRequest ($apiParam, $csvParam) {
    #Write-Host "API"
    #$apiParam
    #Write-Host "CSV"
    #$csvParam
    $data = Invoke-RestMethod -Headers $authHeader -Uri $apiParam
    $data.value.timeseries.data | Export-Csv $csvParam -Append -NoTypeInformation
}

foreach($sub in $subscription) {

    Set-AzureRmContext -Subscription $sub
    AuthHeader -subid $sub

    $output =  "C:\Users\MehtaUt-A\Desktop\PowerShell tutorial II\$sub\"
    if(!(Test-Path $output)) {
        mkdir -Path $output
    }
    foreach($rg in $resourcegroup) {
        $resource = Get-AzureRmResource -ResourceGroupName $rg
        if ($resource -ne $null) {
            Write-Host "Working in resource group $rg"
            foreach($res in $resource) {
                [String]$api = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/"
                if($res.ResourceType -eq 'Microsoft.Storage/storageAccounts') {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $api = $api + "metricnames=Availability&aggregation=average&metricNamespace=microsoft.storage/storageaccounts&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for storage accounts" -ForegroundColor Yellow
                    $csv = $output + "availability" + ($res.ResourceType -replace '[.\/-]','') + "" + $res.Name + ".csv"
                    [URI]$api = $api
                    RestRequest -apiParam $api -csvParam $csv
                } elseif ($res.ResourceType -eq "Microsoft.Web/sites") {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $ipa = $api
                    $api = $api + "metricnames=CpuTime&aggregation=maximum&metricNamespace=microsoft.web/sites&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for app services CPU time" -ForegroundColor Yellow
                    $csv = $output + "cpu_time" + ($res.ResourceType -replace '[.\/-]','') + "" + $res.Name + ".csv"
                    [URI]$api = $api
                    RestRequest -apiParam $api -csvParam $csv
                    $api = $ipa + "metricnames=Http5xx&aggregation=total&metricNamespace=microsoft.web/sites&validatedimensions=false&api-version=2018-01-01"
                    $csv = $output + "http5xx" + ($res.ResourceType -replace '[.\/-]','') + "" + $res.Name + ".csv"
                    [URI]$api = $api
                    RestRequest -apiParam $api -csvParam $csv
                } elseif ($res.ResourceType -eq 'Microsoft.CognitiveServices/accounts') {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $api = $api + "metricnames=TotalErrors&aggregation=total&metricNamespace=microsoft.cognitiveservices/accounts&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for cognitive services total errors" -ForegroundColor Yellow
                    $csv = $output + "total_error" + ($res.ResourceType -replace '[.\/-]','') + "" + $res.Name + ".csv"
                    [URI]$api = $api
                    RestRequest -apiParam $api -csvParam $csv
                } elseif ($res.ResourceType -eq 'Microsoft.DataFactory/factories') {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $ipa = $api
                    $api = $api + "metricnames=ActivityFailedRuns&aggregation=average&metricNamespace=microsoft.datafactory/factories&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for data factory activity failed run" -ForegroundColor Yellow
                    [URI]$api = $api
                    $csv = $output + "activityfail" + ($res.ResourceType -replace '[.\/-]','') + "" + $res.Name + ".csv"
                    RestRequest -apiParam $api -csvParam $csv
                    $api = $ipa + "metricnames=PipelineFailedRuns&aggregation=total&metricNamespace=microsoft.datafactory/factories&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for data factory pipeline failed run" -ForegroundColor Yellow
                    $csv = $output + "pipelinefail" + ($res.ResourceType -replace '[.\/-]','') + "" + $res.Name + ".csv"
                    [URI]$api = $api
                    RestRequest -apiParam $api -csvParam $csv
                }
            }
            $dbserver = $resource | Where-Object {$_.ResourceType -eq 'Microsoft.Sql/servers'}
            foreach($dbser in $dbserver)  {
                $database = Get-AzureRmSqlDatabase -ServerName $dbser.Name -ResourceGroupName $dbser.ResourceGroupName
                foreach($db in $database) {
                    [String]$api = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/"
                    $api = $api + $dbser.ResourceType + "/" + $dbser.Name + "/databases/" + $db.DatabaseName + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $ipa = $api
                    $api = $api + "metricnames=cpu_percent&aggregation=maximum&metricNamespace=microsoft.sql/servers/databases&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for SQL Database CPU usage" -ForegroundColor Yellow
                    $csv = $output + "cpu_usage" + $dbser.Name + "" + $db.DatabaseName + ".csv"
                    [URI]$api = $api
                    RestRequest -apiParam $api -csvParam $csv
                    $api = $ipa + "metricnames=dtu_consumption_percent&aggregation=maximum&metricNamespace=microsoft.sql/servers/databases&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for SQL DB DTU" -ForegroundColor Yellow
                    $csv = $output + "dtu" + $dbser.Name + "" + $db.DatabaseName + ".csv"
                    [URI]$api = $api
                    RestRequest -apiParam $api -csvParam $csv
                    $api = $ipa + "metricnames=physical_data_read_percent&aggregation=maximum&metricNamespace=microsoft.sql/servers/databases&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for SQL DB IO" -ForegroundColor Yellow
                    $csv = $output + "DBIO" + $dbser.Name + "" + $db.DatabaseName + ".csv"
                    [URI]$api = $api
                    RestRequest -apiParam $api -csvParam $csv
                }
            }
        }
    }    
}


<###################
#$headerString = '"'
$headerString = $headerString + (($data.value.timeseries.data | gm | Where-Object {$_.MemberType -eq 'NoteProperty'} | Select-Object -ExpandProperty Name) -join '","')
$headerString = $headerString + '"'
#####################>