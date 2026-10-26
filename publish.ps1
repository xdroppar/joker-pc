# Owner side: publish a Windows build so every installed copy picks it up on its next start.
#   powershell -File publish.ps1 C:\tmp\joker-playsheet-build8
# Zips the build (without the debug-symbols folder) and makes it the latest release, beside install.ps1.

param([Parameter(Mandatory)] [string] $Build)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path (Join-Path $Build 'Joker.exe'))) { throw "no Joker.exe in $Build" }

$tag = 'pc-' + (Get-Item (Join-Path $Build 'Joker_Data\Managed\Assembly-CSharp.dll')).LastWriteTime.ToString('yyyy-MM-dd-HHmm')
$stage = Join-Path $env:TEMP "joker-publish-$tag"
Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force (Join-Path $stage 'Joker') | Out-Null
robocopy $Build (Join-Path $stage 'Joker') /MIR /XD '*_BackUpThisFolder_ButDontShipItWithYourGame' /NFL /NDL /NJH /NJS /NP | Out-Null
$zip = Join-Path $stage 'Joker-PC.zip'
Push-Location $stage; & tar.exe -a -c -f $zip Joker; Pop-Location
if ((Get-Item $zip).Length -ge 2GB) { throw 'zip is 2 GB or more; GitHub release files must be smaller' }

& gh release create $tag $zip (Join-Path $PSScriptRoot 'install.ps1') -R xdroppar/joker-pc --title $tag --notes "Windows build $tag" --latest
Remove-Item -Recurse -Force $stage
"published $tag"
