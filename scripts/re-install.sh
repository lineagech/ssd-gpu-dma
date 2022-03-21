#!/bin/bash                                                                        
set -e                                                                   
 
TARGET_DIR="/export/home2"
CSL_HOME="/home/csl/cuc1057"

if [[ -d "${TARGET_DIR}" ]]                                                              
then
  if [[ ! -z $(lsblk -l | grep "${TARGET_DIR}") ]]; then
    ret=$(umount "${TARGET_DIR}")
  fi
fi

./install-libnvm.sh
echo -n "0000:64:00.0" | sudo tee /sys/bus/pci/drivers/nvme/unbind
echo -n "0000:64:00.0" | sudo tee /sys/bus/pci/drivers/libnvm/bind

sudo chmod 777 /dev/libnvm0

NVM_IDENTIFY_BIN=$(find ${TARGET_DIR}/p2p-research -name "nvm-identify")
if [[ ! -z "${NVM_IDENTIFY_BIN}" ]]
then  
  ${NVM_IDENTIFY_BIN} --ctrl=/dev/libnvm0
fi
