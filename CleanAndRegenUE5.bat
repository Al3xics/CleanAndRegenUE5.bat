@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  Unreal Engine 5 - Clean & Regenerate Project Files
::  Supports: Rider, Visual Studio 2022, VSCode
:: ============================================================

:: ----------------------------------------------------------
:: STEP 1 - Find the .uproject file in the current directory
:: ----------------------------------------------------------
set "UPROJECT_FILE="
for %%F in (*.uproject) do (
    set "UPROJECT_FILE=%%F"
)

if not defined UPROJECT_FILE (
    echo [ERROR] No .uproject file found in the current directory.
    echo         Please run this script from your Unreal Engine project root.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Unreal Engine 5 - Clean ^& Regenerate Project Files
echo ============================================================
echo  Project: %UPROJECT_FILE%
echo ============================================================
echo.

:: ----------------------------------------------------------
:: STEP 2 - Detect installed IDEs, then let the user choose
:: ----------------------------------------------------------
call :detect_ides

:show_ide_menu
echo Select your IDE / Text Editor:
echo.
echo   [1] Rider              %RIDER_STATUS%
echo   [2] Visual Studio 2022 %VS2022_STATUS%
echo   [3] Visual Studio Code %VSCODE_STATUS%
echo.

set "IDE_CHOICE="
:ask_ide
set /p "IDE_CHOICE=Enter the number of your IDE (1, 2, or 3): "

if "%IDE_CHOICE%"=="1" ( set "IDE_NAME=Rider"              & set "IDE_FORMAT=VisualStudio2022" & set "IDE_FOUND=!RIDER_FOUND!"  & goto ide_selected )
if "%IDE_CHOICE%"=="2" ( set "IDE_NAME=Visual Studio 2022" & set "IDE_FORMAT=VisualStudio2022" & set "IDE_FOUND=!VS2022_FOUND!" & goto ide_selected )
if "%IDE_CHOICE%"=="3" ( set "IDE_NAME=Visual Studio Code" & set "IDE_FORMAT=VisualStudioCode" & set "IDE_FOUND=!VSCODE_FOUND!" & goto ide_selected )

echo [ERROR] Invalid choice. Please enter 1, 2, or 3.
goto ask_ide

:ide_selected
if "!IDE_FOUND!"=="0" (
    echo.
    echo [ERROR] %IDE_NAME% does not appear to be installed on this system.
    echo         Please select an installed IDE.
    echo.
    goto show_ide_menu
)

echo.
echo  IDE selected: %IDE_NAME%
echo.

:: ----------------------------------------------------------
:: STEP 3 - Locate Unreal Engine installation
:: ----------------------------------------------------------
set "DEFAULT_UE_ROOT=C:\Program Files\Epic Games"

:: Parse EngineAssociation from .uproject
set "ENGINE_VERSION="
for /f "tokens=2 delims=:, " %%A in ('findstr /i "EngineAssociation" "%UPROJECT_FILE%"') do (
    set "RAW_VER=%%A"
    set "ENGINE_VERSION=!RAW_VER:"=!"
)

set "UE_ROOT="
if defined ENGINE_VERSION (
    set "UE_ROOT=%DEFAULT_UE_ROOT%\UE_%ENGINE_VERSION%"
)

:: Validate the detected path
if defined UE_ROOT (
    call :find_generate_tool "!UE_ROOT!"
    if "!GENERATE_CMD!" neq "" (
        echo  Unreal Engine found at: !UE_ROOT!
        goto proceed
    )
)

:: Default path not valid - open folder browser dialog
echo.
if defined ENGINE_VERSION (
    echo [WARNING] Unreal Engine %ENGINE_VERSION% was not found at the default location:
    echo           %DEFAULT_UE_ROOT%\UE_%ENGINE_VERSION%
) else (
    echo [WARNING] Could not determine the Unreal Engine installation path automatically.
)
echo.
echo  A folder selection dialog will open.
echo  Please navigate to your Unreal Engine installation folder.
echo  Example: C:\Program Files\Epic Games\UE_5.6
echo.

:ask_ue_path
:: Open a Windows folder browser dialog via PowerShell
set "UE_ROOT="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description = 'Select your Unreal Engine installation folder (e.g. UE_5.6)'; $d.RootFolder = 'MyComputer'; $d.SelectedPath = 'C:\Program Files\Epic Games'; if ($d.ShowDialog() -eq 'OK') { $d.SelectedPath } else { '' }" 2^>nul`) do (
    set "UE_ROOT=%%F"
)

if not defined UE_ROOT (
    echo [ERROR] No folder selected. Please try again.
    goto ask_ue_path
)

