@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ================================================================================
echo                        Course Video Integrity Checker
echo ================================================================================
echo.

set total_videos=0
set total_subtitles=0
set missing_subs=0
set orphan_subs=0
set zero_byte_videos=0

echo Scanning video files...
echo.

REM Create temp files
set temp_videos=%temp%\videos_list.txt
set temp_subs=%temp%\subs_list.txt
set temp_report=%temp%\course_check_report.txt

REM Clear temp files
type nul > %temp_videos%
type nul > %temp_subs%
type nul > %temp_report%

REM Count all video and subtitle files
for /r %%f in (*.mp4) do (
    set /a total_videos+=1
)

for /r %%f in (*_en.srt) do (
    set /a total_subtitles+=1
)

echo --------------------------------------------------------------------------------
echo  Statistics
echo --------------------------------------------------------------------------------
echo   Total Videos   : !total_videos!
echo   Total Subtitles: !total_subtitles!
echo.

echo --------------------------------------------------------------------------------
echo  Checking Issues...
echo --------------------------------------------------------------------------------
echo.

REM Check 0-byte video files
echo [CRITICAL] Checking 0-byte video files...
setlocal disabledelayedexpansion
for /r %%f in (*.mp4) do (
    if %%~zf==0 (
        setlocal enabledelayedexpansion
        set /a zero_byte_videos+=1
        echo   [X] 0-byte video: %%f
        echo [CRITICAL] 0-byte video: %%f >> %temp_report%
        endlocal
    )
)
endlocal
if !zero_byte_videos!==0 (
    echo   [OK] No 0-byte videos found
)
echo.

REM Check orphaned subtitles (subtitle without video)
echo [CRITICAL] Checking orphaned subtitles (subtitle without video)...
set orphan_count=0
setlocal disabledelayedexpansion
for /r %%f in (*_en.srt) do (
    setlocal enabledelayedexpansion
    set "sub_file=%%f"
    set "sub_name=%%~nf"
    set "video_name=!sub_name:~0,-3!"
    set "video_path=%%~dpf!video_name!.mp4"

    if not exist "!video_path!" (
        set /a orphan_count+=1
        echo   [X] Orphaned subtitle: %%f
        echo [CRITICAL] Orphaned subtitle (no video): %%f >> %temp_report%
    )
    endlocal
)
endlocal
set /a orphan_subs=!orphan_count!
if !orphan_subs!==0 (
    echo   [OK] No orphaned subtitles
)
echo.

REM Check videos without subtitles
echo [WARNING] Checking videos without subtitles...
set missing_count=0
setlocal disabledelayedexpansion
for /r %%f in (*.mp4) do (
    setlocal enabledelayedexpansion
    set "video_file=%%f"
    set "video_name=%%~nf"
    set "sub_path=%%~dpf!video_name!_en.srt"

    if not exist "!sub_path!" (
        set /a missing_count+=1
        if !missing_count! LEQ 10 (
            echo   [!] Missing subtitle: %%f
        )
        echo [WARNING] Missing subtitle: %%f >> %temp_report%
    )
    endlocal
)
endlocal
set /a missing_subs=!missing_count!
if !missing_subs!==0 (
    echo   [OK] All videos have subtitles
) else (
    if !missing_subs! GTR 10 (
        echo   ... and !missing_subs! more videos without subtitles (showing first 10 only)
    )
)
echo.

echo ================================================================================
echo  Summary Report
echo ================================================================================
echo.
echo   [CRITICAL ISSUES]
echo      - 0-byte videos        : !zero_byte_videos!
echo      - Orphaned subtitles   : !orphan_subs!
echo.
echo   [WARNINGS]
echo      - Missing subtitles    : !missing_subs!
echo.

if !zero_byte_videos!==0 if !orphan_subs!==0 (
    echo   [OK] No critical issues found. All video files are complete!
) else (
    echo   [!] Critical issues detected! Please check the files above.
)

echo.
echo ================================================================================
echo Detailed report saved to: %temp_report%
echo ================================================================================
echo.

REM Ask to open detailed report
set /p open_report="Open detailed report? (Y/N): "
if /i "!open_report!"=="Y" (
    notepad %temp_report%
)

REM Clean up temp files (keep report)
del %temp_videos% 2>nul
del %temp_subs% 2>nul

echo.
pause
