#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Wallet"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"

# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
if [ ! $WALLET ]; then
	echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export UNION_CHAIN_ID=union-testnet-6" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y

# packages
apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

# install go
if ! [ -x "$(command -v go)" ]; then
ver="1.20.3" && \
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
rm "go$ver.linux-amd64.tar.gz" && \
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile && \
source $HOME/.bash_profile
fi

# download binary
cd $HOME
mkdir -p $HOME/go/bin
curl -L https://snapshots-testnet.nodejumper.io/union-testnet/uniond-v0.19.0-linux-amd64 > $HOME/go/bin/uniond
chmod +x $HOME/go/bin/uniond

# config
echo -e 'chain-id = "union-testnet-6"
keyring-backend = "test"
output = "text"
node = "tcp://localhost:${portPrefix}57"
broadcast-mode = "sync"' > $HOME/.union/config/client.toml

# init
uniond init $NODENAME bn254 --chain-id union-testnet-6

# download genesis and addrbook
curl -L https://snapshots-testnet.nodejumper.io/union-testnet/genesis.json > $HOME/.union/config/genesis.json
curl -L https://snapshots-testnet.nodejumper.io/union-testnet/addrbook.json > $HOME/.union/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.0025muno\"|" $HOME/.union/config/app.toml

# set peers and seeds
SEEDS="f1d2674dc111d99dae4638234c502f4a4aaf8270@union.testnet.4.val.poisonphang.com:2665"
PEERS="4d8427235a44a21ce84330ad850068c861ba3680@5.161.47.115:26656,cf73a8aca5ca1c08bbe65f7e0d987a226068fb89@162.250.127.226:41156,9f591758d3d9b23ffdca11e22fa030f678566c4e@88.99.3.158:24656,c7f5ad7a66ab1ebdbb2bb4b6cd55742130c2c82b@149.50.102.41:26656,a0e32aff7707fda85ff87fa8ea6f93d3196984aa@188.40.66.173:24656,214bd537d9eddb87ad1ff9604edcdf3d2f966297@95.217.12.125:26656,de45afe750c41193d2644083e23bd56bcf755177@209.126.86.119:26656,3da703a4195530d6811663da5a48296f6c35b12d@78.47.50.58:26656,7c4b0c65faff3800652a4c042f8b74ca4ca5a184@37.60.232.89:26656,037a00d59e94dc11ecbca06daccf16396fa9b76a@65.108.54.139:26656,97c29d9956f5c852114ad883338da7ae6adba49c@65.21.52.76:26656,52be617885c293a05e12c46665c1ce33aef034b7@63.229.234.75:26656,809f0b700fb6162ae902d1225d1d76f2d47ad58a@65.108.79.246:26709,f1d2674dc111d99dae4638234c502f4a4aaf8270@157.245.1.52:26656,b2f2c6ba26958a1daf5838dee130fe0f0d75518d@34.171.89.160:26656,b35d52a16abb313733882abb14ec1cc61e963cae@65.108.99.37:17156"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.union/config/config.toml

# disable indexing
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.union/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.union/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.union/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.union/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.union/config/app.toml
sed -i "s/snapshot-interval *=.*/snapshot-interval = 0/g" $HOME/.union/config/app.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.union/config/config.toml

# create service
sudo tee /etc/systemd/system/uniond.service > /dev/null << EOF
[Unit]
Description=Union node service
After=network-online.target
[Service]
User=$USER
ExecStart=$(which uniond) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# reset
uniond tendermint unsafe-reset-all --home $HOME/.union --keep-addr-book
curl https://snapshots-testnet.nodejumper.io/union-testnet/union-testnet_latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.union

# start service
sudo systemctl daemon-reload
sudo systemctl enable uniond
sudo systemctl restart uniond
break
;;

"Create Wallet")
uniond keys add $WALLET
echo "============================================================"
echo "Save address and mnemonic"
echo "============================================================"
UNION_WALLET_ADDRESS=$(uniond keys show $WALLET -a)
UNION_VALOPER_ADDRESS=$(uniond keys show $WALLET --bech val -a)
echo 'export UNION_WALLET_ADDRESS='${UNION_WALLET_ADDRESS} >> $HOME/.bash_profile
echo 'export UNION_VALOPER_ADDRESS='${UNION_VALOPER_ADDRESS} >> $HOME/.bash_profile
source $HOME/.bash_profile

break
;;

"Create Validator")
uniond tx staking create-validator \
--amount=1000000muno \
--pubkey=$(uniond tendermint show-validator) \
--moniker=$NODENAME \
--chain-id=union-testnet-6 \
--commission-rate=0.10 \
--commission-max-rate=0.20 \
--commission-max-change-rate=0.01 \
--min-self-delegation=1 \
--from=wallet \
--gas-prices=0.0025muno \
--gas-adjustment=1.5 \
--gas=auto \
-y 

break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
