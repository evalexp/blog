---
title: Matrix-1
tags:
  - Vulnhub
  - Matrix-1
categories: 
  - 渗透靶机训练
description: Easy...
excerpt: Easy...
typora-root-url: Matrix-1
abbrlink: 53702
date: 2021-04-06 20:03:38
---

# Matrix-1

## 基础信息收集

NMAP Result：

![image-20210406201141599](image-20210406201141599.png)

Nikto未披露有效信息，**dirb**也未提供有效信息。

在80端口的HTTP服务未发现有效信息：

![image-20210406201410015](image-20210406201410015.png)

在31337端口发现一串Base64密文：

![image-20210406201447250](image-20210406201447250.png)

解码后：

![image-20210406201524636](image-20210406201524636.png)

访问：

```bash
http://192.168.145.143:31337/Cypher.matrix
```

打开是这样的：

![image-20210406201623004](image-20210406201623004.png)

熟悉的BrainFuck编码，解码得：

> You can enter into matrix as guest, with password k1ll0rXX
>
> Note: Actually, I forget last two characters so I have replaced with XX try your luck and find correct string of password.

## 密码爆破

按照提示，用crunch生成一下字典：

```bash
crunch 8 8 -f /usr/share/crunch/charset.lst mixalpha-numeric -t k1ll0r@@ >> pwd_list
```

然后hydra爆破：

```hydra
hydra -l guest -P pwd_list ssh://192.168.145.143 -t 64
```

![image-20210406201854167](image-20210406201854167.png)

## RBASH逃逸

![image-20210406201941830](image-20210406201941830.png)

登陆上后是显示rbash，export看一下环境变量：

![image-20210406202035089](image-20210406202035089.png)

由于ls用不了，不过可以骚操作用echo代替一下：

```bash
echo /home/guest/prog/*
```

![image-20210406202116060](image-20210406202116060.png)

嗯？有Vi？直接逃逸！

Vi内命令执行：

![image-20210406202221414](image-20210406202221414.png)

成功：

![image-20210406202237516](image-20210406202237516.png)

导入一下环境变量：

```bash
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

## 提权

看一下有无系统内核提权，搜了一下并无。

![image-20210406202316651](image-20210406202316651.png)

sudo权限检查一下：

![image-20210406202348950](image-20210406202348950.png)

？？？

？？？

？？？

我直接好家伙，提权直接su就好了：

![image-20210406202648051](image-20210406202648051.png)

。。。

emmm，这个靶机有点太简单了。。。