<#
Release one Triton security patch to this feed.

  .\release-patch.ps1 -Manifest C:\work\TSP-2026-001.properties -Key E:\triton-patch-primary.key

What it does:
  1. Pulls this repo so the feed sequence continues from the published one.
  2. PatchTool pack : signs <id>.tpatch from the compiled classes the manifest names.
  3. PatchTool feed : re-issues feed.properties (sequence + 1) and signs it.
  4. Commits and pushes (skip the push with -NoPush to look first).

The manifest (patch.properties) looks like:
  id=TSP-2026-001
  sequence=1              (higher than every earlier patch)
  title=Short title
  summary=One or two sentences.
  severity=HIGH           (CRITICAL, HIGH, MODERATE, LOW)
  released=2026-11-23
  build.min=155
  build.max=155           (later builds ship the fix themselves)
  classes=echelon.some.Class,triton.other.Class

Compile the fix first (IntelliJ build or mvn compile) so -Classes holds the new bytes.
The key never enters this folder; keep it on its offline drive.
#>
param(
    [Parameter(Mandatory = $true)][string]$Manifest,
    [Parameter(Mandatory = $true)][string]$Key,
    [string]$Classes = "$env:USERPROFILE\Desktop\Project-E1102\echelon\target\classes",
    [string]$Java = "$env:USERPROFILE\.jdks\jbr-25.0.4.1\bin\java.exe",
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot

function Fail([string]$msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $Manifest -PathType Leaf)) { Fail "Manifest not found: $Manifest" }
if (-not (Test-Path $Key -PathType Leaf)) { Fail "Key not found: $Key" }
if (-not (Test-Path "$Classes\echelon\module\vortex\patch\PatchTool.class")) { Fail "PatchTool is not compiled under $Classes" }
if (-not (Test-Path $Java -PathType Leaf)) {
    $onPath = Get-Command java -ErrorAction SilentlyContinue
    if ($null -eq $onPath) { Fail "No java found. Pass -Java <path to java.exe> (Java 17+)." }
    $Java = $onPath.Source
}

$keyFull = (Resolve-Path $Key).Path
if ($keyFull.StartsWith($repo, [StringComparison]::OrdinalIgnoreCase)) { Fail "The key is inside the repo folder. Keep it outside." }

$idLine = Get-Content $Manifest -Encoding UTF8 | Where-Object { $_ -match '^\s*id\s*=' } | Select-Object -First 1
if ($null -eq $idLine) { Fail "The manifest has no id= line." }
$id = ($idLine -split '=', 2)[1].Trim()
if (Test-Path "$repo\$id.tpatch") { Fail "$id.tpatch is already published. Give the new patch a new id." }

Push-Location $repo
try {
    $dirty = git status --porcelain
    if ($dirty) { Fail "The repo has uncommitted changes. Commit or discard them first:`n$dirty" }
    git pull --ff-only
    if ($LASTEXITCODE -ne 0) { Fail "git pull failed." }

    & $Java -cp $Classes echelon.module.vortex.patch.PatchTool pack $keyFull $Manifest $Classes $repo
    if ($LASTEXITCODE -ne 0) { Fail "Packing failed; nothing was published." }
    & $Java -cp $Classes echelon.module.vortex.patch.PatchTool feed $keyFull $repo
    if ($LASTEXITCODE -ne 0) {
        Remove-Item "$repo\$id.tpatch", "$repo\$id.tpatch.sig" -ErrorAction SilentlyContinue
        Fail "Signing the feed failed; the new package was removed."
    }

    $leak = Get-ChildItem $repo -Recurse -File -Include *.key, *.pem | Select-Object -First 1
    if ($null -ne $leak) { Fail "A key file is inside the repo ($($leak.FullName)). Not committing." }

    git add -- "$id.tpatch" "$id.tpatch.sig" feed.properties feed.properties.sig
    git commit -m "Release $id"
    if ($LASTEXITCODE -ne 0) { Fail "git commit failed." }

    if ($NoPush) {
        Write-Host "Committed locally. Run 'git push' in $repo to publish." -ForegroundColor Yellow
    } else {
        git push
        if ($LASTEXITCODE -ne 0) { Fail "git push failed; the release is committed locally only." }
        Write-Host "Published $id. Installs see it on their next check (GitHub raw can lag a few minutes)." -ForegroundColor Green
    }
} finally {
    Pop-Location
}
