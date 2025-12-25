# ComfyUI GPU Benchmark Tool

Automated tool for testing GPU performance in ComfyUI. Allows comparison of different graphics cards and evaluation of real performance gains when migrating between GPUs.

## 📋 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Examples](#examples)
- [Interpreting Results](#interpreting-results)
- [GPU Comparison](#gpu-comparison)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [Performance Expectations](#performance-expectations)

## 🚀 Features

- ✅ Automated ComfyUI performance testing
- ✅ Support for SDXL, Flux, and other models
- ✅ Automatic detection of available checkpoints
- ✅ Detailed performance metrics (it/s, time, images/min)
- ✅ JSON export of results
- ✅ Tools for comparing different GPUs
- ✅ Result visualization
- ✅ Warm-up run to ensure accurate measurements

## 📦 Requirements

### System Requirements
- Python 3.8+
- ComfyUI installed and running
- At least one Stable Diffusion model installed

### Python Dependencies
```bash
requests  # Required
matplotlib  # Optional - for visualization
```

## 🔧 Installation

### Step 1: Download the script

Save `comfyui_api_test.py` to your desired directory:
```bash
mkdir comfyui-benchmark
cd comfyui-benchmark
# Place comfyui_api_test.py here
```

### Step 2: Install dependencies
```bash
pip install requests

# Optional: for visualization
pip install matplotlib
```

### Step 3: Verify ComfyUI is running
```bash
# Check if ComfyUI server is accessible
curl http://localhost:8188/system_stats
```

If you see JSON output, ComfyUI is running correctly.

## ⚡ Quick Start

### 1. List available models
```bash
python comfyui_api_test.py --list
```

**Example output:**
```
Available checkpoints:
  1. FLUX1/flux1-dev-fp8.safetensors
  2. SDXL/sd_xl_base_1.0.safetensors
  3. SD1.5/v1-5-pruned-emaonly.ckpt
```

### 2. Run basic benchmark
```bash
# Automatic checkpoint selection (prefers SDXL)
python comfyui_api_test.py
```

**Example output:**
```
============================================================
ComfyUI Benchmark Test
============================================================
Server:       http://localhost:8188
Checkpoint:   SDXL/sd_xl_base_1.0.safetensors
Iterations:   5
Steps:        20
Resolution:   1024x1024
============================================================

Iteration 1/5...
Queued with ID: abc123...
⏱️  Warm-up: 10.23s (skipped from average)

Iteration 2/5...
✅ Time: 9.69s

Iteration 3/5...
✅ Time: 9.53s

Iteration 4/5...
✅ Time: 9.87s

Iteration 5/5...
✅ Time: 10.04s

============================================================
RESULTS
============================================================
Checkpoint:       SDXL/sd_xl_base_1.0.safetensors
Average time:     9.69s
Min time:         9.53s
Max time:         10.04s
Images/minute:    6.19
Iterations/sec:   2.06 it/s
============================================================
```

### 3. Save results to file
```bash
python comfyui_api_test.py --output benchmark_rtx4000.json
```

## 📖 Usage

### Command Line Options
```
python comfyui_api_test.py [OPTIONS]

Options:
  --server SERVER       ComfyUI server address 
                        Default: http://localhost:8188
                        
  --iterations N        Number of test iterations (first is warm-up)
                        Default: 5
                        
  --steps N            Number of sampling steps
                        Default: 20
                        
  --resolution N       Image resolution (NxN)
                        Default: 1024
                        
  --checkpoint NAME    Specific checkpoint to use
                        Example: "SDXL/sd_xl_base_1.0.safetensors"
                        
  --list              List available checkpoints and exit
  
  --output FILE       Save results to JSON file
                        Example: results.json
                        
  -h, --help          Show help message
```

## 💡 Examples

### Basic Tests
```bash
# Default test (5 iterations, SDXL 1024x1024, 20 steps)
python comfyui_api_test.py

# Quick test (3 iterations)
python comfyui_api_test.py --iterations 3

# High-quality test (50 steps)
python comfyui_api_test.py --steps 50

# Lower resolution test
python comfyui_api_test.py --resolution 512
```

### Testing Specific Models
```bash
# Test SDXL
python comfyui_api_test.py \
  --checkpoint "SDXL/sd_xl_base_1.0.safetensors" \
  --output benchmark_sdxl.json

# Test Flux
python comfyui_api_test.py \
  --checkpoint "FLUX1/flux1-dev-fp8.safetensors" \
  --steps 30 \
  --output benchmark_flux.json

# Test SD 1.5
python comfyui_api_test.py \
  --checkpoint "SD1.5/v1-5-pruned-emaonly.ckpt" \
  --resolution 512 \
  --output benchmark_sd15.json
```

### Comprehensive Testing
```bash
# Full benchmark suite
python comfyui_api_test.py \
  --checkpoint "SDXL/sd_xl_base_1.0.safetensors" \
  --iterations 10 \
  --steps 20 \
  --resolution 1024 \
  --output benchmark_full.json
```

### Remote ComfyUI Server
```bash
# Test remote server
python comfyui_api_test.py \
  --server http://192.168.1.100:8188 \
  --output remote_benchmark.json
```

## 📊 Interpreting Results

### Key Metrics Explained

| Metric | Description | Good Value |
|--------|-------------|------------|
| **Average time** | Mean generation time per image | Lower is better |
| **Min time** | Fastest generation | Shows peak performance |
| **Max time** | Slowest generation | Shows consistency |
| **Images/minute** | Throughput capacity | Higher is better |
| **Iterations/sec** | Sampling speed (it/s) | Higher is better |

### Example Results Analysis
```json
{
  "checkpoint": "SDXL/sd_xl_base_1.0.safetensors",
  "avg_time": 9.69,
  "min_time": 9.53,
  "max_time": 10.04,
  "images_per_minute": 6.19,
  "iterations_per_sec": 2.06,
  "steps": 20,
  "resolution": 1024
}
```

**Analysis:**
- Consistent performance (max - min = 0.51s)
- Good for production workflows
- Can generate ~6 images per minute
- 2.06 it/s is typical for mid-range GPUs

## 🔄 GPU Comparison

### Comparing Results

Create `compare_results.py`:
```python
#!/usr/bin/env python3
import json
import sys

def compare_benchmarks(baseline_file, *comparison_files):
    with open(baseline_file, 'r') as f:
        baseline = json.load(f)
    
    print("="*80)
    print("GPU BENCHMARK COMPARISON")
    print("="*80)
    print(f"\nBaseline: {baseline_file}")
    print(f"  Avg Time:     {baseline['avg_time']:.2f}s")
    print(f"  Performance:  {baseline['iterations_per_sec']:.2f} it/s")
    
    baseline_time = baseline['avg_time']
    
    for comp_file in comparison_files:
        with open(comp_file, 'r') as f:
            comp = json.load(f)
        
        speedup = baseline_time / comp['avg_time']
        time_saved = baseline_time - comp['avg_time']
        
        print(f"\n{comp_file}:")
        print(f"  Avg Time:     {comp['avg_time']:.2f}s")
        print(f"  Performance:  {comp['iterations_per_sec']:.2f} it/s")
        print(f"  Speedup:      {speedup:.2f}x")
        print(f"  Time saved:   {time_saved:.2f}s per image")
        print(f"  Improvement:  {(speedup-1)*100:.1f}%")
    
    print("="*80)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python compare_results.py baseline.json comparison.json [...]")
        sys.exit(1)
    
    compare_benchmarks(sys.argv[1], *sys.argv[2:])
```

**Usage:**
```bash
python compare_results.py \
  benchmark_rtx4000.json \
  benchmark_a100.json \
  benchmark_h100.json
```

**Example output:**
```
================================================================================
GPU BENCHMARK COMPARISON
================================================================================

Baseline: benchmark_rtx4000.json
  Avg Time:     9.69s
  Performance:  2.06 it/s

benchmark_a100.json:
  Avg Time:     7.12s
  Performance:  2.81 it/s
  Speedup:      1.36x
  Time saved:   2.57s per image
  Improvement:  36.1%

benchmark_h100.json:
  Avg Time:     3.54s
  Performance:  5.65 it/s
  Speedup:      2.74x
  Time saved:   6.15s per image
  Improvement:  173.7%
================================================================================
```

## 🎨 Advanced Usage

### Batch Testing Script

Create `run_batch_tests.sh`:
```bash
#!/bin/bash

echo "Running comprehensive GPU benchmark suite..."

# Test different resolutions
for res in 512 768 1024; do
  python comfyui_api_test.py \
    --checkpoint "SDXL/sd_xl_base_1.0.safetensors" \
    --resolution $res \
    --steps 20 \
    --output "results_sdxl_${res}.json"
done

# Test different step counts
for steps in 20 30 50; do
  python comfyui_api_test.py \
    --checkpoint "SDXL/sd_xl_base_1.0.safetensors" \
    --resolution 1024 \
    --steps $steps \
    --output "results_sdxl_${steps}steps.json"
done

echo "Benchmark suite completed!"
```

Make executable and run:
```bash
chmod +x run_batch_tests.sh
./run_batch_tests.sh
```

### Visualization Script

Create `visualize_benchmark.py`:
```python
#!/usr/bin/env python3
import json
import matplotlib.pyplot as plt
import sys

def visualize_benchmarks(*result_files):
    gpus = []
    times = []
    its = []
    
    for file in result_files:
        with open(file, 'r') as f:
            data = json.load(f)
            gpu_name = file.replace('benchmark_', '').replace('.json', '')
            gpus.append(gpu_name)
            times.append(data['avg_time'])
            its.append(data['iterations_per_sec'])
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    
    # Generation time
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']
    ax1.bar(gpus, times, color=colors[:len(gpus)])
    ax1.set_ylabel('Time (seconds)', fontsize=12)
    ax1.set_title('SDXL Generation Time\n(lower is better)', fontsize=14, fontweight='bold')
    ax1.grid(axis='y', alpha=0.3)
    
    for i, v in enumerate(times):
        ax1.text(i, v + 0.2, f'{v:.2f}s', ha='center', fontweight='bold')
    
    # Iterations per second
    ax2.bar(gpus, its, color=colors[:len(gpus)])
    ax2.set_ylabel('Iterations per second', fontsize=12)
    ax2.set_title('Performance\n(higher is better)', fontsize=14, fontweight='bold')
    ax2.grid(axis='y', alpha=0.3)
    
    for i, v in enumerate(its):
        ax2.text(i, v + 0.1, f'{v:.2f}', ha='center', fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('benchmark_comparison.png', dpi=150, bbox_inches='tight')
    print("✅ Chart saved to benchmark_comparison.png")
    plt.show()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python visualize_benchmark.py result1.json result2.json ...")
        sys.exit(1)
    
    visualize_benchmarks(*sys.argv[1:])
```

**Usage:**
```bash
pip install matplotlib
python visualize_benchmark.py benchmark_*.json
```

## 🔍 Troubleshooting

### Issue: "Cannot connect to ComfyUI server"

**Solution:**
```bash
# Check if ComfyUI is running
ps aux | grep comfyui

# Check if port 8188 is open
netstat -an | grep 8188

# Try accessing directly
curl http://localhost:8188/system_stats
```

### Issue: "Value not in list: ckpt_name"

**Cause:** Checkpoint file path is incorrect

**Solution:**
```bash
# List available checkpoints
python comfyui_api_test.py --list

# Use exact path from the list
python comfyui_api_test.py --checkpoint "SDXL/sd_xl_base_1.0.safetensors"
```

### Issue: "Failed to queue workflow"

**Possible causes:**
1. ComfyUI server is not responding
2. Model is not loaded/available
3. Insufficient VRAM

**Solution:**
```bash
# Check ComfyUI logs
tail -f /path/to/comfyui/logs

# Try with smaller resolution
python comfyui_api_test.py --resolution 512

# Try SD 1.5 instead of SDXL
python comfyui_api_test.py --checkpoint "SD1.5/v1-5-pruned-emaonly.ckpt" --resolution 512
```

### Issue: Timeout errors

**Solution:**
```bash
# Increase timeout in the script or use fewer steps
python comfyui_api_test.py --steps 10
```

### Issue: Inconsistent results

**Solution:**
```bash
# Run more iterations for better averaging
python comfyui_api_test.py --iterations 10

# Ensure no other processes are using GPU
nvidia-smi
```

## 📈 Performance Expectations

### Reference Performance (SDXL 1024x1024, 20 steps)

| GPU | VRAM | Avg Time | it/s | Speedup vs RTX 4000 SFF |
|-----|------|----------|------|-------------------------|
| **RTX 4000 SFF Ada** | 20GB | ~9.7s | ~2.1 | 1.0x (baseline) |
| **RTX 4090** | 24GB | ~3.2s | ~6.3 | 3.0x |
| **A100 80GB** | 80GB | ~7.1s | ~2.8 | 1.4x |
| **H100 SXM** | 80GB | ~3.5s | ~5.7 | 2.8x |
| **L40** | 48GB | ~5.2s | ~3.8 | 1.9x |

### FLUX Performance (1024x1024, 20 steps)

| GPU | Avg Time | Speedup |
|-----|----------|---------|
| **RTX 4000 SFF Ada** | ~45-50s | 1.0x |
| **A100 80GB** | ~22-25s | 2.0x |
| **H100 SXM** | ~10-12s | 4.5x |

## 📝 Best Practices

### For Accurate Benchmarking

1. **Close other applications** using the GPU
2. **Run multiple iterations** (at least 5) for statistical significance
3. **First iteration is warm-up** - automatically excluded from average
4. **Use consistent parameters** when comparing GPUs
5. **Document your environment**:
   - GPU driver version
   - CUDA version
   - ComfyUI version
   - PyTorch version

### Recommended Test Suite
```bash
# Save as test_suite.sh
#!/bin/bash

GPU_NAME="rtx4000"

# SDXL Standard
python comfyui_api_test.py \
  --checkpoint "SDXL/sd_xl_base_1.0.safetensors" \
  --iterations 10 \
  --steps 20 \
  --resolution 1024 \
  --output "${GPU_NAME}_sdxl_standard.json"

# SDXL Quality
python comfyui_api_test.py \
  --checkpoint "SDXL/sd_xl_base_1.0.safetensors" \
  --iterations 5 \
  --steps 50 \
  --resolution 1024 \
  --output "${GPU_NAME}_sdxl_quality.json"

# SD 1.5 Fast
python comfyui_api_test.py \
  --checkpoint "SD1.5/v1-5-pruned-emaonly.ckpt" \
  --iterations 10 \
  --steps 20 \
  --resolution 512 \
  --output "${GPU_NAME}_sd15_fast.json"

echo "Test suite completed for ${GPU_NAME}"
```

## 📄 License

This tool is provided as-is for benchmarking purposes.

## 🤝 Contributing

Feel free to submit issues, suggestions, or improvements.

## 📧 Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Verify ComfyUI is running correctly
3. Check ComfyUI logs for errors

## 🔗 Related Resources

- [ComfyUI Documentation](https://github.com/comfyanonymous/ComfyUI)
- [Stable Diffusion Models](https://huggingface.co/stabilityai)
- [GPU Comparison Database](https://www.techpowerup.com/gpu-specs/)

---

**Version:** 1.0  
**Last Updated:** December 2025  
**Author:** DevOps Team
