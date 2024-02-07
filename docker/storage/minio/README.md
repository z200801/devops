[[_TOC_]]

# Minio for docker-compose

## Url's
 - https://github.com/minio/minio/blob/master/docs/docker/README.md
 - https://www.digitalocean.com/community/tutorials/how-to-set-up-an-object-storage-server-using-minio-on-ubuntu-18-04-ru
 - https://docs.github.com/ru/enterprise-server@3.10/admin/packages/quickstart-for-configuring-your-minio-storage-bucket-for-github-packages

## init

`docker-compose.yaml`
```yaml
version: '3.7'

services:
 minio:
   image: minio/minio:latest
   command: server --console-address ":9001" /data/
   ports:
     - "9000:9000"
     - "9001:9001"
   environment:
     MINIO_ROOT_USER: ozontech
     MINIO_ROOT_PASSWORD: minio123
   volumes:
     - minio-storage:/data
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
     interval: 30s
     timeout: 20s
     retries: 3
volumes:
 minio-storage:
```
## Run
```shell
docker compose up -d
```

## Use
Get http://localhost:9000
