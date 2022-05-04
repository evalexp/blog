---
title: 国内云搭建单机KNative & Github Action CI/CD
tags:
  - CI/CD Working
  - KNative
  - Github
categories:
  - CI/CD
description: Use Github Action CI/CD and KNative as deploy platform.
excerpt: Use Github Action CI/CD and KNative as deploy platform.
abbrlink: 48494
date: 2022-05-03 12:32:33
typora-root-url: 国内云搭建单机KNative-Github-Action-CI-CD
---

# 国内云搭建单机KNative & Github Action CI/CD

> 之所以写这是因为国内的Kubernetes环境实在是太差了，前后折腾了好久才解决。
>
> 选用KNative Serverless平台的主要原因是这个平台成熟好用，并且基于镜像的服务迁移会比基于Gitea + Drone的服务迁移方便快捷。

## K8S安装

KNative原生支持的平台是Kubernetes，可以快速方便的部署到集群中，但是这就为单机部署造成了一定的困难性。

Minikube是一个单机上的Kubernetes集群实现，支持所有的Kubernetes特性，非常适合作为本地Kubernetes的开发和调试，在这里我使用它作为KNative的搭建平台。

### 国内云安装Minikube

#### 下载Minikube

下载二进制版本的程序或者是Debian的Package：

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

或：

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb
```

#### 搭建集群

此处使用阿里云镜像服务作为启动镜像，避免出现`ErrImagePull`问题。

我使用的是Docker驱动，可选Virtualbox：

```bash
minikube start --image-mirror-country cn \
--image-repository=registry.cn-hangzhou.aliyuncs.com/google_containers \
--vm-driver=docker \
--memory=2048 \
--cpus=2
```

参数应该都简洁易懂。

稍等片刻应该就搭建成功了。

#### 安装Kubectl

> 腾讯云的Ubuntu默认好像没有snap，需要自己安装

```bash
sudo apt-get install snapd -y
sudo snap install kubectl
```

版本应该都没有问题的，如果有问题，可以使用minikube安装对应的kubectl。

然后使用：

```bash
kubectl get pods -n kube-system
```

如果有以下输出，并且全部为Ready的话，就是集群搭建好了：

![image-20220503124809795](./image-20220503124809795.png)

在Docker里应该看得到一个name为minikube的容器正在运行。

### 国内云通过Kubeadm初始化K8S

#### 添加K8S源

修改apt的sources.list：

```bash
evalexp@VM-16-6-ubuntu:~/knative$ cat /etc/apt/sources.list
deb http://mirrors.tencentyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.tencentyun.com/ubuntu/ focal-security main restricted universe multiverse
deb http://mirrors.tencentyun.com/ubuntu/ focal-updates main restricted universe multiverse
#deb http://mirrors.tencentyun.com/ubuntu/ focal-proposed main restricted universe multiverse
#deb http://mirrors.tencentyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://mirrors.tencentyun.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.tencentyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://mirrors.tencentyun.com/ubuntu/ focal-updates main restricted universe multiverse
#deb-src http://mirrors.tencentyun.com/ubuntu/ focal-proposed main restricted universe multiverse
#deb-src http://mirrors.tencentyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://mirrors.tencentyun.com/kubernetes/apt kubernetes-xenial main
```

增加最下面的：`deb http://mirrors.tencentyun.com/kubernetes/apt kubernetes-xenial main`

然后添加签名：

```bash
curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -
```

#### 安装K8S工具

```bash
sudo apt-get update 
sudo apt-get install kubectl kubeadm kubelet
```

#### 初始化K8S

关闭Swap和防火墙，修改Docker的Cgroups为Systemd：

```bash
sudo ufw disable
sudo systemctl disable ufw
sudo swapoff -a
# 修改 /etc/fstab
# 将类似/dev/disk/by-uuid/b986dc3b-6b82-44d5-acb8-6cbad5e357d5 / ext4 defaults 0 0这行内容的注释掉
```

然后修改Docker的cgroups：

```bash
{
"registry-mirrors": [
 "https://mirror.ccs.tencentyun.com"
],
"exec-opts": ["native.cgroupdriver=systemd"]
}
```

