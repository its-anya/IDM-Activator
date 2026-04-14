@setlocal DisableDelayedExpansion
@echo off

:: Add custom name in IDM license info, prefer to write it in English and/or numeric in below line after = sign,
set name=@Open Source Community

:: Script Version
set ver=5.0

::========================================================================================================================================

:: Re-launch the script with x64 process if it was initiated by x86 process on x64 bit Windows
:: or with ARM64 process if it was initiated by x86/ARM32 process on ARM64 Windows

if exist %SystemRoot%\Sysnative\cmd.exe (
set "_cmdf=%~f0"
setlocal EnableDelayedExpansion
start %SystemRoot%\Sysnative\cmd.exe /c ""!_cmdf!" %*"
exit /b
)

:: Re-launch the script with ARM32 process if it was initiated by x64 process on ARM64 Windows

if exist %SystemRoot%\Windows\SyChpe32\kernel32.dll if exist %SystemRoot%\SysArm32\cmd.exe if %PROCESSOR_ARCHITECTURE%==AMD64 (
set "_cmdf=%~f0"
setlocal EnableDelayedExpansion
start %SystemRoot%\SysArm32\cmd.exe /c ""!_cmdf!" %*"
exit /b
)

::  Set Path variable, it helps if it is misconfigured in the system

set "SysPath=%SystemRoot%\System32"
set "Path=%SysPath%;%SystemRoot%;%SysPath%\Wbem;%SysPath%\WindowsPowerShell\v1.0\"

::========================================================================================================================================

cls
color 07

set _args=
set _elev=
set reset=
set Silent=
set activate=
set freeze=

set _args=%*
if defined _args set _args=%_args:"=%
if defined _args (
for %%A in (%_args%) do (
if /i "%%A"=="-el"  set _elev=1
if /i "%%A"=="/res" set Unattended=1&set activate=&set reset=1
if /i "%%A"=="/act" set Unattended=1&set activate=1&set reset=
if /i "%%A"=="/frz" set Unattended=1&set freeze=1&set activate=1
if /i "%%A"=="/s"   set Unattended=1&set Silent=1
if /i "%%A"=="/upd" goto :_check_updates
)
)

::========================================================================================================================================

set "nul=>nul 2>&1"
set "nul1=1>nul"
set "nul2=2>nul"
set "nul6=2^>nul"
set "_psc=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set psc=%_psc%
set winbuild=1
for /f "tokens=6 delims=[]. " %%G in ('ver') do set winbuild=%%G
call :_colorprep
set "nceline=echo: &echo ==== ERROR ==== &echo:"
set "eline=echo: &call :_color %Red% "==== ERROR ====" &echo:"
set "line=________________________________________________________________________________________"
set "_buf={$W=$Host.UI.RawUI.WindowSize;$B=$Host.UI.RawUI.BufferSize;$W.Height=31;$B.Height=300;$Host.UI.RawUI.WindowSize=$W;$Host.UI.RawUI.BufferSize=$B;}"

:: Temp files for version checking
set "tempfile_html=%temp%\idm_news.html"

if defined Silent if not defined activate if not defined reset exit /b
if defined Silent call :begin %nul% & exit /b

:begin

::========================================================================================================================================

if %winbuild% LSS 7600 (
%nceline%
echo Unsupported OS version Detected [%winbuild%].
echo Project is supported only for Windows 7/8/8.1/10/11 and their Server equivalent.
goto done2
)

for %%# in (powershell.exe) do @if "%%~$PATH:#"=="" (
%nceline%
echo Unable to find powershell.exe in system PATH.
goto done2
)

::  Check if Null service is working (important for batch script)
sc query Null | find /i "RUNNING" %nul1%
if %errorlevel% NEQ 0 (
echo:
echo Warning: Null service is not running, script may have issues...
echo:
ping 127.0.0.1 -n 5 %nul%
)

::  (LF line ending check removed - not needed for local scripts)

::  Simple PowerShell availability check
for %%# in (powershell.exe) do @if "%%~$PATH:#"=="" (
%nceline%
echo powershell.exe not found in PATH. Aborting...
goto done2
)

::========================================================================================================================================

::  Fix for the special characters limitation in path name
::  Thanks to @OpenSource

set "_work=%~dp0"
if "%_work:~-1%"=="\" set "_work=%_work:~0,-1%"

set "_batf=%~f0"
set "_batp=%_batf:'=''%"

set _PSarg="""%~f0""" -el %_args%
set _PSarg=%_PSarg:'=''%

set "_appdata=%appdata%"
set "_ttemp=%userprofile%\AppData\Local\Temp"
for /f "tokens=2*" %%a in ('reg query "HKCU\Software\DownloadManager" /v ExePath 2^>nul') do call set "IDMan=%%b"

setlocal EnableDelayedExpansion

::  Removed check for temp/archive folder to allow install.ps1 execution

::========================================================================================================================================

::  Check WMI
%_psc% "Get-WmiObject -Class Win32_ComputerSystem | Select-Object -Property CreationClassName" %nul2% | find /i "computersystem" %nul1% || (
%nceline%
echo WMI is not working. Aborting...
goto done2
)

::  Get user account SID
set _sid=
for /f "delims=" %%a in ('%_psc% "([System.Security.Principal.NTAccount](Get-WmiObject -Class Win32_ComputerSystem).UserName).Translate([System.Security.Principal.SecurityIdentifier]).Value" %nul6%') do (set _sid=%%a)

reg query HKU\%_sid%\Software %nul% || (
for /f "delims=" %%a in ('%_psc% "$explorerProc = Get-Process -Name explorer | Where-Object {$_.SessionId -eq (Get-Process -Id $pid).SessionId} | Select-Object -First 1; $sid = (gwmi -Query ('Select * From Win32_Process Where ProcessID=' + $explorerProc.Id)).GetOwnerSid().Sid; $sid" %nul6%') do (set _sid=%%a)
)

reg query HKU\%_sid%\Software %nul% || (
%nceline%
echo User Account SID not found. Aborting...
goto done2
)

