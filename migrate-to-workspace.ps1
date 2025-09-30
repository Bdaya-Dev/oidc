# Migrates the root pubspec.yaml to use Dart/Flutter workspace support via yq.
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '.')).Path,

    [Parameter(Mandatory = $false)]
    [string]$PackagesDir = 'packages',

    [Parameter(Mandatory = $false)]
    [string]$SdkConstraint = '^3.6.0',

    [Parameter(Mandatory = $false)]
    [string]$FlutterConstraint = '>=3.24.0',

    [Parameter(Mandatory = $false)]
    [string]$YqPath = 'yq'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RequiredCommand {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

Resolve-RequiredCommand -Name $YqPath

$pubspecPath = Join-Path $RepoRoot 'pubspec.yaml'
if (-not (Test-Path -Path $pubspecPath -PathType Leaf)) {
    throw "Could not find pubspec.yaml at '$pubspecPath'."
}

$packagesRoot = Join-Path $RepoRoot $PackagesDir
if (-not (Test-Path -Path $packagesRoot -PathType Container)) {
    throw "Could not find packages directory at '$packagesRoot'."
}

$workspaceMembers = Get-ChildItem -Path $packagesRoot -Filter 'pubspec.yaml' -Recurse -File |
    Where-Object {
        $dir = $_.DirectoryName
        $dir -and ($dir -notmatch '\\.dart_tool\\') -and ($dir -notmatch '\\build\\')
    } |
    ForEach-Object {
        $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $_.DirectoryName)
        ($relative -replace '\\', '/')
    } |
    Sort-Object -Unique

if (-not $workspaceMembers) {
    throw "No workspace members were discovered under '$packagesRoot'."
}

$tempFile = [System.IO.Path]::GetTempFileName()
try {
    Set-Content -Path $tempFile -Value ($workspaceMembers -join "`n") -Encoding UTF8

    $tempFilePosix = $tempFile -replace '\\', '/'

        $yqExpr = @"
            .publish_to = "none" |
            .environment.sdk = "$SdkConstraint" |
            .environment.flutter = "$FlutterConstraint" |
            .workspace = (load_str("$tempFilePosix")
                | split("\n")
                | map(sub("\r$"; ""))
                | map(select(length > 0)))
"@

    & $YqPath eval -i $yqExpr $pubspecPath | Out-Null

    Write-Host "Updated '$pubspecPath' with $(($workspaceMembers | Measure-Object).Count) workspace members."
    Write-Host "SDK constraint set to $SdkConstraint and Flutter constraint set to $FlutterConstraint."
}
finally {
    Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
}
