# Text-to-Video Benchmark for ComfyUI

A comprehensive benchmarking tool for measuring text-to-video generation performance using SDXL (Stable Diffusion XL) and SVD-XT (Stable Video Diffusion Extended) in ComfyUI.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Parameters](#parameters)
- [Examples](#examples)
- [Output Format](#output-format)
- [Performance Expectations](#performance-expectations)
- [Troubleshooting](#troubleshooting)
- [Technical Details](#technical-details)

## 🎯 Overview

This benchmark tool measures the complete text-to-video generation pipeline:

1. **Text → Image**: Generates initial image using SDXL
2. **Image → Video**: Converts image to video (25 frames) using SVD-XT

The tool provides detailed metrics including generation time, FPS, throughput, and per-frame statistics.

## ✨ Features

- **Complete Pipeline Benchmark**: Measures both image and video generation
- **Configurable Parameters**: Control frames, resolution, steps, motion intensity
- **Detailed Metrics**: Time per video, FPS, throughput, standard deviation
- **JSON Output**: Saves results in structured format for analysis
- **Progress Tracking**: Real-time status updates during benchmark
- **Error Handling**: Robust error handling and timeout protection
- **Checkpoint Listing**: List available models before running

## 📦 Requirements

### Hardware

- GPU with **24GB+ VRAM** recommended
  - Minimum: 20GB (tight)
  - Recommended: 32GB+
  - Optimal: 48GB+
  - Tested on: H100 (80GB), RTX 6000 Ada (48GB), A100 (80GB), RTX 3090 (24GB)

### Software

- **ComfyUI** (running and accessible)
- **Python 3.8+**
- **Required Python packages**:
  ```bash
  pip install requests
  ```

### Models

- **SDXL Base 1.0** (`sd_xl_base_1.0.safetensors`) - ~6.9 GB
- **SVD-XT** (`svd_xt.safetensors`) - ~9.5 GB

**Total storage required**: ~16.4 GB for models

## 🚀 Installation

### 1. Download Models

```bash
# Navigate to ComfyUI checkpoints directory
cd /path/to/ComfyUI/models/checkpoints

# Download SDXL Base 1.0 (if not already present)
wget https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Download SVD-XT
wget https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt/resolve/main/svd_xt.safetensors

# Verify downloads
ls -lh *.safetensors
```

### 2. Download Benchmark Script

```bash
# Navigate to your working directory
cd /path/to/your/workspace

# Download the script
wget https://raw.githubusercontent.com/your-repo/text2video_benchmark.py
# Or copy the script manually

# Make executable (Linux/Mac)
chmod +x text2video_benchmark.py
```

### 3. Verify ComfyUI is Running

```bash
# Check if ComfyUI is accessible
curl http://localhost:8188/system_stats

# Expected response: JSON with system info
```

If ComfyUI is not running:

```bash
cd /path/to/ComfyUI
python main.py --listen 0.0.0.0 --port 8188
```

## 📖 Usage

### Basic Syntax

```bash
python text2video_benchmark.py SERVER:PORT [OPTIONS]
```

### Show Help

```bash
# Display full help and examples
python text2video_benchmark.py

# Or explicitly
python text2video_benchmark.py --help
```

### Quick Start

```bash
# Basic benchmark with default settings
python text2video_benchmark.py localhost:8188

# With custom iterations
python text2video_benchmark.py localhost:8188 --iterations 10

# Quick test (fewer frames/steps)
python text2video_benchmark.py localhost:8188 --frames 14 --steps 15 --iterations 3
```

## ⚙️ Parameters

### Required

| Parameter | Description | Example |
|-----------|-------------|---------|
| `SERVER:PORT` | ComfyUI server address | `localhost:8188` or `127.0.0.1:8188` |

### Optional

#### Model Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--image-checkpoint` | `sd_xl_base_1.0.safetensors` | SDXL model for image generation |
| `--video-checkpoint` | `svd_xt.safetensors` | SVD-XT model for video generation |

#### Video Settings

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `--frames` | `25` | 14-25 | Number of video frames (SVD-XT supports 14 or 25) |
| `--width` | `1024` | 512-1536 | Video width in pixels |
| `--height` | `576` | 288-864 | Video height in pixels |
| `--steps` | `20` | 10-50 | Denoising steps (higher = better quality, slower) |
| `--fps` | `8` | 6-12 | Frames per second for playback |
| `--motion-bucket-id` | `127` | 0-255 | Motion intensity |

**Motion Bucket ID Guide:**
- `0-50`: Minimal motion (almost static)
- `50-100`: Low motion (subtle movements)
- `100-150`: Medium motion (normal, **default: 127**)
- `150-200`: High motion (active movements)
- `200-255`: Very high motion (may be unstable)

#### Benchmark Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--iterations` | `5` | Number of test runs |
| `--output` | `text2video_benchmark.json` | Output filename |

#### Utility

| Parameter | Description |
|-----------|-------------|
| `--list` | List available checkpoints and exit |

## 💡 Examples

### 1. Standard Benchmark

```bash
python text2video_benchmark.py localhost:8188
```

**Configuration:**
- 5 iterations
- 25 frames per video
- 1024x576 resolution
- 20 denoising steps
- Results saved to `text2video_benchmark.json`

### 2. Production Benchmark (H100/High-end GPU)

```bash
python text2video_benchmark.py 127.0.0.1:8188 \\
  --iterations 10 \\
  --output h100_production_benchmark.json
```

**Use case:** Comprehensive benchmark for production deployment decisions

### 3. Quick Test (Fast iteration)

```bash
python text2video_benchmark.py localhost:8188 \\
  --frames 14 \\
  --steps 15 \\
  --iterations 3 \\
  --output quick_test.json
```

**Use case:** Fast sanity check, initial testing

### 4. High Quality (More steps, higher motion)

```bash
python text2video_benchmark.py localhost:8188 \\
  --steps 30 \\
  --motion-bucket-id 150 \\
  --iterations 5 \\
  --output high_quality_test.json
```

**Use case:** Maximum quality benchmark

### 5. Lower Resolution (Faster, less VRAM)

```bash
python text2video_benchmark.py localhost:8188 \\
  --width 768 \\
  --height 432 \\
  --frames 14 \\
  --output low_res_test.json
```

**Use case:** Testing on GPUs with limited VRAM (16-20GB)

### 6. Remote Server

```bash
python text2video_benchmark.py 192.168.1.100:8188 \\
  --iterations 10 \\
  --output remote_server_benchmark.json
```

**Use case:** Benchmarking remote ComfyUI instance

### 7. List Available Models

```bash
python text2video_benchmark.py localhost:8188 --list
```

**Output:**
```
Connecting to http://localhost:8188...

Available checkpoints:
  - sd_xl_base_1.0.safetensors
  - svd_xt.safetensors
  - sd_v1-5-pruned-emaonly.safetensors
  - dreamshaperXL.safetensors
```

## 📊 Output Format

### Console Output Example

```
======================================================================
TEXT-TO-VIDEO BENCHMARK
======================================================================
Server: http://localhost:8188
Image Model: sd_xl_base_1.0.safetensors
Video Model: svd_xt.safetensors
Resolution: 1024x576
Video Frames: 25
Steps: 20
FPS: 8
Motion Bucket ID: 127
Iterations: 5
======================================================================

Iteration 1/5
  Prompt: A serene mountain landscape with a flowing river...
  Seed: 1234567890
  Queued: abc123-def456-ghi789
  ✓ Completed in 18.45s
  ✓ Generation FPS: 1.35 frames/sec
  ✓ Time per frame: 0.738s

Iteration 2/5
  Prompt: Ocean waves gently crashing on a sandy beach...
  Seed: 1234567891
  Queued: def456-ghi789-jkl012
  ✓ Completed in 17.89s
  ✓ Generation FPS: 1.40 frames/sec
  ✓ Time per frame: 0.716s

...

======================================================================
BENCHMARK RESULTS
======================================================================
Successful iterations: 5/5
Average time per video: 18.45s
Min/Max time: 17.89s / 19.12s
Standard deviation: ±0.487s
Generation FPS: 1.35 frames/sec
Time per frame: 0.738s/frame
Videos per minute: 3.25
======================================================================

Results saved to: text2video_benchmark.json
```

### JSON Output Format

```json
{
  "image_checkpoint": "sd_xl_base_1.0.safetensors",
  "video_checkpoint": "svd_xt.safetensors",
  "video_frames": 25,
  "resolution": "1024x576",
  "steps": 20,
  "fps": 8,
  "motion_bucket_id": 127,
  "iterations": 5,
  "avg_time": 18.45,
  "min_time": 17.89,
  "max_time": 19.12,
  "std_deviation": 0.487,
  "avg_fps_generation": 1.35,
  "videos_per_minute": 3.25,
  "time_per_frame": 0.738,
  "all_times": [18.23, 17.89, 18.67, 19.12, 18.34]
}
```

### Metrics Explanation

| Metric | Description | Unit |
|--------|-------------|------|
| `avg_time` | Average generation time per video | seconds |
| `min_time` | Fastest generation time | seconds |
| `max_time` | Slowest generation time | seconds |
| `std_deviation` | Consistency measure (lower = more consistent) | seconds |
| `avg_fps_generation` | Processing speed during generation | frames/sec |
| `videos_per_minute` | Throughput | videos/min |
| `time_per_frame` | Average time to process one frame | seconds/frame |
| `all_times` | Individual iteration times | array of seconds |

## 📈 Performance Expectations

### GPU Benchmarks (25 frames @ 1024x576, 20 steps)

| GPU | VRAM | Avg Time | FPS | Videos/min | Daily (8h) | Rating |
|-----|------|----------|-----|------------|------------|--------|
| **H100 (Dedicated)** | 80GB | ~15-20s | ~1.25-1.67 | ~3-4 | ~1,440-1,920 | ⭐⭐⭐⭐⭐ |
| **H100 (Cloud)** | 80GB | ~20-30s | ~0.83-1.25 | ~2-3 | ~960-1,440 | ⭐⭐⭐⭐⭐ |
| **RTX 6000 Ada** | 48GB | ~20-30s | ~0.83-1.25 | ~2-3 | ~960-1,440 | ⭐⭐⭐⭐⭐ |
| **A100** | 80GB | ~30-40s | ~0.62-0.83 | ~1.5-2 | ~720-960 | ⭐⭐⭐⭐ |
| **L40S** | 48GB | ~40-55s | ~0.45-0.62 | ~1.1-1.5 | ~528-720 | ⭐⭐⭐ |
| **RTX 3090** | 24GB | ~50-70s | ~0.36-0.50 | ~0.9-1.2 | ~432-576 | ⭐⭐⭐ |

**Note:** Performance varies based on:
- Server configuration (CPU, RAM)
- Cooling and thermal management
- Concurrent workloads
- Driver versions
- Infrastructure (dedicated vs cloud)

### VRAM Usage by Configuration

| Configuration | SDXL Peak | SVD Peak | Total Peak | Safe Min | Recommended |
|---------------|-----------|----------|------------|----------|-------------|
| **1024x576, 25f** | ~8-10 GB | ~18-22 GB | ~22-25 GB | 24GB | 32GB+ |
| **768x432, 25f** | ~6-8 GB | ~14-18 GB | ~18-20 GB | 20GB | 24GB+ |
| **1024x576, 14f** | ~8-10 GB | ~12-16 GB | ~16-20 GB | 20GB | 24GB+ |
| **768x432, 14f** | ~6-8 GB | ~10-14 GB | ~14-16 GB | 16GB | 20GB+ |

## 🔧 Troubleshooting

### Issue: "Connection refused" or "Cannot connect to server"

**Cause:** ComfyUI is not running or not accessible

**Solutions:**

```bash
# 1. Check if ComfyUI is running
curl http://localhost:8188/system_stats

# 2. If not running, start ComfyUI
cd /path/to/ComfyUI
python main.py

# 3. With custom port
python main.py --port 8188

# 4. Listen on all interfaces (for remote access)
python main.py --listen 0.0.0.0 --port 8188

# 5. Check firewall settings
sudo ufw allow 8188
```

### Issue: "SVD_img2vid_Conditioning not found"

**Cause:** ComfyUI version is outdated or missing required nodes

**Solutions:**

```bash
# 1. Update ComfyUI to latest version
cd /path/to/ComfyUI
git pull

# 2. Restart ComfyUI
python main.py

# 3. If still not working, install ComfyUI Manager
cd custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager
cd ..
python main.py
```

### Issue: "Out of memory" / CUDA OOM

**Cause:** Insufficient VRAM for current configuration

**Solutions:**

1. **Reduce frames:**
   ```bash
   python text2video_benchmark.py localhost:8188 --frames 14
   ```

2. **Lower resolution:**
   ```bash
   python text2video_benchmark.py localhost:8188 --width 768 --height 432
   ```

3. **Reduce steps:**
   ```bash
   python text2video_benchmark.py localhost:8188 --steps 15
   ```

4. **Combination (most effective):**
   ```bash
   python text2video_benchmark.py localhost:8188 \\
     --frames 14 \\
     --width 768 \\
     --height 432 \\
     --steps 15
   ```

5. **Clear GPU memory:**
   ```bash
   # Restart ComfyUI
   # Or use nvidia-smi to kill processes
   nvidia-smi
   kill -9 <PID>
   ```

### Issue: "Checkpoint not found"

**Cause:** Model files are missing or in wrong location

**Solutions:**

```bash
# 1. List available checkpoints
python text2video_benchmark.py localhost:8188 --list

# 2. Download missing models
cd /path/to/ComfyUI/models/checkpoints

# SDXL
wget https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# SVD-XT
wget https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt/resolve/main/svd_xt.safetensors

# 3. Verify files
ls -lh *.safetensors

# 4. Restart ComfyUI
```

### Issue: "Workflow timeout"

**Cause:** Generation taking longer than 600s (default timeout)

**Current workaround:** Edit script and increase timeout value:

```python
# In text2video_benchmark.py, line ~95
result = self.wait_for_completion(prompt_id, timeout=1200)  # Increase to 1200s
```

**Note:** This usually indicates a problem with GPU performance or configuration.

### Issue: "All iterations failed"

**Cause:** Multiple possible issues

**Diagnostic steps:**

```bash
# 1. Test ComfyUI directly
curl http://localhost:8188/system_stats

# 2. Check ComfyUI logs
cd /path/to/ComfyUI
tail -f comfyui.log

# 3. Test with minimal configuration
python text2video_benchmark.py localhost:8188 \\
  --frames 14 \\
  --steps 10 \\
  --iterations 1

# 4. Verify GPU is working
nvidia-smi

# 5. Check VRAM usage during run
watch -n 1 nvidia-smi
```

### Issue: "High variance / inconsistent results"

**Causes:**
- Thermal throttling
- Background processes
- Shared GPU usage

**Solutions:**

```bash
# 1. Check GPU temperature
nvidia-smi

# 2. Ensure GPU is not throttling
nvidia-smi dmon -s pucvmet

# 3. Stop background processes
# Kill other GPU processes

# 4. Run benchmark when system is idle

# 5. Increase cooling / check thermal paste
```

## 🔬 Technical Details

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Text Prompt                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────┐
│  STEP 1: SDXL Image Generation                          │
│  ┌────────────────────────────────────────────────┐     │
│  │ CheckpointLoaderSimple                         │     │
│  │ → CLIPTextEncode (positive/negative)           │     │
│  │ → EmptyLatentImage (1024x576)                  │     │
│  │ → KSampler (20 steps, DPM++ 2M Karras)         │     │
│  │ → VAEDecode                                    │     │
│  └────────────────────────────────────────────────┘     │
│  Output: Single 1024x576 image (~1.5-2s on H100)        │
└────────────────────┬────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────┐
│  STEP 2: SVD-XT Video Generation                        │
│  ┌────────────────────────────────────────────────┐     │
│  │ ImageOnlyCheckpointLoader                      │     │
│  │ → SVD_img2vid_Conditioning                     │     │
│  │   - video_frames: 25                           │     │
│  │   - motion_bucket_id: 127                      │     │
│  │   - fps: 8                                     │     │
│  │ → KSampler (20 steps, Euler Karras)            │     │
│  │ → VAEDecode                                    │     │
│  └────────────────────────────────────────────────┘     │
│  Output: 25 frames (576x1024 each) (~13-18s on H100)    │
└────────────────────┬────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────┐
│  Output: Complete Video (25 frames @ 8fps = 3.125s)     │
│  Total generation time: ~15-20s on H100                 │
└─────────────────────────────────────────────────────────┘
```

### Model Specifications

#### SDXL Base 1.0
- **Size**: 6.9 GB
- **Architecture**: Latent Diffusion
- **Parameters**: ~2.3 billion
- **Native Resolution**: 1024x1024
- **Optimal Aspect Ratios**: 1:1, 16:9, 4:3
- **CFG Scale**: 7.0 (default)
- **Sampler**: DPM++ 2M Karras (recommended)

#### SVD-XT (Stable Video Diffusion Extended)
- **Size**: 9.5 GB
- **Architecture**: Video Diffusion
- **Frames**: 25 (extended from 14)
- **Native Resolution**: 576x1024
- **FPS Range**: 6-12
- **Motion Bucket Range**: 0-255
- **CFG Scale**: 2.5 (default)
- **Sampler**: Euler Karras (recommended)

### Workflow Node Details

| Node | Purpose | Key Parameters |
|------|---------|----------------|
| `CheckpointLoaderSimple` | Load SDXL model | `ckpt_name` |
| `CLIPTextEncode` | Convert text to embeddings | `text`, `clip` |
| `EmptyLatentImage` | Create latent space | `width`, `height`, `batch_size` |
| `KSampler` | Denoise latent | `steps`, `cfg`, `sampler_name`, `scheduler` |
| `VAEDecode` | Latent to image | `samples`, `vae` |
| `ImageOnlyCheckpointLoader` | Load SVD model | `ckpt_name` |
| `SVD_img2vid_Conditioning` | Prepare for video | `video_frames`, `motion_bucket_id`, `fps` |

### Performance Factors

**GPU Compute:**
- Tensor Core utilization
- FP16/BF16 precision
- Memory bandwidth

**System:**
- CPU performance (image preprocessing)
- Storage speed (model loading)
- RAM capacity (workflow management)

**Configuration:**
- Frame count (linear scaling)
- Resolution (quadratic scaling)
- Steps (linear scaling)
- Motion intensity (minimal impact)

## 📝 Best Practices

### For Accurate Benchmarking

1. **Run multiple iterations** (10+ recommended)
2. **Warm up the GPU** (first iteration often slower)
3. **Consistent environment** (no background tasks)
4. **Monitor temperature** (thermal throttling affects results)
5. **Record all parameters** (for reproducibility)

### For Production Use

1. **Test multiple configurations** (find optimal settings)
2. **Measure during peak load** (realistic conditions)
3. **Account for variance** (±10-20% is normal)
4. **Plan for scaling** (throughput vs quality tradeoff)
5. **Monitor VRAM headroom** (avoid OOM in production)

### Configuration Recommendations

**Maximum Quality:**
```bash
--frames 25 --steps 30 --motion-bucket-id 150
```

**Balanced (Recommended):**
```bash
--frames 25 --steps 20 --motion-bucket-id 127
```

**Maximum Speed:**
```bash
--frames 14 --steps 15 --motion-bucket-id 100
```

**Low VRAM (16-20GB):**
```bash
--frames 14 --width 768 --height 432 --steps 15
```

## 📄 License

This benchmark tool is provided as-is for testing and evaluation purposes.

**Models:**
- SDXL Base 1.0: [CreativeML Open RAIL++-M License](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md)
- SVD-XT: [Stability AI Community License](https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt/blob/main/LICENSE)

## 🤝 Contributing

Issues and improvements welcome! Please test thoroughly before submitting changes.

## 📞 Support

For issues specific to:
- **ComfyUI**: [ComfyUI GitHub](https://github.com/comfyanonymous/ComfyUI)
- **SDXL**: [Stability AI](https://stability.ai/)
- **SVD**: [Stability AI Research](https://stability.ai/research)

## 🔗 Related Resources

- [ComfyUI Documentation](https://github.com/comfyanonymous/ComfyUI)
- [SDXL Paper](https://arxiv.org/abs/2307.01952)
- [SVD Paper](https://arxiv.org/abs/2311.15127)
- [ComfyUI Examples](https://comfyanonymous.github.io/ComfyUI_examples/)

---

**Version:** 1.0.0  
**Last Updated:** January 2026  
**Tested GPU Platforms:** H100, H200, RTX 6000 Ada, A100, L40S, RTX 3090, RTX 4000 SFF Ada, RTX 5090
