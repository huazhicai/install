#!/bin/sh
# 开机自启

su - gpadmin -c "source /usr/local/greenplum-db/greenplum_path.sh && gpstart -a"