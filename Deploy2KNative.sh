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