::  Check HKCU <-> HKU sync
%nul% reg delete HKCU\IAS_TEST /f
%nul% reg delete HKU\%_sid%\IAS_TEST /f
set HKCUsync=
%nul% reg add HKCU\IAS_TEST
%nul% reg query HKU\%_sid%\IAS_TEST && (set HKCUsync=1)
%nul% reg delete HKCU\IAS_TEST /f
%nul% reg delete HKU\%_sid%\IAS_TEST /f

::========================================================================================================================================

::  Elevate script as admin and pass arguments and preventing loop
::  Thanks to @OpenSource for the powershell method and solving special characters issue in file path name.

%nul1% fltmc || (
if not defined _elev %nul% %_psc% "start cmd.exe -arg '/c \"!_PSarg!\"' -verb runas" && exit /b
%nceline%
echo This script require administrator privileges.
echo To do so, right click on this script and select 'Run as administrator'.
goto done2
)

::========================================================================================================================================

:: Below code also works for ARM64 Windows 10 (including x64 bit emulation)

reg query "HKLM\Hardware\Description\System\CentralProcessor\0" /v "Identifier" | find /i "x86" 1>nul && set arch=x86|| set arch=x64

if not exist "!IDMan!" (
if %arch%==x64 set "IDMan=%ProgramFiles(x86)%\Internet Download Manager\IDMan.exe"
if %arch%==x86 set "IDMan=%ProgramFiles%\Internet Download Manager\IDMan.exe"
)

if "%arch%"=="x86" (
set "CLSID=HKCU\Software\Classes\CLSID"
set "HKLM=HKLM\Software\Internet Download Manager"
set "_tok=5"
) else (
set "CLSID=HKCU\Software\Classes\Wow6432Node\CLSID"
set "HKLM=HKLM\SOFTWARE\Wow6432Node\Internet Download Manager"
set "_tok=6"
)

set _temp=%SystemRoot%\Temp
set regdata=%SystemRoot%\Temp\regdata.txt
set "idmcheck=tasklist /fi "imagename eq idman.exe" | findstr /i "idman.exe" >nul"

::========================================================================================================================================

if defined Unattended (
if defined reset goto _reset
if defined activate goto _activate
)

:MainMenu

cls
title  IDM Activation V5  ^(Open Source Community)
mode 75, 30

:: Check firewall status

set /a _ena=0
set /a _dis=0
for %%# in (DomainProfile PublicProfile StandardProfile) do (
for /f "skip=2 tokens=2*" %%a in ('reg query HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\%%# /v EnableFirewall 2^>nul') do (
if /i %%b equ 0x1 (set /a _ena+=1) else (set /a _dis+=1)
)
)

if %_ena%==3 (
set _status=Enabled
set _col=%_Green%
)

if %_dis%==3 (
set _status=Disabled
set _col=%_Red%
)

if not %_ena%==3 if not %_dis%==3 (
set _status=Status_Unclear
set _col=%_Yellow%
)

echo:
echo:
echo:		Visit: Open Source Community   [v%ver%]
echo:		 
echo:       _______________________________________________________ 
echo:                                                               
echo:          [1] Activate IDM (Registry Method)                   
echo:          [2] Freeze IDM Trial (Lifetime)                       
echo:          [3] Activate IDM (File Replacement Method)            
echo:          [4] Reset IDM Activation / Trial                      
echo:          [5] Check IDM Version                                 
echo:          [6] Download Latest IDM Version                       
echo:          [7] Check Activation Status                           
echo:          [8] Disable IDM Updates                               
echo:          _________________________________________________   
echo:                                                               
call :_color2 %_White% "          [9] Toggle Windows Firewall  " %_col% "[%_status%]"
echo:          _________________________________________________   
echo:                                                               
echo:          [A] ReadMe                                           
echo:          [B] Homepage                                         
echo:          [0] Exit                                             
echo:       _______________________________________________________
echo:   
call :_color2 %_White% "        " %_Green% "Enter option [1,2,3,4,5,6,7,8,9,A,B,0]"
choice /C:1234567890AB /N
set _erl=%errorlevel%

if %_erl%==12 goto homepage
if %_erl%==11 call :readme&goto MainMenu
if %_erl%==10 exit /b
if %_erl%==9 call :_tog_Firewall&goto MainMenu
if %_erl%==8 call :disable_idm_updates&goto MainMenu
if %_erl%==7 call :check_activation_status&goto MainMenu
if %_erl%==6 call :download_latest_idm&goto MainMenu
if %_erl%==5 call :check_idm_version&goto MainMenu
if %_erl%==4 goto _reset
if %_erl%==3 goto _activate_file_method
if %_erl%==2 set freeze=1&goto _activate
if %_erl%==1 set freeze=&goto _activate
goto :MainMenu

::========================================================================================================================================

:_tog_Firewall

if %_status%==Enabled (
netsh AdvFirewall Set AllProfiles State Off >nul
) else (
netsh AdvFirewall Set AllProfiles State On >nul
)
exit /b

::========================================================================================================================================

:readme

set "_ReadMe=%SystemRoot%\Temp\ReadMe.txt"
if exist "%_ReadMe%" del /f /q "%_ReadMe%" %nul%
call :export txt "%_ReadMe%"
start notepad "%_ReadMe%"
timeout /t 2 %nul%
del /f /q "%_ReadMe%"
exit /b

::  Extract the text from batch script without character and file encoding issue
::  Thanks to @OpenSource

:export

%nul% %_psc% "$f=[io.file]::ReadAllText('!_batp!') -split \":%~1\:.*`r`n\"; [io.file]::WriteAllText('%~2',$f[1].Trim(),[System.Text.Encoding]::ASCII);"
exit/b

::========================================================================================================================================

:check_idm_version

cls
mode 90, 30
echo:
echo Checking IDM version...
echo:

