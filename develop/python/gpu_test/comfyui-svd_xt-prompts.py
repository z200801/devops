#!/usr/bin/env python3
"""
Text-to-Video Benchmark Script for ComfyUI (SDXL + SVD-XT)
With support for loading prompts from file
Usage: python text2video_benchmark.py SERVER:PORT [OPTIONS]
"""

import json
import time
import requests
import random
import argparse
import sys
from pathlib import Path

class TextToVideoBenchmark:
    def __init__(self, 
                 server_url,
                 image_checkpoint="sd_xl_base_1.0.safetensors",
                 video_checkpoint="svd_xt.safetensors",
                 video_frames=25,
                 width=1024,
                 height=576,
                 steps=20,
                 motion_bucket_id=127,
                 fps=8):
        
        self.server_url = server_url
        self.image_checkpoint = image_checkpoint
        self.video_checkpoint = video_checkpoint
        self.video_frames = video_frames
        self.width = width
        self.height = height
        self.steps = steps
        self.motion_bucket_id = motion_bucket_id
        self.fps = fps
        
    def load_prompts_from_file(self, filepath):
        """
        Load prompts from file
        Supports: TXT (one per line), JSON (array or object), CSV
        """
        filepath = Path(filepath)
        
        if not filepath.exists():
            raise FileNotFoundError(f"Prompt file not found: {filepath}")
        
        # Detect file type and load accordingly
        if filepath.suffix.lower() == '.json':
            return self._load_json_prompts(filepath)
        elif filepath.suffix.lower() == '.csv':
            return self._load_csv_prompts(filepath)
        else:  # Default to txt
            return self._load_txt_prompts(filepath)
    
    def _load_txt_prompts(self, filepath):
        """Load prompts from text file (one per line)"""
        prompts = []
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                # Skip empty lines and comments
                if line and not line.startswith('#'):
                    prompts.append(line)
        
        if not prompts:
            raise ValueError(f"No prompts found in {filepath}")
        
        print(f"Loaded {len(prompts)} prompts from {filepath}")
        return prompts
    
    def _load_json_prompts(self, filepath):
        """Load prompts from JSON file"""
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Handle different JSON structures
        if isinstance(data, list):
            # Simple array: ["prompt1", "prompt2", ...]
            prompts = data
        elif isinstance(data, dict):
            # Object with prompts key: {"prompts": ["prompt1", ...]}
            if 'prompts' in data:
                prompts = data['prompts']
            # Object with numbered keys: {"1": "prompt1", "2": "prompt2", ...}
            else:
                prompts = [data[key] for key in sorted(data.keys())]
        else:
            raise ValueError(f"Unsupported JSON structure in {filepath}")
        
        if not prompts:
            raise ValueError(f"No prompts found in {filepath}")
        
        print(f"Loaded {len(prompts)} prompts from {filepath}")
        return prompts
    
    def _load_csv_prompts(self, filepath):
        """Load prompts from CSV file"""
        import csv
        
        prompts = []
        with open(filepath, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            
            # Check if first row is header
            first_row = next(reader)
            if first_row and first_row[0].lower() in ['prompt', 'prompts', 'text', 'description']:
                # Skip header
                pass
            else:
                # First row is data
                if first_row and first_row[0].strip():
                    prompts.append(first_row[0].strip())
            
            # Read remaining rows
            for row in reader:
                if row and row[0].strip():
                    prompts.append(row[0].strip())
        
        if not prompts:
            raise ValueError(f"No prompts found in {filepath}")
        
        print(f"Loaded {len(prompts)} prompts from {filepath}")
        return prompts
    
    def get_available_checkpoints(self):
        """Get list of available checkpoints"""
        try:
            response = requests.get(f"{self.server_url}/object_info/CheckpointLoaderSimple")
            if response.status_code == 200:
                data = response.json()
                if "CheckpointLoaderSimple" in data and "input" in data["CheckpointLoaderSimple"]:
                    required = data["CheckpointLoaderSimple"]["input"]["required"]
                    if "ckpt_name" in required and len(required["ckpt_name"]) > 0:
                        return required["ckpt_name"][0]
            return []
        except Exception as e:
            print(f"Warning: Could not fetch checkpoint list: {e}")
            return []
    
    def queue_prompt(self, workflow):
        """Queue a workflow and return prompt_id"""
        response = requests.post(f"{self.server_url}/prompt", json=workflow)
        if response.status_code != 200:
            raise Exception(f"Error queueing prompt: {response.text}")
        return response.json()["prompt_id"]
    
    def wait_for_completion(self, prompt_id, timeout=600):
        """Wait for workflow to complete"""
        start_time = time.time()
        
        while True:
            if time.time() - start_time > timeout:
                raise TimeoutError(f"Workflow timed out after {timeout}s")
            
            history_response = requests.get(f"{self.server_url}/history/{prompt_id}")
            history = history_response.json()
            
            if prompt_id in history:
                if "outputs" in history[prompt_id]:
                    return history[prompt_id]
            
            time.sleep(0.5)
    
    def generate_complete_workflow(self, prompt, seed):
        """Generate complete text-to-video workflow"""
        workflow = {
            # SDXL Image Generation
            "1": {
                "inputs": {"ckpt_name": self.image_checkpoint},
                "class_type": "CheckpointLoaderSimple"
            },
            "2": {
                "inputs": {
                    "text": prompt,
                    "clip": ["1", 1]
                },
                "class_type": "CLIPTextEncode"
            },
            "3": {
                "inputs": {
                    "text": "text, watermark, low quality, blurry, distorted, ugly",
                    "clip": ["1", 1]
                },
                "class_type": "CLIPTextEncode"
            },
            "4": {
                "inputs": {
                    "width": self.width,
                    "height": self.height,
                    "batch_size": 1
                },
                "class_type": "EmptyLatentImage"
            },
            "5": {
                "inputs": {
                    "seed": seed,
                    "steps": self.steps,
                    "cfg": 7.0,
                    "sampler_name": "dpmpp_2m",
                    "scheduler": "karras",
                    "denoise": 1.0,
                    "model": ["1", 0],
                    "positive": ["2", 0],
                    "negative": ["3", 0],
                    "latent_image": ["4", 0]
                },
                "class_type": "KSampler"
            },
            "6": {
                "inputs": {
                    "samples": ["5", 0],
                    "vae": ["1", 2]
                },
                "class_type": "VAEDecode"
            },
            # SVD-XT Video Generation
            "10": {
                "inputs": {"ckpt_name": self.video_checkpoint},
                "class_type": "ImageOnlyCheckpointLoader"
            },
            "11": {
                "inputs": {
                    "width": self.width,
                    "height": self.height,
                    "video_frames": self.video_frames,
                    "motion_bucket_id": self.motion_bucket_id,
                    "fps": self.fps,
                    "augmentation_level": 0.0,
                    "clip_vision": ["10", 1],
                    "init_image": ["6", 0],
                    "vae": ["10", 2]
                },
                "class_type": "SVD_img2vid_Conditioning"
            },
            "12": {
                "inputs": {
                    "seed": seed + 1,
                    "steps": self.steps,
                    "cfg": 2.5,
                    "sampler_name": "euler",
                    "scheduler": "karras",
                    "denoise": 1.0,
                    "model": ["10", 0],
                    "positive": ["11", 0],
                    "negative": ["11", 1],
                    "latent_image": ["11", 2]
                },
                "class_type": "KSampler"
            },
            "13": {
                "inputs": {
                    "samples": ["12", 0],
                    "vae": ["10", 2]
                },
                "class_type": "VAEDecode"
            },
            "14": {
                "inputs": {
                    "filename_prefix": "text2video",
                    "images": ["13", 0]
                },
                "class_type": "SaveImage"
            }
        }
        
        return {"prompt": workflow}
    
    def run_benchmark(self, iterations=5, output_file="text2video_benchmark.json", prompts=None, prompt_file=None):
        """Run text-to-video benchmark"""
        
        # Load prompts from file if specified
        if prompt_file:
            try:
                prompts = self.load_prompts_from_file(prompt_file)
            except Exception as e:
                print(f"Error loading prompts from file: {e}")
                sys.exit(1)
        
        # Use default prompts if none provided
        if not prompts:
            prompts = [
                "A serene mountain landscape with a flowing river, cinematic lighting",
                "Ocean waves gently crashing on a sandy beach at golden hour",
                "A peaceful forest path with sunlight filtering through tall trees",
                "Desert landscape with rolling sand dunes under a clear blue sky",
                "A tranquil lake surrounded by autumn colored trees, misty morning"
            ]
            print("Using default prompts (no prompt file specified)")
        
        print(f"\n{'='*70}")
        print(f"TEXT-TO-VIDEO BENCHMARK")
        print(f"{'='*70}")
        print(f"Server: {self.server_url}")
        print(f"Image Model: {self.image_checkpoint}")
        print(f"Video Model: {self.video_checkpoint}")
        print(f"Resolution: {self.width}x{self.height}")
        print(f"Video Frames: {self.video_frames}")
        print(f"Steps: {self.steps}")
        print(f"FPS: {self.fps}")
        print(f"Motion Bucket ID: {self.motion_bucket_id}")
        print(f"Iterations: {iterations}")
        print(f"Prompts available: {len(prompts)}")
        if prompt_file:
            print(f"Prompt file: {prompt_file}")
        print(f"{'='*70}\n")
        
        all_times = []
        used_prompts = []
        
        for i in range(iterations):
            # Cycle through prompts
            prompt = prompts[i % len(prompts)]
            used_prompts.append(prompt)
            
            seed = random.randint(0, 2**32 - 1)
            
            print(f"Iteration {i+1}/{iterations}")
            print(f"  Prompt: {prompt[:60]}{'...' if len(prompt) > 60 else ''}")
            print(f"  Seed: {seed}")
            
            workflow = self.generate_complete_workflow(prompt, seed)
            
            start_time = time.time()
            
            try:
                prompt_id = self.queue_prompt(workflow)
                print(f"  Queued: {prompt_id}")
                
                result = self.wait_for_completion(prompt_id, timeout=600)
                
                elapsed = time.time() - start_time
                all_times.append(elapsed)
                
                fps_generation = self.video_frames / elapsed
                
                print(f"  ✓ Completed in {elapsed:.2f}s")
                print(f"  ✓ Generation FPS: {fps_generation:.2f} frames/sec")
                print(f"  ✓ Time per frame: {elapsed/self.video_frames:.3f}s")
                print()
                
            except Exception as e:
                print(f"  ✗ Error: {e}\n")
                continue
        
        if not all_times:
            print("No successful iterations!")
            return None
        
        # Calculate statistics
        avg_time = sum(all_times) / len(all_times)
        min_time = min(all_times)
        max_time = max(all_times)
        
        variance = sum((t - avg_time) ** 2 for t in all_times) / len(all_times)
        std_dev = variance ** 0.5
        
        avg_fps = self.video_frames / avg_time
        videos_per_min = 60 / avg_time
        time_per_frame = avg_time / self.video_frames
        
        results = {
            "image_checkpoint": self.image_checkpoint,
            "video_checkpoint": self.video_checkpoint,
            "video_frames": self.video_frames,
            "resolution": f"{self.width}x{self.height}",
            "steps": self.steps,
            "fps": self.fps,
            "motion_bucket_id": self.motion_bucket_id,
            "iterations": len(all_times),
            "prompts_used": used_prompts if prompt_file else None,
            "prompt_file": str(prompt_file) if prompt_file else None,
            "avg_time": avg_time,
            "min_time": min_time,
            "max_time": max_time,
            "std_deviation": std_dev,
            "avg_fps_generation": avg_fps,
            "videos_per_minute": videos_per_min,
            "time_per_frame": time_per_frame,
            "all_times": all_times
        }
        
        print(f"{'='*70}")
        print(f"BENCHMARK RESULTS")
        print(f"{'='*70}")
        print(f"Successful iterations: {len(all_times)}/{iterations}")
        print(f"Average time per video: {avg_time:.2f}s")
        print(f"Min/Max time: {min_time:.2f}s / {max_time:.2f}s")
        print(f"Standard deviation: ±{std_dev:.3f}s")
        print(f"Generation FPS: {avg_fps:.2f} frames/sec")
        print(f"Time per frame: {time_per_frame:.3f}s/frame")
        print(f"Videos per minute: {videos_per_min:.2f}")
        print(f"{'='*70}\n")
        
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        print(f"Results saved to: {output_file}")
        
        return results

def parse_server_address(address):
    """Parse SERVER:PORT or http://SERVER:PORT format"""
    if address.startswith('http://') or address.startswith('https://'):
        return address
    
    if ':' in address:
        host, port = address.rsplit(':', 1)
        return f"http://{host}:{port}"
    
    return f"http://{address}:8188"

def main():
    parser = argparse.ArgumentParser(
        description='Text-to-Video Benchmark for ComfyUI (SDXL + SVD-XT)',
        usage='%(prog)s SERVER:PORT [OPTIONS]\n\nExamples:\n'
              '  %(prog)s localhost:8188\n'
              '  %(prog)s 127.0.0.1:8188 --prompts prompts.txt --iterations 10\n'
              '  %(prog)s localhost:8188 --prompts prompts.json --frames 14',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    # Required positional argument
    parser.add_argument('server',
                       metavar='SERVER:PORT',
                       help='ComfyUI server address (e.g., localhost:8188 or 127.0.0.1:8188)')
    
    # Prompt settings
    parser.add_argument('--prompts',
                       dest='prompt_file',
                       help='Path to file with prompts (TXT, JSON, or CSV format)')
    
    # Model settings
    parser.add_argument('--image-checkpoint',
                       default='sd_xl_base_1.0.safetensors',
                       help='SDXL checkpoint for image generation (default: sd_xl_base_1.0.safetensors)')
    
    parser.add_argument('--video-checkpoint',
                       default='svd_xt.safetensors',
                       help='SVD-XT checkpoint for video generation (default: svd_xt.safetensors)')
    
    # Video settings
    parser.add_argument('--frames',
                       type=int,
                       default=25,
                       help='Number of video frames (default: 25)')
    
    parser.add_argument('--width',
                       type=int,
                       default=1024,
                       help='Video width (default: 1024)')
    
    parser.add_argument('--height',
                       type=int,
                       default=576,
                       help='Video height (default: 576)')
    
    parser.add_argument('--steps',
                       type=int,
                       default=20,
                       help='Number of denoising steps (default: 20)')
    
    parser.add_argument('--fps',
                       type=int,
                       default=8,
                       help='Video frames per second (default: 8)')
    
    parser.add_argument('--motion-bucket-id',
                       type=int,
                       default=127,
                       help='Motion intensity 0-255 (default: 127)')
    
    # Benchmark settings
    parser.add_argument('--iterations',
                       type=int,
                       default=5,
                       help='Number of benchmark iterations (default: 5)')
    
    parser.add_argument('--output',
                       default='text2video_benchmark.json',
                       help='Output JSON file (default: text2video_benchmark.json)')
    
    parser.add_argument('--list',
                       action='store_true',
                       help='List available checkpoints and exit')
    
    # Show help if no arguments
    if len(sys.argv) == 1:
        parser.print_help()
        print("\n" + "="*70)
        print("EXAMPLES:")
        print("="*70)
        print("\nBasic usage:")
        print("  python text2video_benchmark.py localhost:8188")
        print("\nWith prompts from file:")
        print("  python text2video_benchmark.py localhost:8188 --prompts my_prompts.txt")
        print("  python text2video_benchmark.py localhost:8188 --prompts prompts.json --iterations 10")
        print("\nQuick test:")
        print("  python text2video_benchmark.py localhost:8188 --prompts test.txt --frames 14 --steps 15")
        print("\nHigh quality:")
        print("  python text2video_benchmark.py localhost:8188 --prompts prompts.txt --steps 30")
        print("\nCustom output:")
        print("  python text2video_benchmark.py localhost:8188 --prompts data.csv --output results.json")
        print()
        sys.exit(0)
    
    args = parser.parse_args()
    
    # Parse server address
    server_url = parse_server_address(args.server)
    
    # Create benchmark instance
    benchmark = TextToVideoBenchmark(
        server_url=server_url,
        image_checkpoint=args.image_checkpoint,
        video_checkpoint=args.video_checkpoint,
        video_frames=args.frames,
        width=args.width,
        height=args.height,
        steps=args.steps,
        motion_bucket_id=args.motion_bucket_id,
        fps=args.fps
    )
    
    # List checkpoints if requested
    if args.list:
        print(f"Connecting to {server_url}...")
        print("\nAvailable checkpoints:")
        checkpoints = benchmark.get_available_checkpoints()
        if checkpoints:
            for cp in checkpoints:
                print(f"  - {cp}")
        else:
            print("  No checkpoints found or server not responding")
        return
    
    # Run benchmark
    benchmark.run_benchmark(
        iterations=args.iterations,
        output_file=args.output,
        prompt_file=args.prompt_file
    )

if __name__ == "__main__":
    main()
