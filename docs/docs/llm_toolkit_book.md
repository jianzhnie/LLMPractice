# 大语言模型（LLM）训练与运维技术指南

本文档为基于**昇腾（Ascend）NPU**平台的大语言模型训练与部署提供完整技术指导。按照工作流阶段组织为 7 个模块：硬件环境 → 软件配置 → 存储管理 → 代码资源 → 分布式训练 → 实验追踪 → 集群运维。

---

## 一、昇腾硬件环境

本模块介绍昇腾 AI 处理器的驱动安装与设备检查，是所有后续操作的基础。

### 1.1 CANN 安装与配置

CANN（Compute Architecture for Neural Networks）是华为昇腾 AI 软件栈的核心组件，包含算子库、运行时和编译器工具链。

**安装 Toolkit 与算子包：**

```bash
# 安装 CANN Toolkit
bash Ascend-cann-toolkit_8.2.RC1_linux-aarch64.run --install
bash Atlas-A3-cann-kernels_8.2.RC1_linux-aarch64.run --install

# 安装 NNAL 推理加速库
bash Ascend-cann-nnal_8.2.RC1_linux-aarch64.run --install
```

**加载环境变量：**

```bash
install_path=/usr/local/Ascend
source $install_path/ascend-toolkit/set_env.sh
source $install_path/nnal/atb/set_env.sh
```

> **说明**：`set_env.sh` 设置编译器、库路径和运行时依赖。建议将上述 `source` 命令写入 `~/.bashrc` 以实现开机自动加载。

### 1.2 NPU 设备状态检查

使用 `npu-smi` 工具查看设备运行状态：

```bash
npu-smi info
```

该命令输出设备健康状态、显存使用、温度及驱动版本等信息。建议在启动训练前执行以确认硬件可用性。

---

## 二、软件环境配置

本模块涵盖 Python 包管理、Conda 环境管理和深度学习框架安装。

### 2.1 Python 包管理

#### 全局镜像源配置

为加速 Python 包下载，推荐使用国内镜像源。以下为全局配置方式：

**阿里源（推荐）：**

```bash
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple
pip config set install.trusted-host mirrors.aliyun.com
```

**清华源：**

```bash
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple/
pip config set install.trusted-host pypi.tuna.tsinghua.edu.cn
```

**清除额外索引源：**

```bash
pip config unset global.extra-index-url
```

#### 单次使用镜像源

若不想全局修改，可在安装命令中临时指定：

```bash
pip install -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com <package>
```

### 2.2 Conda 环境管理

#### 克隆环境（实现"重命名"）

Conda 不支持直接重命名环境，可通过**克隆 + 删除**间接实现：

```bash
# 1. 克隆
conda create --name new_env_name --clone old_env_name

# 或显式指定路径
conda create --prefix /root/llmdir/miniconda3/envs/rlhf --clone /root/llm_workspace/miniconda3/envs/openRLHF

# 2. 验证
conda info --envs

# 3. 确认无误后删除原环境
conda remove --name old_env_name --all
```

> **注意**：克隆会复制所有包与依赖，耗时较长。删除前务必验证新环境功能完整性。

### 2.3 PyTorch 与 Torch-NPU 安装

安装与 CANN 版本兼容的 `torch` 与 `torch-npu`：

```bash
pip install numpy==1.26.0
pip install torch==2.5.1 && pip install torch-npu==2.5.1rc1
```

> **注意**：`torch-npu` 是华为针对 Ascend 芯片优化的 PyTorch 后端扩展，必须与 `torch` 版本严格匹配。安装前请确认 CANN 已正确加载。

---

## 三、存储管理

本模块介绍集群环境下的存储挂载与权限配置。

### 3.1 数据存储挂载

挂载分布式持久化存储（DPC）至本地目录：

```bash
mount -t dpc /llmdir llmdir
```

请确保挂载路径具备读写权限，并在训练任务中正确引用该路径以实现数据共享。

### 3.2 文件权限配置

修改 Miniconda 安装目录权限，确保当前用户可正常访问：

```bash
chown -R HwHiAiUser:users miniconda3/
chmod -R 755 miniconda3/
```

> **说明**：`HwHiAiUser` 为昇腾平台默认用户，若使用其他账户请相应调整。

---

## 四、代码与资源管理

本模块涵盖 Git 配置、代码仓库管理、模型与数据集下载。

### 4.1 Git SSH Key 配置

#### 生成 SSH Key

