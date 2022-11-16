---
title: CobaltStrike服务端部署
abbrlink: 6861
date: 2022-11-14 09:30:26
tags:
  - Cobalt Strike
  - 内网
categories: 
  - 内网
  - 基础设施建设
description: CobaltStrike服务端部署
excerpt: CobaltStrike服务端部署
typora-root-url: CobaltStrike服务端部署
---

# CobaltStrike服务端部署



## 棉花糖版修正

此次部署的版本为棉花糖发布的4.7版本。

但是有许多地方需要进行修正。

### XieGongzi插件修正

路径为`/plugin/XieGongZi`，由于MHT可能进行压缩时使用的压缩软件并未能有效处理中文文件名，因此该CNA脚本的文件名出现了乱码，需要自己对照`/plugin/XieGongZi/main.cna`对`/plugin/XieGongZi/modules`内的文件名进行修正。

### Windows下Client端巨龙拉冬插件报invokeassembly.x64.dll不存在

删除`CSAgent.jar`，修改`Cobalt_Strike_CN.bat[vbs]`的调用命令为：

```bash
java -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+UseParallelGC -Duser.language=en -Dfile.encoding=utf-8 -jar cobaltstrike-client.jar
```

随后启动即可，此时插件已恢复正常使用。

## Server端部署

### Server端精简化

由于棉花糖的`CS`整一个解压出来比较大，直接丢到服务器上相对而言比较占空间了，如果对服务器空间没有特殊要求的可以忽略此步。

先看最终精简后的大小吧：

![image-20221116103219698](./image-20221116103219698.png)

具体的结构如下：

![image-20221116103339999](./image-20221116103339999.png)

仅保留上图所示文件即可，其余的都可删除（`teamserver`这一个脚本如果后续希望自己写`entrypoint`的话也可以删除）。

### Server端镜像制作

目前比较流行的服务部署方式是容器化，容器的话理论上来说有两种可选，即`Docker`和`Podman`，但是由于`CobaltStrike`本身需要以`Root`权限启动，因此这里选用了`Docker`。

#### 题外话 - Mac下的Docker环境

众所周知的，`Docker`的资源隔离是使用`cgroups`以及`namespace`实现的，但是这两个特性是`Linux`内核支持的，也就是说除了`Linux`系统，其他系统都不可能原生支持Docker，Windows和Mac都是依赖于虚拟机实现的Docker调用。

因此在Windows和MacOS中，实际上一个是依赖于`Windows`的`Hyper-V`，一个则是依赖于`Mac`的`Hyperkit`，但是在实际安装过程中，我发现了只要启动了`Docker Desktop`，笔记本风扇基本就嗡嗡嗡地转了，调小了资源赋值也还是一样的转，这对于我来说有点不能忍受。于是还需要探究在Windows以及Mac环境下的Docker环境实施。

经过反复对比和探究，最终选定了`Multipass`这一软件，该软件主要维护小型虚拟机，但是由于是`Ubuntu`团队的作品，因此目前只支持`Ubuntu`的镜像，不过也很好用了。

可以到此处去查看具体：https://github.com/canonical/multipass

下载的话，在Github Release中即可下载。

理论上来说安装完成后启动托盘应该有图标才对，但是我个人的Mac没有图标，不过问题不大，终端调用即可。

通过`multipass find`列出可用镜像：

```bash
➜  ~ multipass find
Image                       Aliases           Version          Description
snapcraft:core18            18.04             20201111         Snapcraft builder for Core 18
snapcraft:core20            20.04             20210921         Snapcraft builder for Core 20
snapcraft:core22            22.04             20220426         Snapcraft builder for Core 22
18.04                       bionic            20221108         Ubuntu 18.04 LTS
20.04                       focal             20221115.1       Ubuntu 20.04 LTS
22.04                       jammy,lts         20221101.1       Ubuntu 22.04 LTS
anbox-cloud-appliance                         latest           Anbox Cloud Appliance
charm-dev                                     latest           A development and testing environment for charmers
docker                                        latest           A Docker environment with Portainer and related tools
jellyfin                                      latest           Jellyfin is a Free Software Media System that puts you in control of managing and streaming your media.
minikube                                      latest           minikube is local Kubernetes
```

如果只是想用docker的话，推荐直接从docker镜像启动，如果不需要Portainer等相关的话，那就从标准镜像启动，直接安装Docker即可，我选择的是标准镜像22.04（使用Aliases中的任意一个也可）：

```bash
➜  ~ multipass launch --name primary --disk 10G --mem 1G --cpus 2 lts
warning: "--mem" long option will be deprecated in favour of "--memory" in a future release.Please update any scripts, etc.
Launched: primary                                                               
Mounted '/Users/evalexp' into 'primary:Home'     
```

可用看到这里就创建好了一个`Ubuntu 22.04`的虚拟机，通过`multipass shell primary`进入指定的`Instance`（若`name`指定为`primary`，则使用`multipass shell`即可进入）。