重启相关程序：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

开始初始化K8S：

```bash
sudo kubeadm reset
sudo kubeadm init --image-repository registry.aliyuncs.com/google_containers --pod-network-cidr=10.10.0.0/16
```

应该会看到下面的内容：

```bash
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  <https://kubernetes.io/docs/concepts/cluster-administration/addons/>

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 机器IP:6443 --token XXXX.XXXXX \\
    --discovery-token-ca-cert-hash sha256:XXXXXXXXXXXXXXXXXXXXXXXXXX

```

按照提示配置非root操作即可。

#### 安装网络插件

这里选择的是Flannel：

```bash
curl -LO https://ghproxy.com/https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f kube-flannel.yml
```

等待片刻，然后查看各个Pods状态，应该都是Ready的。

#### 允许Master节点创建Pod

```bash
kubectl taint nodes --all node-role.kubernetes.io/master-
```

## 安装KNative

### 国内云安装KNative

> 到这里开始出现大量的问题了，如果一步一步照着我的做应该是没有问题的。用腾讯云的可以使用快照功能，避免出现问题后弄崩了

自己比较熟悉Kubernetes的可以参考下面的镜像源自己配置：

* k8s.gcr.io <==> lank8s.cn
* gcr.io <==> gcr.lank8s.cn
* quay.io <==> quay.mirrors.ustc.edu.cn

#### 应用KNative Custom Resources

```bash
curl  -LO https://ghproxy.com/https://github.com/knative/serving/releases/download/knative-v1.4.0/serving-crds.yaml
kubectl apply -f serving-crds.yaml
```

#### 安装KNative Serving核心组件

```bash
curl -LO https://ghproxy.com/https://github.com/knative/serving/releases/download/knative-v1.4.0/serving-core.yaml
sed -i "s/gcr.io/gcr.lank8s.cn/g" serving-core.yaml # 必做
kubectl apply -f serving-core.yaml
```

#### 安装网络层

> 这里我选择的是Kourier，主要是懒得折腾，我对性能要求也不高

```bash
curl -LO https://ghproxy.com/https://github.com/knative/net-kourier/releases/download/knative-v1.4.0/kourier.yaml
sed -i "s/gcr.io/gcr.lank8s.cn/g" kourier.yaml
kubectl apply -f kourier.yaml
```

#### 配置KNative Serving使用Kourier

```bash
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'
```

#### 获取External IP

```bash
kubectl --namespace kourier-system get service kourier
```

可能会输出如下结果：

```bash
NAME      TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
kourier   LoadBalancer   10.106.138.38   <Pending>       80:30916/TCP,443:32096/TCP   40h
```

##### 使用Minikube Tunnel获取External IP

> 可以使用普通权限的用户，但是注意输入密码

```bash
(minikube tunnel -c &)
```

使用`ps -ef | grep minikube`这会显示：

```bash
evalexp    19585       1  0 May01 ?        00:02:27 minikube tunnel -c
```

可以看到其父进程是pid=1的进程，把这个进程一直放到后台就好。

这个时候再去获取External IP应该就没有问题了。

```bash
NAME      TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
kourier   LoadBalancer   10.106.138.38   10.106.138.38   80:30916/TCP,443:32096/TCP   40h
```

##### 单机K8S获取External IP

需要安装MetalLB：

```bash
curl -LO https://ghproxy.com/https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
curl -LO https://ghproxy.com/https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/metallb.yaml
kubectl apply -f namespace.yaml
kubectl apply -f metallb.yaml
```