```bash
# 推荐：Ed25519 算法
ssh-keygen -t ed25519 -C "your_email@example.com"

# 备选：RSA 算法（旧系统）
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

#### 启动 Agent 并添加 Key

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

#### 添加到 GitHub

复制公钥（macOS: `pbcopy < ~/.ssh/id_ed25519.pub`，Linux: `xclip -selection clipboard < ~/.ssh/id_ed25519.pub`），然后在 GitHub → **Settings** → **SSH and GPG keys** → **New SSH key** 中粘贴。

#### 测试连接

```bash
ssh -T git@github.com
```

### 4.2 代码仓库获取

#### 使用 GitHub 加速代理

推荐使用代理服务加速 GitHub 资源下载：

| 原始链接 | 代理链接 |
|----------|----------|
| `https://github.com/volcengine/verl.git` | `https://gh-proxy.com/https://github.com/volcengine/verl.git` |

#### 常用仓库克隆

```bash
git clone https://gh-proxy.com/https://github.com/huggingface/transformers.git
git clone https://gh-proxy.com/https://github.com/volcengine/verl.git
git clone https://gh-proxy.com/https://github.com/wangshuai09/vllm.git
git clone https://gh-proxy.com/https://gitee.com/ascend/MindSpeed.git
git clone https://gh-proxy.com/https://github.com/NVIDIA/Megatron-LM.git
git clone https://gh-proxy.com/https://github.com/huggingface/trl.git
git clone https://gh-proxy.com/https://github.com/hkust-nlp/simpleRL-reason.git
git clone https://gh-proxy.com/https://github.com/as12138/verl.git verl-npu
```

### 4.3 合并外部 Pull Request

#### Web 界面操作

1. 在仓库的 **Pull Requests** 标签页定位目标 PR
2. 确认 CI 通过且无冲突
3. 选择合并策略：
   - **Create a merge commit**（推荐）：保留完整历史
   - **Squash and merge**：压缩为单个提交
   - **Rebase and merge**：保持线性历史
4. 点击 **Confirm merge** 完成操作

#### 命令行合并

```bash
git clone <主仓库URL> && cd <仓库目录>
git remote add <贡献者名> <PR来源仓库URL>
git fetch <贡献者名> <PR分支名>
git checkout main && git merge <PR分支名>
# 如有冲突，手动解决后 git add . && git commit
git push origin main
```

### 4.4 同步官方上游代码

当 Fork 并修改了官方仓库后，需定期同步上游更新。

```bash
# 1. 添加上游仓库
git remote add online https://github.com/OpenRLHF/OpenRLHF.git

# 2. 获取最新代码
git fetch origin && git fetch online

# 3. 创建合并分支并合并
git checkout -b temp-merge-branch origin/main
git merge online/main
# 如有冲突：手动解决 → git add . → git commit -m "Merge upstream/main"

# 4. 推送到个人仓库
git push origin temp-merge-branch:main
```

验证合并结果：`git log --oneline --graph --all`

> **注意**：若无推送权限，需通过 PR 提交合并变更。其他平台差异：GitLab 称为 Merge Request (MR)，Bitbucket 操作类似。

### 4.5 模型与数据集下载

