#!/usr/bin/env python3
"""
Convert benchmark frames to video files
"""

import subprocess
import argparse
from pathlib import Path
import sys

def frames_to_video(input_pattern, output_file, fps=8, quality="high"):
    """
    Convert image sequence to video using ffmpeg
    
    Args:
        input_pattern: Pattern for input files (e.g., "text2video_%05d_.png")
        output_file: Output video filename (e.g., "output.mp4")
        fps: Frames per second (default: 8)
        quality: 'high', 'medium', or 'low' (affects file size)
    """
    
    # Quality presets
    quality_settings = {
        "high": ["-crf", "18", "-preset", "slow"],
        "medium": ["-crf", "23", "-preset", "medium"],
        "low": ["-crf", "28", "-preset", "fast"]
    }
    
    crf_settings = quality_settings.get(quality, quality_settings["medium"])
    
    # Build ffmpeg command
    cmd = [
        "ffmpeg",
        "-y",  # Overwrite output file
        "-framerate", str(fps),
        "-i", input_pattern,
        "-c:v", "libx264",  # H.264 codec
        "-pix_fmt", "yuv420p",  # Compatibility
        *crf_settings,
        output_file
    ]
    
    print(f"Converting frames to video...")
    print(f"Command: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(f"✓ Video created: {output_file}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ Error: {e}")
        print(f"stderr: {e.stderr}")
        return False

def batch_convert(input_dir, output_dir, fps=8, format="mp4"):
    """
    Convert all frame sequences in directory to videos
    """
    import os
    from collections import defaultdict
    
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    # Group frames by sequence
    sequences = defaultdict(list)
    
    for frame in sorted(input_path.glob("*.png")):
        # Extract sequence name (everything before the number)
        name_parts = frame.stem.rsplit('_', 1)
        if len(name_parts) == 2:
            seq_name = name_parts[0]
            sequences[seq_name].append(frame)
    
    print(f"Found {len(sequences)} video sequences")
    
    for seq_name, frames in sequences.items():
        print(f"\n📹 Processing: {seq_name} ({len(frames)} frames)")
        
        # Determine pattern
        first_frame = frames[0]
        pattern = str(first_frame.parent / f"{seq_name}_%05d_.png")
        
        output_file = output_path / f"{seq_name}.{format}"
        
        frames_to_video(pattern, str(output_file), fps=fps)

def main():
    parser = argparse.ArgumentParser(
        description='Convert frame sequences to video files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert single sequence
  python frames_to_video.py --input "text2video_%05d_.png" --output video.mp4 --fps 8
  
  # Batch convert all sequences in directory
  python frames_to_video.py --batch-dir ./benchmark_videos --output-dir ./videos --fps 8
  
  # High quality conversion
  python frames_to_video.py --input "frames_%05d.png" --output video.mp4 --quality high
        """
    )
    
    parser.add_argument('--input', help='Input frame pattern (e.g., frame_%05d.png)')
    parser.add_argument('--output', help='Output video file (e.g., video.mp4)')
    parser.add_argument('--fps', type=int, default=8, help='Frames per second (default: 8)')
    parser.add_argument('--quality', choices=['high', 'medium', 'low'], default='medium',
                       help='Video quality (default: medium)')
    
    parser.add_argument('--batch-dir', help='Directory with frame sequences (batch mode)')
    parser.add_argument('--output-dir', default='videos', help='Output directory for batch mode')
    parser.add_argument('--format', default='mp4', choices=['mp4', 'webm', 'avi'],
                       help='Output format (default: mp4)')
    
    args = parser.parse_args()
    
    # Show help if no arguments
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)
    
    # Check if ffmpeg is available
    try:
        subprocess.run(['ffmpeg', '-version'], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Error: ffmpeg not found. Please install ffmpeg:")
        print("  Ubuntu/Debian: sudo apt install ffmpeg")
        print("  Mac: brew install ffmpeg")
        print("  Windows: Download from https://ffmpeg.org/")
        sys.exit(1)
    
    # Batch mode
    if args.batch_dir:
        batch_convert(args.batch_dir, args.output_dir, fps=args.fps, format=args.format)
    
    # Single conversion
    elif args.input and args.output:
        frames_to_video(args.input, args.output, fps=args.fps, quality=args.quality)
    
    else:
        print("Error: Either specify --input and --output, or use --batch-dir")
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()
