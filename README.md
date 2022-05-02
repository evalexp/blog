# What is this ?

This is the hexo blog sources.

# Who own this ?

This blog owner is evalexp, you can visit my blog: [Evalexp's blog](https://blog.evalexp.top)

# Other

## Drone deploy

> see .drone.yml and deploy.sh

Only generate the static file and deploy to nginx.

## KNative deploy

> see github workflow ci.yml and Deploy2KNative.sh

Build docker image and push it to aliyun registry, then use KNative CLI to deploy it.