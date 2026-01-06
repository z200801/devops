# FFmpeg Video Conversion Guide

Quick guide for converting ComfyUI benchmark frames to video files.

## 📋 Table of Contents

- [Installation](#installation)
- [Basic Usage](#basic-usage)
- [Common Scenarios](#common-scenarios)
- [Quality Settings](#quality-settings)
- [Batch Processing](#batch-processing)
- [Troubleshooting](#troubleshooting)

## 🚀 Installation

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install ffmpeg -y
```

### CentOS/RHEL
```bash
sudo yum install epel-release -y
sudo yum install ffmpeg -y
```

### macOS
```bash
brew install ffmpeg
```

### Verify Installation
```bash
ffmpeg -version
```

## 📖 Basic Usage

### Convert Frame Sequence to Video

**Basic command:**
```bash
ffmpeg -framerate 8 -i text2video_%05d_.png -c:v libx264 -pix_fmt yuv420p output.mp4
```

**Explanation:**
- `-framerate 8` - 8 frames per second (SVD-XT default)
- `-i text2video_%05d_.png` - Input pattern (5-digit numbering)
- `-c:v libx264` - H.264 video codec
- `-pix_fmt yuv420p` - Pixel format (universal compatibility)
- `output.mp4` - Output filename

## 💡 Common Scenarios

### 1. Standard Benchmark Video (SVD-XT 25 frames)

```bash
cd /opt/comfyui/output

ffmpeg -framerate 8 -i text2video_%05d_.png \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -crf 23 \
  benchmark_video.mp4
```

### 2. High Quality Video

```bash
ffmpeg -framerate 8 -i text2video_%05d_.png \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -crf 18 \
  -preset slow \
  high_quality_video.mp4
```

### 3. Small File Size (For Sharing)

```bash
ffmpeg -framerate 8 -i text2video_%05d_.png \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -crf 28 \
  -preset fast \
  small_video.mp4
```

### 4. GIF Animation

```bash
ffmpeg -framerate 8 -i text2video_%05d_.png \
  -vf "fps=8,scale=512:-1:flags=lanczos" \
  -c:v gif \
  output.gif
```

### 5. WebM Format (Web-optimized)

```bash
ffmpeg -framerate 8 -i text2video_%05d_.png \
  -c:v libvpx-vp9 \
  -crf 30 \
  -b:v 0 \
  output.webm
```

## ⚙️ Quality Settings

### CRF Values (Constant Rate Factor)

Lower = Better quality, Larger file size

| CRF | Quality | Use Case | File Size |
|-----|---------|----------|-----------|
| 18 | Very High | Archival, Professional | ~50-100 MB |
| 23 | High (Default) | General use | ~20-40 MB |
| 28 | Medium | Web sharing | ~10-20 MB |
| 32 | Low | Preview, Draft | ~5-10 MB |

**Example:**
```bash
# Very high quality
ffmpeg -framerate 8 -i frames_%05d.png -crf 18 output.mp4

# Medium quality
ffmpeg -framerate 8 -i frames_%05d.png -crf 28 output.mp4
```

### Preset Values (Encoding Speed)

Slower = Better compression (smaller file at same quality)

| Preset | Speed | Compression | Use Case |
|--------|-------|-------------|----------|
| ultrafast | Fastest | Worst | Real-time encoding |
| fast | Fast | Good | Quick conversion |
| medium | Balanced | Better | Default |
| slow | Slow | Best | Archival |
| veryslow | Very Slow | Best | Maximum compression |

**Example:**
```bash
# Fast encoding
ffmpeg -framerate 8 -i frames_%05d.png -preset fast output.mp4

# Best compression
ffmpeg -framerate 8 -i frames_%05d.png -preset slow output.mp4
```

## 📦 Batch Processing

### Script for Multiple Video Sequences

Create `batch_convert.sh`:

```bash
#!/bin/bash
# Batch convert all frame sequences to videos

OUTPUT_DIR="videos"
mkdir -p "$OUTPUT_DIR"

# Find all unique sequence prefixes
for prefix in $(ls *.png | sed 's/_[0-9]*.png//' | sort -u); do
    echo "Converting: $prefix"
    
    ffmpeg -framerate 8 \
           -i "${prefix}_%05d_.png" \
           -c:v libx264 \
           -pix_fmt yuv420p \
           -crf 23 \
           -preset medium \
           "$OUTPUT_DIR/${prefix}.mp4" \
           -y
done

echo "✓ Done! Videos saved to: $OUTPUT_DIR/"
```

Make executable and run:
```bash
chmod +x batch_convert.sh
./batch_convert.sh
```

### One-liner Batch Convert

```bash
for f in text2video_*_00001_.png; do 
    base=$(echo $f | sed 's/_00001_.png//'); 
    ffmpeg -framerate 8 -i "${base}_%05d_.png" -c:v libx264 -pix_fmt yuv420p "${base}.mp4" -y; 
done
```

## 🔧 Advanced Options

### Add Audio (Silent Audio Track)

Some platforms require audio track:

```bash
ffmpeg -framerate 8 -i text2video_%05d_.png \
  -f lavfi -i anullsrc=r=44100:cl=stereo \
  -c:v libx264 \
  -c:a aac \
  -shortest \
  -pix_fmt yuv420p \
  output_with_audio.mp4
```

### Specific Frame Range

Convert only frames 1-10:

```bash
ffmpeg -framerate 8 \
  -start_number 1 \
  -i text2video_%05d_.png \
  -frames:v 10 \
  -c:v libx264 \
  -pix_fmt yuv420p \
  output_first_10_frames.mp4
```

### Loop Video

Create 3-second loop repeated 10 times:

```bash
ffmpeg -stream_loop 10 -i input.mp4 -c copy looped_video.mp4
```

### Resize Video

Resize to 720p width (maintain aspect ratio):

```bash
ffmpeg -framerate 8 -i text2video_%05d_.png \
  -vf "scale=720:-1" \
  -c:v libx264 \
  -pix_fmt yuv420p \
  resized_video.mp4
```

### Add Metadata

```bash
ffmpeg -framerate 8 -i text2video_%05d_.png \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -metadata title="Benchmark Video" \
  -metadata author="ComfyUI Benchmark" \
  -metadata date="2026-01-06" \
  output.mp4
```

## 🐛 Troubleshooting

### Issue: "No such file or directory"

**Problem:** Frame files not found

**Solution:**
```bash
# List files to verify pattern
ls -1 text2video_*.png

# Check numbering format
# If files are: text2video_1.png, text2video_2.png (no leading zeros)
ffmpeg -framerate 8 -i text2video_%d.png output.mp4

# If files are: text2video_00001.png (no underscore before number)
ffmpeg -framerate 8 -i text2video_%05d.png output.mp4
```

### Issue: "Invalid pixel format"

**Problem:** Output won't play on some devices

**Solution:** Always add `-pix_fmt yuv420p`:
```bash
ffmpeg -framerate 8 -i frames_%05d.png \
  -pix_fmt yuv420p \
  output.mp4
```

### Issue: Video is too large

**Solutions:**

1. **Increase CRF** (lower quality):
   ```bash
   ffmpeg -framerate 8 -i frames_%05d.png -crf 28 output.mp4
   ```

2. **Reduce resolution**:
   ```bash
   ffmpeg -framerate 8 -i frames_%05d.png \
     -vf "scale=512:-1" \
     output.mp4
   ```

3. **Two-pass encoding** (best compression):
   ```bash
   # Pass 1
   ffmpeg -framerate 8 -i frames_%05d.png \
     -c:v libx264 -b:v 2M -pass 1 -f mp4 /dev/null
   
   # Pass 2
   ffmpeg -framerate 8 -i frames_%05d.png \
     -c:v libx264 -b:v 2M -pass 2 output.mp4
   ```

### Issue: "Overwrite output file?"

**Solution:** Add `-y` flag to auto-overwrite:
```bash
ffmpeg -framerate 8 -i frames_%05d.png output.mp4 -y
```

### Issue: Frames start at different number

**Solution:** Use `-start_number`:
```bash
# If frames start at 100
ffmpeg -framerate 8 -start_number 100 -i frames_%05d.png output.mp4
```

## 📊 Quick Reference

### Recommended Settings by Use Case

**Benchmark Archive (High Quality):**
```bash
ffmpeg -framerate 8 -i frames_%05d.png \
  -c:v libx264 -crf 18 -preset slow \
  -pix_fmt yuv420p archive.mp4
```

**Web Upload (Balanced):**
```bash
ffmpeg -framerate 8 -i frames_%05d.png \
  -c:v libx264 -crf 23 -preset medium \
  -pix_fmt yuv420p web_upload.mp4
```

**Quick Preview (Fast):**
```bash
ffmpeg -framerate 8 -i frames_%05d.png \
  -c:v libx264 -crf 28 -preset fast \
  -pix_fmt yuv420p preview.mp4
```

**Social Media (Instagram, Twitter):**
```bash
ffmpeg -framerate 8 -i frames_%05d.png \
  -c:v libx264 -crf 23 \
  -vf "scale=1080:-1" \
  -pix_fmt yuv420p social.mp4
```

## 🔗 Resources

- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [H.264 Encoding Guide](https://trac.ffmpeg.org/wiki/Encode/H.264)
- [FFmpeg Filters](https://ffmpeg.org/ffmpeg-filters.html)

## 📝 Common Patterns

### Frame Pattern Naming

| File Format | FFmpeg Pattern | Example |
|-------------|----------------|---------|
| `frame_1.png` | `frame_%d.png` | No leading zeros |
| `frame_001.png` | `frame_%03d.png` | 3 digits |
| `frame_00001.png` | `frame_%05d.png` | 5 digits |
| `text2video_00001_.png` | `text2video_%05d_.png` | With suffix underscore |

### File Size Estimates (25 frames, 1024x576)

| CRF | Preset | Approximate Size |
|-----|--------|------------------|
| 18 | slow | 80-120 MB |
| 23 | medium | 25-40 MB |
| 28 | fast | 12-20 MB |
| 32 | ultrafast | 5-10 MB |

---

**Version:** 1.0.0  
**Last Updated:** January 2026  
**For:** ComfyUI Text-to-Video Benchmark
