---
title: PHPMyAdmin4.8.1任意文件读取漏洞
tags:
  - BUUCTF
  - PHPMyAdmin 4.8.1
  - LFI
  - HCTF 2018
categories: 
  - PHP
  - PHPMyAdmin
description: PHPMyAdmin 4.8.1 LFI
excerpt: PHPMyAdmin 4.8.1 LFI
typora-root-url: PHPMyAdmin4-8-1任意文件读取漏洞
abbrlink: 27057
date: 2021-05-30 12:29:28
---

> 这题是在BUUCTF平台里遇到的，题目是HCTF 2018的Warm Up.

给出的php代码如下：

```php
<?php
    highlight_file(__FILE__);
    class emmm
    {
        public static function checkFile(&$page)
        {
            $whitelist = ["source"=>"source.php","hint"=>"hint.php"];
            if (! isset($page) || !is_string($page)) {
                echo "you can't see it";
                return false;
            }

            if (in_array($page, $whitelist)) {
                return true;
            }

            $_page = mb_substr(
                $page,
                0,
                mb_strpos($page . '?', '?')
            );
            if (in_array($_page, $whitelist)) {
                return true;
            }

            $_page = urldecode($page);
            $_page = mb_substr(
                $_page,
                0,
                mb_strpos($_page . '?', '?')
            );
            if (in_array($_page, $whitelist)) {
                return true;
            }
            echo "you can't see it";
            return false;
        }
    }

    if (! empty($_REQUEST['file'])
        && is_string($_REQUEST['file'])
        && emmm::checkFile($_REQUEST['file'])
    ) {
        include $_REQUEST['file'];
        exit;
    } else {
        echo "<br><img src=\"https://i.loli.net/2018/11/01/5bdb0d93dc794.jpg\" />";
    }  
?>
```

对这个代码进行分析，发现会下面`include $_REQUEST['file']`，但是需要绕过类`emmm`的静态函数`checkFile`。

分析这个函数，第一个：

```php
$whitelist = ["source"=>"source.php","hint"=>"hint.php"];
if (! isset($page) || !is_string($page)) {
	echo "you can't see it";
	return false;
}
```

只需要传入`file`参数以及确保参数为`string`类型即可过。

第二个：

```php
if (in_array($page, $whitelist)) {
	return true;
}
```

如果是`source.php`或者`hint.php`的话直接放行。

第三个：

```php
$_page = mb_substr($page,0,mb_strpos($page . '?', '?'));
if (in_array($_page, $whitelist)) {
	return true;
}
```

这个也是判断`include`的文件是否为`source.php`或者`hint.php`，用于存在参数时的判断。

第四个：

```php
$_page = urldecode($page);
$_page = mb_substr(
	$_page,
	0,
	mb_strpos($_page . '?', '?')
);
if (in_array($_page, $whitelist)) {
	return true;
}
```

一样的判断逻辑，只是进行了`urldecode`。

整理一下，以上的判断第二个点、第三个点和第四个点都能返回`true`，但是显然的第二个点无法利用。

而第三点显然存在利用方式。

构造`file=hint.php?/../../../../ffffllllaaaagggg`，这样就可以在第三点返回一个`true`从而使得绕过检测，又由于上面的`file`参数进行了路径穿梭，从而使得任意文件包含的可能。

第四点利用，只需要将`?`进行URL编码后即可：

`file=hint.php%253f/../../../../ffffllllaaaagggg`

