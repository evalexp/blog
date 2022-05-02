---
title: DC-6
tags:
  - Vulnhub
  - DC-6
categories: 
  - 渗透靶机训练
description: >-
  DC-4 Challenge, it's impossible for me to think of that author would give a
  tip on the download page.
excerpt: DC-4 Challenge, it's impossible for me to think of that author would give a tip on the download page.
typora-root-url: DC-6
abbrlink: 25208
date: 2021-03-31 19:24:17
---

> 实在想不到不是我没想到，而是字典有问题~~
>
> 另：从这篇博文开始就不给出某一些简单的命令行代码了

# DC-6

## 基础信息收集

NMAP Result：

![image-20210331192847986](image-20210331192847986.png)

其它的收集就不展示了，因为也没怎么用到。

SSH服务和HTTP服务，emmm，来来去去都这两个啊~~

和之前的一个靶机套路一致，加一下HOSTS文件本地域名解析才能正常打开。

## 枚举用户

![image-20210331193408489](image-20210331193408489.png)

网站上基本找不到啥有用的信息，用wpscan看看：

```bash
wpscan --url http://wordy
```

给出了WP版本和主题的版本：

![image-20210331193603731](image-20210331193603731.png)

搜了一下exploit-db，不能直接搞，那看来还是得走别的途径了。

枚举一下WP的用户：

```bash
wpscan --url http://wordy --enumerate u
```

![image-20210331193805571](image-20210331193805571.png)

## 爆破密码

> 讲道理，这里我也爆破过，用的字典是：cirt-default-passwords.txt，一开始没爆出来，我还以为不是这个思路，还纠结地找了别的半天的突破口，后来百度Writeup，心态崩了，原来是我的字典有问题~~

根据别人的Writeup做法，使用Kali的Rockyou字典爆破，然后：

![image-20210331194133803](image-20210331194133803.png)

这不对劲，这得爆破到猴年马月去，不对不对！

然后大师傅给出了这张截图：

![image-20210331194239076](image-20210331194239076.png)

我。。。我懂了，我悟了！

```bash
cat rockyou.txt | grep k01 > pwd.txt
wpscan --url http://wordy/ -U user -P pwd.txt
```

噢，总算爆破出来了。。。

![image-20210331194810738](image-20210331194810738.png)

## 命令行注入

![image-20210331194850330](image-20210331194850330.png)

登录后，随便逛了逛，然后找到了这个：

![image-20210331194933608](image-20210331194933608.png)

嗅到一丝命令行注入的气息，于是打开了Burp测试：

![image-20210331195034188](image-20210331195034188.png)

居然真的是，这。。。这么简单的么？

## 反弹shell

直接反弹一个shell回来开始最后的阶段╮(╯▽╰)╭

![image-20210331195158581](image-20210331195158581.png)

找找home目录下有没有啥线索：

![image-20210331195315459](image-20210331195315459.png)

backups.sh引起了我的注意：

![image-20210331195358713](image-20210331195358713.png)

确实只是一个备份的脚本，看下一个人的home有啥：

![image-20210331195538267](image-20210331195538267.png)

这个就有趣了：

![image-20210331195609542](image-20210331195609542.png)

直接给出了graham的密码，芜湖~~

## 提权

ssh连上去看看：

![image-20210331195729507](image-20210331195729507.png)

成功连上，检查内核看看是否有内核提权：

![image-20210331195801859](image-20210331195801859.png)

搜了一下，没有。。

发现sudo有一个脚本的权限：

![image-20210331195836650](image-20210331195836650.png)

![image-20210331200119931](image-20210331200119931.png)

脚本的内容之前看过，

![image-20210331200245216](image-20210331200245216.png)

可读可写，那么在文件最后加一行：

![image-20210331200337127](image-20210331200337127.png)

然后就可以切换到jens用户了：

![image-20210331200429441](image-20210331200429441.png)

再次找到sudo的特殊权限：

![image-20210331200509180](image-20210331200509180.png)

nmap提权应该算是挺简单的(了解过nse就好)，去/tmp目录写一个nse脚本用于提权：

```bash
echo 'os.execute("/bin/bash")' > /tmp/escape.nse
```

![image-20210331201000608](image-20210331201000608.png)

然后用nmap加载这个脚本：

![image-20210331201315525](image-20210331201315525.png)

END~~╮(╯▽╰)╭

>感觉最近提权的套路好像都是这些╮(╯▽╰)╭