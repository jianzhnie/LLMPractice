# SSH 免密登录配置指南

本文档记录通过 JumpMachine 跳板机免密登录 bms-ly-001 的完整配置过程。

## 当前环境配置

### SSH 配置文件 (`~/.ssh/config`)

```
Host JumpMachine
  HostName 10.16.201.50
  User pcl
  ServerAliveInterval 60
  ServerAliveCountMax 3

Host bms-ly-001
  HostName 10.16.201.229
  ProxyJump JumpMachine
  User root
  ServerAliveInterval 60
  ServerAliveCountMax 3
```

## 免密登录配置步骤

### 1. 检查现有 SSH 密钥

```bash
ls -la ~/.ssh/id_*.pub
```

输出示例：
```
-rw-r--r--@ 1 robin  staff  99 Apr 14 17:20 /Users/robin/.ssh/id_ed25519.pub
```

已有 `id_ed25519` 密钥，可直接使用。

### 2. 复制公钥到 JumpMachine (跳板机)

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub JumpMachine
```

按提示输入 `pcl` 用户的密码。

### 3. 复制公钥到目标机 bms-ly-001

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub bms-ly-001
```

按提示输入 `root` 用户的密码。

**说明**：由于配置了 `ProxyJump`，此命令会自动通过 JumpMachine 跳板机将公钥复制到目标机。

## 验证配置

配置完成后，测试免密登录：

```bash
ssh bms-ly-001
```

如果无需输入密码直接进入，则配置成功。

## 配置原理

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│  本地机器    │ ────▶ │ JumpMachine  │ ────▶ │ bms-ly-001  │
│ (SSH 客户端) │ SSH  │ (跳板机)      │ SSH  │  (目标机)    │
└─────────────┘      └──────────────┘      └─────────────┘
   持有私钥             持有公钥               持有公钥
```

- 本地机器通过 `ProxyJump` 配置，自动经 JumpMachine 转发到目标机
- 两台机器都需要保存本地机器的公钥，才能实现全程免密

## 常见问题

### 问题 1: 权限被拒绝 (Permission denied)

确认：
1. 公钥已正确复制到目标机的 `~/.ssh/authorized_keys`
2. 目标机 `.ssh` 目录权限为 `700`
3. 目标机 `authorized_keys` 文件权限为 `600`

### 问题 2: ProxyJump 不生效

检查 SSH 版本：
```bash
ssh -V
```

OpenSSH 7.3+ 才原生支持 `ProxyJump`，旧版本需使用 `ProxyCommand`：

```
Host bms-ly-001
  HostName 10.16.201.229
  ProxyCommand ssh -W %h:%p JumpMachine
  User root
```

## 参考

- [OpenSSH ProxyJump Documentation](https://man.openbsd.org/ssh_config.5#ProxyJump)
