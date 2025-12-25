# comfyui_api_test.py
import requests
import time
import json
import sys
import argparse
import uuid

def get_available_checkpoints(server_address="http://localhost:8188"):
    """Отримує список доступних моделей"""
    try:
        response = requests.get(f"{server_address}/object_info/CheckpointLoaderSimple")
        response.raise_for_status()
        data = response.json()
        checkpoints = data["CheckpointLoaderSimple"]["input"]["required"]["ckpt_name"][0]
        return checkpoints
    except Exception as e:
        print(f"Error getting checkpoints: {e}")
        return []

def get_workflow_template(checkpoint_name="SDXL/sd_xl_base_1.0.safetensors"):
    """Базовий SDXL workflow template"""
    return {
        "prompt": {
            "3": {
                "inputs": {
                    "seed": 1,
                    "steps": 20,
                    "cfg": 7,
                    "sampler_name": "dpmpp_2m",
                    "scheduler": "karras",
                    "denoise": 1,
                    "model": ["4", 0],
                    "positive": ["6", 0],
                    "negative": ["7", 0],
                    "latent_image": ["5", 0]
                },
                "class_type": "KSampler"
            },
            "4": {
                "inputs": {
                    "ckpt_name": checkpoint_name
                },
                "class_type": "CheckpointLoaderSimple"
            },
            "5": {
                "inputs": {
                    "width": 1024,
                    "height": 1024,
                    "batch_size": 1
                },
                "class_type": "EmptyLatentImage"
            },
            "6": {
                "inputs": {
                    "text": "beautiful scenery nature glass bottle landscape, purple galaxy bottle",
                    "clip": ["4", 1]
                },
                "class_type": "CLIPTextEncode"
            },
            "7": {
                "inputs": {
                    "text": "text, watermark",
                    "clip": ["4", 1]
                },
                "class_type": "CLIPTextEncode"
            },
            "8": {
                "inputs": {
                    "samples": ["3", 0],
                    "vae": ["4", 2]
                },
                "class_type": "VAEDecode"
            },
            "9": {
                "inputs": {
                    "filename_prefix": "ComfyUI",
                    "images": ["8", 0]
                },
                "class_type": "SaveImage"
            }
        }
    }

def queue_prompt(prompt_workflow, server_address="http://localhost:8188"):
    """Відправляє workflow до ComfyUI queue"""
    p = {"prompt": prompt_workflow, "client_id": str(uuid.uuid4())}
    data = json.dumps(p).encode('utf-8')
    
    try:
        response = requests.post(f"{server_address}/prompt", data=data)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error queuing prompt: {e}")
        if hasattr(e.response, 'text'):
            print(f"Response: {e.response.text}")
        return None

def get_history(prompt_id, server_address="http://localhost:8188"):
    """Отримує історію виконання"""
    try:
        response = requests.get(f"{server_address}/history/{prompt_id}")
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error getting history: {e}")
        return None

def wait_for_completion(prompt_id, server_address="http://localhost:8188", timeout=300):
    """Чекає завершення генерації"""
    start_time = time.time()
    
    while True:
        if time.time() - start_time > timeout:
            print(f"Timeout after {timeout} seconds")
            return False
            
        history = get_history(prompt_id, server_address)
        
        if history and prompt_id in history:
            # Перевіряємо чи завершено
            status = history[prompt_id].get("status", {})
            if status.get("completed", False):
                return True
            elif "error" in status:
                print(f"Error in execution: {status['error']}")
                return False
        
        time.sleep(0.5)
    
    return False

def run_workflow(workflow_data, server_address="http://localhost:8188"):
    """Запускає workflow і вимірює час виконання"""
    start = time.time()
    
    # Queue the workflow
    result = queue_prompt(workflow_data["prompt"], server_address)
    
    if not result or "prompt_id" not in result:
        print("Failed to queue workflow")
        return None
    
    prompt_id = result["prompt_id"]
    print(f"Queued with ID: {prompt_id}")
    
    # Wait for completion
    if not wait_for_completion(prompt_id, server_address):
        print("Workflow failed or timed out")
        return None
    
    end = time.time()
    execution_time = end - start
    
    return execution_time

def select_checkpoint(checkpoints, preferred=None):
    """Вибирає найкращий checkpoint для тестування"""
    if preferred and preferred in checkpoints:
        return preferred
    
    # Пріоритет: SDXL models
    sdxl_models = [cp for cp in checkpoints if 'SDXL/' in cp or 'XL/' in cp]
    
    if sdxl_models:
        # Віддаємо перевагу базовій моделі
        for model in sdxl_models:
            if 'sd_xl_base_1.0' in model:
                return model
        return sdxl_models[0]
    
    # Якщо немає SDXL, використовуємо SD 1.5
    sd15_models = [cp for cp in checkpoints if 'SD1.5/' in cp or 'v1-5' in cp]
    if sd15_models:
        return sd15_models[0]
    
    # Інакше перша доступна
    return checkpoints[0] if checkpoints else None

