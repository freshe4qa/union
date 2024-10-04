<p align="center">
  <img height="100" height="auto" src="https://github.com/user-attachments/assets/150481b7-2ab2-4435-a43b-fe20e68e88cb">
</p>

# Union — CEREMONY

Official documentation:
>- [Guide](https://ceremony.union.build)

Explorer:
>- [-](-)

### Minimum Hardware Requirements
 - 2x CPUs; the faster clock speed the better
 - 4GB RAM
 - 100GB of storage (SSD or NVME)
 - Ubuntu 22.04

```
sudo apt update && sudo apt upgrade -y
```

```
apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 -y
```
```
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
```
```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
```
```
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
```
```
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
```
```
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
```
```
apt install docker-compose -y
```

После чего заходим на сайт - https://ceremony.union.build

Выбираем - Linux

![image](https://github.com/user-attachments/assets/62a1df15-47c3-4f64-919c-e12e0f9fd32a)

Вставляем команду в терминал:

```
mkdir -p ceremony && docker pull ghcr.io/unionlabs/union/mpc-client:latest && docker run -v $(pwd)/ceremony:/ceremony -w /ceremony -p 4919:4919 --rm -it ghcr.io/unionlabs/union/mpc-client:latest
```

После чего возвращаемся обратно на сайт


......
