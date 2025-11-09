#!/bin/bash

# ============================================
# 课程视频综合检测工具（并行优化版）
# ============================================
# 功能：
# 1. 视频完整性验证（空文件/DRM/损坏）
# 2. 字幕匹配检查
# 3. 课程分类统计
# 4. 并行处理加速（保证准确性）
# ============================================

set -uo pipefail  # 移除 -e 避免意外退出

# ============================================
# 配置参数
# ============================================
TIMEOUT=15  # ffmpeg 解码超时时间（秒），并发时需要更长时间
MAX_RETRIES=3  # 解码失败时的最大重试次数
VIDEO_FORMATS=("mp4" "mkv" "avi" "mov" "m4v" "wmv" "webm" "flv" "ts")
REPORT_FILE="检测报告_$(date +%Y%m%d_%H%M%S).txt"

# 临时目录（存储并行任务结果）
TEMP_DIR="/tmp/video_check_$$"

# ============================================
# 颜色输出
# ============================================
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# 问题文件统计
# ============================================
declare -a EMPTY_FILES=()
declare -a DRM_FILES=()
declare -a CORRUPTED_FILES=()
declare -a VIDEO_MISSING_SUBTITLE=()
declare -a SUBTITLE_MISSING_VIDEO=()

# ============================================
# 课程统计（关联数组）
# ============================================
declare -A COURSE_VIDEO_COUNT
declare -A COURSE_TOTAL_SECONDS

# ============================================
# 检测CPU核心数
# ============================================
get_cpu_cores() {
    local cores=4  # 默认值

    # macOS
    if command -v sysctl &> /dev/null; then
        cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
    # Linux
    elif [ -f /proc/cpuinfo ]; then
        cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 4)
    # Windows Git Bash
    elif [ -n "$NUMBER_OF_PROCESSORS" ]; then
        cores=$NUMBER_OF_PROCESSORS
    fi

    # 保留2个核心给系统，最少使用2个核心
    local parallel_jobs=$((cores - 2))
    if [ $parallel_jobs -lt 2 ]; then
        parallel_jobs=2
    fi

    echo 8
    # echo $((cores / 2))
}

# ============================================
# 依赖检查
# ============================================
check_dependencies() {
    echo -e "${BLUE}[检查依赖]${NC}"

    local missing_deps=()

    if ! command -v ffmpeg &> /dev/null; then
        missing_deps+=("ffmpeg")
    fi

    if ! command -v ffprobe &> /dev/null; then
        missing_deps+=("ffprobe")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}错误：缺少必需工具：${missing_deps[*]}${NC}"
        echo ""
        echo "安装方法："
        echo "  macOS:   brew install ffmpeg"
        echo "  Windows: 下载 ffmpeg 并添加到 PATH"
        echo ""
        read -p "按 Enter 键退出..." dummy
        exit 1
    fi

    echo -e "${GREEN}✓ 依赖检查通过${NC}"
    echo ""
}

# ============================================
# 环境检查
# ============================================
check_environment() {
    echo -e "${BLUE}[检查运行环境]${NC}"

    # 检查是否在正确的目录
    local has_video_dirs=false
    for dir in */; do
        if [ -d "$dir" ]; then
            has_video_dirs=true
            break
        fi
    done

    if [ "$has_video_dirs" = false ]; then
        echo -e "${RED}错误：当前目录下没有发现子目录${NC}"
        echo "请确保在课程视频根目录下运行此脚本"
        echo ""
        read -p "按 Enter 键退出..." dummy
        exit 1
    fi

    echo -e "${GREEN}✓ 运行环境检查通过${NC}"
    echo ""
}

# ============================================
# 获取文件大小（跨平台）
# ============================================
get_file_size() {
    local file="$1"
    # 使用 wc -c 获取文件大小（跨平台兼容）
    wc -c < "$file" 2>/dev/null | tr -d ' '
}