此时还无法获取到具体的External IP，为其分配IP池：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.240-192.168.1.250
```

保存该文件，使用`kubectl apply -f addrpool.yaml`。

此时查看应该可以看到IP地址了。

#### 确认安装情况

```bash
kubectl get pods -n knative-serving
```

如果看到下面的服务都Ready的话就没什么问题了：

```bash
NAME                                     READY   STATUS    RESTARTS   AGE
activator-794bb7b879-9kccs               1/1     Running   0          40h
autoscaler-6f8d4b944f-pthqm              1/1     Running   0          40h
controller-54bd5dc57-4w9jn               1/1     Running   0          40h
domain-mapping-59ccc644bb-fblnn          1/1     Running   0          40h
domainmapping-webhook-86b8b5658d-b8b6x   1/1     Running   0          40h
net-kourier-controller-9447f47ff-xnz44   1/1     Running   0          40h
webhook-6648b86c68-kqtck                 1/1     Running   0          40h
```

#### 配置DNS

```bash
kubectl patch configmap/config-domain \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"serverless.me":""}}'
```

这会配置好服务域名为`serverless.me`。

你可以通过：

```bash
kubectl get configmaps config-domain -n knative-serving -o yaml
```

来查看具体配置情况，当然，使用`edit`命令直接修改也是可以的：

```bash
kubectl edit configmaps config-domain -n knative-serving
```

```yaml
apiVersion: v1
data:
  _example: |
    ################################
    #                              #
    #    EXAMPLE CONFIGURATION     #
    #                              #
    ################################

    # This block is not actually functional configuration,
    # but serves to illustrate the available configuration
    # options and document them in a way that is accessible
    # to users that `kubectl edit` this config map.
    #
    # These sample configuration options may be copied out of
    # this example block and unindented to be in the data block
    # to actually change the configuration.

    # Default value for domain.
    # Although it will match all routes, it is the least-specific rule so it
    # will only be used if no other domain matches.
    example.com: |

    # These are example settings of domain.
    # example.org will be used for routes having app=nonprofit.
    example.org: |
      selector:
        app: nonprofit

    # Routes having the cluster domain suffix (by default 'svc.cluster.local')
    # will not be exposed through Ingress. You can define your own label
    # selector to assign that domain suffix to your Route here, or you can set
    # the label
    #    "networking.knative.dev/visibility=cluster-local"
    # to achieve the same effect.  This shows how to make routes having
    # the label app=secret only exposed to the local cluster.
    svc.cluster.local: |
      selector:
        app: secret
  serverless.me: ""
kind: ConfigMap
metadata:
  annotations:
    knative.dev/example-checksum: 81552d0b
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"_example":"################################\n#
          #\n#    EXAMPLE CONFIGURATION     #\n#                              #\n################################\n\n# This block is not actually functional configuration,\n# but serves to illustrate the available configuration\n# options and document them in a way that is accessible\n# to users that `kubectl edit` this config map.\n#\n# These sample configuration options may be copied out of\n# this example block and unindented to be in the data block\n# to actually change the configuration.\n\n# Default value for domain.\n# Although it will match all routes, it is the least-specific rule so it\n# will only be used if no other domain matches.\nexample.com: |\n\n# These are example settings of domain.\n# example.org will be used for routes having app=nonprofit.\nexample.org: |\n  selector:\n    app: nonprofit\n\n# Routes having the cluster domain suffix (by default 'svc.cluster.local')\n# will not be exposed through Ingress. You can define your own label\n# selector to assign that domain suffix to your Route here, or you can set\n# the label\n#    \"networking.knative.dev/visibility=cluster-local\"\n# to achieve the same effect.  This shows how to make routes having\n# the label app=secret only exposed to the local cluster.\nsvc.cluster.local: |\n  selector:\n    app: secret\n"},"kind":"ConfigMap","metadata":{"annotations":{"knative.dev/example-checksum":"81552d0b"},"labels":{"app.kubernetes.io/component":"controller","app.kubernetes.io/name":"knative-serving","app.kubernetes.io/version":"1.4.0"},"name":"config-domain","namespace":"knative-serving"}}
  creationTimestamp: "2022-05-01T12:11:10Z"
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: knative-serving
    app.kubernetes.io/version: 1.4.0
  name: config-domain
  namespace: knative-serving
  resourceVersion: "646729"
  uid: 4ae92dcd-c43a-4de5-8987-bbabbb7d9ae9
