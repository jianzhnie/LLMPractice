# 在远程 Linux 服务器上安装 Claude Code（使用代理）

当远程服务器无法直接访问外网时，可以通过 SSH 反向代理，利用本地网络安装 Claude Code。

---

## 前提条件

### 1. 已配置 SSH 反向代理

确保本地 SSH 配置已添加 `RemoteForward`，将远程服务器的端口转发到本地代理：

```ssh-config
# ~/.ssh/config
Host bms-ly-001
  HostName 10.16.201.229
  ProxyJump JumpMachine
  User root
  ForwardAgent yes
  ServerAliveInterval 60
  ServerAliveCountMax 3
  # 反向代理: 将远程服务器的 8080 端口转发到本地的 7897 代理端口
  RemoteForward 8080 localhost:7897
```

### 2. 确认反向代理生效

连接 SSH 后，在远程服务器上验证：

```bash
netstat -tlnp | grep 8080
```

预期输出：
```
tcp    0    0 127.0.0.1:8080    0.0.0.0:*    LISTEN    xxx/sshd: root@
tcp6   0    0 ::1:8080          :::*         LISTEN    xxx/sshd: root@
```

---

## 安装方法

### 方法一：官方安装脚本（推荐）

#### 步骤 1：设置代理环境变量

```bash
export http_proxy=http://localhost:8080
export https_proxy=http://localhost:8080
```

#### 步骤 2：使用代理下载并安装

```bash
curl -fsSL -x http://localhost:8080 https://claude.ai/install.sh | bash
```

或者分步执行（便于排查）：

```bash
# 下载安装脚本
curl -x http://localhost:8080 -o /tmp/install.sh https://claude.ai/install.sh

# 执行安装
bash /tmp/install.sh
```

#### 步骤 3：添加 PATH

```bash
# 临时生效
export PATH="$HOME/.local/bin:$PATH"

# 永久生效
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 步骤 4：验证安装

```bash
claude --version
```

---

### 方法二：使用 npm 安装

如果官方脚本失败，可以使用 npm 安装。

#### 步骤 1：安装 Node.js（使用代理）

```bash
# 设置代理
export http_proxy=http://localhost:8080
export https_proxy=http://localhost:8080

# 安装 nvm
curl -x http://localhost:8080 -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc

# 安装 Node.js 20
nvm install 20
nvm use 20
```

#### 步骤 2：配置 npm 代理

```bash
npm config set proxy http://localhost:8080
npm config set https-proxy http://localhost:8080
```

#### 步骤 3：安装 Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

---

### 方法三：手动下载安装

如果 curl/npm 都无法使用，可以本地下载后上传到服务器。

#### 步骤 1：本地下载安装包

在**本地机器**上执行：

```bash
# 下载 npm 包
npm pack @anthropic-ai/claude-code

# 或者从 GitHub 下载
curl -L -o claude-code.tgz https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-latest.tgz
```

#### 步骤 2：上传到远程服务器

```bash
scp claude-code.tgz bms-ly-001:/tmp/
```

#### 步骤 3：在远程服务器上解压安装

```bash
ssh bms-ly-001

cd /tmp
tar -xzf claude-code.tgz
cd package
npm install
npm run build

# 创建软链接
sudo ln -s "$(pwd)/dist/cli.js" /usr/local/bin/claude
# 或安装到用户目录
mkdir -p ~/.local/bin
ln -s "$(pwd)/dist/cli.js" ~/.local/bin/claude
```

---

## 常见问题

### 问题 1：SSL 连接错误

**错误信息：**
```
curl: (35) OpenSSL SSL_connect: SSL_ERROR_SYSCALL in connection to downloads.claude.ai:443
```

**原因：** 远程服务器无法直接访问外网，SSL 握手失败。

**解决：** 确保使用 `-x` 参数指定代理：

```bash
curl -x http://localhost:8080 https://claude.ai/install.sh
```

### 问题 2：命令未找到 (command not found)

**原因：** 安装路径不在 PATH 中。

**解决：**

```bash
# 查找安装位置
which claude || find ~ -name "claude" -type f 2>/dev/null

# 添加到 PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### 问题 3：Node.js 版本过低

**错误信息：**
```
error: @anthropic-ai/claude-code@x.x.x: The engine "node" is incompatible with this module
```

**解决：** 使用 nvm 安装 Node.js 18+：

```bash
nvm install 20
nvm use 20
```

### 问题 4：npm 安装速度慢

**解决：** 配置 npm 使用国内镜像（如果代理速度不理想）

```bash
# 淘宝镜像
npm config set registry https://registry.npmmirror.com

# 或腾讯镜像
npm config set registry https://mirrors.cloud.tencent.com/npm/
```

### 问题 5：Claude Code 启动后无法连接 API

**原因：** Claude Code 运行时也需要访问 Anthropic API。

**解决：** 启动时指定代理：

```bash
# 设置代理环境变量后启动
export http_proxy=http://localhost:8080
export https_proxy=http://localhost:8080
claude
```

或者在项目目录创建 `.clauderc` 配置代理（Claude Code 会自动读取）。

---

## 使用 Claude Code

### 启动前准备

```bash
# 1. 设置 API 密钥
export ANTHROPIC_API_KEY="sk-..."

# 2. 设置代理（如果需要）
export http_proxy=http://localhost:8080
export https_proxy=http://localhost:8080

# 3. 进入项目目录（必须是 Git 仓库）
cd /path/to/your/project

# 4. 启动
claude
```

### 常用命令

```bash
# 查看帮助
claude --help

# 在指定目录启动
claude /path/to/project

# 使用特定 API 密钥
ANTHROPIC_API_KEY=sk-... claude
```

---

## 持久化代理配置

为避免每次手动设置代理，可以创建启动脚本：

```bash
# 创建启动脚本
cat > ~/claude-start.sh << 'EOF'
#!/bin/bash
export http_proxy=http://localhost:8080
export https_proxy=http://localhost:8080
export ANTHROPIC_API_KEY="your-api-key-here"
export PATH="$HOME/.local/bin:$PATH"
claude "$@"
EOF

chmod +x ~/claude-start.sh

# 使用
~/claude-start.sh
```

---

## 卸载方法

```bash
# 如果是官方脚本安装
rm -rf ~/.local/share/claude
rm ~/.local/bin/claude

# 如果是 npm 安装
npm uninstall -g @anthropic-ai/claude-code
```

---

## 参考

- [Claude Code 官方文档](https://docs.anthropic.com/en/docs/claude-code/overview)
- [SSH 反向代理配置指南](./ssh-reverse-proxy-guide.md)
