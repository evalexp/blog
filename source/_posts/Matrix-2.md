---
title: Matrix-2
tags:
  - Vulnhub
  - Matrix-2
categories: 
  - 渗透靶机训练
description: An unbelievable virtual machine.
excerpt: An unbelievable virtual machine.
typora-root-url: Matrix-2
abbrlink: 53382
date: 2021-04-09 21:50:28
---

> 简单说几句，这个靶机一言难尽，感觉做的我流程都不会了，但是难度又不算特别大，害。

# Matrix-2

## 基础信息收集

NMAP Result：

```nmap
# Nmap 7.91 scan initiated Thu Apr  8 18:30:02 2021 as: nmap -sC -sV -A -p- -oN nmap 192.168.145.144
Nmap scan report for 192.168.145.144
Host is up (0.015s latency).
Not shown: 65530 closed ports
PORT      STATE SERVICE            VERSION
80/tcp    open  http               nginx 1.10.3
|_http-server-header: nginx/1.10.3
|_http-title: Welcome in Matrix v2 Neo
1337/tcp  open  ssl/http           nginx
| http-auth: 
| HTTP/1.1 401 Unauthorized\x0D
|_  Basic realm=Welcome to Matrix 2
|_http-title: 401 Authorization Required
| ssl-cert: Subject: commonName=nginx-php-fastcgi
| Subject Alternative Name: DNS:nginx-php-fastcgi
| Not valid before: 2018-12-07T14:14:44
|_Not valid after:  2028-12-07T14:14:44
|_ssl-date: TLS randomness does not represent time
| tls-alpn: 
|_  http/1.1
| tls-nextprotoneg: 
|_  http/1.1
12320/tcp open  ssl/http           ShellInABox
|_http-title: Shell In A Box
| ssl-cert: Subject: commonName=nginx-php-fastcgi
| Subject Alternative Name: DNS:nginx-php-fastcgi
| Not valid before: 2018-12-07T14:14:44
|_Not valid after:  2028-12-07T14:14:44
|_ssl-date: TLS randomness does not represent time
12321/tcp open  ssl/warehouse-sss?
| ssl-cert: Subject: commonName=nginx-php-fastcgi
| Subject Alternative Name: DNS:nginx-php-fastcgi
| Not valid before: 2018-12-07T14:14:44
|_Not valid after:  2028-12-07T14:14:44
|_ssl-date: TLS randomness does not represent time
12322/tcp open  ssl/http           nginx
| http-robots.txt: 1 disallowed entry 
|_file_view.php
|_http-title: Welcome in Matrix v2 Neo
| ssl-cert: Subject: commonName=nginx-php-fastcgi
| Subject Alternative Name: DNS:nginx-php-fastcgi
| Not valid before: 2018-12-07T14:14:44
|_Not valid after:  2028-12-07T14:14:44
|_ssl-date: TLS randomness does not represent time
| tls-alpn: 
|_  http/1.1
| tls-nextprotoneg: 
|_  http/1.1

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Thu Apr  8 18:30:31 2021 -- 1 IP address (1 host up) scanned in 29.04 seconds

```

Nikto以及dirb并没有啥有用的信息，访问Web的80端口看到了有意思的东西：

![image-20210409215409699](image-20210409215409699.png)

简单的处理一下，JS的内容是这样的：

