$tenantId = ""

$clientId = ""
$key = ""

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