:: Check installed version
set "installed="
for /f "tokens=3" %%a in ('reg query "HKCU\Software\DownloadManager" /v idmvers 2^>nul') do set "installed=%%a"
if not defined installed (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Internet Download Manager" /v Version 2^>nul') do set "installed=%%a"
)

if defined installed (
    set "installed=!installed:v=!
    set "installed=!installed:Full=!
    set "installed=!installed: =!
    set "installed=!installed:b= Build !
    call :_color %Green% "Internet Download Manager found. Installed version: !installed!"
) else (
    call :_color %Red% "Error: Unable to find Internet Download Manager installation."
    echo Please ensure IDM is installed correctly.
    goto version_done
)

:: Get latest version information
echo:
echo Getting latest version information...
%nul% curl -s "https://www.internetdownloadmanager.com/news.html" -o "%tempfile_html%"

set "online_version="
for /f "tokens=1* delims=<>" %%a in ('findstr /i "<H3>What's new in version" "%tempfile_html%" ^| findstr /r /c:"Build [0-9]*"') do (
    set "line=%%b"
    set "line=!line:What's new in version =!
    set "line=!line:</H3>=!
    set "online_version=!line!
    goto :got_version
)

:got_version
if not defined online_version (
    call :_color %Red% "Failed to retrieve online version information."
    goto version_done
)

call :_color %Green% "Latest version available: !online_version!"

:: Parse versions for comparison
for /f "tokens=1,2,4 delims=. " %%a in ("!online_version!") do (
    set "o_major=%%a"
    set "o_minor=%%b"
    set "o_build=%%c"
)

for /f "tokens=1,2,4 delims=. " %%a in ("!installed!") do (
    set "i_major=%%a"
    set "i_minor=%%b"
    set "i_build=%%c"
)

:: Compare versions
set /a i_total = 10000 * !i_major! + 100 * !i_minor! + !i_build!
set /a o_total = 10000 * !o_major! + 100 * !o_minor! + !o_build!

echo:
if !i_total! GEQ !o_total! (
    call :_color %Green% "You already have the latest version of Internet Download Manager."
) else (
    call :_color %Yellow% "A newer version of IDM is available!"
    echo Please consider updating to the latest version: !online_version!
)

:version_done
echo:
echo %line%
echo:
call :_color %_Yellow% "Press any key to return..."
pause >nul
del "%tempfile_html%" >nul 2>&1
goto MainMenu

::========================================================================================================================================

:download_latest_idm

cls
echo:
echo Getting latest version information...
%nul% curl -s "https://www.internetdownloadmanager.com/news.html" -o "%tempfile_html%"

set "online_version="
for /f "tokens=1* delims=<>" %%a in ('findstr /i "<H3>What's new in version" "%tempfile_html%" ^| findstr /r /c:"Build [0-9]*"') do (
    set "line=%%b"
    set "line=!line:What's new in version =!
    set "line=!line:</H3>=!
    set "online_version=!line!
    goto :got_version_dl
)

:got_version_dl
if not defined online_version (
    call :_color %Red% "Failed to retrieve online version information."
    del "%tempfile_html%" >nul 2>&1
    echo:
    echo %line%
    echo:
    call :_color %_Yellow% "Press any key to return..."
    pause >nul
    goto MainMenu
)

:: Generate download URL
for /f "tokens=1,2,4 delims=. " %%a in ("!online_version!") do (
    set "o_major=%%a"
    set "o_minor=%%b"
    set "o_build=%%c"
)

set "downloadcode=!o_major!!o_minor!build!o_build!"
set "downloadurl=https://mirror2.internetdownloadmanager.com/idman%downloadcode%.exe"

call :_color %Green% "Opening your browser to download the latest IDM..."
echo:
start "" "%downloadurl%"
echo If your download does not start automatically, copy and paste this URL into your browser:
call :_color %Yellow% "%downloadurl%"
echo:
del "%tempfile_html%" >nul 2>&1
echo %line%
echo:
call :_color %_Yellow% "Press any key to return..."
pause >nul
goto MainMenu

::========================================================================================================================================

:check_activation_status

cls
mode 90, 30
echo:
echo Checking IDM Activation Status...
echo:
echo:

:: Check if IDM is installed
set "idm_installed="
for /f "tokens=3" %%a in ('reg query "HKCU\Software\DownloadManager" /v ExePath 2^>nul') do set "idm_installed=%%a"

if not defined idm_installed (
    call :_color %Red% "Error: Internet Download Manager is not installed."
    echo Please install IDM before checking activation status.
    goto activation_status_done
)

:: Check for registration information
set "is_activated=0"
set "reg_name="
set "reg_email="
set "reg_serial="

:: Check for FName (First Name)
for /f "tokens=3" %%a in ('reg query "HKCU\Software\DownloadManager" /v FName 2^>nul') do set "reg_name=%%a"

:: Check for Email
for /f "tokens=3" %%a in ('reg query "HKCU\Software\DownloadManager" /v Email 2^>nul') do set "reg_email=%%a"

:: Check for Serial
for /f "tokens=3" %%a in ('reg query "HKCU\Software\DownloadManager" /v Serial 2^>nul') do set "reg_serial=%%a"

:: Determine activation status
if defined reg_name if defined reg_email if defined reg_serial (
    if not "%reg_name%"=="" if not "%reg_email%"=="" if not "%reg_serial%"=="" (
        set "is_activated=1"
    )
)

if "%is_activated%"=="1" (
    call :_color %Green% "IDM is currently activated."
    echo:
    echo Registration Details:
    echo   Name: %reg_name%
    echo   Email: %reg_email%
    echo   Serial: %reg_serial%
) else (
    call :_color %Yellow% "IDM is not activated or is using trial version."
    echo:
    echo No valid registration information found in the registry.
    echo IDM may be in trial mode or not activated.
)

:: Check trial status
echo:
echo Checking trial information...
set "trial_days="
set "last_check="

for /f "tokens=3" %%a in ('reg query "HKCU\Software\DownloadManager" /v tvfrdt 2^>nul') do set "trial_days=%%a"
for /f "tokens=3" %%a in ('reg query "HKCU\Software\DownloadManager" /v LastCheckQU 2^>nul') do set "last_check=%%a"

