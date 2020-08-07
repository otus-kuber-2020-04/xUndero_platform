#!/bin/bash
kubectl -n vault create configmap nginxconfigmap --from-file=default.conf