```

> 关于KNative Eventing的安装可以参考官网和上面的方式，替换gcr.io为gcr.lank8s.cn然后直接安装即可。

## KNative部署服务

### 安装KNative CLI

在这里下载二进制版的CLI：[Releases · knative/client (github.com)](https://github.com/knative/client/releases)

可以这样下载：

```bash
curl -LO https://ghproxy.com/https://github.com/knative/client/releases/download/knative-v1.4.0/kn-linux-amd64
```

然后：

```bash
sudo install kn-linux-amd64 /usr/bin/kn
```

### 部署第一个KNative服务

直接使用KNative CLI部署：

```bash
kn service create hello --image gcr.lank8s.cn/knative-samples/helloworld-go --port 8080 --env TARGET=KNative!
```

> 如果部署失败，说明不是使用Minikube安装的KNative，请看下面[单机K8S的异常](#单机K8S的异常)解决

应该会输出如下：

```bash
Creating service 'hello' in namespace 'default':

  0.101s The Route is still working to reflect the latest desired specification.
  0.127s ...
  0.171s Configuration "hello" is waiting for a Revision to become ready.
  3.510s ...
  3.577s Ingress has not yet been reconciled.
  3.652s Waiting for load balancer to be ready
  3.812s Ready to serve.

Service 'hello' created to latest revision 'hello-00001' is available at URL:
http://hello.default.serverless.me
```

接下来模拟一下请求：

```bash
evalexp@VM-16-6-ubuntu:~/knative$ curl -H 'Host: hello.default.serverless.me' 10.106.138.38
Hello KNative!!
```

可以看到服务部署成功了。

Pods的状态：

```bash
default            hello-00001-deployment-5f8b4b85df-2ks4k   2/2     Running       0             69s
```

```bash
default            hello-00001-deployment-5f8b4b85df-2ks4k   2/2     Terminating   0             69s
```

然后Pods被销毁。

### 单机K8S的异常

当创建服务时，可能会出现如下异常：

```bash
Creating service 'hello' in namespace 'default':

  0.101s The Route is still working to reflect the latest desired specification.
  0.120s ...
  0.158s Configuration "hello" is waiting for a Revision to become ready.
 10.113s Revision "hello-00001" failed with message: Unable to fetch image "gcr.lank8s.cn/knative-samples/helloworld-go": failed to resolve image to digest: Get "https://gcr.lank8s.cn/v2/": context deadline exceeded.
 10.148s Configuration "hello" does not have any ready Revision.
Error: RevisionFailed: Revision "hello-00001" failed with message: Unable to fetch image "gcr.lank8s.cn/knative-samples/helloworld-go": failed to resolve image to digest: Get "https://gcr.lank8s.cn/v2/": context deadline exceeded.
Run 'kn --help' for usage
```

具体原因未知，出现该情况时，需要修改一下KNative Serving的Configmap配置：

```bash
kubectl -n knative-serving edit configmap config-deployment
```

如图所示，你应该在data下面添加一个`registries-skipping-tag-resolving`，然后将自己的私有Registry地址或者可能会用到的Registry地址加进去。

![image-20220504150309225](./image-20220504150309225.png)

添加后，你应该可以看到：

```bash
evalexp@VM-16-6-ubuntu:~$ kn service create blog --image registry.cn-shanghai.aliyuncs.com/evalexp-private/blog --port 80 --pull-secret=aliyunkey --scale-min=1 --scale-max=2
Creating service 'blog' in namespace 'default':

  0.080s The Route is still working to reflect the latest desired specification.
  0.213s ...
  0.289s Configuration "blog" is waiting for a Revision to become ready.
  2.836s ...
  2.926s Ingress has not yet been reconciled.
  3.075s Waiting for load balancer to be ready
  3.203s Ready to serve.

Service 'blog' created to latest revision 'blog-00001' is available at URL:
http://blog.default.serverless.me
```

这样就部署成功了。

## Github Action 构建镜像

> 此处以Hexo博客部署为例

### 生成Hexo Blog静态文件

对应的steps：

```yml
    steps:
      - name: Check out
        uses: actions/checkout@v2

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

### Dockerfile

静态博客想对简单：

```dockerfile
FROM nginx
COPY public /usr/share/nginx/html
```

### 构建 & 推送 镜像

对应steps：

