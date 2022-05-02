---
title: Drone with Gitea
tags:
  - CI/CD Working
  - Drone
  - Gitea
categories: 
  - CI/CD
description: Use Drone CI/CD to auto build and deploy.
excerpt: Use Drone CI/CD to auto build and deploy.
abbrlink: 63622
date: 2021-05-19 15:31:44
typora-root-url: Drone-with-Gitea
---

# Drone with Gitea

首先是配置一个环境，这里我的Gitea以及Drone都将使用Docker进行部署。

## Delpoy Gitea with Docker

先考虑部署Gitea，官方文档可见：

> [Installation with Docker - Docs (gitea.io)](https://docs.gitea.io/en-us/install-with-docker/)

在部署前安装`Docker`以及`Docker-compose`这两个软件。官方给出的基础`docker-compose.yml`文件如下：

```yaml
version: "3"

networks:
  gitea:
    external: false

services:
  server:
    image: gitea/gitea:1.14.2
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: always
    networks:
      - gitea
    volumes:
      - ./gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "222:22"
```

其中`volumes`的挂载卷除第一个可修改外，其余不可修改，另外，本人选取的`docker image tag`为`latest`，建议参考官方给出的版本号`tag`，其余设置按需修改端口号即可。

本人配置如下：

```yaml
version: "3" 

networks:
  gitea:
    external: false

services:
  server:
    image: gitea/gitea:latest
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: always
    networks:
      - gitea
    volumes: 
      - ./data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "10081:3000"
      - "9022:9022"
```

修改完`docker-compose.yml`文件后使用`docker-compose`进行部署：

```bash
mkdir /app/gitea
cd /app/gitea
sudo docker-compose up -d
sudo docker ps -a
```

如无意外应看到`gitea`的`container`运行起来了：

```bash
CONTAINER ID   IMAGE                         COMMAND                  CREATED          STATUS          PORTS                                                                                    NAMES
7045e8aece99   gitea/gitea:latest            "/usr/bin/entrypoint…"   2 days ago       Up 2 hours      0.0.0.0:9022->9022/tcp, :::9022->9022/tcp, 0.0.0.0:10081->3000/tcp, :::10081->3000/tcp   gitea
```

> 本人的Gitea已经部署很久了

接下来访问`Gitea`，系统将要求你进行安装配置，输入配置完成安装后可进入`Gitea`。

> 可以使用Sqlite3，当然也可以使用更好的MySQL以及Postgresql，本人在主机上安装了Postgresql并配置Gitea使用Postgresql

至此，`Gitea`部署完成，如出现容器不断重启，请查看日志，并修改配置文件。

配置文件位于：

```bash
/app/gitea/data/gitea/conf/app.ini
```

你可以按照官方文档修改该配置文件直至容器可正常启动。

## Deploy Drone With Docker

### Drone

先看官方文档：

> [Gitea | Drone](https://docs.drone.io/server/provider/gitea/)

在`Gitea`中登录管理员账号，然后创建一个`OAuth2`程序。官方说的很清楚，你的回调URL应该为：

```conf
http[s]://domain[:port]/login
```

其中`domain`可以为一个IP地址。完成后请保存`secret`，它将在接下来的`Drone部署`应用到。

按照官方给出的文档，使用docker可以直接部署一个基础的`Drone`，命令如下：

```bash
docker run \
  --volume=/var/lib/drone:/data \
  --env=DRONE_GITEA_SERVER={{DRONE_GITEA_SERVER}} \
  --env=DRONE_GITEA_CLIENT_ID={{DRONE_GITEA_CLIENT_ID}} \
  --env=DRONE_GITEA_CLIENT_SECRET={{DRONE_GITEA_CLIENT_SECRET}} \
  --env=DRONE_RPC_SECRET={{DRONE_RPC_SECRET}} \
  --env=DRONE_SERVER_HOST={{DRONE_SERVER_HOST}} \
  --env=DRONE_SERVER_PROTO={{DRONE_SERVER_PROTO}} \
  --publish=80:80 \
  --publish=443:443 \
  --restart=always \
  --detach=true \
  --name=drone \
  drone/drone:1
```

但遗憾的是，官方未给出使用`docker-compose`的`yml`文件，因此我考虑先阅读完整个过程再自行编写`docker-compose.yml`文件，根据上述的命令，可以写出以下的`docker-compose.yml`文件：

> 注意：在该部署中，你需要完整的提供所有信息，包括域名等有效信息，暂时未发现可以直接修改配置文件等方式修改部署配置，因此如果信息有误，你必须删除该容器后重新启动容器

```yaml
version: '3'  
services:
  drone:
    container_name: drone-server
    image: drone/drone:1
    ports:
      - 10082:80
    volumes:
      - ./data:/data
    restart: always
    environment:
      - DRONE_GITEA_SERVER={{DRONE_GITEA_SERVER}}
      - DRONE_GITEA_CLIENT_ID={{DRONE_GITEA_CLIENT_ID}}
      - DRONE_GITEA_CLIENT_SECRET={{DRONE_GITEA_CLIENT_SECRET}}
      - DRONE_RPC_SECRET={{DRONE_RPC_SECRET}}
      - DRONE_SERVER_HOST={{DRONE_SERVER_HOST}}
      - DRONE_SERVER_PROTO={{DRONE_SERVER_PROTO}}
```

说明如下：

* DRONE_GITEA_SERVER: 填写你的`Gitea地址`，包含http(s)，例如`https://mygitea.com`
* DRONE_GITEA_CLIENT_ID: 方才在Gitea创建的`OAuth2`程序中的`客户端ID`
* DRONE_GITEA_CLIENT_SECRET: 方才在Gitea创建的`OAuth2`程序中的`客户端密钥`
* DRONE_RPC_SECRET: 你可以使用openssl生成一个和`Runner`通信的密钥，命令为`openssl rand -hex 16`，该密钥请同样留存

* DRONE_SERVER_HOST: Drone的`域名`，请不要书写协议，例如`mydrone.com`
* DRONE_SERVER_PROTO: 服务协议，可选`http`和`https`，根据自己实际情况而定

在以上基础上，本人引入了`Postgresql`作为Drone的数据库系统，因此还加入了部分配置，亦新建了Drone的管理员，整体配置如下：

```yaml
version: '3'  
services:
  drone:
    container_name: drone-server
    image: drone/drone:1
    ports:
      - 10082:80
    volumes:
      - ./data:/data
    restart: always
    environment:
      - DRONE_GITEA_SERVER={{DRONE_GITEA_SERVER}}
      - DRONE_GITEA_CLIENT_ID={{DRONE_GITEA_CLIENT_ID}}
      - DRONE_GITEA_CLIENT_SECRET={{DRONE_GITEA_CLIENT_SECRET}}
      - DRONE_RPC_SECRET={{DRONE_RPC_SECRET}}
      - DRONE_SERVER_HOST={{DRONE_SERVER_HOST}}
      - DRONE_SERVER_PROTO={{DRONE_SERVER_PROTO}}
      - DRONE_DATABASE_DRIVER=postgres
      - DRONE_DATABASE_DATASOURCE=postgres://root:password@1.2.3.4:5432/postgres?sslmode=disable
      - DRONE_USER_CREATE=username:{{DRONE_ADMIN}},admin:true
```

说明的只有一个：

* DRONE_ADMIN: Drone的管理员用户名

至于数据库配置请参照配置中的链接。

完成后，我们来进行`Runner`的部署。

### Drone Runner

我这里选用的是`Docker Runner`，这对我而言更加易于使用。

官方文档：

> [Runner Overview | Drone](https://docs.drone.io/runner/docker/overview/)

同样的，官方未给出`docker-compose.yml`，因此还是照着命令书写，官方命令如下：

```bash
docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e DRONE_RPC_PROTO=https \
  -e DRONE_RPC_HOST=drone.company.com \
  -e DRONE_RPC_SECRET=super-duper-secret \
  -e DRONE_RUNNER_CAPACITY=2 \
  -e DRONE_RUNNER_NAME=${HOSTNAME} \
  -p 3000:3000 \
  --restart always \
  --name runner \
  drone/drone-runner-docker:1
```

对应的`docker-compose.yml`文件则为：

```yaml
drone-docker-runner:
    container_name: drone-docker-runner
    image: drone/drone-runner-docker:1
    ports:
    - 10011:3000
    restart: always
    depends_on:
    - drone
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    environment:
    - DRONE_RPC_PROTO={{DRONE_SERVER_PROTO}}
    - DRONE_RPC_HOST={{DRONE_SERVER_HOST}}
    - DRONE_RPC_SECRET={{DRONE_RPC_SECRET}}
    - DRONE_RUNNER_CAPACITY=2
    - DRONE_RUNNER_NAME=docker-runner
```

> !此内容为节选，不是完整的文件内容

然后组合一下，完整的文件内容为：

```yaml
version: '3'  
services:
  drone:
    container_name: drone-server
    image: drone/drone:1
    ports:
      - 10082:80
    volumes:
      - ./data:/data
    restart: always
    environment:
      - DRONE_GITEA_SERVER={{DRONE_GITEA_SERVER}}
      - DRONE_GITEA_CLIENT_ID={{DRONE_GITEA_CLIENT_ID}}
      - DRONE_GITEA_CLIENT_SECRET={{DRONE_GITEA_CLIENT_SECRET}}
      - DRONE_RPC_SECRET={{DRONE_RPC_SECRET}}
      - DRONE_SERVER_HOST={{DRONE_SERVER_HOST}}
      - DRONE_SERVER_PROTO={{DRONE_SERVER_PROTO}}
      - DRONE_DATABASE_DRIVER=postgres
      - DRONE_DATABASE_DATASOURCE=postgres://root:password@1.2.3.4:5432/postgres?sslmode=disable
      - DRONE_USER_CREATE=username:{{DRONE_ADMIN}},admin:true
      
  drone-docker-runner:
    container_name: drone-docker-runner
    image: drone/drone-runner-docker:1
    ports:
    - 10011:3000
    restart: always
    depends_on:
    - drone
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    environment:
    - DRONE_RPC_PROTO={{DRONE_SERVER_PROTO}}
    - DRONE_RPC_HOST={{DRONE_SERVER_HOST}}
    - DRONE_RPC_SECRET={{DRONE_RPC_SECRET}}
    - DRONE_RUNNER_CAPACITY=2
    - DRONE_RUNNER_NAME=docker-runner
```

随后，使用`docker-compose`启动该容器。

```bash
mkdir /app/drone
cd /app/drone
sudo docker-compose up -d
sudo docker ps -a
```

如无意外，你将看到两个容器正常启动;

```bash
CONTAINER ID   IMAGE                         COMMAND                  CREATED             STATUS             PORTS                                                                                    NAMES 	
f14db02cd116   drone/drone-runner-docker:1   "/bin/drone-runner-d…"   About an hour ago   Up About an hour   0.0.0.0:10011->3000/tcp, :::10011->3000/tcp                                              drone-docker-runner
247fe706b523   drone/drone:1                 "/bin/drone-server"      About an hour ago   Up About an hour   443/tcp, 0.0.0.0:10082->80/tcp, :::10082->80/tcp                                         drone-server
```

但是`runner`不一定能正常启动，请使用日志判断是否正常：

```bash
sudo docker logs drone-docker-runner
```

当存在一下类似日志时，即表明正常:

```log
time="2021-05-19T07:14:18Z" level=info msg="successfully pinged the remote server"
```

至此，`Drone with Gitea部署`完成。

## Drone CI/CD Example with hexo blog

> 说明：这个例子是为了解决一些未使用过Drone已经刚接触Drone不太熟悉Drone的人准备的，里面包含的问题大部分新手都可能遇到。

开始前，我们了解一下官方对`pipeline`的解释：

> Pipelines help you automate steps in your software delivery process, such as initiating code builds, running automated tests, and deploying to a staging or production environment.
>
> Pipeline execution is triggered by a source code repository. A change in code triggers a webhook to Drone which runs the corresponding pipeline. Other common triggers include automatically scheduled or user-initiated workflows.
>
> Pipelines are configured by placing a `.drone.yml` file in the root of your git repository. The yaml syntax is designed to be easy to read and expressive so that anyone viewing the repository can understand the workflow.

翻译一下，大致意思就是流水线自动构建、测试以及部署你的服务，这一切依赖于文件`.drone.yml`实现，来看一下一个`pipeline`的例子：

```yaml
kind: pipeline
type: docker
name: default

steps:
- name: greeting
  image: alpine
  commands:
  - echo hello
  - echo world
```

接下来对上面的一些字段解释：

* kind 一般而言都是定义为流水线，即`pipeline`，也可以定义为`secret`和`signature`，具体见文档[Secrets | Drone](https://docs.drone.io/secret/)和[Signatures | Drone](https://docs.drone.io/signature/)
* type 流水线类型，具体参考Drone的各类型`Pipeline`
* name 为此次CI/CD指定名字
* steps 在steps下指定若干个step执行流水线作业，其中一个流水线作业失败，整个流水线作业都将终止

然后来看看具体的单个`step`应该怎么做：

定义单个`step`非常简单，只需要指定它的`name`和它的`image`即可，这就是一个最简单的`step`，但是该`step`将什么都不做，如果需要进行操作，你需要配置`commands`或者根据相应的插件配置对应的`字段值`。

接下来我们将以一个`Hexo Blog Build and Delploy`的例子来看看一个`CI/CD`具体应该如何书写。	

### Step 1 - Clone

该代码仓库为`Gitea`的`Private Repo`，对于私有仓库，我们应该自主`clone`，而不应该使用`Drone`的`Clone`过程，所以第一步我们禁用`Drone Clone`，第二步使用`git`的容器进行克隆。

则书写为下面的配置文件：

> 该文件内容来自于我真实的博客`CI/CD`配置

```yaml
kind: pipeline
type: docker
name: blog-pipeline

clone:
  disable: true

steps:
- name: clone
  image: alpine/git
  environment: 
    SSH_KEY:
      from_secret: SSH_KEY
  commands:
    - mkdir -p /root/.ssh/
    - echo "$SSH_KEY" > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
    - ssh-keyscan -p $SSH_PORT -t rsa $SSH_HOST >> ~/.ssh/known_hosts
    - git clone "ssh://git@$SSH_HOST:$SSH_PORT/evalexp/PentestBlog.git" .
```

> 不需要在普通命令中使用secret的变量，上面的除了SSH_KEY变量以外，请将SSH_PORT以及SSH_HOST修改为准确值。

在第一个`clone`的`step`中，我们使用了`alpine/git`这个镜像来进行克隆。由于是私有仓库的克隆，因此，我们需要导入`SSH 密钥`来进行克隆，这里的`SSH 密钥`建议使用`Gitea 部署密钥`，具体密钥生成方法参照Github以及Gitlab的`Deploy Key`。

你应该注意到了，`environment`实际上就是暴露给容器的环境变量，而`from_secret`则是`Drone`配置，你需要在`Drone`中添加`Secret`，这样才可以使用`from_secret`获取这些变量的值，添加页面如下：

![image-20210519164140935](image-20210519164140935.png)

这样第一个克隆步骤就可以完成了。

### Step 2 - Build

第二个步骤，构建这个博客。

这个`step`相对简单，我们使用`node`镜像利用`npm install`等即可完成，此处不再赘述，配置如下：

> 完成后将生成的文件打包一下，以便传输

```yaml
- name: generate
  image: node:16-alpine
  commands:
    - npm install hexo -g
    - npm install
    - node fix-image.js
    - hexo g
    - tar -czvf publish.tar.gz -C public .
```

### Step 3 - Upload

这个步骤实际上用于将打包的文件上传到你的服务器上，我们使用`Drone`的插件`SCP`来完成这件事，插件用法可以去插件首页查看。

文件内容如下：

```yaml
- name: scp file
  image: appleboy/drone-scp
  settings:
    host:
      from_secret: SSH_HOST
    username:
      from_secret: SSH_USER
    password:
      from_secret: SSH_PASSWORD
    port:
      from_secret: SSH_PORT
    target: /tmp
    source:
      - publish.tar.gz
      - deploy.sh
```

> 此处拷贝了发布文件的压缩包，以及部署脚本，部署脚本将在服务器上运行

### Step 4 - Deploy

关于部署，自动化由脚本完成，`Drone`的使命至此完成，在执行`deploy.sh`后，整个`CI/CD`便完成了，但是最关键的部署往往是最复杂的，请注意部署脚本的书写。

这是我的部署脚本：

```bash
#!/bin/bash

DEPLOY_DIR=/app/blog
BACKUP_DIR=/home/evalexp/backups/blog
USER_AND_GROUP=evalexp:evalexp

# prepare workspace
if [ ! -d $DEPLOY_DIR ]; then
    mkdir -p $DEPLOY_DIR
    chown -R $USER_AND_GROUP $DEPLOY_DIR
fi

if [ ! -d $BACKUP_DIR ]; then
    mkdir -p $BACKUP_DIR
    chown -R $USER_AND_GROUP $BACKUP_DIR
fi

# backup
time=$(date +%Y-%m-%d-%H:%M)
tar -czvf "$BACKUP_DIR/blog.$time.tar.gz" $DEPLOY_DIR

# clean old data
rm -rf "$DEPLOY_DIR/*"

# deploy
tar -zxvf /tmp/publish.tar.gz -C $DEPLOY_DIR
```

使用该脚本部署将自动备份旧版本博客，并将发布包释放到部署目录，仅用于静态网站部署。

> Web服务部署实际也差不多一致，在项目中书写好`Dockerfile`，将`jar`或者其余格式的文件挂载到宿主机，使用`docker`停止容器，更换后继续启动容器即可。

由于在宿主机中执行脚本等，使用`Drone`的`SSH`插件来完成此次工作：

```yaml
- name: deploy
  image: appleboy/drone-ssh
  settings:
    host:
      from_secret: SSH_HOST
    username:
      from_secret: SSH_USER
    password:
      from_secret: SSH_PASSWORD
    port:
      from_secret: SSH_PORT
    script:
      - bash /tmp/deploy.sh
      
```

这样就配置好了一个`CI/CD`流水线作业，现在推送，让服务器自动构建，并部署到我们的服务器上。

如果你愿意配置，使用`Docker hub`的镜像以及官方插件，你有无限的可能。

