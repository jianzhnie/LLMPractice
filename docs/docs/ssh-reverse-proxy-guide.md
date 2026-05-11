# SSH 反向代理配置指南

通过 SSH 反向端口转发（Remote Forward），将远程服务器的流量转发到本地代理，实现远程服务器通过本地网络访问互联网。

---

## 原理图

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────┐
│   远程服务器     │ ──────> │   SSH 反向隧道    │ ──────> │  本地代理    │
│  (bms-ly-001)   │  :8080  │  (RemoteForward) │  :7897  │  (Clash等)  │
└─────────────────┘         └──────────────────┘         └─────────────┘
                                                                │
                                                                v
                                                        ┌─────────────┐
                                                        │   互联网     │
                                                        │  (Google)   │
                                                        └─────────────┘
```

---

## 配置步骤

### 1. 修改 SSH 配置文件

编辑 `~/.ssh/config`，在目标主机配置中添加 `RemoteForward`：

```ssh-config
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

**参数说明：**
- `RemoteForward <远程端口> <本地地址>:<本地端口>`
- `8080`：远程服务器上监听的端口（可自定义）
- `localhost:7897`：本地代理软件的监听地址和端口

### 2. 重新连接 SSH

断开现有连接，重新建立 SSH 连接以使配置生效：

```bash
ssh bms-ly-001
```

### 3. 验证反向转发是否生效

在**远程服务器**上执行：

```bash
netstat -tlnp | grep 8080
```

预期输出（显示端口正在监听）：
```
tcp    0    0 127.0.0.1:8080    0.0.0.0:*    LISTEN    xxx/sshd: root@
tcp6   0    0 ::1:8080          :::*         LISTEN    xxx/sshd: root@
```

---

## 使用方法

### 临时设置代理（当前会话有效）

在远程服务器上执行：

```bash
export http_proxy=http://localhost:8080
export https_proxy=http://localhost:8080
```

### 测试代理是否正常工作

```bash
# 方法 1: 使用 curl
curl -I https://www.google.com

# 方法 2: 使用 wget
wget --timeout=10 -q -O - https://www.google.com > /dev/null && echo "代理连接成功"

# 方法 3: 查看当前 IP 地址
curl -s ip.sb
curl -s cip.cc
```

### 永久设置代理（所有会话有效）

将代理配置添加到 shell 配置文件中：

**Bash 用户：**
```bash
echo 'export http_proxy=http://localhost:8080' >> ~/.bashrc
echo 'export https_proxy=http://localhost:8080' >> ~/.bashrc
source ~/.bashrc
```

**Zsh 用户：**
```bash
echo 'export http_proxy=http://localhost:8080' >> ~/.zshrc
echo 'export https_proxy=http://localhost:8080' >> ~/.zshrc
source ~/.zshrc
```

---

## 本地代理端口对照表

| 代理软件 | SOCKS5 端口 | HTTP 端口 |
|---------|------------|----------|
| Clash   | 7897       | 7890     |
| Clash Verge | 7897   | 7890     |
| V2RayN  | 10808      | -        |
| Shadowsocks | 1080   | -        |

**注意：** SSH 反向转发 SOCKS5 端口时，远程服务器上可能需要使用 HTTP 协议格式访问。

---

## 常见问题排查

### 问题 1：curl 报错 `setsockopt TCP_NODELAY: Invalid argument`

**原因：** curl 的 SOCKS5 协议兼容性问题

**解决：** 使用 HTTP 代理格式而非 SOCKS5

```bash
# 错误用法
export https_proxy=socks5://localhost:8080

# 正确用法
export https_proxy=http://localhost:8080
```

### 问题 2：端口未监听

**检查步骤：**

1. 确认 SSH 连接正常：
   ```bash
   ssh -O check bms-ly-001
   ```

2. 断开并重新连接 SSH：
   ```bash
   ssh -O exit bms-ly-001
   ssh bms-ly-001
   ```

3. 检查本地代理是否运行：
   ```bash
   # 在本地执行
   curl -x http://localhost:7897 -I https://www.google.com
   ```

