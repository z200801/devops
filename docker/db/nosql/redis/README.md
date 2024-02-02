[[_TOC_]]

# Redis

## Url's
 - https://habr.com/ru/companies/wunderfund/articles/685894/

## Install tools
```shell
apt install -y redis-tools
```
## Use

### Connect
```shell
redis-cli -h localhost -p 6379
```
## Useful commands
```
SET m1 "Hello world"
GET m1
```
Dict
```
HMSET mydict name John age 30 city NewYor
HGETALL mydict
```
Hash
```
HMSET myhash field1 value1 field2 value2 field3 value3
HGETALL myhash
```

List
```
RPUSH mylist value1 value2 value3
LRANGE mylist 0 -1
```
