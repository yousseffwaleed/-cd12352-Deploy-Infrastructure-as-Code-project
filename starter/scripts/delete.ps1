$ErrorActionPreference = 'Stop'

$Region = if ($env:AWS_REGION) { $env:AWS_REGION } elseif ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { 'us-east-1' }
$NetworkStackName = if ($env:NETWORK_STACK_NAME) { $env:NETWORK_STACK_NAME } else { 'udagram-network' }
$AppStackName = if ($env:APP_STACK_NAME) { $env:APP_STACK_NAME } else { 'udagram-app' }

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw 'AWS CLI is required.'
}

aws sts get-caller-identity --region $Region | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'AWS credentials are missing or invalid. Refresh your credentials before deleting.'
}

function Test-StackExists([string] $StackName) {
    aws cloudformation describe-stacks --stack-name $StackName --region $Region 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Remove-Stack([string] $StackName) {
    if (-not (Test-StackExists $StackName)) {
        Write-Output "$StackName does not exist; skipping."
        return
    }

    Write-Output "Deleting $StackName..."
    aws cloudformation delete-stack --stack-name $StackName --region $Region
    if ($LASTEXITCODE -ne 0) { throw "Could not delete $StackName." }
    aws cloudformation wait stack-delete-complete --stack-name $StackName --region $Region
    if ($LASTEXITCODE -ne 0) { throw "$StackName did not finish deleting." }
    Write-Output "$StackName deleted."
}

# Delete the application first because it imports network-stack exports.
Remove-Stack $AppStackName
Remove-Stack $NetworkStackName
Write-Output 'Teardown complete.'
