﻿param(
    # Automatically performs a 'dotnet restore' when being run the first time
    [switch]$Build,
    # Restore Projects in case NuGet packages have changed
    [switch]$Restore,
    [switch]$Uninstall,
    [switch]$Install,

    [ValidateSet("net451", "netstandard1.6")]
    [string]$Framework = "netstandard1.6",

    [ValidateSet("Debug", "Release", "PSv3Debug", "PSv3Release")]
    [string]$Configuration = "Debug"
)

if ($Configuration -match "PSv3" -and $Framework -eq "netstandard1.6")
{
    throw ("{0} configuration is not applicable to {1} framework" -f $Configuration,$Framework)
}

Function Test-DotNetRestore
{
    param(
        [string] $projectPath
    )
    Test-Path ([System.IO.Path]::Combine($projectPath, 'obj', 'project.assets.json'))
}

function Invoke-RestoreSolution
{
    dotnet restore (Join-Path $PSScriptRoot .\PSScriptAnalyzer.sln)
}

Push-Location $PSScriptRoot

$itemsToCopyCommon = @("$PSScriptRoot\Engine\PSScriptAnalyzer.psd1",
                       "$PSScriptRoot\Engine\PSScriptAnalyzer.psm1",
                       "$PSScriptRoot\Engine\ScriptAnalyzer.format.ps1xml",
                       "$PSScriptRoot\Engine\ScriptAnalyzer.types.ps1xml")

$destinationDir = "$PSScriptRoot\out\PSScriptAnalyzer"
$destinationDirBinaries = $destinationDir
if ($Framework -eq "netstandard1.6")
{
    $destinationDirBinaries = "$destinationDir\coreclr"
}
elseif ($Configuration -match 'PSv3') {
    $destinationDirBinaries = "$destinationDir\PSv3"
}

if ($Restore.IsPresent)
{
    Invoke-RestoreSolution
}

if ($build)
{

    if (-not (Test-DotNetRestore((Join-Path $PSScriptRoot Engine))))
    {
        Invoke-RestoreSolution
    }
    Push-Location Engine\
    dotnet build Engine.csproj --framework $Framework --configuration $Configuration
    Pop-Location


    if (-not (Test-DotNetRestore((Join-Path $PSScriptRoot Rules))))
    {
        Invoke-RestoreSolution
    }
    Push-Location Rules\
    dotnet build Rules.csproj --framework $Framework --configuration $Configuration
    dotnet publish Rules.csproj --framework $Framework --configuration $Configuration --output $destinationDirBinaries
    Pop-Location

    Function CopyToDestinationDir($itemsToCopy, $destination)
    {
        if (-not (Test-Path $destination))
        {
            New-Item -ItemType Directory $destination -Force
        }
        foreach ($file in $itemsToCopy)
        {
            Copy-Item -Path $file -Destination (Join-Path $destination (Split-Path $file -Leaf)) -Verbose -Force
        }
    }
    CopyToDestinationDir $itemsToCopyCommon $destinationDir
}

$modulePath = "$HOME\Documents\WindowsPowerShell\Modules";
$pssaModulePath = Join-Path $modulePath PSScriptAnalyzer


if ($uninstall)
{
    if ((Test-Path $pssaModulePath))
    {
        Remove-Item -Recurse $pssaModulePath -Verbose
    }
}

if ($install)
{
    Copy-Item -Recurse -Path "$destinationDir" -Destination "$modulePath\." -Verbose -Force
}

Pop-Location
