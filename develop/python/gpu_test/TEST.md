```sh
python comfyui-benchmark.py \
  --checkpoint "sd_xl_base_1.0.safetensors" \
  --steps 20 \
  --resolution 1024 \
  --iterations 10 \
  --server http://localhost:18188 \
  --output h100_sdxl_base.json
```
