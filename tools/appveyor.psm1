# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'

# Implements the AppVeyor 'install' step and installs the required versions of Pester, platyPS and the .Net Core SDK if needed.
function Invoke-AppVeyorInstall {
    $requiredPesterVersion = '4.4.1'
    $pester = Get-Module Pester -ListAvailable | Where-Object { $_.Version -eq $requiredPesterVersion }
    if ($null -eq $pester) {
        if ($null -eq (Get-Module -ListAvailable PowershellGet)) {
            # WMF 4 image build
            Write-Verbose -Verbose "Installing Pester via nuget"
            nuget install Pester -Version $requiredPesterVersion -source https://www.powershellgallery.com/api/v2 -outputDirectory "$env:ProgramFiles\WindowsPowerShell\Modules\." -ExcludeVersion
        }
        else {
            # Visual Studio 2017 build (has already Pester v3, therefore a different installation mechanism is needed to make it also use the new version 4)
            Write-Verbose -Verbose "Installing Pester via Install-Module"
            Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser -RequiredVersion $requiredPesterVersion
        }
    }

    if ($null -eq (Get-Module -ListAvailable PowershellGet)) {
        # WMF 4 image build
        Write-Verbose -Verbose "Installing platyPS via nuget"
        nuget install platyPS -Version 0.9.0 -source https://www.powershellgallery.com/api/v2 -outputDirectory "$Env:ProgramFiles\WindowsPowerShell\Modules\." -ExcludeVersion
    }
    else {
        Write-Verbose -Verbose "Installing platyPS via Install-Module"
        Install-Module -Name platyPS -Force -Scope CurrentUser -RequiredVersion '0.9.0'
    }

	$globalDotJson = Get-Content (Join-Path $PSScriptRoot '..\global.json') -Raw | ConvertFrom-Json
	$dotNetCoreSDKVersion = $globalDotJson.sdk.version
	if ($PSVersionTable.PSVersion.Major -eq '4') {
		# the legacy WMF4 image only has the old .Net Core CLI that does not have the --list-sdks parameter
		$requiredDotNetSDKsAvailable = (dotnet --version).StartsWith($dotNetCoreSDKVersion)
	}
	else {
		$dotnetSDKs = dotnet --list-sdks
		$requiredDotNetSDKsAvailable = $dotnetSDKs -match $requiredDotNetCoreSDKVersion
	}
    if (-not $requiredDotNetSDKsAvailable) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # https://github.com/dotnet/announcements/issues/77
        Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -OutFile dotnet-install.ps1
        .\dotnet-install.ps1 -Version $dotNetCoreSDKVersion
        Remove-Item .\dotnet-install.ps1
    }
}

# Implements AppVeyor 'test_script' step
function Invoke-AppveyorTest {
    Param(
        [Parameter(Mandatory)]
        [ValidateScript( {Test-Path $_})]
        $CheckoutPath
    )

    Write-Verbose -Verbose ("Running tests on PowerShell version " + $PSVersionTable.PSVersion)

    $modulePath = $env:PSModulePath.Split([System.IO.Path]::PathSeparator) | Where-Object { Test-Path $_} | Select-Object -First 1
	Copy-Item "${CheckoutPath}\out\PSScriptAnalyzer" "$modulePath\" -Recurse -Force


    $testResultsFile = ".\TestResults.xml"
    $testScripts = "${CheckoutPath}\Tests\Engine","${CheckoutPath}\Tests\Rules","${CheckoutPath}\Tests\Documentation"
    $testResults = Invoke-Pester -Script $testScripts -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
    (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/${env:APPVEYOR_JOB_ID}", (Resolve-Path $testResultsFile))


	# $violationMessage = "Missing 'Get-TargetResource' function. DSC Resource must implement Get, Set and Test-TargetResource functions."
	# $classViolationMessage = "Missing 'Set' function. DSC Class must implement Get, Set and Test functions."
	# $violationName = "PSDSCStandardDSCFunctionsInResource"
	# $directory = Join-Path $PSScriptRoot '../Tests/Rules'
	# $violations = Invoke-ScriptAnalyzer $directory\DSCResourceModule\DSCResources\MSFT_WaitForAll\MSFT_WaitForAll.psm1 | Where-Object {$_.RuleName -eq $violationName}
	# $noViolations = Invoke-ScriptAnalyzer $directory\DSCResourceModule\DSCResources\MSFT_WaitForAny\MSFT_WaitForAny.psm1 | Where-Object {$_.RuleName -eq $violationName}

	if ($PSVersionTable.PSVersion -ge [Version]'5.0.0')
	{
		$classViolations = Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue $directory\DSCResourceModule\DSCResources\BadDscResource\BadDscResource.psm1 | Where-Object {$_.RuleName -eq $violationName}
		$noClassViolations = Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue $directory\DSCResourceModule\DSCResources\MyDscResource\MyDscResource.psm1 | Where-Object {$_.RuleName -eq $violationName}
	}


	if ($testResults.FailedCount -gt 0) {
        throw "$($testResults.FailedCount) tests failed."
    }
}

# Implements AppVeyor 'on_finish' step
function Invoke-AppveyorFinish {
    $stagingDirectory = (Resolve-Path ..).Path
    $zipFile = Join-Path $stagingDirectory "$(Split-Path $pwd -Leaf).zip"
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    [System.IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $pwd 'out'), $zipFile)
    @(
        # You can add other artifacts here
        (Get-ChildItem $zipFile)
    ) | ForEach-Object { Push-AppveyorArtifact $_.FullName }
}
