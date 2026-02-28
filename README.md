# Zombie Cleaner - 僵尸进程自动检测与清理脚本

[![Test](https://github.com/ywmy210/zombie_cleaner/actions/workflows/test.yml/badge.svg)](https://github.com/ywmy210/zombie_cleaner/actions/workflows/test.yml)
[![Release](https://github.com/ywmy210/zombie_cleaner/actions/workflows/release.yml/badge.svg)](https://github.com/ywmy210/zombie_cleaner/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![GitHub release](https://img.shields.io/github/release/ywmy210/zombie_cleaner.svg)](https://github.com/ywmy210/zombie_cleaner/releases)

一个用于 Linux 系统的僵尸进程自动检测与清理工具。当僵尸进程数量超过设定阈值时，自动终止其父进程以清理僵尸进程。

## 功能特性

- **自动检测**：实时检测系统中的僵尸进程数量
- **阈值触发**：仅在僵尸进程数量超过设定阈值时执行清理
- **安全保护**：内置保护机制，避免终止关键系统进程
- **优雅终止**：先尝试 SIGTERM，无响应时再使用 SIGKILL
- **并发控制**：使用锁文件机制防止脚本重复执行
- **日志记录**：详细记录操作日志，支持文件日志和系统日志

## 使用要求

- Linux 操作系统
- **Root 权限**（必需）

## 安装

```bash
# 方法一：直接下载最新版本
curl -O https://raw.githubusercontent.com/ywmy210/zombie_cleaner/main/zombie_cleaner.sh
chmod +x zombie_cleaner.sh

# 方法二：克隆仓库
git clone https://github.com/ywmy210/zombie_cleaner.git
cd zombie_cleaner
chmod +x zombie_cleaner.sh
```

## 使用方法

```bash
# 直接运行（需要 root 权限）
sudo ./zombie_cleaner.sh
```

### 配合 Cron 定时执行

```bash
# 编辑 crontab
sudo crontab -e

# 每 10 分钟检查一次
*/10 * * * * /path/to/zombie_cleaner.sh

# 每小时检查一次
0 * * * * /path/to/zombie_cleaner.sh
```

## 配置参数

脚本顶部的配置参数可根据需要修改：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `ZOMBIE_THRESHOLD` | 5 | 僵尸进程阈值，超过此数量触发清理 |
| `LOG_FILE` | `/var/log/zombie_cleaner.log` | 日志文件路径 |
| `LOCK_FILE` | `/var/run/zombie_cleaner.lock` | 锁文件路径 |
| `SAFE_PIDS` | 1 | 保护的 PID 列表（如 init 进程） |
| `SAFE_PROCESSES` | systemd,kthreadd,sshd,cron... | 保护的进程名称列表 |

## 日志说明

日志输出格式：`[时间戳] [级别] 消息`

日志级别：
- `INFO` - 常规信息
- `WARN` - 警告信息
- `ALERT` - 超阈值警报
- `ACTION` - 执行操作
- `SUCCESS` - 操作成功
- `SKIP` - 跳过保护进程
- `ERROR` - 错误信息

查看日志：
```bash
# 查看最新日志
tail -f /var/log/zombie_cleaner.log

# 或通过系统日志查看
journalctl -t zombie_cleaner
```

## 工作原理

1. 检测系统中状态为 `Z`（zombie）的进程
2. 统计僵尸进程数量，与阈值比较
3. 若超过阈值，提取僵尸进程的父进程 PID
4. 过滤受保护的系统进程
5. 依次向父进程发送终止信号
6. 验证清理效果并记录结果

## 安全机制

- **保护关键进程**：不会终止 systemd、sshd、cron 等关键服务
- **优雅终止**：优先发送 SIGTERM，给予进程清理资源的机会
- **锁文件机制**：防止脚本并发执行造成冲突

## 注意事项

1. 僵尸进程本身无法被直接杀死，必须终止其父进程
2. 父进程终止后，僵尸进程会被 init/systemd 自动回收
3. 建议先排查僵尸进程产生的根本原因，而非仅依赖此脚本
4. 频繁产生僵尸进程通常意味着程序存在 bug，应修复源程序

## 常见问题

**Q: 为什么僵尸进程数量没有减少？**

A: 可能原因：
- 僵尸进程的父进程在保护列表中
- 父进程无法被终止（权限不足或特殊情况）
- 需要人工排查父进程存在的问题

**Q: 如何查看僵尸进程详情？**

```bash
# 查看僵尸进程
ps aux | awk '$8 ~ /Z/'

# 或使用
ps -eo pid,ppid,stat,cmd | grep '^Z'
```

## 目录结构

```
zombie_cleaner/
├── .github/
│   ├── CODEOWNERS              # 代码所有者配置
│   ├── PULL_REQUEST_TEMPLATE.md # PR 模板
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md       # Bug 报告模板
│   │   └── feature_request.md  # 功能请求模板
│   └── workflows/
│       ├── test.yml            # 自动测试工作流
│       └── release.yml         # 版本发布工作流
├── .gitignore                  # Git 忽略文件
├── CONTRIBUTING.md             # 贡献指南
├── LICENSE                     # MIT 许可证
├── README.md                   # 项目说明
├── SECURITY.md                 # 安全策略
└── zombie_cleaner.sh           # 主脚本
```

## License

MIT License
