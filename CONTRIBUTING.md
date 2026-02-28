# 贡献指南

感谢你考虑为 Zombie Cleaner 做出贡献！

## 如何贡献

### 报告 Bug

如果你发现了 bug，请通过 [GitHub Issues](https://github.com/ywmy210/zombie_cleaner/issues) 提交，包含以下信息：

- 操作系统版本
- Bash 版本 (`bash --version`)
- 问题描述和复现步骤
- 相关日志输出
- 期望行为和实际行为

### 提出新功能

欢迎提出新功能建议！请在 Issue 中详细描述：

- 功能用途和使用场景
- 预期的行为方式
- 可能的实现思路（可选）

### 提交代码

1. **Fork 仓库**

   点击右上角 Fork 按钮

2. **克隆你的 Fork**
   ```bash
   git clone https://github.com/你的用户名/zombie_cleaner.git
   cd zombie_cleaner
   ```

3. **创建分支**
   ```bash
   git checkout -b feature/你的功能名称
   # 或
   git checkout -b fix/你要修复的问题
   ```

4. **进行修改**

   - 遵循现有的代码风格
   - 添加必要的注释
   - 保持脚本简洁

5. **测试修改**
   ```bash
   # 语法检查
   bash -n zombie_cleaner.sh

   # ShellCheck 检查（推荐安装）
   shellcheck zombie_cleaner.sh
   ```

6. **提交更改**
   ```bash
   git add .
   git commit -m "简洁的提交说明"
   ```

7. **推送到 Fork**
   ```bash
   git push origin feature/你的功能名称
   ```

8. **创建 Pull Request**

   在 GitHub 上创建 Pull Request，描述你的修改内容和目的。

## 代码规范

### Shell 脚本风格

- 使用 4 空格缩进
- 变量名使用大写（常量）或小写（局部变量）
- 函数名使用小写和下划线
- 添加有意义的注释

### 示例

```bash
# 配置参数（常量大写）
CONFIG_FILE="/etc/config.conf"

# 函数定义
do_something() {
    local param=$1
    # 处理逻辑
}
```

## 行为准则

- 尊重所有贡献者
- 保持专业和友好的交流
- 接受建设性批评

## 许可证

提交代码即表示你同意你的贡献将按照 [MIT License](LICENSE) 授权。
