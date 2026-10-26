# Owner side: publish a Windows build. Every installed copy offers it the next time Joker is opened.
#   powershell -File publish.ps1 C:\tmp\joker-playsheet-build8 [-NoUpload]
# Builds JokerLauncher.exe and JokerSetup.exe (into out\), then makes the setup the latest GitHub release.
# -NoUpload stops after building, for trying the setup locally first.

param([Parameter(Mandatory)] [string] $Build, [switch] $NoUpload)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path (Join-Path $Build 'Joker.exe'))) { throw "no Joker.exe in $Build" }

$built = (Get-Item (Join-Path $Build 'Joker_Data\Managed\Assembly-CSharp.dll')).LastWriteTime
$tag = 'pc-' + $built.ToString('yyyy-MM-dd-HHmm')
$version = '{0}.{1}.{2}.{3}' -f $built.Year, $built.Month, $built.Day, [int]$built.ToString('HHmm')
$out = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force $out | Out-Null

# The launcher, with the C# compiler that ships in Windows.
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:winexe /optimize+ "/win32icon:$PSScriptRoot\art\joker.ico" "/out:$out\JokerLauncher.exe" `
    /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll "$PSScriptRoot\launcher\JokerLauncher.cs"
if ($LASTEXITCODE -ne 0) { throw 'launcher did not compile' }

$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 is not installed (winget install JRSoftware.InnoSetup)' }
& $iscc /Q "/DBuild=$Build" "/DTag=$tag" "/DVersion=$version" "$PSScriptRoot\installer\joker.iss"
if ($LASTEXITCODE -ne 0) { throw 'setup did not build' }
$setup = Join-Path $out 'JokerSetup.exe'
if ((Get-Item $setup).Length -ge 2GB) { throw 'setup is 2 GB or more; GitHub release files must be smaller' }
"built $tag ($version): $([math]::Round((Get-Item $setup).Length / 1MB)) MB"
if ($NoUpload) { return }

& gh release create $tag $setup -R xdroppar/joker-pc --title "Joker $($built.ToString('MMMM d, yyyy'))" --notes "Download **JokerSetup.exe** below, or get it from https://xdroppar.github.io/joker-pc/" --latest
if ($LASTEXITCODE -ne 0) { throw 'release failed' }
"published $tag"
