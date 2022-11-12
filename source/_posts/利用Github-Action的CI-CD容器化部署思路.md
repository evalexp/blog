---
title: 利用Github Action的CI/CD容器化部署思路
tags:
  - CI/CD Working
  - Github Action
categories:
  - CI/CD
description: 利用Github Action的CI/CD容器化部署思路
excerpt: 利用Github Action的CI/CD容器化部署思路
typora-root-url: 利用Github-Action的CI-CD容器化部署思路
abbrlink: 37025
date: 2022-11-12 20:23:38
---

> 之前是用的KNative Serverless，还算比较好用，可以使用kn cli直接处理镜像容器的问题，但是由于目前各大云服务器厂商的价格都比较高，我还是选择了海外的节点，海外的节点带宽较高，但是配置相对较低，KNative比较适合部署在高配机子上，所以只能探索一种新的CI/CD方案了。

# 利用Github Action的CI/CD容器化部署思路

## Github Action

Github Action目前对普通用户也是免费使用的，貌似有一定的额度，但是对于个人用户而言肯定是足够的。

如果喜欢官方文档，可以去这里：https://docs.github.com/cn/actions

如果想精简一点，会用就行，可以接着看下面的内容，否则直接跳到第二部分即可。

### 快速开始Github Action

你需要在你的Git repository创建一个文件夹名为`.github/workflows`，这个文件夹名字必须是固定的。在其内部则可以创建你的工作流文件。

工作流文件是YAML格式的文件，例如官方给的Example：

```yaml
name: GitHub Actions Demo
run-name: ${{ github.actor }} is testing out GitHub Actions 🚀
on: [push]
jobs:
  Explore-GitHub-Actions:
    runs-on: ubuntu-latest
    steps:
      - run: echo "🎉 The job was automatically triggered by a ${{ github.event_name }} event."
      - run: echo "🐧 This job is now running on a ${{ runner.os }} server hosted by GitHub!"
      - run: echo "🔎 The name of your branch is ${{ github.ref }} and your repository is ${{ github.repository }}."
      - name: Check out repository code
        uses: actions/checkout@v3
      - run: echo "💡 The ${{ github.repository }} repository has been cloned to the runner."
      - run: echo "🖥️ The workflow is now ready to test your code on the runner."
      - name: List files in the repository
        run: |
          ls ${{ github.workspace }}
      - run: echo "🍏 This job's status is ${{ job.status }}."
```

### 定制简单构建工作流

在开始前，必须明白CI中的一些术语：

* workflow：持续集成的一次过程，即一个工作流
* job：一个workflow包含若干个job，即工作流中的工作
* step：一个job包含若干个step，每个step可以执行特定的操作，多个step组成一个完整的job
* action：每个step可以依次执行多个命令（action）

接下来定制工作流，首先需要一个workflow模板，推荐如下：

```yaml
name: Workflow Name

on:
  push:
    tags:
      - "*-build"

jobs:
```

注意这里的name只是指定了工作流的名称，其中`on`是触发配置，如上所示，即会在repository的拥有者push且push的tag为`xxxxx-build`时才会触发此工作流。

> Tips: Github Action的工作流可以有多个，通过不同的文件配置不同的trigger即可。

完整事件列表还是去官网看，此处不列出了。

配置好上面的信息后，只需要开始配置你的jobs即可完成Action的定制了。

以使用`Gradle`构建的`Java Application`为例，针对其`build`过程，可以分解为两个`step`，第一个是安装合适版本的JDK和`Gradle`，第二个则是通过`Gradle`构建程序。

于是可以得到下面的Jobs：

```yaml
    runs-on: ubuntu-latest
    steps:
      - name: set up JDK 11
        uses: actions/setup-java@v3
        with:
          java-version: "11"
          distribution: "temurin"
          cache: gradle

      - name: Grant execute permission for gradlew
        run: chmod +x gradlew
      - name: Build with Gradle
        run: ./gradlew build
```

针对上面的一些东西进行讲解，可以看到`runs-on`用于定制运行环境。

同时这里可以看到在安装JDK时，使用了`uses: action/setup-java@v3`，具体的可以看其使用说明：https://github.com/actions/setup-java，此处仅讲解关键点。

每个`step`的name可以随意，但是最好见名知意，`uses`可以指定一个`action`仓库，一般来说可以到https://github.com/actions里找适合自己的，然后参照使用说明配置`with`项。

这里的`actions/setup-java@v3`就是用于安装JDK的。

随后的`step`都仅仅是执行命令，第二个`step`为`gradle`赋予了执行权限，随后第三个`step`调用了`gradle`构建了程序。

在这里其实还有一个问题，即代码从哪儿来？

一般来说会在`steps`的第一个`step`配置代码，使用的是`actions/checkout@v3`，完整的配置如下：

```yaml
name: Android CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
      - name: set up JDK 11
        uses: actions/setup-java@v3
        with:
          java-version: "11"
          distribution: "temurin"
          cache: gradle

      - name: Grant execute permission for gradlew
        run: chmod +x gradlew
      - name: Build with Gradle
        run: ./gradlew build
```

