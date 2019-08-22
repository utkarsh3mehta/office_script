<#
.SYNOPSIS
Function to create metric alerts using inputs from a CSV file

.DESCRIPTION
This function allows you to create metric alerts just be putting the information in a CSV file (as mentioned in the Input part)
The function considers names as per UTC naming convention. 
I.e.: 
1. Action groups are be placed in resource groups names like <subscriptionName>AlertingRG<locationOfResource>
2. Action groups are named Support Email <locationOfResource>
----------------
The function validates the CSV file as it goes ahead creating the alerts and saves the alerts information if it faces any issue.


.INPUT
The CSV file that must contain columns of
Column 1: 
Header: AlertName
Description: Name of the alert
Content type: Text
-----------------
Column 2: 
Header: ResourceId
Description: Resource ID of the resource
Content type: Text
-----------------
Column 3:
Header: ResourceGroupName
Description: Resource group of the resource
Context type: Text
-----------------
Column 4:
Header: Location
Description: Location of the resource
Context type: Text
Preference: No special character or spaces
-----------------
Column 5:
Header: SubscriptionId
Description: Subscription ID of the resource
Context type: Numbers with hyphen(-)
-----------------
Column 6:
Header: Metric
Description: Metric on which you would like to monitor the resource
Reference: https://docs.microsoft.com/en-us/azure/azure-monitor/platform/metrics-supported
Context type: Text
-----------------
Column 7:
Header: Threshold
Description: The limit that should not be breached
Context type: Number
-----------------
Column 8:
Header: Operator
Description: The relation between the threshold and the metric
Preference: greater than, greater than or equal to, less than, less than or equal to
Context type: Text, any one from above
-----------------
Column 9:
Header: Aggregator
Description: The relation between operator and threshold
Preference: Average, minimum, maximum, total
Context type: Text
-----------------
Column 10:
Header: Severity
Description: Severity of the alert to be created
Preference: 0 - 4 (0 is low, 4 is high)
Context type: Number
-----------------
Column 11:
Header: Window
Description: Time window that the resource needs to be monitored before throwing an alert
Reference: 1m, 5m, 1h, 1d and so on
Context type: Alphanumeric
-----------------
Column 12:
Header: ActionGroup
Description: An action group that will be assigned to the alert upon creation
Context type: Text
-----------------
Column 13:
Header: Emailid
Description: Email ID has must recieve the alert
Context type: Email

.OUTPUT
For every row it faces a validation issue, it saves that information and shares it in the end. For each row that has no issue, alerts are created and displayed.

.EXAMPLE
PS> Create-UTCMetricAlert -CsvPath "C:/temp/metricInfo.csv"

.LINK

https://docs.microsoft.com/en-us/azure/azure-monitor/platform/metrics-supported

#>

