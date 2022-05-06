---
title: PHP反序列化总结
tags:
  - 知识点总结
  - PHP反序列化
categories:
  - PHP
  - 反序列化
description: PHP unserialize Summary
excerpt: PHP unserialize Summary
typora-root-url: PHP反序列化总结
abbrlink: 64706
date: 2022-05-06 11:56:03
---

## PHP反序列化漏洞总结

> 找实习时被问到了相关问题，虽说前前后后还是能答出来，但是感觉有些东西已经忘的差不多了，答的不利索，索性直接写一篇总结博文好了。

### PHP反序列化漏洞概述

PHP反序列化一直是CTF竞赛中的宠儿吧，自己做CTF题目时时常会做到PHP的题目，但凡是PHP的题目，反序列化一般都少不了。

而国内的ThinkPHP、Yii等框架时不时会爆出反序列化利用，相比起Java，PHP更受中小型企业的青睐，快速开发、维护成本低等等特性使其成为一门很优秀的语言。

### PHP反序列化基础

#### PHP类与对象

在学习编程语言时，应该能了解到`类是定义一系列属性和操作的模板`，`对象是类的实例化`。

来看一个简单的例子：

```php
<?php
class Person
{
    public $name;
    public function eat()
    {
        echo $this->name . " eat something..." . "<br>";
    }
    public function sleep()
    {
        echo $this->name . " sleeping..." . "<br>";
    }
    public function __construct($name)
    {
        $this->name = $name;
    }
}

$person = new Person("Zhangsan");
$person->eat();
$person->sleep();
```

其输出为：

```bash
Zhangsan eat something...
Zhangsan sleeping...
```

上面的代码非常简单，定义了一个`Person`类，在`Person`类中定义了`name`成员变量和`eat`、`sleep`成员函数。

而后实例化了一个`Person`对象，然后依次调用`eat`和`sleep`函数，进行输出。

#### PHP魔术方法

值得一提的是，几乎所有的高级语言都支持魔术方法，但是叫法不一。

例如python中，`__repr__`、`__item__`等等函数都是魔术方法，在PHP中，常见的魔术方法及其调用机制如下：

|     方法名     |                             作用                             |
| :------------: | :----------------------------------------------------------: |
| __construct()  |   构造函数，在创建对象时候初始化对象，一般用于对变量赋初值   |
|  __destruct()  | 析构函数，和构造函数相反，在对象不再被使用时(将所有该对象的引用设为null)或者程序退出时自动调用 |
|  __toString()  | 当一个对象被当作一个字符串被调用，把类当作字符串使用时触发，返回值需要为字符串，例如echo打印出对象就会调用此方法 |
|   __wakeup()   |    使用unserialize时触发，反序列化恢复对象之前调用该方法     |
|   __sleep()    | 使用serialize时触发 ，在对象被序列化前自动调用，该函数需要返回以类成员变量名作为元素的数组(该数组里的元素会影响类成员变量是否被序列化。只有出现在该数组元素里的类成员变量才会被序列化) |
|    __call()    | 在对象中调用不可访问的方法时触发，即当调用对象中不存在的方法会自动调用该方法 |
| __callStatic() |            在静态上下文中调用不可访问的方法时触发            |
|    __get()     | 读取不可访问的属性的值时会被调用（不可访问包括私有属性，或者没有初始化的属性） |
|    __set()     |   在给不可访问属性赋值时，即在调用私有属性的时候会自动执行   |
|   __isset()    |          当对不可访问属性调用isset()或empty()时触发          |
|   __unset()    |              当对不可访问属性调用unset()时触发               |
|   __invoke()   |               当脚本尝试将对象调用为函数时触发               |
|   __clone()    |                        克隆对象时调用                        |
| __set_state()  |                       调用var_export时                       |
|  __autoload()  |       实例化一个对象时，如果对应的类不存在，调用该方法       |

其中`__toString`的触发场景由很多，简单的提一下，只要是当作字符串处理时就会调用：

1. echo/print
2. 对象与字符串连接
3. 对象参与字符串格式化
4. 对象与字符串进行==比较
5. 对象作为SQL语句参数绑定时
6. 作为PHP字符串函数参数，如strlen、addslashes
7. 对象作为class_exists参数时

> 顺口提一句，面试时被问到了实例化对象过程中魔术方法的调用顺序，这里实际上个人感觉能说的不多，把常规的魔术方法都说说就行，但是构造和析构肯定是必须提及的。

来看一个简单的样例：

```php
<?php
class Person
{
    private $name;

    public function __wakeup()
    {
        echo "<hr>";
        echo "Call __wakeup";
    }

    public function __construct(String $name)
    {
        $this->name = $name;
        echo "<hr>";
        echo "Call __construct";
    }

    public function __destruct()
    {
        echo "<hr>";
        echo "Call __destruct";
    }

    public function __toString()
    {
        echo "<hr>";
        echo "Call __toString";
        return $this->name;
    }

    public function __set($name, $value)
    {
        echo "<hr>";
        echo "Call __set";
    }

    public function __get($name)
    {
        echo "<hr>";
        echo "Call __get";
    }

    public function __invoke()
    {
        echo "<hr>";
        echo "Call __invoke";
    }
}

$person = new Person("Zhangsan");// __construct
$person->sex = 'Man';	// __set
echo $person->name;	// __get
$s = "Welcome, " . $person;	// __toString
$per_s = serialize($person);	// nothing happen
print_r(unserialize($per_s));	//__wakeup
$person();	// __invoke
// after all, call __destruct
```

