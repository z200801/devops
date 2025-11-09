#!/bin/bash

# Script for own use

# Global variables
mnt_dir="/mnt/docker"
dest_mnt_dir="/var/lib/docker"
lvm_dir="${mnt_dir}${dest_mnt_dir}"

#LVM variables
lv_name="lv-var-docker"
vg_name=$(lvs -o lv_name,vg_name --nohead 2>/dev/null|grep -Po "${lv_name}\x20+\K\S+")
if [ -z "${vg_name}" ]; then echo "Error. Can't find vgs for ${lv_name}. Exit"; exit 1; fi


# Check running service
_chk_service(){
 __service="${1}"
 if [ -z "${__service}" ]; then return 1; fi
 __status=$(systemctl status ${__service}|grep -Po "Active:\s+\K\S+")
 if [ "${__status}" = "inactive" ]; then return 1; else return 0; fi
 unset __service
}

_service_disable(){
 __service="${1}"
 if [ -z "${__service}" ]; then return 1; fi
 if ! _chk_service "${__service}"; then return 0; fi
 systemctl stop ${__service}
 unset __service
}

_service_enable(){
 __service="${1}"
 if [ -z "${__service}" ]; then return 1; fi
 if _chk_service "${__service}"; then return 0; fi
 systemctl start ${__service}
 unset __service
}


# Mount LVM volume
lvm_mount()
{
    p1="${1}"
    echo "Check exist dir [${lvm_dir}]"
    if [ ! -d ${mnt_dir} ]; then echo "Creating dir [${mnt_dir}]";mkdir -p ${mnt_dir} || exit 1; fi
    echo "Checking mounting point"
    lvm_mpt1=$(mount|grep "${lv_name}")
    echo "Mount point is [${lvm_mpt1}]"
    if [ -z "${lvm_mpt1}" ]; then
        echo "Service docker docker.socket stoping"
	_service_disable docker 2>/dev/null
	_service_disable docker.socket
	echo "Mounting [${vg_name}/${lv_name}] to [${mnt_dir}]"
    	mount "/dev/${vg_name}/${lv_name}" ${mnt_dir}
    else
	echo "Exist mount point [${vg_name}/${lv_name}] to [${mnt_dir}]"
    fi
# if $1 is l then make link
    if [ "${p1}" = "l" ]; then
        echo "Chek link to LVM"
        lnk1=$(ls -ld ${dest_mnt_dir}|cut -d ' ' -f1|cut -b1)
        if [ "${lnk1}" = "d" ]; then
	    echo "Making link to dir"
    	    mv "${dest_mnt_dir}" "${dest_mnt_dir}.old"
	    ln -s "${lvm_dir}" "${dest_mnt_dir}"
        else
	    echo "link present. lnk1=[${lnk1}]"
        fi
    fi
    _service_enable docker
}

# LVM umount 
lvm_umount()
{
    
    _service_disable docker 2>/dev/null
    _service_disable docker.socket
    if [ -d "${dest_mnt_dir}.old" ]; then 
     echo "Remove link [${dest_mnt_dir}.old]"
     rm "${dest_mnt_dir}"
     mv "${dest_mnt_dir}.old" "${dest_mnt_dir}"
    fi
    lvm_mpt1=$(mount|grep "${mnt_dir}")
    echo "LVM Mount point is [${lvm_mpt1}]"
    if [ -z "${lvm_mpt1}" ]; then echo "Mount point not exist";
     else  echo "UnMount mount point [${lvm_dir}]";umount ${mnt_dir}
    fi
    _service_enable docker
}

lvm_clean()
{
 return 0
}

# Check root access privilagy 
_chk_root()
{
 if [ $(id -u) -ne 0 ]; then
    echo "Error. Need root access privilagy. Exiting"
    exit 1
fi
}

# Print help usage
_print_help()
{
    echo "Usage: ${0} [commands]"
    echo " commands:"
    echo "  -h 	help"
    echo "  -m 	mount LVM"
    echo "  -u	umount LVM"
}

# Check command line parameters and run funct
_chk_cmdline()
{
    echo "Cmd line is: [${1}]"
    if [ -z "${1}" ]; then
	_print_help
	exit 1
    else
	case ${1} in
	 -h ) _print_help; exit 0 ;;
	 -m ) lvm_mount l;;
	 -u ) lvm_umount l;;
	 * ) _print_help ;;
	esac
    fi
}
#########################################
# Main section
_chk_cmdline ${*}
_chk_root