进入Shell后先换源：

```bash
ubuntu@primary:~$ sudo sed -i 's/http:\/\/archive.ubuntu.com/https:\/\/mirror.sjtu.edu.cn/g' /etc/apt/sources.list
ubuntu@primary:~$ sudo sed -i 's/http:\/\/security.ubuntu.com/https:\/\/mirror.sjtu.edu.cn/g' /etc/apt/sources.list
```

随后安装Docker以及Docker-Compose，完成后退出，使用`multipass`设置别名。

```bash
➜  ~ multipass alias primary:docker docker
```

第一次设置`alias`时应该会提示将一个路径添加到`Path`中，按照指示即可，随后即可在命令行直接调用Docker：

![image-20221116152631805](./image-20221116152631805.png)

#### 容器基础镜像选择

在开始前，需要选定一个基础的镜像，而这个基础的镜像应该满足以下条件：

- GLibc支持
- freetype等动态链接库支持

注意其实`TeamServerImage`包含了`JRE`，因此这里无需再去使用`JRE`的镜像。

在以上的考虑情况之下，首先考虑的是`debian:bullseye`，但是后来想想，`debian:bullseye-slim`似乎会更好，就是不知道`bullseye-slim`是否有`GLibc`支持了。

然后测试:

![image-20221116180130254](./image-20221116180130254.png)

可以看到实际上是有`GLibc 2`的支持的，所以可以选择此镜像了。

但是实际上，这个镜像没有`freetype6`的支持，因此需要使用APT安装。

#### Dockerfile编写

这里的话选用`Workdir`路径是`/usr/app`，然后拷贝对应的`CS Server`，这样子实际上就完成了。

但是为了使得该镜像通用性更好，可以自己写一下`docker-entrypoint.sh`。

这里的话，我个人是写了一个简单的`docker-entrypoint.sh`：

```bash
#!/bin/sh
# vim:sw=4:ts=4:et

set -e

if [ -z $SERVER_PORT ]; then
    SERVER_PORT=50050
fi
if [ -z $BIND ]; then
    BIND=0.0.0.0
fi
if [ -z $KEYSTORE_FILE ]; then
    KEYSTORE_FILE=key.store
fi
if [ -z $KEYSTORE_PASSWORD ]; then
    KEYSTORE_PASSWORD=1234560
fi
if [ -z $HOST ] || [ -z $PASSWORD ]; then
    echo '[-] <HOST>, <PASSWORD> must be set, which would be passed to Cobalt Strike Commandline arguments <host> and <password>.'
    exit 1
fi
if [ -z $C2PROFILE ]; then
    echo "[-] Malleable-C2 Profile not set, are you serious?"
fi
if [ -z $KILLDATE ]; then
    echo "[-] Kill date for Beacon payloads not set."
fi

./TeamServerImage -Dcobaltstrike.server_port=$SERVER_PORT -Dcobaltstrike.server_bindto=$BIND -Djavax.net.ssl.keyStore=$KEYSTORE_FILE -Djavax.net.ssl.keyStorePassword=$KEYSTORE_PASSWORD teamserver $HOST $PASSWORD $C2PROFILE $KILLDATE
```

没有注释，但是应该也很容易看，只是判断是否存在环境变量，然后对应设置初始值或者检查一些必要参数是否有设置，然后传入`TeamServerImage`命令行参数。

至于`Dockerfile`，仅供参考：

```dockerfile
FROM debian:bullseye-slim
MAINTAINER evalexp
RUN mkdir /usr/app
WORKDIR /usr/app
COPY cs4.7-server /usr/app/
RUN chmod +x TeamServerImage && \
    apt-get update && \
    apt-get install -y libfreetype6 && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/*
COPY docker-entrypoint.sh /usr/app
ENTRYPOINT ["bash", "/usr/app/docker-entrypoint.sh"]
```

> 如果解压出来没有对`TeamServerIamge`赋权的话，那么就在`Dockerfile`里赋权。

如果没有最后的`ENTRYPOINT`，则需要自己传入`COMMAND`手动去执行命令。

至此，实际上镜像就已经制作完成了，来看一下大小：

```bash
REPOSITORY         TAG             IMAGE ID       CREATED         SIZE
cobaltstrike-4.7   latest          bf24baee211a   4 seconds ago   348MB
```

总共大约350M左右，还算不错。

> 如果是个人专用的镜像，还可以直接将Malleable-C2配置和keystore文件直接也COPY到镜像里，这样就不用文件映射了。

#### Docker-compose部署

这一个其实就没有什么技术含量了，直接放配置吧：

```yaml
version: "3"

services:
  cobaltstrike:
    image: cobaltstrike-4.7:latest
    network_mode: "host"
    volumes:
      - ./key.store:/usr/app/key.store
      - ./malleable-c2.profile:/usr/app/malleable-c2.profile
    environment:
      - HOST=192.168.1.1
      - PASSWORD=123456
      - SERVER_PORT=12345
      - C2PROFILE=malleable-c2.profile
```