if defined trial_days (
    call :_color %Gray% "Trial period information found in registry."
    echo   Trial days: %trial_days%
    if defined last_check echo   Last check: %last_check%
) else (
    call :_color %Gray% "No trial information found in registry."
)

:activation_status_done
echo:
echo %line%
echo:
call :_color %_Yellow% "Press any key to return..."
pause >nul
goto MainMenu

::========================================================================================================================================

:_reset

if not defined Unattended (
mode 93, 32
%nul% %_psc% "&%_buf%"
)

echo:
set _error=

reg query "HKCU\Software\DownloadManager" "/v" "Serial" %nul% && (
%idmcheck% && taskkill /f /im idman.exe
)

if exist "!_appdata!\DMCache\settings.bak" del /s /f /q "!_appdata!\DMCache\settings.bak"

:: Backup CLSID registry keys before reset
set _time=
for /f %%a in ('%_psc% "(Get-Date).ToString('yyyyMMdd-HHmmssfff')"') do set _time=%%a
echo:
echo Creating backup of CLSID registry keys in %SystemRoot%\Temp...
if defined _time (
    reg export %CLSID% "%SystemRoot%\Temp\_Backup_HKCU_CLSID_%_time%.reg" %nul%
)

set "_action=call :delete_key"
call :reset

echo:
echo %line%
echo:
if not defined _error (
call :_color %Green% "IDM Activation - Trial is successfully reset in the registry."
) else (
call :_color %Red% "Failed to completely reset IDM Activation - Trial."
)

goto done

::========================================================================================================================================

:_activate

if not defined Unattended (
mode 93, 32
%nul% %_psc% "&%_buf%"
)

echo:
set _error=

if not exist "!IDMan!" (
call :_color %Red% "IDM [Internet Download Manager] is not Installed."
echo You can download it from  https://www.internetdownloadmanager.com/download.html
goto done
)

:: Ensure IDM is not blocked by firewall (required for Registry Method)
netsh advfirewall firewall delete rule name="Block IDM Update" %nul%
netsh advfirewall firewall delete rule name="Block IDM Update Out" %nul%
netsh advfirewall firewall delete rule name="IDM Block" %nul%

:: Show Freeze Trial warning if not freeze mode
if not defined freeze if not defined Unattended (
echo:
echo %line%
echo:
echo      Note: If activation shows fake serial nag screen,
call :_color2 %_White% "      " %_Green% "use option [2] Freeze Trial instead - it is more reliable."
echo %line%
echo:
)

:: Internet check with internetdownloadmanager.com ping and port 80 test

set _int=
for /f "delims=[] tokens=2" %%# in ('ping -n 1 internetdownloadmanager.com') do (if not [%%#]==[] set _int=1)

if not defined _int (
%_psc% "$t = New-Object Net.Sockets.TcpClient;try{$t.Connect('internetdownloadmanager.com', 80)}catch{};$t.Connected" | findstr /i true %nul1% || (
call :_color %Red% "Unable to connect internetdownloadmanager.com, aborting..."
goto done
)
call :_color %Gray% "Ping failed but TCP connection succeeded."
echo:
)

echo Internet is connected.

:: Show system info
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul') do set "regwinos=%%b"
for /f "tokens=2*" %%a in ('reg query "HKU\%_sid%\Software\DownloadManager" /v idmvers %nul6%') do set "IDMver=%%b"
echo Checking Info - [%regwinos% ^| Build %winbuild% ^| IDM: %IDMver%]

%idmcheck% && (echo: & taskkill /f /im idman.exe)

if exist "!_appdata!\DMCache\settings.bak" del /s /f /q "!_appdata!\DMCache\settings.bak"

:: Backup CLSID registry keys before activation
set _time=
for /f %%a in ('%_psc% "(Get-Date).ToString('yyyyMMdd-HHmmssfff')"') do set _time=%%a
echo:
echo Creating backup of CLSID registry keys in %SystemRoot%\Temp...
if defined _time (
    reg export %CLSID% "%SystemRoot%\Temp\_Backup_HKCU_CLSID_%_time%.reg" %nul%
)

set "_action=call :delete_key"
call :reset

set "_action=call :count_key"
call :register_IDM

echo:
if defined _derror call :f_reset & goto done

set lockedkeys=
set "_action=call :lock_key"
echo Locking registry keys...
echo:
call :action

if not defined _error if [%lockedkeys%] GEQ [7] (
echo:
echo %line%
echo:
if defined freeze (
call :_color %Green% "IDM 30-day trial is successfully FROZEN for Lifetime."
echo:
call :_color %Gray% "If IDM shows a popup to register, try reinstalling IDM."
) else (
call :_color %Green% "IDM is successfully activated."
echo:
call :_color %Gray% "If fake serial screen appears, run activation option again."
)
goto done
)

call :f_reset

::========================================================================================================================================

:_activate_file_method

cls
mode 93, 32
%nul% %_psc% "&%_buf%"
echo:
echo File Replacement Activation Method
echo ==================================
echo:

:: Check if required files exist
set "script_dir=%~dp0"
set "data_file=%script_dir%src\data.bin"
set "datahlp_file=%script_dir%src\dataHlp.bin"
set "registry_file=%script_dir%src\registry.bin"

if not exist "%data_file%" (
    call :_color %Red% "Error: data.bin file not found in script directory."
    echo This activation method requires the data.bin file.
    goto file_method_done
)

if not exist "%datahlp_file%" (
    call :_color %Red% "Error: dataHlp.bin file not found in script directory."
    echo This activation method requires the dataHlp.bin file.
    goto file_method_done
)

if not exist "!IDMan!" (
    call :_color %Red% "IDM [Internet Download Manager] is not Installed."
    echo You can download it from  https://www.internetdownloadmanager.com/download.html
    goto file_method_done
)

