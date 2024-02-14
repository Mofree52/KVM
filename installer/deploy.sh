#!/usr/bin/env bash
#
# coding: utf-8
# author: liuchao
# usage: deploy kvm environment.


# check current system =? CentOS
# The current script supports the use of the centos distribution, 
# and centos 7 is recommended; the script execution environment is bash
if [ -f /etc/redhat-release ];then
	echo "$(cat /etc/redhat-release)"
else
  echo "this system is not CentOS"
  exit 1
fi

function initial_environment() {
  # set off firewalld & selinux
  systemctl disable --now firewalld
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
  # configure yum repo files
  mkdir -p /etc/yum.repos.d/repobak; mv /etc/yum.repos.d/* /etc/yum.repos.d/repobak/
  curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
  curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
  yum clean all; yum makecache
  # install require software
  yum -y install vim net-tools bridge-utils qemu-kvm libvirt virt-install libguestfs libguestfs-tools
  systemctl enable --now libvirtd.service
  # initial directory
  mkdir -p /kvm/{vdisks,isos,modify}
}

function upgrade_kernel() {
  # upgrade kernel
  kernel_package_name=$(curl -s https://elrepo.org/linux/kernel/el7/x86_64/RPMS/ | grep kernel-lt | awk -F"href=" 'NR==1{ print $2 }' | awk -F'"' '{ print $2 }')
  kernel_devel_name=$(curl -s https://elrepo.org/linux/kernel/el7/x86_64/RPMS/ | grep kernel-lt-devel | awk -F"href=" 'NR==1{ print $2 }' | awk -F'"' '{ print $2 }')
  
  yum -y update --exclude=kernel*
  if [ ! -f $kernel_package_name ];then
    curl -o $kernel_package_name https://elrepo.org/linux/kernel/el7/x86_64/RPMS/$kernel_package_name
  fi
  if [ ! -f $kernel_devel_name ];then
    curl -o $kernel_devel_name https://elrepo.org/linux/kernel/el7/x86_64/RPMS/$kernel_devel_name
  fi

  yum -y localinstall kernel-lt-*
  grub2-set-default 0 && grub2-mkconfig -o /etc/grub2.cfg
  grubby --args="user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"
  modprobe -a kvm
}

initial_environment
upgrade_kernel

# reboot machines, continue load kernel kvm module
reboot

## this is a test deploy.sh modified