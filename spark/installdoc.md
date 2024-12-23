### 开发机器装spark,作为driver，不用启动，脚本里注释掉sh spark_init.sh 

## spark 配置
1、节点互通
    保证master与所有worker互通
        检查防火墙配置

    保证driver与master、worker互通
        driver即启动sprak-context的进程，如bdp-datasource-service和bdp-analysis-service
        除防火墙配置外需要特别注意，如果启动driver的机器配置了hostname，需要保证worker节点可以通过hostname连接driver（原因是worker启动的executor会去连driver），
        方法是在/etc/hosts中增加ip到hostname的映射，如 172.16.130.116 Node-04  如果dns能保证hostname转换为ip，可不配置


2、配置.bashrc
    需要配置的节点
        所有节点

    至少需要配置以下两项
    export SPARK_HOME='/home/aiit-zhyl/spark/spark-3.0.0-bin-hadoop3.2'
    export PYSPARK_PYTHON=python3

    其中python3是executor执行python代码时，启动python代理时用的python路径


3、配置python
    需要配置的节点
        所有driver（启动模式为local的driver节点）

    所有节点python版本必须一致
    需要装的依赖库参见：data-platform\tools\algorithm\data-platform-algorithm\requirements.txt


4、配置/tmp清理规则
    需要配置的节点
        master
        所有worker
        启动模式为local的driver节点

    spark运行时，会在/tmp目录生成一些资源目录，这些目录不可在spark运行是删除，所以需要配置centos清理规则以防被误删
    方法：修改/usr/lib/tmpfiles.d/tmp.conf，添加如下几行

    x /tmp/blockmgr-*
    x /tmp/spark-*

    参考地址：https://www.cnblogs.com/samtech/p/9490166.html


5、配置节点ip
    需要配置的节点
        master
        所有worker

    /home/aiit-zhyl/spark/spark-3.0.0-bin-hadoop3.2/conf
    cp spark-env.sh.template spark-env.sh
    添加如下配置
    export SPARK_LOCAL_IP=172.16.130.117   其中ip根据机器修改


6、配置master
    在spark-env.sh中添加如下配置
    export SPARK_MASTER_HOST=172.16.130.116 其中ip根据机器修改

    cp slaves.template slaves并添加所有worker的ip，例如：
    172.16.130.116
    172.16.130.117


7、需要的jar包
    目前使用了mongo-spark，所以需要将相关jar包放到spark目录下，路径是
    /home/aiit-zhyl/spark/spark-3.0.0-bin-hadoop3.2/jars/

    可以从10.0.108.12上下载打包好的spark.tgz,里面已经包括了mongo-spark的jar包，如下几个

    org.mongodb_bson-4.0.5.jar
    org.mongodb_mongodb-driver-core-4.0.5.jar
    org.mongodb_mongodb-driver-sync-4.0.5.jar
    org.mongodb.spark_mongo-spark-connector_2.12-3.0.0.jar

    后期若用到了其它的jar，也需要将jar copy在所有节点的/home/aiit-zhyl/spark/spark-3.0.0-bin-hadoop3.2/jars/目录下

    bdp-custom-udf-1.0.6-SNAPSHOT.jar不需要手动copy，driver会自动分发


8、启动与停止
    脚本目录  /home/aiit-zhyl/spark/spark-3.0.0-bin-hadoop3.2/sbin
    start-all.sh  启动master与worker
    stop-all.sh 停止master与worker
    注 停止master会导致driver里的spark context 关闭，目前没做重连机制，需要重启driver

    start-slaves.sh 启动所有worker
    stop-slaves.sh 停止所有worker

    注：停止worker会停止对应节点上 worker管理的所有executor，这可能导致driver中的计算任务失败，除非被停掉某个worker之后计算资源依然足够，则spark能重试成功


9、相关日志所在位置
    /home/aiit-zhyl/spark/spark-3.0.0-bin-hadoop3.2/logs
    此目录下有master与worker的日志

    /home/aiit-zhyl/spark/spark-3.0.0-bin-hadoop3.2/work
    此目录下有executor的日志，executor是按app名归类的，driver启动时会分配一个app名，一个app会有多个executor

    master的管理UI地址 http://[master-ip]:8080
    web上有很多监控信息，包括日志，可以查bug