:: Get IDM installation directory
for /f "tokens=2*" %%A in ('reg query "HKCU\SOFTWARE\DownloadManager" /v ExePath 2^>nul') do (
    set "idm_dir=%%B"
)

if defined idm_dir (
    for %%A in ("%idm_dir%") do set "idm_dir=%%~dpA"
) else (
    call :_color %Red% "Error: Unable to find IDM installation directory."
    goto file_method_done
)

echo IDM installation directory: %idm_dir%
echo:

:: Kill IDM process
%idmcheck% && (
    echo Stopping IDM process...
    taskkill /f /im idman.exe >nul 2>&1
    timeout /t 2 >nul
)

:: Backup original files
echo Creating backup of original files...
if exist "%idm_dir%IDMan.exe" (
    if not exist "%idm_dir%IDMan.exe.bak" (
        copy "%idm_dir%IDMan.exe" "%idm_dir%IDMan.exe.bak" >nul
        if !errorlevel! equ 0 (
            echo Backed up IDMan.exe
        ) else (
            call :_color %Yellow% "Warning: Could not backup IDMan.exe"
        )
    ) else (
        echo Backup of IDMan.exe already exists
    )
)

if exist "%idm_dir%IDMGrHlp.exe" (
    if not exist "%idm_dir%IDMGrHlp.exe.bak" (
        copy "%idm_dir%IDMGrHlp.exe" "%idm_dir%IDMGrHlp.exe.bak" >nul
        if !errorlevel! equ 0 (
            echo Backed up IDMGrHlp.exe
        ) else (
            call :_color %Yellow% "Warning: Could not backup IDMGrHlp.exe"
        )
    ) else (
        echo Backup of IDMGrHlp.exe already exists
    )
)

:: Copy modified files
echo:
echo Copying modified files...
copy "%data_file%" "%idm_dir%IDMan.exe" >nul
if !errorlevel! equ 0 (
    echo Successfully replaced IDMan.exe
) else (
    call :_color %Red% "Error: Failed to replace IDMan.exe"
    goto file_method_done
)

copy "%datahlp_file%" "%idm_dir%IDMGrHlp.exe" >nul
if !errorlevel! equ 0 (
    echo Successfully replaced IDMGrHlp.exe
) else (
    call :_color %Red% "Error: Failed to replace IDMGrHlp.exe"
    goto file_method_done
)

:: Apply registry settings
if exist "%registry_file%" (
    echo:
    echo Applying registry settings...
    regedit /s "%registry_file%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo Registry settings applied
    ) else (
        call :_color %Yellow% "Warning: Could not apply registry settings"
    )
)

:: Prompt for user info
echo:
echo Enter your registration details (optional):
echo Press Enter to use default values
echo:
set "FName="
set "LName="
set /p FName="Enter First Name (default: Open Source): "
set /p LName="Enter Last Name (default: Community): "

:: Use defaults if empty
if "%FName%"=="" set "FName=Open Source"
if "%LName%"=="" set "LName=Community"

:: Update registry with user info
reg add "HKCU\SOFTWARE\DownloadManager" /v FName /t REG_SZ /d "%FName%" /f >nul 2>&1
reg add "HKCU\SOFTWARE\DownloadManager" /v LName /t REG_SZ /d "%LName%" /f >nul 2>&1

echo:
echo %line%
echo:
call :_color %Green% "IDM has been activated using the file replacement method."
echo:
call :_color %Yellow% "Note: This method replaces IDM executable files."
echo Make sure to restore the original files if you update IDM.

:file_method_done
echo:
echo %line%
echo:
call :_color %_Yellow% "Press any key to return..."
pause >nul
goto MainMenu

::========================================================================================================================================

:done

echo %line%
echo:
echo:
if defined Unattended (
timeout /t 3
exit /b
)

call :_color %_Yellow% "Press any key to return..."
pause >nul
goto MainMenu

:done2

if defined Unattended (
timeout /t 3
exit /b
)

echo Press any key to exit...
pause >nul
exit /b

::========================================================================================================================================

::========================================================================================================================================

:disable_idm_updates

cls
mode 90, 30
echo:
echo IDM Auto-Update Blocker
echo ========================
echo:

:: Check current status (Registry based)
set _upd_disabled=
for /f "tokens=3" %%a in ('reg query "HKCU\Software\DownloadManager" /v CheckUpdtVM 2^>nul') do if "%%a"=="0" set _upd_disabled=1

:: Also check if firewall rules exist (to offer cleanup)
set _idm_fw_blocked=
netsh advfirewall firewall show rule name="Block IDM Update" %nul% && set _idm_fw_blocked=1

if defined _idm_fw_blocked (
    echo Current Status: IDM is BLOCKED by Firewall ^(Total Block^).
    echo:
    call :_color %Yellow% "Do you want to RESTORE IDM internet access? [Y/N]"
    choice /C:YN /N
    if !errorlevel!==2 goto MainMenu
    echo:
    echo Restoring IDM internet access...
    netsh advfirewall firewall delete rule name="Block IDM Update" %nul%
    netsh advfirewall firewall delete rule name="Block IDM Update Out" %nul%
    netsh advfirewall firewall delete rule name="IDM Block" %nul%
    echo:
    call :_color %Green% "IDM internet access has been RESTORED."
    timeout /t 2 >nul
)

