$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$Region = if ($env:AWS_REGION) { $env:AWS_REGION } elseif ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { 'us-east-1' }
$AwsTlsArgs = @()
if ($env:AWS_CLI_NO_VERIFY_SSL -eq '1') { $AwsTlsArgs += '--no-verify-ssl' }

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw 'AWS CLI is required.'
}

aws cloudformation validate-template --template-body "file://$RootDir/network.yml" --region $Region @AwsTlsArgs | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Network template validation failed.' }

aws cloudformation validate-template --template-body "file://$RootDir/udagram.yml" --region $Region @AwsTlsArgs | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Application template validation failed.' }

Write-Output "Both CloudFormation templates are valid in $Region."
