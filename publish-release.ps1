<#
Announce a new full Triton build to every install's updater.

  .\publish-release.ps1 -Release p155-b6 -Key E:\triton-patch-primary.key -Summary "Short line for the update page."

Before running it:
  1. Bump shared.TritonVersion (PROTOTYPE / BUILD) and build the jar.
     The tool refuses a jar that does not say it is -Release.
  2. Upload the jar:  ..\triton-release\upload-release.ps1 -Release p155-b6 -Files <triton.jar>

What it does:
  1. Checks the public download link answers with the same size as -Jar.
  2. Pulls this repo so the notice sequence continues from the published one.
  3. UpdateTool notice : hashes the jar, writes release.properties (sequence + 1) and signs it.
  4. Commits and pushes (skip the push with -NoPush to look first).

Installs see it on their next check: Settings > System > Triton Update, or the
automatic check after boot. They download from -Url, check the SHA-256 against
this signed notice, and install on restart.
The key never enters this folder; keep it on its offline drive.
#>
param(
    [Parameter(Mandatory = $true)][string]$Release,
    [Parameter(Mandatory = $true)][string]$Key,
    [string]$Summary = "",
    [string]$Jar = "$env:USERPROFILE\Desktop\Project-E1102\echelon\target\triton.jar",
    [string]$Url = "",
    [string]$Notes = "https://strombos.dev/",
    [string]$Classes = "$env:USERPROFILE\Desktop\Project-E1102\echelon\target\classes",
    [string]$Java = "$env:USERPROFILE\.jdks\jbr-25.0.4.1\bin\java.exe",
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot

function Fail([string]$msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

if ($Release -notmatch '^p\d{1,6}-b\d{1,6}$') { Fail "-Release must look like p155-b6." }
if ($Url -eq "") { $Url = "https://downloads.strombos.dev/$Release/triton.jar" }
if (-not $Url.StartsWith("https://")) { Fail "-Url must be https." }
if (-not (Test-Path $Jar -PathType Leaf)) { Fail "Jar not found: $Jar" }
if (-not (Test-Path $Key -PathType Leaf)) { Fail "Key not found: $Key" }
if (-not (Test-Path "$Classes\echelon\module\vortex\update\UpdateTool.class")) { Fail "UpdateTool is not compiled under $Classes" }
if (-not (Test-Path $Java -PathType Leaf)) {
    $onPath = Get-Command java -ErrorAction SilentlyContinue
    if ($null -eq $onPath) { Fail "No java found. Pass -Java <path to java.exe> (Java 21+)." }
    $Java = $onPath.Source
}

$keyFull = (Resolve-Path $Key).Path
$jarFull = (Resolve-Path $Jar).Path
if ($keyFull.StartsWith($repo, [StringComparison]::OrdinalIgnoreCase)) { Fail "The key is inside the repo folder. Keep it outside." }

# 1. The download has to be there, and be this jar's size, before anyone is told about it.
$localSize = (Get-Item $jarFull).Length
Write-Host "Checking $Url ..."
try {
    $head = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing
} catch {
    Fail "The download link does not answer ($($_.Exception.Message)). Upload the jar first with upload-release.ps1."
}
$remoteSize = [int64]($head.Headers['Content-Length'] | Select-Object -First 1)
if ($remoteSize -ne $localSize) {
    Fail "The uploaded file is $remoteSize bytes but $Jar is $localSize. Upload this jar, or point -Jar at the one you uploaded."
}
Write-Host "  online and the same size ($localSize bytes)" -ForegroundColor Green

Push-Location $repo
try {
    $dirty = git status --porcelain
    if ($dirty) { Fail "The repo has uncommitted changes. Commit or discard them first:`n$dirty" }
    git pull --ff-only
    if ($LASTEXITCODE -ne 0) { Fail "git pull failed." }

    $before = $null
    if (Test-Path "$repo\release.properties") { $before = Get-Content "$repo\release.properties" -Raw }

    & $Java -cp $Classes echelon.module.vortex.update.UpdateTool notice $keyFull $jarFull $Release $Url $repo $Summary $Notes
    if ($LASTEXITCODE -ne 0) { Fail "Writing the notice failed; nothing was published." }
    & $Java -cp $Classes echelon.module.vortex.update.UpdateTool verify $repo
    if ($LASTEXITCODE -ne 0) {
        git checkout -- release.properties release.properties.sig 2>$null
        Fail "The new notice does not verify against the keys built into Triton; it was not published."
    }

    $leak = Get-ChildItem $repo -Recurse -File -Include *.key, *.pem | Select-Object -First 1
    if ($null -ne $leak) { Fail "A key file is inside the repo ($($leak.FullName)). Not committing." }

    git add -- release.properties release.properties.sig
    git commit -m "Release $Release"
    if ($LASTEXITCODE -ne 0) { Fail "git commit failed." }

    if ($NoPush) {
        Write-Host "Committed locally. Run 'git push' in $repo to publish." -ForegroundColor Yellow
    } else {
        git push
        if ($LASTEXITCODE -ne 0) { Fail "git push failed; the notice is committed locally only." }
        Write-Host "Published $Release. Installs see it on their next check (GitHub raw can lag a few minutes)." -ForegroundColor Green
    }
} finally {
    Pop-Location
}