if defined _upd_disabled (
    echo Current Status: IDM Updates are DISABLED ^(Safe Method^).
    echo:
    call :_color %Yellow% "Do you want to RE-ENABLE IDM auto-update notifications? [Y/N]"
    choice /C:YN /N
    if !errorlevel!==2 goto MainMenu
    echo:
    echo Re-enabling IDM auto-update...
    reg add "HKCU\Software\DownloadManager" /v CheckUpdtVM /t REG_SZ /d "1" /f %nul%
    reg add "HKCU\Software\DownloadManager" /v LstCheck /t REG_SZ /d "" /f %nul%
    reg add "HKCU\Software\DownloadManager" /v CheckNewVersion /t REG_DWORD /d 1 /f %nul%
    echo:
    call :_color %Green% "IDM auto-update has been RE-ENABLED."
) else (
    echo Current Status: IDM Updates are ENABLED.
    echo:
    call :_color %Yellow% "Do you want to DISABLE IDM auto-update notifications? [Y/N]"
    choice /C:YN /N
    if !errorlevel!==2 goto MainMenu
    echo:
    echo Disabling IDM auto-update ^(Safe Registry Method^)...
    reg add "HKCU\Software\DownloadManager" /v CheckUpdtVM /t REG_SZ /d "0" /f %nul%
    reg add "HKCU\Software\DownloadManager" /v LstCheck /t REG_SZ /d "12/12/99" /f %nul%
    reg add "HKCU\Software\DownloadManager" /v CheckNewVersion /t REG_DWORD /d 0 /f %nul%
    echo:
    call :_color %Green% "IDM auto-update has been DISABLED successfully."
    echo Downloads remain functional.
)

echo:
echo %line%
echo:
call :_color %_Yellow% "Press any key to return..."
pause >nul
goto MainMenu

::========================================================================================================================================

:homepage

cls
echo:
echo:
echo Website: Open Source Community
echo:
echo:
timeout /t 3

start https://github.com/its-anya
goto MainMenu

::========================================================================================================================================

:f_reset

echo:
echo %line%
echo:
call :_color %Red% "Error found, resetting IDM activation..."
set "_action=call :delete_key"
call :reset
echo:
echo %line%
echo:
call :_color %Red% "Failed to activate IDM."
exit /b

::========================================================================================================================================

:reset

set take_permission=
call :delete_queue
set take_permission=1
call :action
call :add_key
exit /b

::========================================================================================================================================

:_rcont

reg add %reg% %nul%
call :_add_key
exit /b

:register_IDM

echo:
echo Applying registration details...
echo:

If not defined name set name=Tonec FZE

:: Generate random serial if not in freeze mode, else use fixed fake
if defined freeze (
    set "reg=HKCU\SOFTWARE\DownloadManager /v FName /t REG_SZ /d "%name%"" & call :_rcont
    set "reg=HKCU\SOFTWARE\DownloadManager /v LName /t REG_SZ /d """ & call :_rcont
    set "reg=HKCU\SOFTWARE\DownloadManager /v Email /t REG_SZ /d "info@tonec.com"" & call :_rcont
    set "reg=HKCU\SOFTWARE\DownloadManager /v Serial /t REG_SZ /d "FOX6H-3KWH4-7TSIN-Q4US7"" & call :_rcont
) else (
    :: Generate random registration details
    set /a _fname=%random% %% 9999 + 1000
    set /a _lname=%random% %% 9999 + 1000
    set _regemail=!_fname!.!_lname!@tonec.com
    for /f "delims=" %%a in ('%_psc% "$k=-join((Get-Random -Count 20 -InputObject([char[]]('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')));$k=$k.Substring(0,5)+'-'+$k.Substring(5,5)+'-'+$k.Substring(10,5)+'-'+$k.Substring(15,5);Write-Output $k" %nul6%') do (set _regkey=%%a)
    if not defined _regkey set "_regkey=FOX6H-3KWH4-7TSIN-Q4US7"
    set "reg=HKCU\SOFTWARE\DownloadManager /v FName /t REG_SZ /d "!_fname!"" & call :_rcont
    set "reg=HKCU\SOFTWARE\DownloadManager /v LName /t REG_SZ /d "!_lname!"" & call :_rcont
    set "reg=HKCU\SOFTWARE\DownloadManager /v Email /t REG_SZ /d "!_regemail!"" & call :_rcont
    set "reg=HKCU\SOFTWARE\DownloadManager /v Serial /t REG_SZ /d "!_regkey!"" & call :_rcont
)

echo:
echo Triggering a few downloads to create certain registry keys, please wait...

set "file=%_temp%\temp.png"
set _fileexist=
set _derror=

%idmcheck% && taskkill /f /im idman.exe

set link=https://www.internetdownloadmanager.com/images/idm_box_min.png
call :download
set link=https://www.internetdownloadmanager.com/register/IDMlib/images/idman_logos.png
call :download

:: it may take some time to reflect registry keys.
timeout /t 3 >nul

set foundkeys=
call :action
if [%foundkeys%] GEQ [7] goto _skip

set link=https://www.internetdownloadmanager.com/pictures/idm_about.png
call :download
set link=https://www.internetdownloadmanager.com/languages/indian.png
call :download

timeout /t 3 >nul

set foundkeys=
call :action
if not [%foundkeys%] GEQ [7] set _derror=1

:_skip

echo:
if not defined _derror (
echo Required registry keys were created successfully.
) else (
if not defined _fileexist call :_color %Red% "Unable to download files with IDM."
call :_color %Red% "Failed to create required registry keys."
call :_color %Magenta% "Try again - disable Windows firewall with script options - check Read Me."
)

echo:
%idmcheck% && taskkill /f /im idman.exe
if exist "%file%" del /f /q "%file%"
exit /b

:download

set /a attempt=0
if exist "%file%" del /f /q "%file%"
start "" /B "!IDMan!" /n /d "%link%" /p "%_temp%" /f temp.png

:check_file

timeout /t 1 >nul
set /a attempt+=1
if exist "%file%" set _fileexist=1&exit /b
if %attempt% GEQ 20 exit /b
goto :Check_file

::========================================================================================================================================

:delete_queue

echo:
echo Deleting registry keys...
echo:

for %%# in (
""HKCU\Software\DownloadManager" "/v" "FName""
""HKCU\Software\DownloadManager" "/v" "LName""
""HKCU\Software\DownloadManager" "/v" "Email""
""HKCU\Software\DownloadManager" "/v" "Serial""
""HKCU\Software\DownloadManager" "/v" "scansk""
""HKCU\Software\DownloadManager" "/v" "tvfrdt""
""HKCU\Software\DownloadManager" "/v" "radxcnt""
""HKCU\Software\DownloadManager" "/v" "LstCheck""
""HKCU\Software\DownloadManager" "/v" "ptrk_scdt""
""HKCU\Software\DownloadManager" "/v" "LastCheckQU""
"%HKLM%"
) do for /f "tokens=* delims=" %%A in ("%%~#") do (
set "reg="%%~A"" &reg query !reg! %nul% && call :delete_key
)

