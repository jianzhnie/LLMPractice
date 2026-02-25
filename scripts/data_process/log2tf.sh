#!/bin/bash

# PROJECT DIR
PROJECT_DIR=/Users/jianzhengnie/work_dir/chatgpt/LLMPractice

# 日志文件路径 (请根据实际情况修改)
LOG_PATH="$PROJECT_DIR/work_dir/kimi_train.log"

# TensorBoard 日志输出目录
SAVE_DIR="$PROJECT_DIR/work_dir/tf_logs"

# 输出文件前缀
Prefix="random_ckpt"

# 1. 解析 SFT (Supervised Fine-Tuning) 日志
# python3 llmpractice/data_process/log2tf.py \
#     --log-path "$LOG_PATH" \
#     --save-log-dir "$SAVE_DIR/sft_$Prefix" \
#     --stage sft \
#     --tag-prefix "train/"

# 2. 解析 DPO (Direct Preference Optimization) 日志
# python3 llmpractice/data_process/log2tf.py \
#     --log-path "$LOG_PATH" \
#     --save-log-dir "$SAVE_DIR/dpo_$Prefix" \
#     --stage dpo \
#     --tag-prefix "train/"

# 3. 解析 Pretrain (预训练) 日志
# 示例：解析名为 pretrain.log 的文件
echo "Processing Pretrain Log..."

python $PROJECT_DIR/llmpractice/data_process/log2tf.py \
    --log-path "$LOG_PATH" \
    --save-log-dir "$SAVE_DIR/$Prefix" \
    --stage pretrain \
    --tag-prefix "pretrain/"

echo "Done! Run 'tensorboard --logdir $SAVE_DIR' to view the results."
