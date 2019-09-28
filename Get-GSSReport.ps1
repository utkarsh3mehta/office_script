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

Function RestRequest ($apiParam, $csvParam, $nameParam) {
    #Write-Host "API"
    #$apiParam
    #Write-Host "CSV"
    #$csvParam
    [URI]$apiParam = $apiParam
    $nameParam | Out-File -FilePath $csvParam -Encoding utf8 -Append
    $data = Invoke-RestMethod -Headers $authHeader -Uri $apiParam
    $data.namespace | Out-File -FilePath $csvParam -Encoding utf8 -Append
    $data.timespan | Out-File -FilePath $csvParam -Encoding utf8 -Append
    $data.value.name.localizedValue | Out-File -FilePath $csvParam -Encoding utf8 -Append
    [array]$header = $data.value.timeseries.data | gm | Where-Object {$_.MemberType -eq 'NoteProperty'} | Select-Object -ExpandProperty Name
    $headerString = '"'
    $headerString = $headerString + (($data.value.timeseries.data | gm | Where-Object {$_.MemberType -eq 'NoteProperty'} | Select-Object -ExpandProperty Name) -join '","')
    $headerString = $headerString + '"'
    $headerString | Out-File -FilePath $csvParam -Encoding utf8 -Append
    foreach ($row in $data.value.timeseries.data) {
        $dataString = '"'
        for ($i = 0; $i -lt $header.Length; $i++) {
            $column = $header[$i]
            if($i -eq ($header.Length - 1)) {
                $dataString = $dataString + $row.$column + '"'
            } else {
                $dataString = $dataString + $row.$column + '","'
            }
        }
        $dataString | Out-File -FilePath $csvParam -Encoding utf8 -Append
    }
    "`r`n" | Out-File -FilePath $csvParam -Encoding utf8 -Append
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
                if($res.ResourceType -eq 'Microsoft.Storage/storageAccounts') 
                {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $api = $api + "metricnames=Availability&aggregation=average&metricNamespace=microsoft.storage/storageaccounts&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for storage accounts" -ForegroundColor Yellow
                    $csv = $output + "Availability-" + ($res.ResourceType -replace '[.\/-]','') + ".csv"
                    RestRequest -apiParam $api -csvParam $csv -nameParam $res.Name
                } 
                elseif ($res.ResourceType -eq "Microsoft.Web/sites") 
                {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $ipa = $api
                    $api = $api + "metricnames=CpuTime&aggregation=maximum&metricNamespace=microsoft.web/sites&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for app services CPU time" -ForegroundColor Yellow
                    $csv = $output + "CPUtime-" + ($res.ResourceType -replace '[.\/-]','') + ".csv"
                    RestRequest -apiParam $api -csvParam $csv -nameParam $res.Name
                    $api = $ipa + "metricnames=Http5xx&aggregation=total&metricNamespace=microsoft.web/sites&validatedimensions=false&api-version=2018-01-01"
                    $csv = $output + "http5xx-" + ($res.ResourceType -replace '[.\/-]','') + ".csv"
                    RestRequest -apiParam $api -csvParam $csv -nameParam $res.Name
                } 
                elseif ($res.ResourceType -eq 'Microsoft.CognitiveServices/accounts') 
                {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $api = $api + "metricnames=TotalErrors&aggregation=total&metricNamespace=microsoft.cognitiveservices/accounts&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for cognitive services total errors" -ForegroundColor Yellow
                    $csv = $output + "totalErrors-" + ($res.ResourceType -replace '[.\/-]','') + ".csv"
                    RestRequest -apiParam $api -csvParam $csv -nameParam $res.Name
                } 
                elseif ($res.ResourceType -eq 'Microsoft.DataFactory/factories') 
                {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $ipa = $api
                    $api = $api + "metricnames=ActivityFailedRuns&aggregation=average&metricNamespace=microsoft.datafactory/factories&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for data factory activity failed run" -ForegroundColor Yellow
                    $csv = $output + "failedActivity-" + ($res.ResourceType -replace '[.\/-]','') + ".csv"
                    RestRequest -apiParam $api -csvParam $csv -nameParam $res.Name
                    $api = $ipa + "metricnames=PipelineFailedRuns&aggregation=total&metricNamespace=microsoft.datafactory/factories&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for data factory pipeline failed run" -ForegroundColor Yellow
                    $csv = "FailedPipeline-" + $csv
                    $csv = $output + "fialedPipeline-" + ($res.ResourceType -replace '[.\/-]','') + ".csv"
                    RestRequest -apiParam $api -csvParam $csv -nameParam $res.Name
                } 
                elseif ($res.ResourceType -eq 'Microsoft.Sql/servers') 
                {
                    $database = Get-AzureRmSqlDatabase -ServerName $res.Name -ResourceGroupName $res.ResourceGroupName
                    foreach($db in $database) {
                        [String]$api = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/"
                        $api = $api + $res.ResourceType + "/" + $res.Name + "/databases/" + $db.DatabaseName + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                        $ipa = $api
                        $api = $api + "metricnames=cpu_percent&aggregation=maximum&metricNamespace=microsoft.sql/servers/databases&validatedimensions=false&api-version=2018-01-01"
                        Write-Host "API for SQL Database CPU usage" -ForegroundColor Yellow
                        $csv = $output + "CPUusage-" + ($res.ResourceType -replace '[.\/-]','') + ".csv"
                        RestRequest -apiParam $api -csvParam $csv -nameParam $res.Name
                        $api = $ipa + "metricnames=dtu_consumption_percent&aggregation=maximum&metricNamespace=microsoft.sql/servers/databases&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                        Write-Host "API for SQL DB DTU" -ForegroundColor Yellow
                        $csv = $output + "DTU-" + ($res.ResourceType -replace '[.\/-]','') + ".csv"
                        RestRequest -apiParam $api -csvParam $csv -nameParam $res.Name
                        $api = $ipa + "metricnames=physical_data_read_percent&aggregation=maximum&metricNamespace=microsoft.sql/servers/databases&validatedimensions=false&api-version=2018-01-01"
                        Write-Host "API for SQL DB IO" -ForegroundColor Yellow
                        $csv = $output + "IO-" + ($res.ResourceType -replace '[.\/-]','') + ".csv"
                        RestRequest -apiParam $api -csvParam $csv -nameParam $res.Name
                    }
                }
            }
        }
    }    
}