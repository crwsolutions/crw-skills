@echo off
setlocal enableextensions

set "SCRIPT_DIR=%~dp0"
set "SKILLS_SRC=%SCRIPT_DIR%skills"
set "TARGET_DIR=%USERPROFILE%\.alta\skills"

if not exist "%SKILLS_SRC%" (
    echo Skills source folder not found: "%SKILLS_SRC%"
    exit /b 1
)

if not exist "%TARGET_DIR%" (
    echo Creating target directory: "%TARGET_DIR%"
    mkdir "%TARGET_DIR%" >nul 2>&1
    if errorlevel 1 (
        echo Failed to create target directory.
        exit /b 1
    )
)

robocopy "%SKILLS_SRC%" "%TARGET_DIR%" /E /PURGE >nul
if errorlevel 8 (
    echo Copy finished with warnings or errors.
    exit /b 1
)

echo Skills copied to: "%TARGET_DIR%"
exit /b 0
