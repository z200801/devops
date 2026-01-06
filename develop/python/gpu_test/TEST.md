```sh
python comfyui-benchmark.py \
  --checkpoint "sd_xl_base_1.0.safetensors" \
  --steps 20 \
  --resolution 1024 \
  --iterations 10 \
  --server http://localhost:8188 \
  --output h100_sdxl_base.json
```

## SVD XT
```sh
python comfyui-svd_xt-benchmark.py 127.0.0.1:8188 \
  --image-checkpoint sd_xl_base_1.0.safetensors \
  --video-checkpoint svd_xt.safetensors \
  --frames 25 \
  --width 1024 \
  --height 576 \
  --steps 20 \
  --fps 8 \
  --motion-bucket-id 127 \
  --iterations 10 \
  --output full_benchmark.json
```