# ============================================
# 带超时的命令执行（并发安全版本）
# ============================================
run_with_timeout() {
    local timeout=$1
    shift
    local cmd=("$@")

    # 为每个调用创建唯一的临时文件
    local status_file="${TEMP_DIR}/cmd_status_$$_${RANDOM}.tmp"

    # 在子shell中运行命令，捕获退出码
    (
        "${cmd[@]}" &> /dev/null
        echo $? > "$status_file"
    ) &
    local pid=$!

    # 等待命令完成或超时
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        # 检查进程是否还在运行
        if ! kill -0 $pid 2>/dev/null; then
            # 进程已结束
            wait $pid 2>/dev/null || true

            # 读取退出码
            if [ -f "$status_file" ]; then
                local exit_code=$(cat "$status_file" 2>/dev/null || echo 1)
                rm -f "$status_file"
                return $exit_code
            fi

            # 如果没有状态文件，返回0（成功）
            return 0
        fi

        sleep 1
        ((elapsed++))
    done

    # 超时：杀死进程及其子进程
    # 尝试杀死进程组（负PID）
    kill -TERM -$pid 2>/dev/null || kill -TERM $pid 2>/dev/null || true
    sleep 1
    kill -9 -$pid 2>/dev/null || kill -9 $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true

    rm -f "$status_file"
    return 124  # 超时返回码
}

# ============================================
# 检测视频完整性
# ============================================
check_video_integrity() {
    local video_file="$1"
    local file_size=$(get_file_size "$video_file")

    # 1. 检查空文件
    if [ -z "$file_size" ] || [ "$file_size" -lt 1024 ]; then
        return 1  # 空文件
    fi

    # 2. 使用 ffprobe 快速检测元数据
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null)

    if [ -z "$duration" ] || [ "$duration" = "N/A" ]; then
        return 2  # DRM 或严重损坏（无法读取时长）
    fi

    # 3. 使用 ffmpeg 解码前 1 秒验证完整性（支持重试）
    local retry_count=0
    local decode_success=false

    while [ $retry_count -lt $MAX_RETRIES ]; do
        if run_with_timeout $TIMEOUT ffmpeg -v error -i "$video_file" -t 1 -f null -; then
            decode_success=true
            break
        fi

        ((retry_count++))

        # 如果还有重试机会，等待2秒后重试
        if [ $retry_count -lt $MAX_RETRIES ]; then
            sleep 2
        fi
    done

    # 3次重试都失败才标记为损坏
    if [ "$decode_success" = false ]; then
        return 3  # 下载不完整/损坏
    fi

    # 返回时长（秒）
    echo "$duration"
    return 0
}

# ============================================
# 检查字幕匹配
# ============================================
check_subtitle_match() {
    local video_file="$1"
    local video_dir=$(dirname "$video_file")
    local video_basename=$(basename "$video_file")
    local video_name="${video_basename%.*}"

    # 检查两种字幕格式：_en.srt 和 .srt
    local subtitle_en="${video_dir}/${video_name}_en.srt"
    local subtitle_plain="${video_dir}/${video_name}.srt"

    if [ -f "$subtitle_en" ] || [ -f "$subtitle_plain" ]; then
        return 0  # 找到字幕
    else
        return 1  # 缺少字幕
    fi
}

# ============================================
# 处理单个视频（并行任务单元）
# ============================================
process_single_video() {
    local video_file="$1"
    local task_id="$2"
    local result_file="${TEMP_DIR}/result_${task_id}.txt"

    # 获取一级目录（课程名称）
    local course_name=$(echo "$video_file" | cut -d'/' -f2)

    # 检测视频完整性
    local duration
    duration=$(check_video_integrity "$video_file")
    local integrity_status=$?

    # 将结果写入临时文件
    echo "VIDEO|$video_file" >> "$result_file"
    echo "COURSE|$course_name" >> "$result_file"
    echo "STATUS|$integrity_status" >> "$result_file"

    if [ $integrity_status -eq 0 ]; then
        echo "DURATION|$duration" >> "$result_file"

        # 检查字幕
        if ! check_subtitle_match "$video_file"; then
            echo "MISSING_SUBTITLE|1" >> "$result_file"
        fi
    fi
}

