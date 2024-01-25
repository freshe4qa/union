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
echo "export UNION_CHAIN_ID=union-testnet-5" >> $HOME/.bash_profile
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
mkdir -p $HOME/.union/cosmovisor/genesis/bin
wget -O $HOME/.union/cosmovisor/genesis/bin/uniond https://snapshots.kjnodes.com/union-testnet/uniond-genesis-linux-amd64
chmod +x $HOME/.union/cosmovisor/genesis/bin/uniond

sudo ln -s $HOME/.union/cosmovisor/genesis $HOME/.union/cosmovisor/current -f
sudo ln -s $HOME/.union/cosmovisor/current/bin/uniond /usr/local/bin/uniond -f

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0

# config
alias uniond='uniond --home=/home/union-testnet/.union/'
uniond config chain-id $UNION_CHAIN_ID
uniond config keyring-backend test

# init
uniond init $NODENAME bn254 --chain-id union-testnet-5

# download genesis and addrbook
curl -Ls https://snapshots.kjnodes.com/union-testnet/genesis.json > $HOME/.union/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/union-testnet/addrbook.json > $HOME/.union/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0muno\"|" $HOME/.union/config/app.toml

# set peers and seeds
SEEDS="3f472746f46493309650e5a033076689996c8881@union-testnet.rpc.kjnodes.com:17159"
PEERS="3ebf2e11e771ef7db14217e1a8fa365fdf028eb4@65.108.134.215:28656,017f2c708749c0a789e794f16face1b9662c63d0@23.111.23.233:16656,89e7c090409da29a3525ecd2e9676579cfab487c@213.239.214.73:26656,ec244b6ea1ff9314e32e269045d08035f53c71cd@167.235.178.134:24656,a3fb532f4386cfdf01a5a1bdf0a568457b9dc310@153.92.126.130:26656,2dad4529930a677fe267cedcac86043d09acdc36@65.108.105.48:24656,a24e67b59b0541a03d6faec19b74bc40a4cb1452@144.217.211.107:26656"
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
sudo tee /etc/systemd/system/union.service > /dev/null << EOF
[Unit]
Description=union node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start --home=/home/union-testnet/.union/
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.union"
Environment="DAEMON_NAME=uniond"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$HOME/.union/cosmovisor/current/bin"

[Install]
WantedBy=multi-user.target
EOF

# reset
uniond tendermint unsafe-reset-all --home $HOME/.union --keep-addr-book 
curl -L https://snapshots.kjnodes.com/union-testnet/snapshot_latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.union
[[ -f $HOME/.union/data/upgrade-info.json ]] && cp $HOME/.union/data/upgrade-info.json $HOME/.union/cosmovisor/genesis/upgrade-info.json

# start service
sudo systemctl daemon-reload
sudo systemctl enable union.service
sudo systemctl restart union.service

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
--amount 1000000muno \
--pubkey $(uniond tendermint show-validator) \
--moniker "$NODENAME" \
--chain-id union-testnet-5 \
--commission-rate 0.05 \
--commission-max-rate 0.20 \
--commission-max-change-rate 0.01 \
--min-self-delegation 1 \
--from wallet \
--gas-adjustment 1.4 \
--gas auto \
--gas-prices 0muno \
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