### 问题 3：需要代理特定命令

使用 `proxychains`（推荐用于复杂场景）：

```bash
# 安装
yum install -y proxychains-ng    # CentOS/RHEL
apt-get install -y proxychains    # Ubuntu/Debian

# 配置
echo -e "[ProxyList]\nhttp 127.0.0.1 8080" > ~/.proxychains.conf

# 使用
proxychains curl https://www.google.com
proxychains git clone https://github.com/...
proxychains pip install xxx
```

### 问题 4：多个远程服务器配置

为每个服务器分配不同端口：

```ssh-config
Host server1
  HostName 10.0.0.1
  User root
  RemoteForward 8081 localhost:7897

Host server2
  HostName 10.0.0.2
  User root
  RemoteForward 8082 localhost:7897
```

远程服务器对应使用各自的端口：
```bash
# server1 上
export http_proxy=http://localhost:8081

# server2 上
export http_proxy=http://localhost:8082
```

---

## 安全注意事项

1. **绑定地址限制：** 默认只绑定到 `127.0.0.1`（本地回环），这是安全的。不要改为 `0.0.0.0`。

2. **GatewayPorts 设置：** 如需让远程服务器上的其他机器也能使用此代理，需要：
   - 服务器端 SSH 配置 `GatewayPorts yes`
   - 或使用 `-R 0.0.0.0:8080:localhost:7897`（命令行）

3. **连接中断：** SSH 断开后反向转发失效，建议使用 `autossh` 保持连接：
   ```bash
   autossh -M 0 -N -R 8080:localhost:7897 bms-ly-001
   ```

---

## 一键测试脚本（从本地执行）

在本地机器上直接测试远程服务器的 SSH 连接、反向代理端口监听和代理可用性：

```bash
# 测试单台服务器（以 bms1889 为例）
ssh <主机别名> "echo '=== 连接成功 ===' && \
  (netstat -tlnp 2>/dev/null | grep 8080 || ss -tlnp | grep 8080) && \
  curl -s --max-time 10 -x http://localhost:8080 https://www.google.com -o /dev/null -w '代理状态: HTTP %{http_code}\n'"
```

**批量测试多台服务器：**

```bash
#!/bin/bash
# 文件名: test_ssh_proxy.sh
# 用法: bash test_ssh_proxy.sh bms1889 bms1890 bms-ly-001

for host in "$@"; do
  echo "===== 测试 $host ====="
  ssh -o ConnectTimeout=10 "$host" \
    "echo '连接: 成功'; \
     netstat -tlnp 2>/dev/null | grep -q 8080 && echo '端口 8080: 已监听' || echo '端口 8080: 未监听'; \
     curl -s --max-time 10 -x http://localhost:8080 https://www.google.com -o /dev/null -w '代理访问: HTTP %{http_code}\n'" \
    2>/dev/null
  echo ""
done
```

**预期输出示例：**

```
===== 测试 bms1889 =====
连接: 成功
端口 8080: 已监听
代理访问: HTTP 302

===== 测试 bms1890 =====
连接: 成功
端口 8080: 已监听
代理访问: HTTP 302
```

> **说明：** Google 返回 `302` 表示代理正常工作（重定向到本地化站点）。如果返回 `000` 或超时，说明代理不通。

---

## 相关命令速查

| 命令 | 说明 |
|-----|------|
| `ssh -R 远程端口:本地地址:本地端口 主机` | 命令行方式建立反向转发 |
| `ssh -O check 主机` | 检查连接状态 |
| `ssh -O exit 主机` | 强制断开连接 |
| `netstat -tlnp \| grep 端口` | 检查端口监听状态 |
| `ss -tlnp` | 查看所有监听端口 |

---

## 参考

- [OpenSSH 文档 - TCP Forwarding](https://www.ssh.com/academy/ssh/tunneling/example#remote-forwarding)
- [SSH 端口转发详解](https://wangdoc.com/ssh/port-forwarding.html)