### Server端伪装

#### CloudFlare CDN

需要先有一个CloudFlare的账号，和一个域名，如果想免费域名可以去`Freenom`，付费的国内租即可。

> CDN也可以用其他的，但是需要根据自己的Malleable-C2配置定义规则。

首先配置A记录到你的`Server IP`，如图：

![image-20221116191748188](./image-20221116191748188.png)

然后设置SSL加密方式，在左侧的`Dashboard`选择`SSL/TLS => 概述`，选择`完全`：

![image-20221116192706695](./image-20221116192706695.png)

然后设置SSL证书，在左侧的`Dashboard`选择`SSL/TLS => 源服务器`，创建证书：

![image-20221116191912033](./image-20221116191912033.png)

生成默认的泛域名证书即可。

创建完成后复制公私钥，使用OpenSSL创建`keystore`。

请注意以下，`server.pem`为公钥，`server.key`为私钥。

```bash
openssl pkcs12 -export -in server.pem -inkey server.key -out cdn.xxx.com.p12 -name cdn.xxx.com -passout pass:123456
```

这里的`passout`可以自行设置，只要前后对应即可，接着：

```bash
keytool -importkeystore -deststorepass 123456 -destkeypass 123456 -destkeystore cdn.xxx.com.store -srckeystore cdn.xxx.com.p12 -srcstoretype PKCS12 -srcstorepass 123456 -alias cdn.xxx.com
```

这样子就获得了`cdn.xxx.com.store`，这也是CS即将用到的`keystore`。

至此，Cloudflare CDN就配置完成了，如果你的`Malleable-C2`配置是伪装成静态文件的话，那么还需进行下一步配置。

#### Cloudflare CDN 绕过静态缓存

在左侧的`Dashboard`选择`规则 => 页面规则`，创建一个页面规则，如果是使用`Javascript`静态伪装，则像这样：

![image-20221116192929517](./image-20221116192929517.png)

如果是`png`，则应该改为`cdn.xxx.com/*png`，级别选择绕过。

#### Malleable-C2 Profile

我选择的是这个项目：https://github.com/threatexpress/malleable-c2

可以参考一下，是伪装成`jQeury.js`的请求，下载对应版本的`Profile`，然后需要进行修改：

1. https-certificate

   ```conf
   https-certificate {
       
       ## Option 1) Trusted and Signed Certificate
       ## Use keytool to create a Java Keystore file. 
       ## Refer to https://www.cobaltstrike.com/help-malleable-c2#validssl
       ## or https://github.com/killswitch-GUI/CobaltStrike-ToolKit/blob/master/HTTPsC2DoneRight.sh
      
       ## Option 2) Create your own Self-Signed Certificate
       ## Use keytool to import your own self signed certificates
   
       set keystore "key.store";
       set password "123456";
   
       ## Option 3) Cobalt Strike Self-Signed Certificate
       # set C   "US";
       # set CN  "jquery.com";
       # set O   "jQuery";
       # set OU  "Certificate Authority";
       # set validity "365";
   }
   ```

   注意这里需要密码对应你的`keystore`的密码。

2. http-stager

   ```conf
   http-stager {  
       set uri_x86 "/jquery-3.3.1.slim.min.js";
       set uri_x64 "/jquery-3.3.2.slim.min.js";
   
       server {
           header "Server" "NetDNA-cache/2.2";
           header "Cache-Control" "max-age=0, no-cache";
           header "Pragma" "no-cache";
           header "Connection" "keep-alive";
           header "Content-Type" "application/*; charset=utf-8";
           //...
       }
       client {
           header "Accept" "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8";
           header "Accept-Language" "en-US,en;q=0.5";
           header "Host" "cdn.xxx.com";
           header "Referer" "http://cdn.xxx.com/";
           header "Accept-Encoding" "gzip, deflate";
       }
   }
   ```

   注意只改`http-stager.server.header.Content-Type`、`http-stager.client.Host`、`http-stager.client.Referer`。

3. http-get

   跟上面的`http-stager`差不多，改内部的`server.header.Content-Type`和`client.Host`和`client.Referer`。

4. http-post

   跟上面的`http-stager`差不多，改内部的`server.header.Content-Type`和`client.Host`和`client.Referer`。

> Content-Type不修改的话，容易造成可以上线，但是无法发送命令。

这样，就完成了`Malleable-C2.profile`的修改，可以使用`c2lint`检查一下。

### 测试上线

创建一个HTTPS的监听器：

![image-20221116195120126](./image-20221116195120126.png)

注意`CloudFlare`对HTTPS端口是有限制的，以下端口可供HTTPS连接：

- 443
- 2053
- 2083
- 2087
- 2096
- 8443

上线成功：

![image-20221116195340807](./image-20221116195340807.png)

> Cloudflare在国内很慢，上线需要等待一会儿。

上线后自行测试各项功能是否正常:

![image-20221116204310867](./image-20221116204310867.png)
