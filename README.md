# installer

### redis 
```
/usr/local/redis/bin/redis-cli -h ip -p port && cluster info && cluster nodes  查看节点信息
 重集群，停掉所有redis, 删除data目录、log目录、pid目录下的文件， 再执行上面命令
```

