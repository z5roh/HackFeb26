Param (
    [string] $ResourceGroupName = "htmlwebapp-local-rg",
    [string] $Location = "North Europe",
    [string] $Template = "$PSScriptRoot\azuredeploy.json",
    [string] $TemplateParameters = "$PSScriptRoot\azuredeploy.parameters.json"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($env:RELEASE_DEFINITIONNAME))
{
    Write-Host (@"
Not executing inside VSTS Release Management.
Make sure you have done "Login-AzureRmAccount" and
"Select-AzureRmSubscription -SubscriptionName name"
so that script continues to work correctly for you.
"@)
}

if ((Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue) -eq $null)
{
    Write-Warning "Resource group '$ResourceGroupName' doesn't exist and it will be created."
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -Verbose
}

$result = New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $Template `
    -TemplateParameterFile $TemplateParameters `
    -Verbose

if ($result.Outputs.webAppName -eq $null -or
    $result.Outputs.webAppUri -eq $null)
{
    Throw "Template deployment didn't return web app information correctly and therefore deployment is cancelled."
}

$result

$webAppName = $result.Outputs.webAppName.value
$webAppUri = $result.Outputs.webAppUri.value
Write-Host "##vso[task.setvariable variable=Custom.WebAppName;]$webAppName"

Write-Host "Validating that site is up and running..."
$running = 0
for ($i = 0; $i -lt 60; $i++)
{
    try 
    {
        $request = Invoke-WebRequest -Uri $webAppUri -UseBasicParsing -DisableKeepAlive -ErrorAction SilentlyContinue
        Write-Host "Site status code $($request.StatusCode)."

        if ($request.StatusCode -eq 200)
        {
            Write-Host "Site is up and running."
            $running++
        }
    }
    catch
    {
        Start-Sleep -Seconds 3
    }

    if ($running -eq 10)
    {
        return
    }
}

Throw "Site didn't respond on defined time."
