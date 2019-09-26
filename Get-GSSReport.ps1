$tenantId = "03afca2b-f47f-4d0b-9a25-d464aff5d351"

$clientId = "39d4aeb5-68b7-47ea-8750-64d77ffc2750"
$key = "ab688f54-5ebf-4e8c-92c1-53f43e32e0bd"

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


$data = Invoke-RestMethod -Method Get -Headers $authHeader -Uri "https://management.azure.com/subscriptions/7785bb96-4a80-4ad9-a587-e478bfa62cf8/resourceGroups/AlexaTesting/providers/Microsoft.Web/sites/AlexaForG3MS/providers/microsoft.Insights/metrics?timespan=2019-07-26T12:00:00.000Z/2019-09-26T12:00:00.000Z&interval=PT12H&metricnames=CpuTime&aggregation=maximum&metricNamespace=microsoft.web/sites&validatedimensions=false&api-version=2018-01-01"

$data.value.timeseries.data


$subscription = "subscription-id-01","subscription-id-02"
$resourcegroup = "resource-group-name-01","resource-group-name-02"
$starttime = (Get-Date).AddMonths(-2).ToString("yyyy-MM-ddT12:00:00.000Z")
$endtime = (Get-Date).ToString("yyyy-MM-ddT12:00:00.000Z")

foreach($sub in $subscription) {
    Set-AzureRmContext -Subscription $sub
    foreach($rg in $resourcegroup) {
        $resource = Get-AzureRmResource -ResourceGroupName $rg
        if ($resource -ne $null) {
            Write-Host "Working in resource group $rg"
            foreach($res in $resource) {
                $api = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/"
                if($res.ResourceType -eq 'Microsoft.Storage/storageAccounts') {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $api = $api + "metricnames=Availability&aggregation=average&metricNamespace=microsoft.storage/storageaccounts&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for storage accounts" -ForegroundColor Yellow
                    $api
                } elseif ($res.ResourceType -eq "Microsoft.Web/sites") {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $ipa = $api
                    $api = $api + "metricnames=CpuTime&aggregation=average&metricNamespace=microsoft.web/sites&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for app services CPU time" -ForegroundColor Yellow
                    $api
                    $api = $ipa + "metricnames=Http5xx&aggregation=average&metricNamespace=microsoft.web/sites&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for app services HTTP Server Errors" -ForegroundColor Yellow
                    $api
                } elseif ($res.ResourceType -eq 'Microsoft.CognitiveServices/accounts') {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $api = $api + "metricnames=TotalErrors&aggregation=total&metricNamespace=microsoft.cognitiveservices/accounts&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for cognitive services total errors" -ForegroundColor Yellow
                    $api
                } elseif ($res.ResourceType -eq 'Microsoft.DataFactory/factories') {
                    $api = $api + $res.ResourceType +"/" + $res.Name + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $ipa = $api
                    $api = $api + "metricnames=ActivityFailedRuns&aggregation=average&metricNamespace=microsoft.datafactory/factories&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for data factory activity failed run" -ForegroundColor Yellow
                    $api
                    $api = $ipa + "metricnames=PipelineFailedRuns&aggregation=total&metricNamespace=microsoft.datafactory/factories&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for data factory pipeline failed run" -ForegroundColor Yellow
                    $api
                }
            }
            $dbserver = $resource | Where-Object {$_.ResourceType -eq 'Microsoft.Sql/servers'}
            foreach($dbser in $dbserver)  {
                $database = Get-AzureRmSqlDatabase -ServerName $dbser.Name -ResourceGroupName $dbser.ResourceGroupName
                foreach($db in $database) {
                    $api = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/"
                    $api = $api + $dbser.ResourceType + "/" + $dbser.Name + "/databases/" + $db.DatabaseName + "/providers/microsoft.Insights/metrics?timespan=$starttime/$endtime&interval=PT12H&"
                    $ipa = $api
                    $api = $api + "metricnames=cpu_percent&aggregation=maximum&metricNamespace=microsoft.sql/servers/databases&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for SQL Database CPU usage" -ForegroundColor Yellow
                    $api
                    $api = $ipa + "metricnames=dtu_consumption_percent&aggregation=maximum&metricNamespace=microsoft.sql/servers/databases&autoadjusttimegrain=true&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for SQL DB DTU" -ForegroundColor Yellow
                    $api
                    $api = $ipa + "metricnames=physical_data_read_percent&aggregation=maximum&metricNamespace=microsoft.sql/servers/databases&validatedimensions=false&api-version=2018-01-01"
                    Write-Host "API for SQL DB IO" -ForegroundColor Yellow
                    $api
                }
            }
        }
    }    
}