if not exist "!UE_ROOT!" (
    echo [ERROR] The selected path does not exist. Please try again.
    goto ask_ue_path
)

call :find_generate_tool "!UE_ROOT!"
if "!GENERATE_CMD!"=="" (
    echo [ERROR] The selected folder does not appear to be a valid Unreal Engine root.
    echo         Please select the folder that contains the "Engine" subfolder.
    echo         Example: C:\Program Files\Epic Games\UE_5.6
    goto ask_ue_path
)

echo  Unreal Engine found at: !UE_ROOT!

:proceed
echo.

:: ----------------------------------------------------------
:: STEP 4 - Detect previous IDE and confirm before cleaning
:: ----------------------------------------------------------

:: Detect previous IDE from leftover folders/files.
:: Priority:
::   1. .idea\           -> Rider   (Rider-exclusive)
::   2. .vscode\         -> VSCode  (VSCode-exclusive)
::   3. *.code-workspace -> VSCode  (VSCode-exclusive)
::   4. .vs\ or *.sln   -> VS2022  (only if no .idea, since Rider also generates these)
set "PREV_IDE=none"
if exist ".idea" (
    set "PREV_IDE=Rider"
    goto prev_ide_detected
)
if exist ".vscode" (
    set "PREV_IDE=VSCode"
    goto prev_ide_detected
)
for %%F in (*.code-workspace) do (
    set "PREV_IDE=VSCode"
    goto prev_ide_detected
)
if exist ".vs" (
    set "PREV_IDE=VS2022"
    goto prev_ide_detected
)
for %%F in (*.sln) do (
    set "PREV_IDE=VS2022"
    goto prev_ide_detected
)
:prev_ide_detected

echo ============================================================
echo  The following folders/files will be DELETED:
echo ============================================================
echo   - Binaries\
echo   - DerivedDataCache\
echo   - Intermediate\
echo   - Saved\
if "%PREV_IDE%"=="Rider"  echo   - .idea\
if "%PREV_IDE%"=="VS2022" echo   - .vs\
if "%PREV_IDE%"=="VS2022" echo   - .vsconfig
if "%PREV_IDE%"=="VS2022" echo   - *.sln
if "%PREV_IDE%"=="VSCode" echo   - .vscode\
if "%PREV_IDE%"=="VSCode" echo   - *.code-workspace
if "%PREV_IDE%"=="none"   echo   (no previous IDE artifacts detected)

echo.
set "CONFIRM="
:ask_confirm
set /p "CONFIRM=Are you sure you want to continue? (Y/N): "
if /i "%CONFIRM%"=="Y" goto do_clean
if /i "%CONFIRM%"=="N" (
    echo  Operation cancelled by user.
    pause
    exit /b 0
)
echo [ERROR] Please enter Y or N.
goto ask_confirm

:do_clean
echo.
echo ============================================================
echo  Cleaning project...
echo ============================================================

:: Common folders for all IDEs
call :delete_dir "Binaries"
call :delete_dir "DerivedDataCache"
call :delete_dir "Intermediate"
call :delete_dir "Saved"


if "%PREV_IDE%"=="none" (
    echo   [INFO    ] No previous IDE artifacts detected, skipping IDE-specific cleanup.
) else (
    echo   [INFO    ] Previous IDE detected: %PREV_IDE%
)

:: Clean previous IDE artifacts
if "%PREV_IDE%"=="Rider" (
    call :delete_dir ".idea"
)
if "%PREV_IDE%"=="VS2022" (
    call :delete_dir ".vs"
    call :delete_file ".vsconfig"
    call :delete_glob "*.sln"
)
if "%PREV_IDE%"=="VSCode" (
    call :delete_dir ".vscode"
    call :delete_glob "*.code-workspace"
)

echo.
echo  Clean complete.
echo.

:: ----------------------------------------------------------
:: STEP 5 - Write BuildConfiguration.xml
::           Recommended approach for UE 5.3+ to set the IDE
::           format without passing CLI flags to UBT.
:: ----------------------------------------------------------
set "BUILD_CFG_DIR=%APPDATA%\Unreal Engine\UnrealBuildTool"
set "BUILD_CFG_FILE=!BUILD_CFG_DIR!\BuildConfiguration.xml"

echo ============================================================
echo  Configuring BuildConfiguration.xml for %IDE_NAME%...
echo ============================================================

if not exist "!BUILD_CFG_DIR!" (
    mkdir "!BUILD_CFG_DIR!"
)

(
    echo ^<?xml version="1.0" encoding="utf-8" ?^>
    echo ^<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration"^>
    echo   ^<ProjectFileGenerator^>
    echo     ^<Format^>%IDE_FORMAT%^</Format^>
    echo   ^</ProjectFileGenerator^>
    echo ^</Configuration^>
) > "!BUILD_CFG_FILE!"

