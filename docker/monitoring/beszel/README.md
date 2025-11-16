# Beszel monitoring
## Install `beszel`
```sh
make init && \
make version-create version-set-latest version-copy build create start SERVICE=beszel
```
 - Open in browser http://localhost:8090
 - Create `admin` account
 - Settings -> Tokens & Fingerprints - enable `Universal Token`
 - copy `TOKEN`, `KEY`, `HUB_URL` and add it in file `.env` variables
 - start `baszel-agent`
```sh
make build create start SERVICE=baszel-agent
```


