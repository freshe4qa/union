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
echo "export UNION_CHAIN_ID=union-testnet-4" >> $HOME/.bash_profile
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
wget -O $HOME/.union/cosmovisor/genesis/bin/uniond https://snapshots.kjnodes.com/union-testnet/uniond-0.15.0-linux-amd64
chmod +x $HOME/.union/cosmovisor/genesis/bin/uniond

sudo ln -s $HOME/.union/cosmovisor/genesis $HOME/.union/cosmovisor/current -f
sudo ln -s $HOME/.union/cosmovisor/current/bin/uniond /usr/local/bin/uniond -f

# config
uniond config chain-id $UNION_CHAIN_ID
uniond config keyring-backend test

# init
uniond init $NODENAME bn254 --chain-id $UNION_CHAIN_ID

# download genesis and addrbook
curl -Ls https://snapshots.kjnodes.com/union-testnet/genesis.json > $HOME/.union/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/union-testnet/addrbook.json > $HOME/.union/config/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0muno\"|" $HOME/.union/config/app.toml

# set peers and seeds
SEEDS="3f472746f46493309650e5a033076689996c8881@union-testnet.rpc.kjnodes.com:17159"
PEERS="835c7f8a5ba11a53244ca9346ea5324c3a4ba3ed@188.40.66.173:24656,7c743b507ec3b67bc790c826ec471d2635c992f7@88.99.3.158:24656,2dad4529930a677fe267cedcac86043d09acdc36@65.108.105.48:24656,d5519e378247dfb61dfe90652d1fe3e2b3005a5b@65.109.68.190:17156,5543e759001443e5953b7a23d8d424c35454deea@167.235.178.134:24656,821eade3cdada32cd15bfc7bd941e5bfad173d35@5.9.115.189:26656,65d3fbc95488503554d554f6332db4dbd68accb0@65.109.69.239:15007,470bf421c6887def16e65dfe05cf1344826be06b@95.214.53.187:32656"
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
Description=Union Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which uniond) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

# reset
uniond tendermint unsafe-reset-all --home $HOME/.union --keep-addr-book 
curl -L https://snapshots.kjnodes.com/union-testnet/snapshot_latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.union

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
--moniker="$NODENAME" \
--chain-id=union-testnet-4 \
--commission-rate 0.05 \
--commission-max-rate 0.20 \
--commission-max-change-rate 0.01 \
--min-self-delegation=1 \
--from=wallet \
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
