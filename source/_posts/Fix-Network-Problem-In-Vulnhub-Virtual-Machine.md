---
title: Fix Network Problem In Vulnhub Virtual Machine
abbrlink: 38372
date: 2021-03-21 16:15:56
tags:
	- Network Interface
	- Network Problem
categories: 
  - 渗透靶机训练
typora-root-url: Fix-Network-Problem-In-Vulnhub-Virtual-Machine
description: Fix Network Problem In Vulnhub Virtual Machine
excerpt: Fix Network Problem In Vulnhub Virtual Machine
---



## Vulnhub

Vulnhub 是一个提供了大量渗透测试靶机的平台，在该平台可以下载靶机虚拟机文件进行渗透测试练习。

此为其地址：[http://www.vulnhub.com/](http://www.vulnhub.com/)

尽管Vulnhub在提供的Virtual Machine OVA File Detail中指明该虚拟机已启用DHCP Service，但是部分虚拟机仍无法通过DHCP自动配置网络获得分配的IP地址。



以下为解决方案：

以**ALFA: 1**为例。



### ALFA: 1 使用interfaces文件配置网络的情况

#### About

此靶机地址为：[http://www.vulnhub.com/entry/alfa-1,655/](http://www.vulnhub.com/entry/alfa-1,655/)

下载导入至VMWare中，发现该虚拟机在**Bridged**模式以及**NAT**模式下均无法正常联网。

#### Rescue Mode

将虚拟机网络模式切为**NAT**模式，启动虚拟机，在**GRUB**选择页面按**E**进入编辑模式，如图：

![image-20210321162709261](image-20210321162709261.png)

在此界面按下**E**后理应出现编辑界面如图：

![image-20210321162758350](image-20210321162758350.png)

#### Load Bash

在上述的编辑界面找到下图所框示：

![image-20210321162901156](image-20210321162901156.png)

将末尾的**ro quiet**修改未**rw single init=/bin/bash**

修改完成后如图所示(其余Linux按此原理修改)：

![image-20210321163025877](image-20210321163025877.png)

完成后按**Win+X**加载Bash，加载完成如图：

![image-20210321163114615](image-20210321163114615.png)

#### Network Interface Fix

查看网络情况：

```bash
ip a
```

应有如下类似回显：

![image-20210321163211826](image-20210321163211826.png)

查看网络配置文件，并检查：

```bash
cat /etc/network/interfaces
```

应有如下类似回显：

![image-20210321163321581](image-20210321163321581.png)

可以确定问题是由于网卡名配置错误导致的网络问题，修改配置文件以使网络正常。

此处只需将**\/etc\/network\/interfaces**文件中的**enp0s3**替换为**ens33**即可。

执行命令：

```bash
sed -i 's/enp0s3/ens33/g' /etc/network/interfaces
```

命令格式如下：

```bash
sed -i 's/源字符串/替换字符串/g' 文件路径
```

执行完成后重启网络服务查看：

```bash
/etc/init.d/networking restart
```

应有以下类似回显：

![image-20210321163751119](image-20210321163751119.png)

可以看到DHCP服务分配的IP地址为**192.168.145.132**，至此网络问题修复完成。

重启虚拟机即可正常开始渗透测试。

### KB-VULN-FINAL NETPLAN配置

#### Network Config Fix

按照上面**ALFA**的情况加载Bash。

进入**\/etc\/netplan**目录，查看配置文件：

![image-20210321223747766](image-20210321223747766.png)

文件内容如图：

![image-20210321223812873](image-20210321223812873.png)

通过执行**ip a**命令可以发现网卡名配置出错。

修改网卡名：

```bash
sed -i 's/enp0s3/ens33/g' 00-installer-config.yaml
```

修改完成后执行**netplan apply**。

此时理应网络配置成功，重启即可开始渗透测试。

