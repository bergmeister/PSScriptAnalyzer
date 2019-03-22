param(
    [ValidateSet("net451", "netstandard2.0")]
    [string]$Framework = "net451",

    [ValidateSet("Debug", "Release", "PSv3Debug", "PSv3Release", "PSv4Release")]
    [string]$Configuration = "Debug"
)

# todo remove aliases
# todo make each project have its own build script

$outPath = "$BuildRoot/out"
$modulePath = "$outPath/PSScriptAnalyzer"

$buildData = @{}
if ($BuildTask -eq "release") {
    $buildData = @{
        Frameworks = @{
            "net451"         = @{
                Configuration = @('Release', "PSV3Release", "PSv4Release")
            }
            "netstandard2.0" = @{
                Configuration = @('Release')
            }
        }
    }
}
else {
    $buildData.Add("Frameworks", @{})
    $buildData["Frameworks"].Add($Framework, @{})
    $buildData["Frameworks"][$Framework].Add("Configuration", $Configuration)
}

function CreateIfNotExists([string] $folderPath) {
    if (-not (Test-Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory -Verbose:$verbosity
    }
}

function Get-BuildInputs($project) {
    Push-Location $buildRoot/$project
    Get-ChildItem -Filter *.cs
    Get-ChildItem -Directory -Exclude obj, bin | Get-ChildItem -Filter *.cs -Recurse
    Pop-Location
}

function Get-BuildOutputs($project) {
    $bin = "$buildRoot/$project/bin/$Configuration/$Framework"
    $obj = "$buildRoot/$project/obj/$Configuration/$Framework"
    if (Test-Path $bin) {
        Get-ChildItem $bin -Recurse
    }
    if (Test-Path $obj) {
        Get-ChildItem $obj -Recurse
    }
}

function Get-BuildTaskParams($project) {
    $taskParams = @{
        Data = $buildData
        Jobs = {
            $d = $($Task.Data)
            foreach ($frmwrk in $d.Frameworks.Keys) {
                foreach ($config in $d.Frameworks[$frmwrk].Configuration) {
                    dotnet build --framework $frmwrk --configuration $config
                }
            }
        }
    }

    $outputs = (Get-BuildOutputs $project)
    if ($null -ne $outputs) {
        $inputs = (Get-BuildInputs $project)
        $taskParams.Add("Outputs", $outputs)
        $taskParams.Add("Inputs", $inputs)
    }

    $taskParams
}

function Get-CleanTaskParams($project) {
    @{
        Jobs = {
            if (Test-Path obj) {
                Remove-Item obj -Force -Recurse
            }

            if (Test-Path bin) {
                Remove-Item bin -Force -Recurse
            }
        }
    }
}

function Get-TestTaskParam($project) {
    @{
        Jobs = {
            Invoke-Pester
        }
    }
}

function Add-ProjectTask([string]$project, [string]$taskName, [hashtable]$taskParams, [string]$pathPrefix = $buildRoot) {
    $jobs = [scriptblock]::Create(@"
pushd $pathPrefix/$project
$($taskParams.Jobs)
popd
"@)
    $taskParams.Jobs = $jobs
    $taskParams.Name = "$project/$taskName"
    task @taskParams
}

$projects = @("engine", "rules")
$projects | ForEach-Object {
    Add-ProjectTask $_ build (Get-BuildTaskParams $_)
    Add-ProjectTask $_ clean (Get-CleanTaskParams $_)
    Add-ProjectTask $_ test (Get-TestTaskParam $_) "$BuildRoot/tests"
}

task build "engine/build", "rules/build"
task clean "engine/clean", "rules/clean"
task test "engine/test", "rules/test"

task createModule {
    Function CopyToDestinationDir($itemsToCopy, $destination) {
        CreateIfNotExists($destination)
        foreach ($file in $itemsToCopy) {
            Copy-Item -Path $file -Destination (Join-Path $destination (Split-Path $file -Leaf)) -Force
        }
    }

    $solutionDir = $BuildRoot

    $itemsToCopyCommon = @("$solutionDir\Engine\PSScriptAnalyzer.psd1",
        "$solutionDir\Engine\PSScriptAnalyzer.psm1",
        "$solutionDir\Engine\ScriptAnalyzer.format.ps1xml",
        "$solutionDir\Engine\ScriptAnalyzer.types.ps1xml")

    $destinationDir = "$solutionDir\out\PSScriptAnalyzer"
    $destinationDirBinaries = $destinationDir

    foreach ($Framework in $buildData.Frameworks.Keys) {
        foreach ($Configuration in $buildData.Frameworks[$Framework].Configuration) {
            $itemsToCopyBinaries = @("$solutionDir\Engine\bin\$Configuration\$Framework\Microsoft.Windows.PowerShell.ScriptAnalyzer.dll",
                "$solutionDir\Rules\bin\$Configuration\$Framework\Microsoft.Windows.PowerShell.ScriptAnalyzer.BuiltinRules.dll")

            if ($Framework -eq "netstandard2.0") {
                $destinationDirBinaries = "$destinationDir\coreclr"
            }
            elseif ($Configuration -match 'PSv3') {
                $destinationDirBinaries = "$destinationDir\PSv3"
            }
            else {
                $destinationDirBinaries = $destinationDir
            }

            CopyToDestinationDir $itemsToCopyBinaries $destinationDirBinaries

            # copy newtonsoft dll if net451 framework
            if ($Framework -eq "net451") {
                copy-item -path "$solutionDir\Rules\bin\$Configuration\$Framework\Newtonsoft.Json.dll" -Destination $destinationDirBinaries
            }
        }
    }

    CopyToDestinationDir $itemsToCopyCommon $destinationDir

    # Copy Settings File
    Copy-Item -Path "$solutionDir\Engine\Settings" -Destination $destinationDir -Force -Recurse
}

task cleanModule -if (Test-Path $outPath) {
    Remove-Item -Path out/ -Recurse -Force
}


$docsPath = Join-Path $BuildRoot 'docs'
$outputDocsPath = Join-Path $modulePath 'en-US'
$bdInputs = (Get-ChildItem $docsPath -File -Recurse)
$bdOutputs = @(
    "$outputDocsPath/about_PSScriptAnalyzer.help.txt",
    "$outputDocsPath/Microsoft.Windows.PowerShell.ScriptAnalyzer.dll-Help.xml"
)

task buildDocs -Inputs $bdInputs -Outputs $bdOutputs {
    # todo move common variables to script scope
    $markdownDocsPath = Join-Path $docsPath 'markdown'
    CreateIfNotExists($outputDocsPath)

    # Build documentation using platyPS
    if ($null -eq (Get-Module platyPS -ListAvailable -Verbose:$verbosity | Where-Object { $_.Version -ge 0.9 })) {
        throw "Cannot find platyPS of version greater or equal to 0.9. Please install it from https://www.powershellgallery.com/packages/platyPS/ using e.g. the following command: Install-Module platyPS"
    }
    Import-Module platyPS
    if (-not (Test-Path $markdownDocsPath -Verbose:$verbosity)) {
        throw "Cannot find markdown documentation folder."
    }
    New-ExternalHelp -Path $markdownDocsPath -OutputPath $outputDocsPath -Force
}

task cleanDocs -if (Test-Path $outputDocsPath) {
    Remove-Item -Path $outputDocsPath -Recurse -Force
}

task newSession {
    Start-Process "powershell" -ArgumentList @('-noexit', "-command import-module $modulePath -verbose")
}

$localPSModulePath = $env:PSMODULEPATH -split ";" | Where-Object {$_.StartsWith($HOME)}
$pssaDestModulePath = ''
if ($null -ne $localPSModulePath -and $localPSModulePath.Count -eq 1) {
    $pssaDestModulePath = Join-Path $localPSModulePath 'PSScriptAnalyzer'
}

function Test-PSSADestModulePath {
    ($pssaDestModulePath -ne '') -and (Test-Path $pssaDestModulePath)
}

task uninstall -if {Test-PSSADestModulePath} {
    Remove-Item -Force -Recurse $pssaDestModulePath
}

task install -if {Test-Path $modulePath} uninstall, {
    Copy-Item `
        -Recurse `
        -Path  $modulePath `
        -Destination  $pssaDestModulePath
}

# TODO fix building psv3
task release cleanModule, clean, build, createModule, buildDocs
task . build, createModule, newSession