def run_benchmark(num_iterations=5, steps=20, resolution=1024, 
                 server_address="http://localhost:8188", checkpoint=None):
    """Запускає benchmark тест"""
    
    # Отримуємо доступні моделі
    print("Fetching available checkpoints...")
    checkpoints = get_available_checkpoints(server_address)
    
    if not checkpoints:
        print("❌ No checkpoints found!")
        return None
    
    print(f"Found {len(checkpoints)} checkpoints")
    
    # Вибираємо checkpoint
    selected_checkpoint = select_checkpoint(checkpoints, checkpoint)
    
    if not selected_checkpoint:
        print("❌ Could not select a checkpoint!")
        return None
    
    print(f"\n{'='*60}")
    print(f"ComfyUI Benchmark Test")
    print(f"{'='*60}")
    print(f"Server:       {server_address}")
    print(f"Checkpoint:   {selected_checkpoint}")
    print(f"Iterations:   {num_iterations}")
    print(f"Steps:        {steps}")
    print(f"Resolution:   {resolution}x{resolution}")
    print(f"{'='*60}\n")
    
    # Отримуємо базовий workflow
    workflow = get_workflow_template(selected_checkpoint)
    
    # Оновлюємо параметри
    workflow["prompt"]["3"]["inputs"]["steps"] = steps
    workflow["prompt"]["5"]["inputs"]["width"] = resolution
    workflow["prompt"]["5"]["inputs"]["height"] = resolution
    
    times = []
    
    for i in range(num_iterations):
        print(f"\nIteration {i+1}/{num_iterations}...")
        
        # Змінюємо seed для кожної ітерації
        workflow["prompt"]["3"]["inputs"]["seed"] = i + 1
        
        execution_time = run_workflow(workflow, server_address)
        
        if execution_time is None:
            print(f"⚠️  Iteration {i+1} failed")
            continue
        
        if i == 0:
            print(f"⏱️  Warm-up: {execution_time:.2f}s (skipped from average)")
        else:
            times.append(execution_time)
            print(f"✅ Time: {execution_time:.2f}s")
    
    if not times:
        print("\n❌ All iterations failed!")
        return None
    
    # Статистика
    avg_time = sum(times) / len(times)
    min_time = min(times)
    max_time = max(times)
    
    print(f"\n{'='*60}")
    print(f"RESULTS")
    print(f"{'='*60}")
    print(f"Checkpoint:       {selected_checkpoint}")
    print(f"Average time:     {avg_time:.2f}s")
    print(f"Min time:         {min_time:.2f}s")
    print(f"Max time:         {max_time:.2f}s")
    print(f"Images/minute:    {60/avg_time:.2f}")
    print(f"Iterations/sec:   {steps/avg_time:.2f} it/s")
    print(f"{'='*60}\n")
    
    return {
        "checkpoint": selected_checkpoint,
        "avg_time": avg_time,
        "min_time": min_time,
        "max_time": max_time,
        "images_per_minute": 60/avg_time,
        "iterations_per_sec": steps/avg_time,
        "all_times": times,
        "steps": steps,
        "resolution": resolution
    }

def list_checkpoints(server_address="http://localhost:8188"):
    """Виводить список доступних моделей"""
    print("Available checkpoints:")
    checkpoints = get_available_checkpoints(server_address)
    
    for i, cp in enumerate(checkpoints, 1):
        print(f"  {i}. {cp}")
    
    return checkpoints

def main():
    parser = argparse.ArgumentParser(description='ComfyUI Benchmark Test')
    parser.add_argument('--server', default='http://localhost:8188', 
                       help='ComfyUI server address (default: http://localhost:8188)')
    parser.add_argument('--iterations', type=int, default=5,
                       help='Number of test iterations (default: 5)')
    parser.add_argument('--steps', type=int, default=20,
                       help='Number of sampling steps (default: 20)')
    parser.add_argument('--resolution', type=int, default=1024,
                       help='Image resolution (default: 1024)')
    parser.add_argument('--checkpoint', type=str, default=None,
                       help='Specific checkpoint to use')
    parser.add_argument('--list', action='store_true',
                       help='List available checkpoints and exit')
    parser.add_argument('--output', type=str, default=None,
                       help='Output JSON file for results')
    
    args = parser.parse_args()
    
    # Перевірка доступності сервера
    try:
        response = requests.get(f"{args.server}/system_stats")
        response.raise_for_status()
        print(f"✅ ComfyUI server is reachable at {args.server}\n")
    except requests.exceptions.RequestException:
        print(f"❌ Cannot connect to ComfyUI server at {args.server}")
        print("   Make sure ComfyUI is running and accessible")
        sys.exit(1)
    
    # Якщо потрібен тільки список моделей
    if args.list:
        list_checkpoints(args.server)
        sys.exit(0)
    
    # Запуск benchmark
    results = run_benchmark(
        num_iterations=args.iterations,
        steps=args.steps,
        resolution=args.resolution,
        server_address=args.server,
        checkpoint=args.checkpoint
    )
    
    # Збереження результатів
    if args.output and results:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"📄 Results saved to {args.output}")

if __name__ == "__main__":
    main()
