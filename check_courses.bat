@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ================================================================================
echo                            课程视频完整性检查工具
echo ================================================================================
echo.

set total_videos=0
set total_subtitles=0
set missing_subs=0
set orphan_subs=0
set zero_byte_videos=0

echo 正在扫描视频文件...
echo.

REM 创建临时文件
set temp_report=%temp%\course_check_report.txt
set temp_missing=%temp%\missing_count.txt
set temp_orphan=%temp%\orphan_count.txt
type nul > "!temp_report!"
(echo 0) > "!temp_missing!"
(echo 0) > "!temp_orphan!"

REM 统计所有视频和字幕文件
for /r %%f in (*.mp4) do (
    set /a total_videos+=1
)

for /r %%f in (*_en.srt) do (
    set /a total_subtitles+=1
)

echo --------------------------------------------------------------------------------
echo  统计信息
echo --------------------------------------------------------------------------------
echo   视频总数: !total_videos!
echo   字幕总数: !total_subtitles!
echo.

echo --------------------------------------------------------------------------------
echo  正在检查问题...
echo --------------------------------------------------------------------------------
echo.

REM 检查0字节视频文件
echo [严重] 检查0字节视频文件...
for /r %%f in (*.mp4) do (
    if %%~zf==0 (
        set /a zero_byte_videos+=1
        echo   [X] 0字节视频: %%f
        echo [严重] 0字节视频: %%f >> "!temp_report!"
    )
)
if !zero_byte_videos!==0 (
    echo   [OK] 未发现0字节视频
)
echo.

REM 检查孤立字幕（有字幕但无视频）
echo [严重] 检查孤立字幕文件（有字幕但无视频）...
setlocal disabledelayedexpansion
for /r %%f in (*_en.srt) do (
    set "srt_file=%%f"
    set "srt_path=%%~dpf"
    set "srt_name=%%~nf"
    setlocal enabledelayedexpansion
    REM 替换 _en 为空来获取视频名称
    set "vid_name=!srt_name:_en=!"
    set "vid_path=!srt_path!!vid_name!.mp4"

    if not exist "!vid_path!" (
        REM 读取并更新孤立字幕计数
        set /p orphan_count=<"!temp_orphan!" 2>nul
        if "!orphan_count!"=="" set orphan_count=0
        set /a orphan_count+=1
        (echo !orphan_count!) > "!temp_orphan!"

        echo   [X] 孤立字幕: %%f
        echo [严重] 孤立字幕: %%f >> "!temp_report!"
    )
    endlocal
)
endlocal

REM 读取孤立字幕计数
set /p orphan_subs=<"!temp_orphan!" 2>nul
if "!orphan_subs!"=="" set orphan_subs=0

if !orphan_subs!==0 (
    echo   [OK] 未发现孤立字幕
)
echo.

REM 检查缺少字幕的视频
echo [警告] 检查缺少字幕的视频...
setlocal disabledelayedexpansion
for /r %%f in (*.mp4) do (
    if not exist "%%~dpf%%~nf_en.srt" (
        setlocal enabledelayedexpansion
        REM 读取并更新缺失字幕计数
        set /p missing_count=<"!temp_missing!" 2>nul
        if "!missing_count!"=="" set missing_count=0
        set /a missing_count+=1
        (echo !missing_count!) > "!temp_missing!"

        echo   [!] 缺少字幕: %%f
        echo [警告] 缺少字幕: %%f >> "!temp_report!"
        endlocal
    )
)
endlocal

REM 读取缺失字幕计数
set /p missing_subs=<"!temp_missing!" 2>nul
if "!missing_subs!"=="" set missing_subs=0

if !missing_subs!==0 (
    echo   [OK] 所有视频都有字幕
)
echo.

REM 确保所有计数变量都是纯数字
set /a zero_display=!zero_byte_videos!+0
set /a orphan_display=!orphan_subs!+0
set /a missing_display=!missing_subs!+0

echo ================================================================================
echo  检查结果汇总
echo ================================================================================
echo.
echo   [严重问题]
echo     0字节视频 = !zero_display!
echo     孤立字幕 = !orphan_display!
echo.
echo   [警告]
echo     缺失字幕 = !missing_display!
echo.

if !zero_byte_videos!==0 if !orphan_subs!==0 (
    echo   [OK] 没有严重问题，所有视频文件完整
) else (
    echo   [!] 发现严重问题，请检查上述文件
)

echo.
echo ================================================================================
echo 详细报告已保存到: !temp_report!
echo ================================================================================
echo.

REM 清理临时计数文件
del "!temp_missing!" 2>nul
del "!temp_orphan!" 2>nul

REM 询问是否打开详细报告
set /p open_report="是否打开详细报告 (Y/N): "
if /i "!open_report!"=="Y" (
    start notepad "!temp_report!"
)

echo.
echo 按任意键退出...
pause >nul
