# sh commands

```sh

VERSION=${VERSION}

docker pull hawsers/pause-amd64:${VERSION}
docker tag hawsers/pause-amd64:${VERSION} k8s.gcr.io/pause-amd64:${VERSION}
docker rmi hawsers/pause-amd64:${VERSION}
```