上面的只配置了一个`job`即构建，实际上可以加上`test`等不同需求的`job`。

### 定制工作流 - Github Release自动推送

在这里会通过定义多个`job`来实现构建与`Github Release`的推送。

以构建安卓程序来说，其构建的`step`可以定制为：

 ```yaml
 jobs:
   build:
     runs-on: ubuntu-latest
 
     steps:
       - uses: actions/checkout@v3
       - name: set up JDK 11
         uses: actions/setup-java@v3
         with:
           java-version: "11"
           distribution: "temurin"
           cache: gradle
 
       - name: Grant execute permission for gradlew
         run: chmod +x gradlew
       - name: Build with Gradle
         run: ./gradlew build
 
 
 ```

为了自动上传构建后的文件到`Github Release`，我们需要添加一个`Upload Action`，如下：

```yaml
      - name: Upload Release APK
        uses: actions/upload-artifact@v3
        with:
          name: AndroidAppliacation-Release
          path: app/build/outputs/apk/release/app-release-unsigned.apk
```

接下来定制`release job`，首先`Github Release`实际根据`Tag`进行分类，

那么首先先获取对应的`Tag Name`：

```yaml
      - name: Prepare Release
        id: prepare_release
        run: |
          TAG_NAME=`echo $GITHUB_REF | cut -d / -f3`
          echo ::set-output name=tag_name::$TAG_NAME
```

随后问题来了，怎么获取上一个`job`的构建程序呢？

要注意每个`job`都是运行在独立的环境中的，于是需要对一个`job`进行调整，使其上传对应的构建好的文件：

```yaml
      - name: Upload Release APK
        uses: actions/upload-artifact@v3
        with:
          name: AndroidApp-Release
          path: app/build/outputs/apk/release/app-release-unsigned.apk
```

然后在第二个`job`中下载该APK：

```yaml
      - name: Download Release APK
        if: steps.prepare_release.outputs.tag_name
        uses: actions/download-artifact@v2
        with:
          name: AndroidApp-Release
```

请注意`name`字段的对应关系。

可以看到这里实际上还配置了`if`，只有在获取`tag_name`成功时才会执行此步。

随后创建`Github Release`：

```yaml
      - name: Create Release
        id: create_release
        if: steps.prepare_release.outputs.tag_name
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
        with:
          tag_name: ${{steps.prepare_release.outputs.tag_name}}
          release: Release ${{steps.prepare_release.outputs.tag_name}} by Evalexp
          draft: false
          prerelease: false
```

这里的`GITHUB_TOKEN`是自己获取的，无需自己进行配置。

注意`steps.prepare_release.outputs.tag_name`实际上是第一个`step`的输出，在使用中可以通过`echo ::set-output name=key::value`设置键值对，然后在其他`step`中通过上述手段获取。

最后，将对应的APK上传至`Github Release`中：

```yaml
      - name: Upload Release Assets
        id: upload_release_assets
        if: steps.create_release.outputs.upload_url
        uses: actions/upload-release-asset@v1
        env:
          GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
        with:
          upload_url: ${{steps.create_release.outputs.upload_url}}
          asset_path: ./app-release-unsigned-${{steps.prepare_release.outputs.tag_name}}.apk
          asset_name: app-release-unsigned-${{steps.prepare_release.outputs.tag_name}}.apk
          asset_content_type: application/vnd.android.package-archive
```

至此就配置完成了。

附完整配置：

```yaml
name: Android Release

on:
  push:
    tags: [v*]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
      - name: set up JDK 11
        uses: actions/setup-java@v3
        with:
          java-version: "11"
          distribution: "temurin"
          cache: gradle

      - name: Grant execute permission for gradlew
        run: chmod +x gradlew
      - name: Build with Gradle
        run: ./gradlew build

      - name: Upload Release APK
        uses: actions/upload-artifact@v3
        with:
          name: AndroidApp-Release
          path: app/build/outputs/apk/release/app-release-unsigned.apk

  release:
    needs: build

    runs-on: ubuntu-latest

    steps:
      - name: Prepare Release
        id: prepare_release
        run: |
          TAG_NAME=`echo $GITHUB_REF | cut -d / -f3`
          echo ::set-output name=tag_name::$TAG_NAME
      - name: Download Release APK
        if: steps.prepare_release.outputs.tag_name
        uses: actions/download-artifact@v2
        with:
          name: AndroidApp-Release

      - shell: bash
        run: |
          mv app-release-unsigned.apk app-release-unsigned-${{steps.prepare_release.outputs.tag_name}}.apk
      - name: Create Release
        id: create_release
        if: steps.prepare_release.outputs.tag_name
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
        with:
          tag_name: ${{steps.prepare_release.outputs.tag_name}}
          release: Release ${{steps.prepare_release.outputs.tag_name}} by Evalexp
          draft: false
          prerelease: false

      - name: Upload Release Assets
        id: upload_release_assets
        if: steps.create_release.outputs.upload_url
        uses: actions/upload-release-asset@v1
        env:
          GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
        with:
          upload_url: ${{steps.create_release.outputs.upload_url}}
          asset_path: ./app-release-unsigned-${{steps.prepare_release.outputs.tag_name}}.apk
          asset_name: app-release-unsigned-${{steps.prepare_release.outputs.tag_name}}.apk
          asset_content_type: application/vnd.android.package-archive
```