# ============================================
# 并行处理视频列表
# ============================================
process_videos_parallel() {
    local video_files=("$@")
    local total_videos=${#video_files[@]}
    local parallel_jobs=$(get_cpu_cores)

    echo -e "${BLUE}检测到 CPU 核心数，使用 $parallel_jobs 个并行任务${NC}"
    echo ""

    # 创建临时目录
    mkdir -p "$TEMP_DIR"

    echo -e "${BLUE}[开始并行检测]${NC}"
    echo ""

    local count=0
    local active_jobs=0

    for video_file in "${video_files[@]}"; do
        # 启动后台任务
        process_single_video "$video_file" "$count" &

        ((count++))
        ((active_jobs++))

        # 控制并发数
        if [ $active_jobs -ge $parallel_jobs ]; then
            wait -n  # 等待任意一个任务完成
            ((active_jobs--))
        fi

        # 每20个文件显示一次进度
        if [ $((count % 20)) -eq 0 ]; then
            echo -e "${BLUE}进度: $count/$total_videos${NC}"
        fi
    done

    # 等待所有任务完成
    wait

    echo -e "${BLUE}进度: $total_videos/$total_videos${NC}"
    echo ""
    echo -e "${GREEN}检测完成！${NC}"
    echo ""
}

# ============================================
# 汇总并行结果
# ============================================
collect_results() {
    echo -e "${BLUE}[汇总检测结果]${NC}"

    # 遍历所有结果文件
    for result_file in "$TEMP_DIR"/result_*.txt; do
        if [ ! -f "$result_file" ]; then
            continue
        fi

        local video_file=""
        local course_name=""
        local status=""
        local duration=""
        local missing_subtitle=0

        # 读取结果文件
        while IFS='|' read -r key value; do
            case $key in
                VIDEO)
                    video_file="$value"
                    ;;
                COURSE)
                    course_name="$value"
                    ;;
                STATUS)
                    status="$value"
                    ;;
                DURATION)
                    duration="$value"
                    ;;
                MISSING_SUBTITLE)
                    missing_subtitle=1
                    ;;
            esac
        done < "$result_file"

        # 根据状态分类
        case $status in
            0)
                # 视频正常
                if [ -z "${COURSE_VIDEO_COUNT[$course_name]:-}" ]; then
                    COURSE_VIDEO_COUNT[$course_name]=0
                    COURSE_TOTAL_SECONDS[$course_name]=0
                fi

                ((COURSE_VIDEO_COUNT[$course_name]++))

                # 累加时长
                local duration_int=${duration%.*}
                COURSE_TOTAL_SECONDS[$course_name]=$((${COURSE_TOTAL_SECONDS[$course_name]} + duration_int))

                # 字幕缺失
                if [ $missing_subtitle -eq 1 ]; then
                    VIDEO_MISSING_SUBTITLE+=("$video_file")
                fi
                ;;
            1)
                EMPTY_FILES+=("$video_file")
                ;;
            2)
                DRM_FILES+=("$video_file")
                ;;
            3)
                CORRUPTED_FILES+=("$video_file")
                ;;
        esac
    done

    echo ""
}

# ============================================
# 检查孤立字幕
# ============================================
check_orphan_subtitles() {
    echo -e "${BLUE}[检查孤立字幕]${NC}"

    local subtitle_files=()
    while IFS= read -r -d '' file; do
        subtitle_files+=("$file")
    done < <(find . -type f -name "*_en.srt" -print0)

    for subtitle_file in "${subtitle_files[@]}"; do
        local subtitle_dir=$(dirname "$subtitle_file")
        local subtitle_basename=$(basename "$subtitle_file")
        local video_name="${subtitle_basename%_en.srt}"

        # 检查是否存在对应的视频文件
        local has_video=false
        for fmt in "${VIDEO_FORMATS[@]}"; do
            if [ -f "${subtitle_dir}/${video_name}.${fmt}" ]; then
                has_video=true
                break
            fi
        done

        if [ "$has_video" = false ]; then
            SUBTITLE_MISSING_VIDEO+=("$subtitle_file")
        fi
    done

    echo ""
}