```yml
      - name: Get Tag
        id: meta
        uses: docker/metadata-action@v3
        with:
          images: |
            registry.cn-shanghai.aliyuncs.com/evalexp-private/blog
            
	  - name: Login Registry
        uses: docker/login-action@v1
        with:
          registry: registry.cn-shanghai.aliyuncs.com
          username: ${{ secrets.ALIYUN_USER }}
          password: ${{ secrets.ALIYUN_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v2
        env:
          tag: ${{ steps.get_tag.outputs.tag }}
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### 部署脚本

```shell
#!/bin/bash

if ! [ -x "$(command -v kn)" ]; then
    echo "Error: kn cli is not installed." >&2
    exit 1
fi

kn service list | grep -Eq "blog"

if [ $? -eq 0 ]; then
    # blog service existed, update service
    kn service update blog --image registry.cn-shanghai.aliyuncs.com/evalexp-private/blog --pull-secret=aliyunkey
else
    kn service create blog --image registry.cn-shanghai.aliyuncs.com/evalexp-private/blog --port 80 --pull-secret=aliyunkey --scale-min=1 --scale-max=2
fi
```

### 整体Workflow

```yml
name: Blog CI

on:
  push:
    tags:
      - '*-build'

jobs:
  build:
    name: Build Docker image and Deploy to KNative
    runs-on: ubuntu-latest

    steps:
      - name: Check out
        uses: actions/checkout@v2

      - name: Get Tag
        id: meta
        uses: docker/metadata-action@v3
        with:
          images: |
            registry.cn-shanghai.aliyuncs.com/***/blog

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
        uses: docker/build-push-action@v2
        env:
          tag: ${{ steps.get_tag.outputs.tag }}
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

      - name: Upload Script
        uses: appleboy/scp-action@master
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.SSHUSER }}
          password: ${{ secrets.SSHPASSWORD }}
          port: ${{ secrets.PORT }}
          source: "Deploy2KNative.sh"
          target: "/tmp"

      - name: Deploy
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.SSHUSER }}
          password: ${{ secrets.SSHPASSWORD }}
          port: ${{ secrets.PORT }}
          script: |
            bash /tmp/Deploy2KNative.sh
            rm /tmp/Deploy2KNative.sh

```

注意应该在Kubernetes中创建阿里云的镜像Registry的账密Secret，并且在仓库设置对应的Secret。

完成后推送标签`2022.05.03-build`，此时触发Github Workflow：

![image-20220503133236356](./image-20220503133236356.png)

推送的镜像：

![image-20220503133353854](./image-20220503133353854.png)

可以看到部署成功，在云服务器查看：

```bash
evalexp@VM-16-6-ubuntu:~/knative$ kn service list
NAME    URL                                  LATEST        AGE   CONDITIONS   READY   REASON
blog    http://blog.default.serverless.me    blog-00001    12h   3 OK / 3     True
```

> Blog部署时，收缩极限是1，扩容极限是2，这样会一直至少保持一个Pod在运行从而不影响基础响应时间。
>
> 同时，推送镜像的日期Tag可以方便快速地定位日期恢复博客当日状态，可以说是非常的Nice了。

## Nginx反代KNative服务注意事项

KNative的服务是原生支持WebSocket的，但是会出现426异常，这是因为Nginx默认反代的HTTP协议是1.0，设置为1.1即可。

如我的博客的反代配置：

```nginx
server {
        listen 80;
        server_name blog.evalexp.top;
        return 301 https://$host$request_uri;
}
server {
        listen 443 ssl;
        server_name blog.evalexp.top;

        ssl_certificate /etc/nginx/cert/1_blog.evalexp.top_bundle.crt;
        ssl_certificate_key /etc/nginx/cert/2_blog.evalexp.top.key;
        ssl_session_timeout 5m;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;

        add_header Strict-Transport-Security max-age=31536000;
        client_max_body_size 200m;
        location / {
                #root /app/blog/html;
                #index index.html index.htm;
                proxy_set_header        Host blog.default.serverless.me;
                proxy_set_header        X-Real-IP $remote_addr;
                proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header        X-Forwarded-Proto $scheme;
                proxy_http_version 1.1;
                proxy_pass http://10.106.138.38;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection upgrade;
                proxy_set_header Accept-Encoding gzip;
        }
 }
```

