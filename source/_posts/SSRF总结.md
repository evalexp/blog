---
title: SSRF总结
tags:
  - 知识点总结
  - SSRF
categories: 
  - 知识点总结
  - SSRF
description: SSRF Summary
excerpt: SSRF Summary
abbrlink: 2569
date: 2022-02-27 13:25:51
---

## 什么是SSRF

SSRF(Server-Side Request Forgery,服务器请求伪造)是一种由攻击者构造请求,由服务端发起请求的安全漏洞,

一般情况下,SSRF攻击的目标是外网无法访问的内网系统(正因为请求时由服务端发起的,所以服务端能请求到与自身相连而与外网隔绝的内部系统)。

SSRF漏洞形成的原因大都是由于服务端提供了从其他服务器应用获取数据的功能且没有对目标地址做过滤与限制。

例如,黑客操作服务端从指定URL地址获取网页文本内容,加载指定地址的图片等,利用的是服务端的请求伪造,SSRF利用存在缺陷的WEB应用作为代理攻击远程和本地的服务器。

除了http/https等方式可以造成ssrf，类似tcp connect 方式也可以探测内网一些ip 的端口是否开发服务，只不过危害比较小而已。

## SSRF的分类

* 显示对攻击者的响应(Basic)
* 不显示响应(Blind)

其中Basic的回显响应最容易利用并且危害较大，一旦确认存在SSRF漏洞，攻击者就可能利用该漏洞对内网进行探测等。

## SSRF怎么挖掘

重点关注Web系统上的以下功能：

1. 分享：通过URL地址进行的网页内容分享
2. 转码服务：通过URL地址将原地址的网页内容调整为自适应设备的浏览页面
3. 在线翻译：通过URL地址翻译对应的网页文本内容
4. 图片加载与下载：通过URL地址加载或下载图片
5. 收藏功能：对图片或文章的收藏功能
6. 可能的URL调用：可能存在的URL调用
7. 离线下载：从URL下载文件后再传输给用户

在实际寻找时，可以考虑使用搜索引擎检索以下字段：

1. share
2. wap
3. url
4. link
5. src
6. source
7. target
8. u
9. 3g
10. display
11. sourceURL
12. imageURL
13. domain
14. downloadURL
15. externalURL

等等。

## SSRF漏洞的绕过

在确认存在SSRF漏洞存在后，可能由于WAF等原因，需要进行绕过，以下为一些常用的绕过技巧：

1. 对于内网探测，如果拦截了127.0.0.1或者localhost，可以考虑使用[::]
2. 使用@符绕过，例如http://baidu.com@127.0.0.1，其意为使用baidu.com的用户登录127.0.0.1，实际地址为127.0.0.1
3. 使用指向任意IP的域名xip.io，例如10.0.0.1.xip.io指向10.0.0.1
4. 特殊进制绕过，可以将IP地址改为各种进制进行绕过，例如192.168.0.1
   * 八进制：0300.0250.0.1
   * 十六进制：0xC0.0xA8.0.1或整数形式的0xC0A80001(写成整数形式注意对齐)
   * 十进制：3232235521

5. DNS解析，设置域名的A记录为127.0.0.1等
6. 利用句号，例如127。0。0。1实际和127.0.0.1一样
7. 对于先检测域名再进行实际请求的，可以考虑使用DNS Rebinding(域名重绑定)技术进行绕过
8. SSRF可利用的协议：
   * file协议，可读取文件
   * dict协议，当无法使用gopher协议时可以考虑使用该协议探测内网甚至写Shell
   * gopher协议，该协议可发送Get、POST请求
   * ldap协议
   * sftp与tftp

## SSRF的利用方式

1. 在外网就可以对服务器所在的内网进行端口扫描获取内网资产信息，甚至对内网进行测绘，得到完整的内网拓扑
2. 大多数企业对于内网过于信任，对于内网的一些App没有进行安全保护，从而可以攻击内网的应用程序
3. 对内网的Web系统等进行指纹识别(通过获取一些默认文件进行判断)
4. 读取敏感文件

## SSRF的防御

对于安全来说，怎么复杂都不为过，以下为参考的一些防御方式：

1. 过滤返回信息。例如接口的功能是翻译HTML文档中的文字，那么在返回时就检查响应是否为HTML格式，如果不是，那么就拒绝返回。
2. 统一化错误信息，从而避免用户可以通过错误信息来判断内网状态。例如，当127.0.0.1:3306无法连接时，不要直接返回该端口无法连接，而是直接向用户表示出错，但不表示具体为何类错误。
3. 限制请求的端口，例如只是下载HTML文档，限制端口为80与443。
4. 内网黑名单，采用更为严格的限制，禁止访问内网服务
5. 严格白名单，只允许访问部分支持的URL
6. 禁用无关协议，例如下载服务，仅提供HTTP、HTTPS、FTP等协议即可，禁用dict、gopher、file协议等。