Function Create-UTCMetricAlert 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $CsvPath
    )

    Begin
    {
        if(Test-Path -Path $CsvPath -ErrorAction Stop) 
        {
            $csv = Import-Csv -Path $CsvPath
            az login -u notification@otiselevator.net -p Inecurity.097
            # get the list of unique subscriptions present in the CSV
            $subscriptionlist = ($csv | Group-Object SubscriptionId).Name

            if($subscriptionlist -eq $null) 
            {
                Write-Error "No subscription detected. Do you have a column 'SubscriptonId' in the mentioned CSV file?"
                Sleep -Seconds 10
                Exit
            }

            #initialing important variables
            $wrong_operator = ""
            $wrong_aggregator = ""
            $total_rid = ""
            $r = 1
            $total_r = @()
            $total_a = @()
            $err = $false
        } else {
            Write-Error "CSV file path does not exist."
        }
    }

    Process
    {
        foreach($sub in $subscriptionlist) {
            # Set each subscription as the current subscription
            az account set -s $sub
            # Get the name of the current subscription
            $subscriptionName = (az account show | ConvertFrom-Json).name
            $subscriptionName = $subscriptionName -replace '[ -\/:*?"<>|.,]',''
            Write-Host "Logged into $subscriptionName" -ForegroundColor Cyan
            # Select the rows of each subscription from the CSV file
            Write-Verbose "Collecting data from CSV for subscription $subscriptionName" -Verbose
            $data = $csv | Where-Object SubscriptionId -EQ $sub    

            foreach($row in $data){
                # Declare the variables from each row of the CSV file
                Write-Verbose "Initializing variables" -Verbose
                $location = $row.Location -replace ('[ -\/:*?"<>|.,]','')
                $name = $row.AlertName
                $resourcegroupname = $row.ResourceGroupName        
                $metric = $row.Metric
                $resourceid = $row.ResourceId
                $threshold = $row.Threshold
                $sev = $row.Severity
                $window = $row.Window
                $actionGroup = $row.ActionGroup
                $emailid = $row.Emailid
                $recipientName = ($emailid -split '@')[0]

                if(!($name -and $location -and $resourcegroupname -and $metric -and $resourceid -and $threshold -and $sev -and $window)) {
                    Write-Error "Some important value missing at row number $r. Please check."
                    $total_r += $r
                    $err = $true
                }

                if(!(az resource show --id $resourceid)) {
                    Write-Error "Issue finding resource for the alert $name."
                    $total_rid += $name+";`n"
                    $err = $true
                }

                if(!$actionGroup -and !$emailid) {
                    Write-Error "No recipient mentioned at row number $r. Please check."
                    $total_r += $r
                    $err = $true
                }

                $operator = $row.Operator
                if($operator -like 'Greater than'){$operator_final = '>'}
                elseif($operator -like 'Greater than or equal to'){$operator_final = '>='}
                elseif($operator -like 'less than'){$operator_final = '<'}
                elseif($operator -like 'Less than or equal to'){$operator_final = '<='}
                else{
                    $wrong_operator += $name+";`n"
                    Write-Error "Wrong operator detected"
                    $err = $true
                }

                $aggregator = $row.Aggregator
                if($aggregator -like 'av*g*'){$aggregator_final = 'avg'}
                elseif($aggregator -like 'max*'){$aggregator_final = 'max'}
                elseif($aggregator -like 'min*'){$aggregator_final = 'min'}
                elseif($aggregator -like 'tot*'){$aggregator_final = 'total'}
                else{
                    $wrong_aggregator += $name+";`n"
                    Write-Error "Wrong aggregator detected"
                    $err = $true
                }

                if($err -eq $true){
                    ++$r
                    $err = $false
                    continue
                }

                $condition = $aggregator_final + " " + $metric + " " + $operator_final + " " + $threshold        
                $resourcename = ($resourceid -split '/')[-1]        
                $description = "Send alert when $condition on $resourcename"
                
                # Get the list of action groups in the subscription and convert to JSON for PowerShell to parse
                $action_group = az monitor action-group list | ConvertFrom-Json
                $action_group_final = $null
                Write-Host "Searching for action group in existing resource groups" -ForegroundColor Cyan
                :outer foreach($ag in $action_group){
                    # Check if any action group belongs to the resource groups as per UTC naming convention
	                if($ag.resourceGroup -like "*AlertingRG$location*"){
                        if($actionGroup -match $ag.name) {
                            $action_group_final = $ag.id
                            Write-Host "Action group found using the provided action group name. Breaking loop" -ForegroundColor Cyan
                            Break
                        }
                        if($emailid) {
		                    foreach($email in $ag.emailReceivers){
                                # If it does, then check if any action group has a reciever of the email provided
			                    if($email.emailAddress -eq $emailid){
                                    # Get the ID of the action group
                                    $action_group_final = $ag.id
                                    Write-Host "Action group found that uses the provided email ID. Breaking loop" -ForegroundColor Cyan
                                    Break outer
                                }
                            }
                        }
                    }
                }

                # if action group couldn't be found, then it is mandatory to get the email id.
                if(($action_group_final -eq $null) -and !$emailid) {
                    Write-Error "No action group found. The email id is also not present at row number $r. Please check."
                    $total_a += $r
                    $err = $true
                }

                if($err -eq $true){
                    ++$r
                    $err = $false
                    continue
                }

                # If action group final is empty, i.e. no action group found
                if($action_group_final -eq $null){
                    Write-Host "No action group found with required email addresses." -ForegroundColor Cyan
                    Write-Host "Starting the process of creating an action group" -ForegroundColor Cyan

                    # Declare names of resource groups and action groups
                    $rgname = $subscriptionName+"AlertingRG"+$location
                    $action_group_name = "Support Email $location"

                    # Check if the resource group exists
                    Write-host "Looking for resource group as per naming convention" -ForegroundColor Cyan
                    if((az group exists --name $rgname) -eq 'true'){
                        # If yes, create an action group
                        Write-Host "Resource group found. Creating action group" -ForegroundColor Cyan
                        az monitor action-group create --name $action_group_name -g $rgname --action email $recipientName $emailid
                    }
                    else{
                        # If no, create a resource group
                        Write-Host "No resource group found. Creating a resource group." -ForegroundColor Cyan
                        az group create --location $location --name $rgname
                        Write-host "Resource Group created" -ForegroundColor Cyan
                        # Create an action group
                        Write-Host "Creating action group" -ForegroundColor Cyan
                        az monitor action-group create --name $action_group_name -g $rgname --action email $recipientName $emailid
                        Write-Host "Action group created" -ForegroundColor Cyan
                    }

                    # Get the ID of the newly created action group
                    $action_group_final = (az monitor action-group show --name $action_group_name -g $rgname | ConvertFrom-Json).id
                }

                # Create the metric alert
                Write-Host "Creating alert" -ForegroundColor Cyan
                az monitor metrics alert create -n $name -g $resourcegroupname --scopes $resourceid --condition $condition --description $description --severity $sev --window-size $window --action $action_group_final

                Write-Host "Created an alert $name for $resourcename" -ForegroundColor Black -BackgroundColor White
                $emailid = $null
                ++$r
            }
        }
    }

    End
    {
        Write-Host "Below is the list of alerts that were not created" -ForegroundColor Red -BackgroundColor White
        Write-Host "Alerts that have the wrong aggregator." -ForegroundColor Red -BackgroundColor White
        Write-Host ($wrong_aggregator) -ForegroundColor Red -BackgroundColor White
        Write-Host "=================================================" -ForegroundColor Red -BackgroundColor White
        Write-Host "Alerts that have the wrong operator." -ForegroundColor Red -BackgroundColor White
        Write-Host ($wrong_operator) -ForegroundColor Red -BackgroundColor White
        Write-Host "=================================================" -ForegroundColor Red -BackgroundColor White
        Write-Host "Alerts that have the wrong resource mentioned." -ForegroundColor Red -BackgroundColor White
        Write-Host ($total_rid) -ForegroundColor Red -BackgroundColor White
        Write-Host "=================================================" -ForegroundColor Red -BackgroundColor White
        Write-Host "Rows that have some important info missing OR Have no recipient address mentioned (Action group and email ID)." -ForegroundColor Red -BackgroundColor White
        Write-Host (($total_r -join '; ')+"`n") -ForegroundColor Red -BackgroundColor White
        Write-Host "=================================================" -ForegroundColor Red -BackgroundColor White
        Write-Host "Rows where the action group is mentioned but couldn't be found. Also, the email id is not present for me to automatically create the action group" -ForegroundColor Red -BackgroundColor White
        Write-Host (($total_a -join '; ')+"`n") -ForegroundColor Red -BackgroundColor White
        Write-Host "Thank you for using this script."
        Write-Verbose "Logging out of Azure" -Verbose
        az logout
    }
}