if errorlevel 1 (
    echo [ERROR] Failed to write BuildConfiguration.xml at:
    echo         !BUILD_CFG_FILE!
    pause
    exit /b 1
)

echo   Written : !BUILD_CFG_FILE!
echo   Format  : %IDE_FORMAT%
echo.

:: ----------------------------------------------------------
:: STEP 6 - Regenerate project files
:: ----------------------------------------------------------
echo ============================================================
echo  Regenerating project files for %IDE_NAME%...
echo ============================================================
echo.

echo  Tool: !GENERATE_CMD!
echo.

:: Call UnrealVersionSelector with -projectfiles, same as right-click menu.
:: This respects BuildConfiguration.xml and only generates files for the
:: configured IDE, without creating extra files for other IDEs.
"!GENERATE_CMD!" -projectfiles "%CD%\%UPROJECT_FILE%"
set "REGEN_ERR=!errorlevel!"

if "!REGEN_ERR!" neq "0" (
    echo.
    echo [ERROR] Project file generation failed ^(exit code: !REGEN_ERR!^).
    echo         See output above for details.
    echo.
    echo  Press any key to close...
    pause ^>nul
    exit /b 1
)

:: ----------------------------------------------------------
:: STEP 7 - Post-generation cleanup
::           Remove any IDE artifacts that UE generated but don't
::           belong to the target IDE.
:: ----------------------------------------------------------
echo ============================================================
echo  Post-generation cleanup...
echo ============================================================

:: Rider and VS2022 both use .sln — only remove if switching to VSCode
if "%IDE_NAME%"=="Visual Studio Code" (
    call :delete_dir ".vs"
    call :delete_dir ".idea"
    call :delete_file ".vsconfig"
    call :delete_glob "*.sln"
)

:: Remove VSCode artifacts if target IDE is not VSCode
if not "%IDE_NAME%"=="Visual Studio Code" (
    call :delete_dir ".vscode"
    call :delete_glob "*.code-workspace"
)

echo.
echo ============================================================
echo  Done! Project files regenerated successfully for %IDE_NAME%.
echo ============================================================
echo.
exit /b 0

:: ============================================================
::  Subroutine : detect_ides
::  Probes the system for each supported IDE and sets:
::    RIDER_FOUND / VS2022_FOUND / VSCODE_FOUND  (1 = found, 0 = not found)
::    RIDER_STATUS / VS2022_STATUS / VSCODE_STATUS  (label shown in menu)
:: ============================================================
:detect_ides
set "RIDER_FOUND=0"
set "VS2022_FOUND=0"
set "VSCODE_FOUND=0"
set "RIDER_STATUS=(not detected)"
set "VS2022_STATUS=(not detected)"
set "VSCODE_STATUS=(not detected)"

:: --- Rider ---

:: Method 1: fixed folder name (older standalone installs)
for %%P in (
    "%LOCALAPPDATA%\Programs\Rider\bin\rider64.exe"
    "%PROGRAMFILES%\JetBrains\JetBrains Rider\bin\rider64.exe"
    "%PROGRAMFILES%\JetBrains\Rider\bin\rider64.exe"
) do (
    if exist %%P (
        set "RIDER_FOUND=1"
        set "RIDER_STATUS=(installed)"
    )
)

:: Method 2: versioned folder name e.g. "JetBrains Rider 2026.1.0.1" (recent standalone installs)
if "!RIDER_FOUND!"=="0" (
    for /d %%D in ("%LOCALAPPDATA%\Programs\JetBrains Rider *") do (
        if exist "%%D\bin\rider64.exe" (
            set "RIDER_FOUND=1"
            set "RIDER_STATUS=(installed)"
        )
    )
)

:: Method 3: JetBrains Toolbox apps folder
if "!RIDER_FOUND!"=="0" (
    for /d %%D in ("%LOCALAPPDATA%\JetBrains\Toolbox\apps\Rider\*") do (
        if exist "%%D\bin\rider64.exe" (
            set "RIDER_FOUND=1"
            set "RIDER_STATUS=(installed)"
        )
        for /d %%S in ("%%D\*") do (
            if exist "%%S\bin\rider64.exe" (
                set "RIDER_FOUND=1"
                set "RIDER_STATUS=(installed)"
            )
        )
    )
)

:: --- Visual Studio 2022 ---