# ============================================
# 清理临时文件
# ============================================
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# ============================================
# 生成报告
# ============================================
generate_report() {
    {
        echo "================================================"
        echo "        课程视频综合检测报告"
        echo "        生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "================================================"
        echo ""

        # 问题文件统计
        echo "【问题文件统计】"
        echo ""

        if [ ${#EMPTY_FILES[@]} -gt 0 ]; then
            echo "❌ 空文件 (${#EMPTY_FILES[@]} 个):"
            for file in "${EMPTY_FILES[@]}"; do
                echo "  - $file"
            done
            echo ""
        fi

        if [ ${#DRM_FILES[@]} -gt 0 ]; then
            echo "🔒 DRM 保护/严重损坏 (${#DRM_FILES[@]} 个):"
            for file in "${DRM_FILES[@]}"; do
                echo "  - $file"
            done
            echo ""
        fi

        if [ ${#CORRUPTED_FILES[@]} -gt 0 ]; then
            echo "⚠️  损坏/下载不完整 (${#CORRUPTED_FILES[@]} 个):"
            for file in "${CORRUPTED_FILES[@]}"; do
                echo "  - $file"
            done
            echo ""
        fi

        if [ ${#VIDEO_MISSING_SUBTITLE[@]} -gt 0 ]; then
            echo "⚠️  视频缺字幕 (${#VIDEO_MISSING_SUBTITLE[@]} 个):"
            for file in "${VIDEO_MISSING_SUBTITLE[@]}"; do
                echo "  - $file"
            done
            echo ""
        fi

        if [ ${#SUBTITLE_MISSING_VIDEO[@]} -gt 0 ]; then
            echo "❌ 字幕缺对应视频 (${#SUBTITLE_MISSING_VIDEO[@]} 个):"
            for file in "${SUBTITLE_MISSING_VIDEO[@]}"; do
                echo "  - $file"
            done
            echo ""
        fi

        if [ ${#EMPTY_FILES[@]} -eq 0 ] && [ ${#DRM_FILES[@]} -eq 0 ] && \
           [ ${#CORRUPTED_FILES[@]} -eq 0 ] && [ ${#VIDEO_MISSING_SUBTITLE[@]} -eq 0 ] && \
           [ ${#SUBTITLE_MISSING_VIDEO[@]} -eq 0 ]; then
            echo "✅ 未发现问题文件"
            echo ""
        fi

        echo "================================================"
        echo ""

        # 课程统计
        echo "【课程统计】"
        echo ""

        # 按课程名称排序输出
        for course_name in $(echo "${!COURSE_VIDEO_COUNT[@]}" | tr ' ' '\n' | sort); do
            local video_count=${COURSE_VIDEO_COUNT[$course_name]}
            local total_seconds=${COURSE_TOTAL_SECONDS[$course_name]}
            # 用bash整数运算计算小时数（保留一位小数）
            local hours=$((total_seconds / 3600))
            local remainder=$((total_seconds % 3600))
            local decimal=$((remainder * 10 / 3600))
            local total_hours="${hours}.${decimal}"

            echo "📁 $course_name"
            echo "   可播放视频: $video_count 个"
            echo "   总时长: $total_hours hours"
            echo ""
        done

        echo "================================================"

    } | tee "$REPORT_FILE"
}

# ============================================
# 主检测流程
# ============================================
main() {
    # 设置清理陷阱
    trap cleanup EXIT

    echo "================================================"
    echo "   课程视频综合检测工具（并行优化版）"
    echo "================================================"
    echo ""

    check_dependencies
    check_environment

    echo -e "${BLUE}[开始扫描视频文件]${NC}"

    # 查找所有视频文件
    local video_files=()
    while IFS= read -r -d '' file; do
        video_files+=("$file")
    done < <(find . -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" -o -name "*.m4v" -o -name "*.wmv" -o -name "*.webm" -o -name "*.flv" -o -name "*.ts" \) -print0)

    local total_videos=${#video_files[@]}
    echo -e "${GREEN}找到 $total_videos 个视频文件${NC}"
    echo ""

    if [ $total_videos -eq 0 ]; then
        echo -e "${YELLOW}警告：未找到任何视频文件${NC}"
        echo ""
        read -p "按 Enter 键退出..." dummy
        exit 0
    fi

    # 并行处理视频
    process_videos_parallel "${video_files[@]}"

    # 汇总结果
    collect_results

    # 检查孤立字幕
    check_orphan_subtitles

    # 生成报告
    generate_report

    echo ""
    echo -e "${GREEN}报告已保存到: $REPORT_FILE${NC}"
    echo ""

    # 防止窗口闪退
    read -p "按 Enter 键退出..." dummy
}

# ============================================
# 执行主流程
# ============================================
main