使用国内镜像站 [hf-mirror.com](https://hf-mirror.com) 加速下载。

#### 配置镜像源

```bash
pip install -U huggingface_hub
export HF_ENDPOINT="https://hf-mirror.com"
export HF_HUB_ENABLE_HF_TRANSFER=0
```

#### 下载模型权重

```bash
huggingface-cli download Qwen/Qwen2.5-0.5B --local-dir /root/llmdir/hfhub/models/Qwen/Qwen2.5-0.5B
huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct --local-dir /root/llmdir/hfhub/models/Qwen/Qwen2.5-0.5B-Instruct
```

#### 下载数据集

```bash
huggingface-cli download --repo-type dataset openai/gsm8k --local-dir /root/llmdir/hfhub/datasets/openai/gsm8k
huggingface-cli download --repo-type dataset BytedTsinghua-SIA/DAPO-Math-17k --local-dir /root/llmdir/hfhub/datasets/BytedTsinghua-SIA/DAPO-Math-17k
```

#### 批量下载脚本

```bash
#!/bin/bash
export HF_ENDPOINT="https://hf-mirror.com"
export HF_HUB_ENABLE_HF_TRANSFER=0

# 模型
huggingface-cli download Qwen/Qwen2.5-0.5B --local-dir /root/llmdir/hfhub/models/Qwen/Qwen2.5-0.5B
huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct --local-dir /root/llmdir/hfhub/models/Qwen/Qwen2.5-0.5B-Instruct

# 数据集
huggingface-cli download --repo-type dataset openai/gsm8k --local-dir /root/llmdir/hfhub/datasets/openai/gsm8k
huggingface-cli download --repo-type dataset BytedTsinghua-SIA/DAPO-Math-17k --local-dir /root/llmdir/hfhub/datasets/BytedTsinghua-SIA/DAPO-Math-17k
```

---

## 五、分布式训练

本模块介绍多节点分布式训练的通信验证。昇腾 NPU 使用 **HCCL**（Huawei Collective Communication Library）作为通信后端，功能对标 NVIDIA GPU 的 **NCCL**。

### 5.1 HCCL 通信测试（All-Reduce）

#### 测试脚本：`allreduce_demo.py`

```python
import torch
import torch_npu
from torch_npu.contrib import transfer_to_npu
import torch.distributed as dist
import os


def main():
    local_rank = int(os.environ["LOCAL_RANK"])
    world_size = int(os.environ["WORLD_SIZE"])
    rank = int(os.environ["RANK"])

    torch.npu.set_device(local_rank)
    device = torch.device(f"npu:{torch.npu.current_device()}")

    dist.init_process_group(backend="hccl")

    tensor = torch.ones(2, 2, dtype=torch.float16, device=device) * (rank + 1)

    print(f'Rank {rank} 初始张量:\n{tensor}')
    print(f'数据类型: {tensor.dtype}, 设备: {tensor.device}')

    dist.all_reduce(tensor, op=dist.ReduceOp.SUM)

    print(f'Rank {rank} All-Reduce 结果:\n{tensor}')

    dist.destroy_process_group()


if __name__ == "__main__":
    main()
```

#### 启动脚本：`run.sh`

```bash
#!/bin/bash
export ASCEND_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

torchrun \
    --nproc_per_node=8 \
    --nnodes=1 \
    --node_rank=0 \
    --master_addr="localhost" \
    --master_port=29500 \
    allreduce_demo.py
```

```bash
bash run.sh
```

预期输出：每个 Rank 的输出张量值为 $ \sum_{i=0}^{7}(i+1) = 36 $，验证 HCCL 通信正常。

---

## 六、实验追踪

本模块介绍使用 Weights & Biases (Wandb) 进行实验管理与日志同步。

### 6.1 Wandb 登录

```bash
wandb login
```

执行后输入 API Key。登录成功后可在训练脚本中通过 `wandb.init(project="your_project")` 记录指标。

### 6.2 Wandb 日志同步

#### 在线模式

使用 `wandb.init()` 且网络正常时，日志自动上传至云端。

#### 离线模式

以 `WANDB_MODE=offline` 运行时，日志保存在本地（`./wandb/run-<RUN_ID>/`），需手动同步：

```bash
# 同步当前目录日志
wandb sync wandb/

# 同步特定运行
wandb sync wandb/run-<RUN_ID>/

# 同步所有未上传记录
wandb sync --sync-all

# 清理缓存后同步
wandb sync --clean
wandb sync --include-offline

# 指定项目上传
WANDB_PROJECT="your_project" wandb sync wandb/
```

### 6.3 同步 TensorBoard 日志

#### 命令行同步

```bash
wandb sync --sync-tensorboard <tensorboard_log_dir>
```

自动解析 `.tfevents` 文件并上传至 W&B。

#### Python 代码集成

方式一：自动监听 TensorBoard 目录：

```python
import wandb
wandb.init(project="my_project", sync_tensorboard=True)
```

方式二：手动指定目录：

```python
import wandb
wandb.init(project="my_project")
wandb.tensorboard.patch(root_logdir="logs/")
```

---

## 七、集群运维

本模块提供集群日常运维的常用命令速查。

### 7.1 常用运维命令速查

| 场景 | 命令 |
|------|------|
| 后台运行任务 | `nohup sh script.sh > output.log 2>&1 &` |
| 查看后台进程 | `ps aux \| grep <关键词>` |
| 终止 Python 进程 | `ps aux \| grep python \| awk '{print $2}' \| xargs kill -9` |
| 清理 Torch 缓存 | `rm -rf /root/.cache/torch_extensions/` |

> **警告**：`kill -9` 强制终止进程，可能导致数据丢失，请谨慎使用。

### 7.2 常见问题排查

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| `wandb sync` 无响应 | 网络不通、日志损坏、已同步 | 检查网络，使用 `--clean` 清理缓存 |
| 无法访问 `hf-mirror.com` | 镜像站失效或网络限制 | 更换镜像源或配置代理 |
| NPU 设备未识别 | 驱动未安装或环境未加载 | 检查 `npu-smi` 输出，确认 CANN 配置 |
| `torch-npu` 导入失败 | torch/torch-npu 版本不匹配 | 确保两者版本号一致 |
| HCCL 通信超时 | 节点间网络不通或端口未开放 | 检查防火墙，确认 `ASCEND_VISIBLE_DEVICES` 设置 |
