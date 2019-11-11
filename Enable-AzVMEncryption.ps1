<#

.Synopsis
Enable disk encryption on all disks of a virtual machine

.Description
This script first checks if the right modules are installed or not. 
Then it logs you in the portal. 
Taking all the necessary inputs, the script checks/creates for the correct key-vault and keys to encrpyt all the disks of a VM.
It also gives you and backup management service Service principle the required access to work fine.

#>

# Check for the required modules
if(!(Get-Module -ListAvailable -Name Az.Accounts)){
    Write-Error "Az.Accounts module not present. Also make sure, Az.KeyVault and Az.Compute modules are present."
    Sleep -Seconds 5
    Exit
}
if(!(Get-Module -ListAvailable -Name Az.KeyVault)){
    Write-Error "Az.KeyVault module not present. Also make sure, Az.Compute modules is present."
    Sleep -Seconds 5
    Exit
}
if(!(Get-Module -ListAvailable -Name Az.Compute)){
    Write-Error "Az.Compute module not present."
    Sleep -Seconds 5
    Exit
}

# Login to azure portal
Write-Verbose "Logging you to Azure Portal.`nPlease make sure that your have atleast contributor access on the corresponding resources" -Verbose
Sleep -Seconds 10
az login

# take the inputs
$subscriptionid = Read-Host "Enter subscription ID"
$resourcegroup = Read-Host "Enter resource group name. (CASE-SENSITIVE)"
$vmname = Read-Host "Enter the name of the virtual machine (CASE-SENSITIVE)"

# select the subscription
az account set -s $subscriptionid
$keyvaultname = "$resourcegroup-KV"
$keyname = "$vmname-AK"
# Get user object id
$userobjectid = (az ad signed-in-user show | ConvertFrom-Json).objectId
# Get object id of backup service principal
$splist = az ad sp list --all | ConvertFrom-Json
$backupobjectid = ($splist | Where-Object {$_.displayName -clike "*Backup*Management*Service"}).objectid

# Check if resource provider
Write-Verbose "Checking if a key vault resource provided exists." -Verbose
$azkeyvaultprovider = az provider show --namespace "Microsoft.KeyVault"

if($azkeyvaultprovider -eq $null){
    # if the provider does not exist, create one
    Write-Verbose "Registering a Key vault resource provider." -Verbose
    az provider register --namespace "Microsoft.KeyVault"
}
else{
    Write-Verbose "Resource Provider already registered."
}


# Check if key vault exists
Write-Verbose "Checking if the key vault exists." -Verbose
$azkeyvault = az keyvault show --name $keyvaultname
# Does the key vault exist
if($azkeyvault -eq $null){
    # If not, create one
    Write-Verbose "Creating a new vault." -Verbose
    az keyvault create --name $keyvaultname --resource-group $resourcegroup
}
else{
    Write-Verbose "Key vault found."
}

# Give permissions to user and backup service principal
az keyvault set-policy --name $keyvaultname --object-id $userobjectid --key-permissions get update create import delete list --secret-permissions set delete get list
az keyvault set-policy --name $keyvaultname --object-id $backupobjectid --key-permissions get list backup --secret-permissions get list backup

#Check if key exists
Write-Verbose "Checking if key exists" -Verbose
$azkey = az keyvault key show --name $keyname --vault-name $keyvaultname
if($azkey -eq $null){
    #If not, then create one
    Write-Verbose "Creating a new key" -Verbose
    az keyvault key create --name $keyname --vault-name $keyvaultname --protection software
}
else{
    Write-Verbose "Key found."
}

# Encrypt the VM
Write-Verbose "Encrypting the VM. This may take up 1 hr to complete." -Verbose
az vm encryption enable --disk-encryption-keyvault $keyvaultname --key-encryption-key $keyname --name $vmname --resource-group $resourcegroup --volume-type ALL

##To see the encryption status, uncomment the follow command
#az vm encryption show --name $vmname --resource-group $resourcegroup

## To logout automatically, uncomment the following command
# az logout