#!/bin/bash
kubectl -n vault create secret generic consul-gossip-encryption-key --from-literal=key=$(docker run --rm -it consul:1.8.0 consul keygen)
