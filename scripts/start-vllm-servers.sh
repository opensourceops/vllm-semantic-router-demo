#!/bin/bash

# Kill any existing vLLM processes
echo "Stopping any existing vLLM processes..."
pkill -f "vllm serve"
sleep 5

# Create logs directory
mkdir -p ~/logs

# Clear old logs
rm -f ~/logs/vllm-*.log

echo "Starting Qwen2.5-3B on port 8000..."
nohup ~/vllm-env/bin/vllm serve ~/models/Qwen2.5-3B-Instruct \
  --port 8000 \
  --gpu-memory-utilization 0.12 \
  --dtype bfloat16 \
  --max-model-len 8192 \
  --disable-log-requests \
  > ~/logs/vllm-qwen-3b.log 2>&1 &

echo "Waiting 60 seconds for Qwen2.5-3B to initialize..."
sleep 60

echo "Checking Qwen2.5-3B status..."
tail -10 ~/logs/vllm-qwen-3b.log | grep -i "startup complete" && echo "✅ Qwen2.5-3B started successfully" || echo "⚠️  Check ~/logs/vllm-qwen-3b.log for errors"

echo ""
echo "Starting Ministral-3B-2512 on port 8001..."
nohup ~/vllm-env/bin/vllm serve ~/models/Ministral-3-3B-Instruct-2512 \
  --port 8001 \
  --gpu-memory-utilization 0.12 \
  --dtype bfloat16 \
  --max-model-len 8192 \
  --disable-log-requests \
  > ~/logs/vllm-ministral-3b.log 2>&1 &

echo "Waiting 60 seconds for Ministral-3B to initialize..."
sleep 60

echo "Checking Ministral-3B status..."
tail -10 ~/logs/vllm-ministral-3b.log | grep -i "startup complete" && echo "✅ Ministral-3B started successfully" || echo "⚠️  Check ~/logs/vllm-ministral-3b.log for errors"

echo ""
echo "Starting DeepSeek-R1-14B on port 8002..."
nohup ~/vllm-env/bin/vllm serve ~/models/DeepSeek-R1-Distill-Qwen-14B \
  --port 8002 \
  --gpu-memory-utilization 0.30 \
  --dtype bfloat16 \
  --max-model-len 32768 \
  --enable-chunked-prefill \
  --disable-log-requests \
  > ~/logs/vllm-deepseek-14b.log 2>&1 &

echo "Waiting 60 seconds for DeepSeek-R1-14B to initialize..."
sleep 60

echo "Checking DeepSeek-R1-14B status..."
tail -10 ~/logs/vllm-deepseek-14b.log | grep -i "startup complete" && echo "✅ DeepSeek-R1-14B started successfully" || echo "⚠️  Check ~/logs/vllm-deepseek-14b.log for errors"

echo ""
echo "========================================="
echo "All vLLM servers started!"
echo "========================================="
echo ""
echo "Running processes:"
ps aux | grep "vllm serve" | grep -v grep

echo ""
echo "Testing endpoints..."
echo ""

echo "Testing Qwen2.5-3B (port 8000):"
curl -s http://localhost:8000/v1/models | head -3

echo ""
echo "Testing Ministral-3B (port 8001):"
curl -s http://localhost:8001/v1/models | head -3

echo ""
echo "Testing DeepSeek-R1-14B (port 8002):"
curl -s http://localhost:8002/v1/models | head -3

echo ""
echo "GPU Memory Usage:"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv

echo ""
echo "========================================="
echo "Logs available at:"
echo "  - Qwen2.5-3B:      ~/logs/vllm-qwen-3b.log"
echo "  - Ministral-3B:    ~/logs/vllm-ministral-3b.log"
echo "  - DeepSeek-R1-14B: ~/logs/vllm-deepseek-14b.log"
echo "========================================="