exit /b

::========================================================================================================================================

:add_key

echo:
echo Adding registry key...
echo:

set "reg="%HKLM%" /v "AdvIntDriverEnabled2""

reg add %reg% /t REG_DWORD /d "1" /f %nul%

:_add_key

if [%errorlevel%]==[0] (
set "reg=%reg:"=%"
echo Added - !reg!
) else (
set _error=1
set "reg=%reg:"=%"
%_psc% write-host 'Failed' -fore 'white' -back 'DarkRed'  -NoNewline&echo  - !reg!
)
exit /b

::========================================================================================================================================

:action

if exist %regdata% del /f /q %regdata% %nul%

reg query %CLSID% > %regdata%

%nul% %_psc% "(gc %regdata%) -replace 'HKEY_CURRENT_USER', 'HKCU' | Out-File -encoding ASCII %regdata%"

for /f %%a in (%regdata%) do (
for /f "tokens=%_tok% delims=\" %%# in ("%%a") do (
echo %%#|findstr /r "{.*-.*-.*-.*-.*}" >nul && (set "reg=%%a" & call :scan_key)
)
)

if exist %regdata% del /f /q %regdata% %nul%

exit /b

::========================================================================================================================================

:scan_key

reg query %reg% 2>nul | findstr /i "LocalServer32 InProcServer32 InProcHandler32" >nul && exit /b

reg query %reg% 2>nul | find /i "H" 1>nul || (
%_action%
exit /b
)

for /f "skip=2 tokens=*" %%a in ('reg query %reg% /ve 2^>nul') do echo %%a|findstr /r /e "[^0-9]" >nul || (
%_action%
exit /b
)

for /f "skip=2 tokens=3" %%a in ('reg query %reg%\Version /ve 2^>nul') do echo %%a|findstr /r "[^0-9]" >nul || (
%_action%
exit /b
)

for /f "skip=2 tokens=1" %%a in ('reg query %reg% 2^>nul') do echo %%a| findstr /i "MData Model scansk Therad" >nul && (
%_action%
exit /b
)

for /f "skip=2 tokens=*" %%a in ('reg query %reg% /ve 2^>nul') do echo %%a| find /i "+" >nul && (
%_action%
exit /b
)

exit/b

::========================================================================================================================================

:delete_key

reg delete %reg% /f %nul%

if not [%errorlevel%]==[0] if defined take_permission (
%nul% call :reg_own "%reg%" preserve S-1-1-0
reg delete %reg% /f %nul%
)

if [%errorlevel%]==[0] (
set "reg=%reg:"=%"
echo Deleted - !reg!
) else (
set "reg=%reg:"=%"
set _error=1
%_psc% write-host 'Failed' -fore 'white' -back 'DarkRed'  -NoNewline & echo  - !reg!
)

exit /b

::========================================================================================================================================

:lock_key

%nul% call :reg_own "%reg%" "" S-1-1-0 S-1-0-0 Deny "FullControl"

reg delete %reg% /f %nul%

if not [%errorlevel%]==[0] (
set "reg=%reg:"=%"
echo Locked - !reg!
set /a lockedkeys+=1
) else (
set _error=1
set "reg=%reg:"=%"
%_psc% write-host 'Failed' -fore 'white' -back 'DarkRed'  -NoNewline&echo  - !reg!
)

exit /b

::========================================================================================================================================

:count_key

set /a foundkeys+=1
exit /b

::========================================================================================================================================

::  A lean and mean snippet to set registry ownership and permission recursively
::  Written by @OpenSource
::  pastebin.com/OpenSource

:reg_own

%_psc% $A='%~1','%~2','%~3','%~4','%~5','%~6';iex(([io.file]::ReadAllText('!_batp!')-split':Own1\:.*')[1])&exit/b:Own1:
$D1=[uri].module.gettype('System.Diagnostics.Process')."GetM`ethods"(42) |where {$_.Name -eq 'SetPrivilege'} #`:no-ev-warn
'SeSecurityPrivilege','SeTakeOwnershipPrivilege','SeBackupPrivilege','SeRestorePrivilege'|foreach {$D1.Invoke($null, @("$_",2))}
$path=$A[0]; $rk=$path-split'\\',2; $HK=gi -lit Registry::$($rk[0]) -fo; $s=$A[1]; $sps=[Security.Principal.SecurityIdentifier]
$u=($A[2],'S-1-5-32-544')[!$A[2]];$o=($A[3],$u)[!$A[3]];$w=$u,$o |% {new-object $sps($_)}; $old=!$A[3];$own=!$old; $y=$s-eq'all'
$rar=new-object Security.AccessControl.RegistryAccessRule( $w[0], ($A[5],'FullControl')[!$A[5]], 1, 0, ($A[4],'Allow')[!$A[4]] )
$x=$s-eq'none';function Own1($k){$t=$HK.OpenSubKey($k,2,'TakeOwnership');if($t){0,4|%{try{$o=$t.GetAccessControl($_)}catch{$old=0}
};if($old){$own=1;$w[1]=$o.GetOwner($sps)};$o.SetOwner($w[0]);$t.SetAccessControl($o); $c=$HK.OpenSubKey($k,2,'ChangePermissions')
$p=$c.GetAccessControl(2);if($y){$p.SetAccessRuleProtection(1,1)};$p.ResetAccessRule($rar);if($x){$p.RemoveAccessRuleAll($rar)}
$c.SetAccessControl($p);if($own){$o.SetOwner($w[1]);$t.SetAccessControl($o)};if($s){$subkeys=$HK.OpenSubKey($k).GetSubKeyNames()
foreach($n in $subkeys){Own1 "$k\$n"}}}};Own1 $rk[1];if($env:VO){get-acl Registry::$path|fl} #:Own1: lean & mean snippet by AveYo

