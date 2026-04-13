# Changelog

## Version 5.0 (2026-04-12)

### New Features
- **[NEW] Freeze IDM Trial (Lifetime)** - Freeze IDM 30-day trial for Lifetime (Option [2]) - no nag screen, no serial needed
- **[NEW] Disable IDM Updates** - Stops IDM from checking for updates (Option [8])
- **[NEW] Random Serial Generator** - Generates unique random registration info on each activation
- **[NEW] WMI Health Check** - Verifies WMI is working before proceeding
- **[NEW] Null Service Check** - Warns if Null service is not running (can cause issues)
- **[NEW] LF Line Ending Check** - Detects corrupted/improperly extracted script files
- **[NEW] PowerShell Language Mode Check** - Detects restricted/constrained PS mode
- **[NEW] User SID Detection** - Proper HKU-based registry access using current user's SID
- **[NEW] HKCU <-> HKU Sync Check** - Validates HKCU and HKU keys are properly synced
- **[NEW] CLSID Registry Backup** - Auto-backup of CLSID keys before any modification
- **[NEW] /frz parameter** - Freeze trial in unattended mode via command line
- **[NEW] /upd parameter** - Check for updates via command line
- Added "Check Activation Status" feature to verify IDM activation without performing activation
- Added multiple installation methods including PowerShell one-liner
- Added launcher script (IASL.cmd) for easier execution
- Added PowerShell installation script (install.ps1) with automatic download and execution

### Improvements
- Rebuilt menu with 12 options (A, B keys for Readme/Homepage)
- Improved elevation detection using fltmc (more reliable than HKU\S-1-5-19)
- Better archive/temp folder detection to prevent running from ZIP
- Activation now shows system info (OS, Build, IDM version) before proceeding
- Activation warns user to try Freeze Trial if fake serial screen appears
- TCP fallback check if ping fails to internetdownloadmanager.com
- Enhanced documentation with comprehensive installation instructions

### Bug Fixes
- **[CRITICAL]** Fixed a fatal script crash when selecting **[8] Disable IDM Updates** caused by unescaped parentheses in text strings prematurely breaking command blocks.
- **[CRITICAL]** Fixed syntax errors (`REG QUERY /?` invalid syntax and "Failed to create required registry keys") globally by correcting malformed error-suppression commands (`2^nul` to `2^>nul`).
- Updated `README.md` to offer a transparent comparison between activation methods, clearly recommending **Freeze IDM Trial (Lifetime)** as optimal.
- Added a fallback instruction block in `README.md` guiding users to utilize the pre-tested offline installers provided in the `IDM/` directory if new IDM versions block activation.

### Installation Methods
1. **PowerShell One-liner** - Direct execution from GitHub
2. **Manual Download** - Download from releases or direct link
3. **Launcher Script** - Simple CMD wrapper for execution
4. **PowerShell Installation Script** - Automated download and execution

## Version 3.0 (Original)

### Features
- Registry-based activation method
- File replacement activation method
- IDM version checking
- Direct download of latest IDM version
- Trial reset functionality
- Windows Firewall toggle
- Built-in documentation

### Technical Implementation
- Registry modification for activation
- File download simulation to create legitimate registry entries
- Registry key locking to prevent detection
- Support for both x86 and x64 systems
- Automatic architecture detection
