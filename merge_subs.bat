@echo off
setlocal enabledelayedexpansion

:: 初始化参数
set "TEST_MODE=0"
set "DELETE_OLD=0"
set "ROOT_DIR="

:: 检查必传参数（第一个参数为目录）
if "%1%"=="" (
    echo 错误：请传入课程根目录作为第一个参数！
    echo 用法：merge_subs.bat "out_dir\课程文件夹" [-t] [-d]
    pause
    exit /b 1
)
set "ROOT_DIR=%1%"
shift  :: 移除第一个参数，处理剩余选项

:: 解析其他参数
:parse_args
if "%1%"=="-t" (set "TEST_MODE=1" & shift & goto parse_args)
if "%1%"=="-d" (set "DELETE_OLD=1" & shift & goto parse_args)
if not "%1%"=="" (
    echo 警告：未知参数 "%1%"，已忽略
    shift & goto parse_args
)

:: 检查目录是否存在
if not exist "%ROOT_DIR%" (
    echo 错误：目录 "%ROOT_DIR%" 不存在！
    pause
    exit /b 1
)

:: 遍历处理
for /d /r "%ROOT_DIR%" %%d in (*) do (
    cd /d "%%d" || continue
    for %%f in (*.mp4) do (
        set "name=%%~nf"
        set "srt=!name!.srt"
        if exist "!srt!" (
            echo 处理：%%d\%%f
            ffmpeg -hide_banner -loglevel error -i "%%f" -vf "subtitles=!srt!" -c:v libx264 -c:a copy "!name!_sub.mp4"
            if exist "!name!_sub.mp4" (
                if "!DELETE_OLD!"=="1" (
                    del "%%f" & ren "!name!_sub.mp4" "%%f"
                    echo 已替换原文件
                ) else (
                    echo 生成带字幕文件：!name!_sub.mp4
                )
            )
            if "!TEST_MODE!"=="1" (
                echo 测试模式结束
                goto end
            )
        )
    )
)

:end
echo 处理完成！
pause