对应的输出为：

![image-20220506124430759](./image-20220506124430759.png)

参照代码应该不难理解。

#### PHP的序列化与反序列化

##### 序列化

在开发过程中，将对象或者数组之类的数据进行存储是一个十分常见的情况。

在这种需求下，序列化对象与反序列化几乎是刚需，PHP提供的常规序列化相关的方式有：

* serialize、unserialize、json_encode、json_decode

来看个序列化的样例：

```php
<?php
class Obj
{
    public $property1 = 'ppt1';
    private $property2 = 'ppt2';
    protected $property3 = 'ppt3';

    function func()
    {
    }
}

$o = new Obj();
echo serialize($o);
```

其对应的输出为：

```bash
O:3:"Obj":3:{s:9:"property1";s:4:"ppt1";s:14:"Objproperty2";s:4:"ppt2";s:12:"*property3";s:4:"ppt3";}
```

简单说一下序列化的结果，`o:3:"Obj":3`的`o`表示这是一个对象，`3`表示类名长度为3，`"Obj"`表示类名为`Obj`，而后的`3`表示该对象有三个属性，接下来的大括号内的内容就是属性内容，格式为`type:length:value`，`s`表示是一个String类型。

这里应该可以注意到，使用不同修饰符进行修饰的变量，其序列化后的长度和名称发生了变化：

* public：正常长度
* private：长度+类名称+2
* protected：长度+1(*)+2

这里估计有很多人会疑惑这里的+2怎么来的。

将输出结果URL编码后的结果是这样子的：

```bash
O%3A3%3A%22Obj%22%3A3%3A%7Bs%3A9%3A%22property1%22%3Bs%3A4%3A%22ppt1%22%3Bs%3A14%3A%22%00Obj%00property2%22%3Bs%3A4%3A%22ppt2%22%3Bs%3A12%3A%22%00%2A%00property3%22%3Bs%3A4%3A%22ppt3%22%3B%7D
```

为了方便观看，只编码关键部分：

```bash
O:3:"Obj":3:{s:9:"property1";s:4:"ppt1";s:14:"%00Obj%00property2";s:4:"ppt2";s:12:"%00*%00property3";s:4:"ppt3";}
```

应该可以看到，在类名或者`*`前后都有一个`%00`，这是用于区分划分属性名所设置的，占两个字符。

给出常规序列化的`type`：

| tpye |       含义        |
| :--: | :---------------: |
|  a   |       array       |
|  d   |      double       |
|  o   |   common object   |
|  s   |      string       |
|  O   |       class       |
|  R   | pointer reference |
|  b   |      boolean      |
|  i   |      integer      |
|  r   |     reference     |
|  C   |   custom object   |
|  N   |       null        |
|  U   |  unicode string   |

##### 反序列化

这里拿刚刚的字符来反序列化：

```php
$data = urldecode('O:3:"Obj":3:{s:9:"property1";s:4:"ppt1";s:14:"%00Obj%00property2";s:4:"ppt2";s:12:"%00*%00property3";s:4:"ppt3";}');
var_dump(unserialize($data));
```

其结果如图：

![image-20220506131347521](./image-20220506131347521.png)

### PHP反序列化漏洞分析

#### 一个简单的反序列化漏洞

来看一个十分简单的案例：

```php
<?php

class Evil
{
    var $code = 'echo "Hello World!";';
    function __destruct()
    {
        @eval($this->code);
    }
}

$obj = unserialize($_GET['data']);
```

这里的代码十分简单，可以看到，代码反序列化了传入的GET参数data，但是代码中存在一个类Evil，可能被恶意利用。

当我们传入的data是`O:4:"Evil":1:{s:4:"code";s:10:"phpinfo();";}`，此时：

![image-20220506132128300](./image-20220506132128300.png)

而其原因是什么呢？

反序列化的对象的code成员实际上是一个`String="phpinfo();"`，在该对象析构时则调用了Eval函数从而执行任意代码。

从这里不难分析出，PHP反序列化漏洞的利用条件：

1. unserialize函数的参数可控
2. 存在一个合适的魔术方法作为`跳板`
3. 能够将程序流程导向恶意流程

#### POP链构造

POP构造最主要是利用魔术方法，然后在魔术方法中调用其他函数，通过寻找相同名字的函数，再与类中的敏感函数和属性相关联，这样就可以通过控制反序列化字符串达到利用反序列化漏洞的目的。

##### 技巧性的东西

主要关注POP链可能利用的方法：

```php
命令执行：exec()、passthru()、popen()、system()
文件操作：file_put_contents()、file_get_contents()、unlink()
代码执行：eval()、assert()、call_user_func()
```

大S绕过：

```php
s:4:"user";
// equal
S:4:"use\72";
```

使用大S，后面的字符就支持16进制表示。

如果可以进行文件读取或者其他文件操作，可以考虑使用PHP伪协议。

##### 例子

