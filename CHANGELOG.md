# Changelog

## Version 4.0 (2025-10-26)

### New Features
- Added "Check Activation Status" feature to verify IDM activation without performing activation
- Added multiple installation methods including PowerShell one-liner
- Added launcher script (IASL.cmd) for easier execution
- Added PowerShell installation script (install.ps1) with automatic download and execution
- Added version tracking mechanism

### Improvements
- Updated menu to include new "Check Activation Status" option
- Enhanced documentation with comprehensive installation instructions
- Added support for multiple download sources in installation scripts
- Improved error handling in PowerShell scripts

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