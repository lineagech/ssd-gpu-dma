#!/bin/bash

set -e

NVM_INT_BIN=$(find ~/p2p-research/ssd-gpu-dma -name nvm-integrity-util)
echo "nvm-integrity-util found @ ${NVM_INT_BIN} --- "

READ_BYTES=(4096 65536 524288 1048576 4194304 16777216 536870912)
NUM_OF_QUEUES=(1 8 32)

for read_bytes in "${READ_BYTES[@]}"
do
  for num_of_queues in "${NUM_OF_QUEUES[@]}"
  do
    if [[ $((${read_bytes} / ${num_of_queues})) -lt 512 ]]; then
      continue
    fi
    sudo ${NVM_INT_BIN} \
      --ctrl=/dev/libnvm0 \
      --read=${read_bytes} \
      -q ${num_of_queues} \
      /tmp/nvm-integrity-output
      
      #echo "${read_bytes}"
      wait $!
      sleep 1
  done
done
