$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$Region = if ($env:AWS_REGION) { $env:AWS_REGION } elseif ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { 'us-east-1' }
$AwsTlsArgs = @()
if ($env:AWS_CLI_NO_VERIFY_SSL -eq '1') { $AwsTlsArgs += '--no-verify-ssl' }
$NetworkStackName = if ($env:NETWORK_STACK_NAME) { $env:NETWORK_STACK_NAME } else { 'udagram-network' }
$AppStackName = if ($env:APP_STACK_NAME) { $env:APP_STACK_NAME } else { 'udagram-app' }

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw 'AWS CLI is required.'
}

aws sts get-caller-identity --region $Region @AwsTlsArgs | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'AWS credentials are missing or invalid. Run aws configure or refresh your credentials.'
}

function Test-StackExists([string] $StackName) {
    aws cloudformation describe-stacks --stack-name $StackName --region $Region @AwsTlsArgs 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Wait-ForStack([string] $StackName, [string] $Action) {
    aws cloudformation wait "stack-$Action-complete" --stack-name $StackName --region $Region @AwsTlsArgs
    if ($LASTEXITCODE -ne 0) { throw "$StackName did not complete successfully." }
}

function Deploy-Stack([string] $StackName, [string] $TemplatePath, [string] $ParameterPath) {
    if (Test-StackExists $StackName) {
        Write-Output "Updating $StackName..."
        $output = aws cloudformation update-stack --stack-name $StackName --template-body "file://$TemplatePath" --parameters "file://$ParameterPath" --capabilities CAPABILITY_IAM --region $Region @AwsTlsArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            if ($output -match 'No updates are to be performed') {
                Write-Output "$StackName is already up to date."
                return
            }
            throw ($output -join [Environment]::NewLine)
        }
        Wait-ForStack $StackName 'update'
    } else {
        Write-Output "Creating $StackName..."
        aws cloudformation create-stack --stack-name $StackName --template-body "file://$TemplatePath" --parameters "file://$ParameterPath" --capabilities CAPABILITY_IAM --region $Region @AwsTlsArgs | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not create $StackName." }
        Wait-ForStack $StackName 'create'
    }
    Write-Output "$StackName is ready."
}

& "$ScriptDir\validate.ps1"
Deploy-Stack $NetworkStackName "$RootDir\network.yml" "$RootDir\network-parameters.json"
Deploy-Stack $AppStackName "$RootDir\udagram.yml" "$RootDir\udagram-parameters.json"

Write-Output 'Deployment complete. Application outputs:'
aws cloudformation describe-stacks --stack-name $AppStackName --query 'Stacks[0].Outputs' --output table --region $Region @AwsTlsArgs