```javascript
class TextScramble {
    constructor(el) {
        this.el = el;
        this.chars = '!@#$%^&*()_-=+{}:"|<>?,./;';
        this.update = this.update.bind(this);
    }
    setText(newText) {
        const oldText = this.el.innerText;
        const length = Math.max(oldText.length, newText.length);
        const promise = new Promise((resolve) => this.resolve = resolve);
        this.queue = [];
        for (let i = 0; i < length; i++) {
            const from = oldText[i] || '';
            const to = newText[i] || '';
            const start = Math.floor(Math.random() * 40); 
            const end = start + Math.floor(Math.random() * 40); 
            this.queue.push({
                from,
                to,
                start,
                end
            })
        }
        cancelAnimationFrame(this.frameRequest); 
        this.frame = 0; 
        this.update(); 
        return promise
    }
    update() {
        let output = '';
        let complete = 0;
        for (let i = 0, n = this.queue.length; i < n; i++) {
            let {
                from,
                to,
                start,
                end,
                char
            } = this.queue[i];
            if (this.frame >= end) {
                complete++;
                output += to;
            } else if (this.frame >= start) {
                if (!char || Math.random() < 0.28) {
                    char = this.randomChar(); 
                    this.queue[i].char = char;
                }
                output += `<span class="dud">${char}</span>`;
            } else {
                output += from;
            }
        }
        this.el.innerHTML = output;
        if (complete === this.queue.length) {
            this.resolve();
        } else {
            this.frameRequest = requestAnimationFrame(this.update);
             this.frame++;
        }
    }
    randomChar() {
        return this.chars[Math.floor(Math.random() * this.chars.length)];
    }
}
const phrases = ['Yes, I am a criminal.', 'My crime is that of curiosity.', 'My crime is that of judging people by what they say and think, not what they look like.', 'My crime is that of outsmarting you, something that you will never forgive me for.', 'I am a hacker, and this is my manifesto.', 'You may stop this individual, but you cant stop us all...', 'after all, were all alike.'];
const el = document.querySelector('.text'); 
const fx = new TextScramble(el); 
let counter = 0;
const next = () => {
    fx.setText(phrases[counter]).then(() => {
        setTimeout(next, 1500);
    });
    counter = (counter + 1) % phrases.length
}
next()
'use strict';
var app = {
    chars: ['PureHackers', 'Unleashed', '127.0.0.1', '1337', '0x523344', 'Localhost', 'Cr4sH CoD3', 'HACKED!', 'Security', 'Breached!', 'System'],
    init: function () {
        app.container = document.createElement('div');
        app.container.className = 'animation-container';
        document.body.appendChild(app.container);
        window.setInterval(app.add, 100);
    },
    add: function () {
        var element = document.createElement('span');
        app.container.appendChild(element);
        app.animate(element);
    },
    animate: function (element) {
        var character = app.chars[Math.floor(Math.random() * app.chars.length)];
        var duration = Math.floor(Math.random() * 15) + 1;
        var offset = Math.floor(Math.random() * (50 - duration * 2)) + 3;
        var size = 10 + (15 - duration);
        element.style.cssText = 'right:' + offset + 'vw; font-size:' + size + 'px;animation-duration:' + duration + 's';
        element.innerHTML = character;
        window.setTimeout(app.remove, duration * 1000, element);
    },
    remove: function (element) {
        element.parentNode.removeChild(element);
    },
};
document.addEventListener('DOMContentLoaded', app.init);
```

注意一下，里面有一个**127.0.0.1**以及**1337**，联想NMAP扫描结果，访问一下。

## 文件包含

![image-20210409215634920](image-20210409215634920.png)

要求登录，那么问题来了，我目前不知道账号密码，弱口令试了，并未命中。

显然1337端口所开放的内容必须要我们拿到账号和密码才能继续了。

于是把NMAP的端口挨个访问了遍，在12320发现一个Shell的登录页面，12321无法访问，**12322出现内容**，且内容和80端口大致相同，但是NMAP**扫出有robots.txt**的文件，我尝试读取，并找到**file_view.php**：

![image-20210409220245114](image-20210409220245114.png)

然后我尝试了访问：

![image-20210409220308914](image-20210409220308914.png)

遗憾的是，Get请求似乎并不奏效：

![image-20210409220347342](image-20210409220347342.png)

我打开了Burp，希望使用POST请求再试试：

![image-20210409220422113](image-20210409220422113.png)

好像成功了，并且找到了一个叫**n30**的用户，给的备注是Neo，保存备用。

## 基础认证账户密码破解

由于该网站使用了Nginx的中间件，那么读取一下Nginx的默认站点配置文件：

![image-20210409220542006](image-20210409220542006.png)

收获颇丰，至少我知道了基础认证的文件在哪儿，查看该文件：

![image-20210409220627874](image-20210409220627874.png)



很好，至少现在我知道了用户名以及其密码的哈希，使用John爆破一下Hash：

![image-20210409220855215](image-20210409220855215.png)

现在知道了账号和密码，那么应该能登录到**1337**端口了。

![image-20210409221024182](image-20210409221024182.png)

成功登录。

## 图片隐写

> 这个确实是我没想到的，居然把信息用图片隐写了，不吐槽不行╮(╯▽╰)╭

![image-20210409221158082](image-20210409221158082.png)

在网页源代码中发现了这个，Download下来后，emmm：

![image-20210409221227748](image-20210409221227748.png)

本以为只是一张普通的图片，谁知道居然内含信息，再吐槽一下，密码放图片里可太离谱了~

![image-20210409221330607](image-20210409221330607.png)

盲猜了一下密码**n30**，wow~ ⊙o⊙，居然对了，直接把信息解出来把。

![image-20210409221417579](image-20210409221417579.png)

## 提权

![image-20210409221451051](image-20210409221451051.png)

非常的贴心，连反弹Shell都不用了，23333

用**n30**登录一下：

![image-20210409221625155](image-20210409221625155.png)

成功登录，查看一下内核版本，无提权漏洞，查一下sudo，结果没有sudo，最后：

```bash
find / -perm -u=s -type f 2>/dev/null
```

![image-20210409221717409](image-20210409221717409.png)

EMMM，好像常见的提权程序都没在里面的说。。。一筹莫展之际：

![image-20210409221841066](image-20210409221841066.png)

顺手打出`ls -al`居然找到了Bash History，╮(╯▽╰)╭，看一下内容：

![image-20210409221941010](image-20210409221941010.png)

我只能感叹一句，作者会玩啊！

![image-20210409222019018](image-20210409222019018.png)