## 持续集成 - CI

在有了上面的基础知识后，就可以进入到今天的主题了，即使用`Github Action`进行`CI/CD`，实际上`Github Action`主要还是进行的`CI`而不是`CD`。

以常规的静态博客为例，我使用的是`Hexo`，这是一个基于`NodeJS`的静态博客生成框架，那么对于静态博客的生成来说，其构建步骤较为简单，给出`workflow`如下：

```yaml
name: Blog CI

on:
  push:
    tags:
      - "*-build"

jobs:
  build:
    name: Build Docker image and auto deploy
    runs-on: ubuntu-latest

    steps:
      - name: Check out
        uses: actions/checkout@v2

      - name: Get Tag
        id: meta
        uses: docker/metadata-action@v3
        with:
          images: |
            registry.cn-shanghai.aliyuncs.com/evalexp-private/blog

      - name: Setup Nodejs
        uses: actions/setup-node@v3
        with:
          node-version: 16

      - name: Install Hexo
        run: npm install hexo -g

      - name: Install dependencies
        run: npm install

      - name: Generate Blog
        run: hexo g

```

上面唯一需要解释一下的就是第二个`step`了，这个是`docker`官方提供的从`Git refs`提取元数据的`Action`，比较方便。其中`images`字段是`Tag`的`base name`，

注意上面其实就已经将博客正常构建完成了，接下来是将其进行`Docker`镜像的打包，对于静态博客，打包比较简单，只需要通过`Nginx`镜像的定制即可，`Dockerfile`如下：

```dockerfile
FROM nginx
COPY public /usr/share/nginx/html
```

随后使用`Docker`官方的`Action`构建并推送到远程仓库。

由于`Docker Hub`国内基本访问龟速，因此这里使用了阿里云的镜像服务，个人版有100个镜像仓库容量，比较推荐。

在推送前需要进行登陆操作：

```yaml
      - name: Login Registry
        uses: docker/login-action@v1
        with:
          registry: registry.cn-shanghai.aliyuncs.com
          username: ${{ secrets.ALIYUN_USER }}
          password: ${{ secrets.ALIYUN_PASSWORD }}
```

这里需要注意，这里的`secrets`需要自己在项目的`Settings`中配置才能使用。

随后根据`Dockerfile`构建推送：

```yaml
      - name: Build and push
        uses: docker/build-push-action@v3
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

附完整的配置文件：

```yaml
name: Blog CI

on:
  push:
    tags:
      - "*-build"

jobs:
  build:
    name: Build Docker image and auto deploy
    runs-on: ubuntu-latest

    steps:
      - name: Check out
        uses: actions/checkout@v2

      - name: Get Tag
        id: meta
        uses: docker/metadata-action@v3
        with:
          images: |
            registry.cn-shanghai.aliyuncs.com/evalexp-private/blog

      - name: Setup Nodejs
        uses: actions/setup-node@v3
        with:
          node-version: 16

      - name: Install Hexo
        run: npm install hexo -g

      - name: Install dependencies
        run: npm install

      - name: Generate Blog
        run: hexo g

      - name: Login Registry
        uses: docker/login-action@v1
        with:
          registry: registry.cn-shanghai.aliyuncs.com
          username: ${{ secrets.ALIYUN_USER }}
          password: ${{ secrets.ALIYUN_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v3
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

```

## 持续部署 - CD

基于容器化的持续部署其实比较简单，常见的方案就两种：

* Webhook
* Watch

两种方案其实理论上`Webhook`会更好一点，只需要在服务器上启动一个`Webhook`服务，`Github Action`构建完成后通过`Webhook`通知服务器拉取最新镜像重新通过新镜像启动容器即可自动部署，但是目前来说该方案还没有一个成熟的实践，因此还是采用了第二种，即`Watch`方式。

`Watch`方式实际上是通过一定时间间隔的轮询镜像是否更新，如果有则停止容器并且拉取最新镜像，这种方式无需`Github`方面有任何配置，也算是一种优点了。

此处采用的是`watchtower`，这里我只对个人的博客以及cyberchef（传入的参数应该是容器名，因此建议容器名自定义）进行了`watch`，轮询时间为30秒：

```yaml
version: "3"
services:
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /home/evalexp/.docker/config.json:/config.json
    command: --interval 30 cyberchef blog 
    logging:
      options:
        max-size: "5m"
```

此时通过推送最新博客的`source`至`Github`触发构建，即可完成整套`CI/CD`流程。
