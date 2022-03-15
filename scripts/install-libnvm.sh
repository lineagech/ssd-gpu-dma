#!/bin/bash


LIBNVM_PATH="/home/csl/cuc1057/p2p_research/ssd-gpu-dma/build/module/libnvm.ko"

sudo rmmod libnvm
cp ${LIBNVM_PATH} /tmp
sudo insmod /tmp/libnvm.ko
