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

Write-Progress "Building ScriptAnalyzer"
$solutionDir = Split-Path $MyInvocation.InvocationName
if (-not (Test-Path "$solutionDir/global.json"))
{
    throw "Not in solution root"
}

$itemsToCopyBinaries = @("$solutionDir\Engine\bin\$Configuration\$Framework\Microsoft.Windows.PowerShell.ScriptAnalyzer.dll",
    "$solutionDir\Rules\bin\$Configuration\$Framework\Microsoft.Windows.PowerShell.ScriptAnalyzer.BuiltinRules.dll")

$itemsToCopyCommon = @("$solutionDir\Engine\PSScriptAnalyzer.psd1",
    "$solutionDir\Engine\PSScriptAnalyzer.psm1",
    "$solutionDir\Engine\ScriptAnalyzer.format.ps1xml",
    "$solutionDir\Engine\ScriptAnalyzer.types.ps1xml")

$destinationDir = "$solutionDir\out\PSScriptAnalyzer"
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

    Write-Progress "Building Engine"
    if (-not (Test-DotNetRestore((Join-Path $solutionDir Engine))))
    {
        Invoke-RestoreSolution
    }
    .\New-StronglyTypedCsFileForResx.ps1 Engine
    Push-Location Engine\
    dotnet build Engine.csproj --framework $Framework --configuration $Configuration
    Pop-Location


    if (-not (Test-DotNetRestore((Join-Path $solutionDir Rules))))
    {
        Invoke-RestoreSolution
    }
    Write-Progress "Building for framework $Framework, configuration $Configuration"
    Push-Location Rules\
    dotnet build Rules.csproj --framework $Framework --configuration $Configuration
    Pop-Location

    Function CopyToDestinationDir($itemsToCopy, $destination)
    {
        if (-not (Test-Path $destination))
        {
            $null = New-Item -ItemType Directory $destination -Force
        }
        foreach ($file in $itemsToCopy)
        {
            Copy-Item -Path $file -Destination (Join-Path $destination (Split-Path $file -Leaf)) -Force
        }
    }


    Write-Progress "Copying files to $destinationDir"
    CopyToDestinationDir $itemsToCopyCommon $destinationDir
    CopyToDestinationDir $itemsToCopyBinaries $destinationDirBinaries

    # Copy Settings File
    Copy-Item -Path "$solutionDir\Engine\Settings" -Destination $destinationDir -Force -Recurse

    # copy newtonsoft dll if net451 framework
    if ($Framework -eq "net451")
    {
        copy-item -path "$solutionDir\Rules\bin\$Configuration\$Framework\Newtonsoft.Json.dll" -Destination $destinationDirBinaries
    }
}

$modulePath = "$HOME\Documents\WindowsPowerShell\Modules";
$pssaModulePath = Join-Path $modulePath PSScriptAnalyzer


if ($uninstall)
{
    if ((Test-Path $pssaModulePath))
    {
        Remove-Item -Recurse $pssaModulePath
    }
}

if ($install)
{
    Write-Progress "Installing to $modulePath"
    Copy-Item -Recurse -Path "$destinationDir" -Destination "$modulePath\." -Force
}
