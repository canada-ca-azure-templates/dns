Param(
    [Parameter(Mandatory = $True)][string]$templateLibraryName = "name of template",
    [Parameter(Mandatory = $True)][string]$templateLibraryVersion = "version of template",
    [string]$templateName = "azuredeploy.json",
    [string]$containerName = "library-dev",
    [string]$prodContainerName = "library",
    [string]$storageRG = "PwS2-Infra-Storage-RG",
    [string]$storageAccountName = "azpwsdeploytpnjitlh3orvq",
    [string]$Location = "canadacentral"
)

function Output-DeploymentName {
    param( [string]$Name)

    $pattern = '[^a-zA-Z0-9-]'

    # Remove illegal characters from deployment name
    $Name = $Name -replace $pattern, ''

    # Truncate deplayment name to 64 characters
    $Name.subString(0, [System.Math]::Min(64, $Name.Length))
}
$devBaseTemplateUrl = "https://$storageAccountName.blob.core.windows.net/$containerName/arm"
$prodBaseTemplateUrl = "https://$storageAccountName.blob.core.windows.net/$prodContainerName/arm"
$gcLibraryUrl = "https://azpwsdeployment.blob.core.windows.net/library/arm"

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************

# Cleanup old jobs
Get-Job | Remove-Job

#Set-AzureRmCurrentStorageAccount -ResourceGroupName $storageRG -Name $storageAccountName

# Start the deployment
Write-Host "Starting deployment...";

# Building dependencies needed for the server validation
New-AzureRmDeployment -Location $Location -Name "dependancy-$templateLibraryName-Build-resourcegroups" -TemplateUri "$gcLibraryUrl/resourcegroups/20190207.2/$templateName" -TemplateParameterFile (Resolve-Path "$PSScriptRoot\dependancy-resourcegroups-canadacentral.parameters.json") -Verbose

# Cleanup validation resource content
New-AzureRmResourceGroupDeployment -ResourceGroupName PwS2-validate-DNS-RG -Mode Complete -TemplateFile (Resolve-Path "$PSScriptRoot\cleanup.json") -Force -Verbose

# Validating server template
New-AzureRmResourceGroupDeployment -ResourceGroupName PwS2-validate-DNS-RG -Name "validate-$templateLibraryName-Build-$templateLibraryName" -TemplateUri "$devBaseTemplateUrl/$templateLibraryName/$templateLibraryVersion/azuredeploy.json" -TemplateParameterFile (Resolve-Path "$PSScriptRoot\validate.parameters.json") -Verbose

$provisionningState = (Get-AzureRmResourceGroupDeployment -ResourceGroupName PwS2-validate-DNS-RG -Name "validate-$templateLibraryName-Build-$templateLibraryName").ProvisioningState

if ($provisionningState -eq "Failed") {
    Write-Host  "Test deployment failed..."
} else {
    Write-Host  "Test deployment succeeded..."
}

# Cleanup validation resource content
#Write-Host "Cleanup validation resource content...";
#New-AzureRmResourceGroupDeployment -ResourceGroupName PwS2-validate-DNS-RG -Mode Complete -TemplateFile (Resolve-Path "$PSScriptRoot\cleanup.json") -Force -Verbose