::========================================================================================================================================

:_color

if %winbuild% GEQ 10586 (
echo %esc%[%~1%~2%esc%[0m
) else (
call :batcol %~1 "%~2"
)
exit /b

:_color2

if %winbuild% GEQ 10586 (
echo %esc%[%~1%~2%esc%[%~3%~4%esc%[0m
) else (
call :batcol %~1 "%~2" %~3 "%~4"
)
exit /b

::=======================================

:: Colored text with pure batch method
:: Thanks to @OpenSource
:: https://stackoverflow.com/a/OpenSource

:: Powershell is not used here because its slow

:batcol

pushd %_coltemp%
if not exist "'" (<nul >"'" set /p "=.")
setlocal
set "s=%~2"
set "t=%~4"
call :_batcol %1 s %3 t
del /f /q "'"
del /f /q "`.txt"
popd
exit /b

:_batcol

setlocal EnableDelayedExpansion
set "s=!%~2!"
set "t=!%~4!"
for /f delims^=^ eol^= %%i in ("!s!") do (
  if "!" equ "" setlocal DisableDelayedExpansion
    >`.txt (echo %%i\..\')
    findstr /a:%~1 /f:`.txt "."
    <nul set /p "=%_BS%%_BS%%_BS%%_BS%%_BS%%_BS%%_BS%"
)
if "%~4"=="" echo(&exit /b
setlocal EnableDelayedExpansion
for /f delims^=^ eol^= %%i in ("!t!") do (
  if "!" equ "" setlocal DisableDelayedExpansion
    >`.txt (echo %%i\..\')
    findstr /a:%~3 /f:`.txt "."
    <nul set /p "=%_BS%%_BS%%_BS%%_BS%%_BS%%_BS%%_BS%"
)
echo(
exit /b

::=======================================

:_colorprep

if %winbuild% GEQ 10586 (
for /F %%a in ('echo prompt $E ^| cmd') do set "esc=%%a"

set     "Red="41;97m""
set    "Gray="100;97m""
set   "Black="30m""
set   "Green="42;97m""
set    "Blue="44;97m""
set  "Yellow="43;97m""
set "Magenta="45;97m""

set    "_Red="40;91m""
set  "_Green="40;92m""
set   "_Blue="40;94m""
set  "_White="40;37m""
set "_Yellow="40;93m""

exit /b
)

if not defined _BS for /f %%A in ('"prompt $H&for %%B in (1) do rem"') do set "_BS=%%A %%A"
set "_coltemp=%SystemRoot%\Temp"

set     "Red="CF""
set    "Gray="8F""
set   "Black="00""
set   "Green="2F""
set    "Blue="1F""
set  "Yellow="6F""
set "Magenta="5F""

set    "_Red="0C""
set  "_Green="0A""
set   "_Blue="09""
set  "_White="07""
set "_Yellow="0E""

exit /b

::========================================================================================================================================

:txt:
_________________________________

   Activation:
_________________________________

 - This script applies registry lock method to activate Internet download manager (IDM).

 - This method requires Internet at the time of activation.

 - IDM updates can be installed directly without having to activate again.

 - After the activation, if in some case, the IDM starts to show activation nag screen, 
   then just run the activation option again.

_________________________________

   Alternative Activation:
_________________________________

 - File Replacement Method: Replaces IDM executable files with modified versions.
 - This method can be used if the registry method is detected or blocked.
 - Note: Backup files are created before replacement.

_________________________________

   Reset IDM Activation / Trial:
_________________________________

 - Internet download manager provides 30 days trial period, you can use this script to 
   reset this Activation / Trial period whenever you want.
 
 - This option also can be used to restore status if in case the IDM reports fake serial
   key and other similar errors.

_________________________________

   OS requirement:
_________________________________

 - Project is supported only for Windows 7/8/8.1/10/11 and their Server equivalent.

_________________________________

 - Advanced Info:
_________________________________

   - To add a custom name in IDM license info, edit the line number 5 in the script file.

   - For activation in unattended mode, run the script with /act parameter.
   - For reset in unattended mode, run the script with /res parameter.
   - To enable silent mode with above two methods, run the script with /s parameter.

Possible accepted values,

"IAS_xxxxxxxx.cmd" /act
"IAS_xxxxxxxx.cmd" /res
"IAS_xxxxxxxx.cmd" /act /s
"IAS_xxxxxxxx.cmd" /res /s

_________________________________

   Additional Features:
_________________________________

   - Check IDM Version: Compare your installed version with the latest available version.

   - Download Latest IDM Version: Directly download the latest version of IDM.
   
   - Check Activation Status: Verify if IDM is currently activated without performing activation.

_________________________________

 - Troubleshooting steps:
_________________________________

   - If any other activator was used to activate IDM previously then make sure to properly
     uninstall it with that same activator (if there is an option), this is especially important
     if any registry / firewall block method was used.

   - Uninstall the IDM from control panel.

   - Make sure the latest original IDM setup is used for the installation,
     you can download it from https://www.internetdownloadmanager.com/download.html

   - Now install the IDM and use the activate option in this script and if failed then,

     - Disable windows firewall with the script option, this help in case of leftover entries of
       previously used activator (some file patch method also creates firewall entries).

     - Some security programs may block this script, this is false-positive, as long as you 
       downloaded the file from original post (mentioned below in this page), temporary suspend
       Antivirus realtime protection, or exclude the downloaded file/extracted folder from scanning.

     - If you are still facing any issues, please contact me (mentioned below in this page).

____________________________________________________________________________________________________

   Credits:
____________________________________________________________________________________________________

   
_________________________________

   IDM Activation Script
   
   Homepage: Open Source Community
             
   
   Email:    opensource

____________________________________________________________________________________________________
:txt:

::========================================================================================================================================