:: Method 1: vswhere.exe without any workload requirement (most permissive)
set "VSWHERE=%PROGRAMFILES(X86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "!VSWHERE!" (
    for /f "usebackq tokens=*" %%V in (
        `"!VSWHERE!" -version "[17.0,18.0)" -products * -find "Common7\IDE\devenv.exe" 2^>nul`
    ) do (
        if exist "%%V" (
            set "VS2022_FOUND=1"
            set "VS2022_STATUS=(installed)"
        )
    )
)

:: Method 2: look for devenv.exe in all known VS2022 install paths
if "!VS2022_FOUND!"=="0" (
    for %%P in (
        "%PROGRAMFILES%\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"
        "%PROGRAMFILES%\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe"
        "%PROGRAMFILES%\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe"
        "%PROGRAMFILES%\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\devenv.exe"
        "%PROGRAMFILES(X86)%\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"
        "%PROGRAMFILES(X86)%\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe"
        "%PROGRAMFILES(X86)%\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe"
    ) do (
        if exist %%P (
            set "VS2022_FOUND=1"
            set "VS2022_STATUS=(installed)"
        )
    )
)

:: Method 3: registry lookup (covers non-standard install locations)
if "!VS2022_FOUND!"=="0" (
    for /f "tokens=2*" %%A in (
        'reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\17.0" /v "InstallDir" 2^>nul'
    ) do (
        if exist "%%B\devenv.exe" (
            set "VS2022_FOUND=1"
            set "VS2022_STATUS=(installed)"
        )
    )
)
if "!VS2022_FOUND!"=="0" (
    for /f "tokens=2*" %%A in (
        'reg query "HKCU\SOFTWARE\Microsoft\VisualStudio\17.0" /v "InstallDir" 2^>nul'
    ) do (
        if exist "%%B\devenv.exe" (
            set "VS2022_FOUND=1"
            set "VS2022_STATUS=(installed)"
        )
    )
)

:: --- Visual Studio Code ---
for %%P in (
    "%LOCALAPPDATA%\Programs\Microsoft VS Code\code.exe"
    "%PROGRAMFILES%\Microsoft VS Code\code.exe"
) do (
    if exist %%P (
        set "VSCODE_FOUND=1"
        set "VSCODE_STATUS=(installed)"
    )
)
:: Also check if 'code' is on the PATH
if "!VSCODE_FOUND!"=="0" (
    where code >nul 2>&1
    if not errorlevel 1 (
        set "VSCODE_FOUND=1"
        set "VSCODE_STATUS=(installed)"
    )
)

exit /b 0

:: ============================================================
::  Subroutine : find_generate_tool <ue_root>
::  Sets GENERATE_CMD if UnrealVersionSelector.exe is found.
::  This mimics the "Generate Visual Studio project files"
::  right-click behaviour and respects BuildConfiguration.xml
::  without generating extra IDE files like UBT does directly.
:: ============================================================
:find_generate_tool
set "GENERATE_CMD="
set "_ROOT=%~1"

:: Option A : UnrealVersionSelector.exe - Win64 (standard launcher install)
if exist "!_ROOT!\Engine\Binaries\Win64\UnrealVersionSelector.exe" (
    set "GENERATE_CMD=!_ROOT!\Engine\Binaries\Win64\UnrealVersionSelector.exe"
    exit /b 0
)

:: Option B : UnrealVersionSelector-Win64-Shipping.exe (some engine builds)
if exist "!_ROOT!\Engine\Binaries\Win64\UnrealVersionSelector-Win64-Shipping.exe" (
    set "GENERATE_CMD=!_ROOT!\Engine\Binaries\Win64\UnrealVersionSelector-Win64-Shipping.exe"
    exit /b 0
)

:: Option C : fallback to Epic Games Launcher's own UnrealVersionSelector
if exist "%PROGRAMFILES(X86)%\Epic Games\Launcher\Engine\Binaries\Win64\UnrealVersionSelector.exe" (
    set "GENERATE_CMD=%PROGRAMFILES(X86)%\Epic Games\Launcher\Engine\Binaries\Win64\UnrealVersionSelector.exe"
    exit /b 0
)

exit /b 0

:: ============================================================
:delete_dir
if exist "%~1\" (
    echo   [DEL DIR ] %~1\
    rd /s /q "%~1"
) else (
    echo   [SKIP     ] %~1\  ^(not found^)
)
exit /b 0

:delete_file
if exist "%~1" (
    echo   [DEL FILE ] %~1
    del /f /q "%~1"
) else (
    echo   [SKIP     ] %~1  ^(not found^)
)
exit /b 0

:delete_glob
set "_found=0"
for %%F in (%~1) do (
    echo   [DEL FILE ] %%F
    del /f /q "%%F"
    set "_found=1"
)
if "!_found!"=="0" echo   [SKIP     ] %~1  ^(no files found^)
exit /b 0
