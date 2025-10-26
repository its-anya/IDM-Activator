# Check the instructions here on how to use it https://github.com/its-anya/IDM-Activator

# Define multiple URLs (in order)
$urls = @(
    "https://raw.githubusercontent.com/its-anya/IDM-Activator/main/IDM_Activator.cmd",
    "https://github.com/its-anya/IDM-Activator/releases/download/latest/IDM-Activator-main.zip",
    "https://codeload.github.com/its-anya/IDM-Activator/zip/refs/heads/main"
)

# Define variables
$tempDir = "$env:TEMP\IDM_ACTIVATOR_$(Get-Random)"
$output = "$tempDir\IDM_Activator.cmd"
$extractDir = "$tempDir"
$versionFile = "$env:TEMP\idm_latest_version.txt"

# Ensure the temp directory exists
if (!(Test-Path -Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# Try downloading from available URLs
$success = $false
foreach ($url in $urls) {
    Write-Host ""
    Write-Host "Downloading IDM Activator Script from:" -ForegroundColor Cyan
    Write-Host "$url" -ForegroundColor Yellow

    try {
        $webclient = New-Object System.Net.WebClient

        # Show simple progress (no async issues)
        $webclient.DownloadFile($url, $output)

        Write-Host "Download successful!" -ForegroundColor Green
        $success = $true
        break
    } catch {
        Write-Host "Failed to download from this URL. Trying next..." -ForegroundColor Red
    }
}

if (-not $success) {
    Write-Host ""
    Write-Host "ERROR: Download failed from all available sources." -ForegroundColor Red
    exit 1
}

# Fetch Latest IDM Version
$versionURL = "https://www.internetdownloadmanager.com/news.html"
try {
    $response = Invoke-WebRequest -Uri $versionURL -UseBasicParsing -ErrorAction Stop
    if ($response.Content -match "What's new in version ([\d\.]+ Build \d+)") {
        $latestVersion = $matches[1]
        "Latest IDM Version: $latestVersion" | Set-Content -Path $versionFile -Encoding UTF8
    } else {
        Write-Host "Could not extract version from response."
        "Latest IDM Version: Unknown" | Set-Content -Path $versionFile -Encoding UTF8
    }
} catch {
    Write-Host "Version check failed: $_"
    "ERROR: PowerShell request failed: $($_.Exception.Message)" | Set-Content -Path $versionFile -Encoding UTF8
}

# Run the batch script
$batchFile = "$output"

if (Test-Path -Path $batchFile) {
    Write-Host "Running the activation script..."
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batchFile`"" -Wait
} else {
    Write-Host "Batch script not found in expected folder."
    exit 1
}

# Cleanup
Write-Host "Cleaning up downloaded files..."
Remove-Item -Path "$tempDir" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "All set." -ForegroundColor Green
Write-Host "IDM Activator Script closed successfully." -ForegroundColor Green