#!/bin/bash

help(){
 echo "Usage: ${0} [vg name]"
}

if [ $(id -u) -ne 0 ]; then echo "Need root for run script. Exit"; exit 1; fi

vgs=${1}

if [ -z ${vgs} ]; then help; exit 1; fi

if ! $(vgs -o vg_name --noheadings|grep -q ${vgs}); then echo "VG not found. Exit"; exit 1; fi
echo "Disconnect LVS"
for i in $(lvs -o lv_name --noheadings ${vgs}); do 
 echo "Disconnect: [${i}]"
 lvchange -an ${vgs}/${i}
done
echo "Disconnect VGS [${vgs}]"
vgchange -an ${vgs}
