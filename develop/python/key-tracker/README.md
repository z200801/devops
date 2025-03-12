# Key tracker for sites

# Docs

Used

- frontend: react
- backend: python fastapi
- db: postgresql
- nginx

# Issues

- [ ] Create Makefile for build, create, upgrade

## Start project

```sh
#!/bin/bash

_pr_name="key_tr_prod"
for i in build create; do docker compose -p "${_pr_name}" ${i}; done
docker compose -p "${_pr_name}" up -d
```

In browser open: `http://localhost:18180`
