#!/bin/bash
################################################################################
# zombie_cleaner.sh - 僵尸进程自动检测与清理脚本
# 功能：检测僵尸进程数量，超过阈值时终止其父进程并记录日志
# 要求：需 root 权限执行
################################################################################

# ========== 配置参数 ==========
ZOMBIE_THRESHOLD=5                 # 僵尸进程阈值
LOG_FILE="/var/log/zombie_cleaner.log"
LOCK_FILE="/var/run/zombie_cleaner.lock"
SAFE_PIDS="1"                      # 保护 PID（避免杀死 systemd/init）
SAFE_PROCESSES="systemd|kthreadd|sshd|cron|systemd-journald"  # 保护进程名

# 必需命令列表
REQUIRED_COMMANDS="ps awk grep kill logger tee date tr"

# ========== 日志函数 ==========
log() {
    local level=$1
    local msg=$2
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
    logger -t "zombie_cleaner" "[$level] $msg" 2>/dev/null
}

# ========== 依赖检查 ==========
check_dependencies() {
    local missing=()
    
    for cmd in $REQUIRED_COMMANDS; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "错误：缺少必需命令: ${missing[*]}"
        echo "请安装相应的软件包后重试"
        exit 1
    fi
}

# ========== 兼容性检查 ==========
check_compatibility() {
    # 检查 Bash 版本 (需要 4.0+ 以支持关联数组)
    local bash_major="${BASH_VERSION%%.*}"
    if [[ $bash_major -lt 4 ]]; then
        echo "错误：Bash 版本过低 (当前: $BASH_VERSION)"
        echo "此脚本需要 Bash 4.0 或更高版本"
        exit 1
    fi
    
    # 检查操作系统
    if [[ ! -f /proc/version ]]; then
        echo "警告：无法检测操作系统信息"
    fi
}

# ========== 权限检查 ==========
if [[ $EUID -ne 0 ]]; then
    echo "错误：此脚本需要 root 权限执行！"
    exit 1
fi

# ========== 锁文件机制（防止并发执行）==========
if [[ -f "$LOCK_FILE" ]]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        log "WARN" "检测到锁文件，PID $LOCK_PID 可能正在运行，退出"
        exit 1
    else
        log "INFO" "清理过期锁文件"
        rm -f "$LOCK_FILE"
    fi
fi
echo $$ > "$LOCK_FILE"

# ========== 清理函数（脚本退出时移除锁文件）==========
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT INT TERM

# ========== 检测僵尸进程 ==========
detect_zombies() {
    # 获取僵尸进程列表：PID, PPID, COMMAND
    local zombies
    local count
    zombies=$(ps -eo pid,ppid,stat,comm | awk '$3 ~ /^Z/ {print $1":"$2":"$4}')
    count=$(echo "$zombies" | grep -c '^[0-9]' || echo 0)

    # 输出格式：第一行数量，后续为僵尸进程列表
    echo "$count"
    echo "$zombies"
}

# ========== 主逻辑 ==========
main() {
    log "INFO" "========== 僵尸进程检测开始 =========="
    
    # 检测僵尸进程
    local detect_output
    local zombie_count
    local zombie_list
    detect_output=$(detect_zombies)
    zombie_count=$(echo "$detect_output" | head -1)
    zombie_list=$(echo "$detect_output" | tail -n +2)
    log "INFO" "当前僵尸进程数量: $zombie_count"
    
    if [[ $zombie_count -le $ZOMBIE_THRESHOLD ]]; then
        log "INFO" "僵尸进程数量未超过阈值($ZOMBIE_THRESHOLD)，无需处理"
        exit 0
    fi
    
    log "ALERT" "僵尸进程数量($zombie_count) 超过阈值($ZOMBIE_THRESHOLD)！"
    
    # 提取唯一父进程 PID 列表
    declare -A parent_pids
    while IFS=: read -r zpid ppid _; do
        [[ -z "$ppid" || "$ppid" == "0" ]] && continue
        
        # 跳过保护进程
        if [[ " $SAFE_PIDS " == *" $ppid "* ]]; then
            log "SKIP" "跳过保护 PID $ppid (僵尸: $zpid)"
            continue
        fi
        
        # 检查父进程名是否在保护列表
        parent_name=$(ps -p "$ppid" -o comm= 2>/dev/null | tr -d ' ')
        if echo "$parent_name" | grep -Eq "$SAFE_PROCESSES"; then
            log "SKIP" "跳过保护进程 $parent_name (PID $ppid, 僵尸: $zpid)"
            continue
        fi
        
        parent_pids["$ppid"]="$parent_name"
    done < <(echo "$zombie_list")
    
    if [[ ${#parent_pids[@]} -eq 0 ]]; then
        log "WARN" "未找到可清理的父进程（可能均为受保护进程）"
        exit 0
    fi
    
    log "INFO" "发现 ${#parent_pids[@]} 个需处理的父进程："
    for ppid in "${!parent_pids[@]}"; do
        log "INFO" "  - PID $ppid (进程名: ${parent_pids[$ppid]})"
    done
    
    # 终止父进程
    for ppid in "${!parent_pids[@]}"; do
        parent_name="${parent_pids[$ppid]}"
        
        log "ACTION" "尝试终止父进程 PID $ppid ($parent_name)..."
        
        # 先发送 SIGTERM（优雅终止）
        if kill -TERM "$ppid" 2>/dev/null; then
            log "INFO" "已发送 SIGTERM 到 PID $ppid"
            
            # 等待 5 秒观察是否退出
            for _ in {1..5}; do
                if ! kill -0 "$ppid" 2>/dev/null; then
                    log "SUCCESS" "父进程 PID $ppid 已退出，其僵尸进程将被 systemd 回收"
                    continue 2
                fi
                sleep 1
            done
            
            # 5 秒后仍未退出，发送 SIGKILL
            log "WARN" "PID $ppid 未响应 SIGTERM，发送 SIGKILL..."
            if kill -KILL "$ppid" 2>/dev/null; then
                log "SUCCESS" "已强制终止 PID $ppid"
            else
                log "ERROR" "无法终止 PID $ppid（可能权限不足或进程已消失）"
            fi
        else
            log "ERROR" "无法向 PID $ppid 发送信号（进程可能已退出）"
        fi
    done
    
    # 验证清理效果
    sleep 2
    local detect_output2
    local new_count
    detect_output2=$(detect_zombies)
    new_count=$(echo "$detect_output2" | head -1)
    log "INFO" "清理后僵尸进程数量: $new_count"
    
    if [[ $new_count -lt $zombie_count ]]; then
        log "SUCCESS" "成功减少 $(($zombie_count - $new_count)) 个僵尸进程"
    else
        log "WARN" "僵尸进程数量未减少，可能需要人工排查父进程问题"
    fi
    
    log "INFO" "========== 僵尸进程检测结束 =========="
}

# ========== 执行主逻辑 ==========
check_dependencies
check_compatibility
main

exit 0