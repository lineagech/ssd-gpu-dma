#!/bin/bash                                                                        
set -e                                                                   
                                                                                
if [[ -d "/mount" ]]                                                              
then
  if [[ ! -z $(lsblk -l | grep "/mount") ]]; then
    ret=$(umount /mount)
  fi
fi

echo -n "0000:64:00.0" | sudo tee /sys/bus/pci/drivers/nvme/unbind
echo -n "0000:64:00.0" | sudo tee /sys/bus/pci/drivers/libnvm/bind


NVM_IDENTIFY_BIN=$(find ~/p2p-research -name "nvm-identify")
if [[ ! -z "${NVM_IDENTIFY_BIN}" ]]
then  
  ${NVM_IDENTIFY_BIN} --ctrl=/dev/libnvm0
fi
