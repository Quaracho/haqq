#!/bin/bash
echo "=================================================="
echo -e "\033[0;35m"
echo " | \ | |         | |    (_)   | |  ";
echo " |  \| | ___   __| | ___ _ ___| |_ ";
echo " |     |/ _ \ / _  |/ _ \ / __| __| ";
echo " | |\  | (_) | (_| |  __/ \__ \ |_ ";
echo " |_| \_|\___/ \__,_|\___|_|___/\__| ";
echo -e "\e[0m"
echo "=================================================="                                                            
sleep 2
# set vars
if [ ! $NODENAME ]; then
	read -p "Node ismi yaziniz: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
echo "export WALLET=wallet" >> $HOME/.bash_profile
echo "export CHAIN_ID=Cardchain” >> $HOME/.bash_profile
source $HOME/.bash_profile

echo '================================================='
echo 'Node isminiz: ' $NODENAME
echo 'Cüzdan isminiz: ' $WALLET
echo 'Chain ismi: ' $CHAIN_ID
echo '================================================='
sleep 2
echo -e "\e[1m\e[32m1. Paketler güncelleniyor... \e[0m" && sleep 1
# update
sudo apt update && sudo apt upgrade -y
echo -e "\e[1m\e[32m2. Bagliliklar yukleniyor... \e[0m" && sleep 1
# packages
sudo apt install curl tar wget clang pkg-config libssl-dev jq build-essential bsdmainutils git make ncdu gcc git jq chrony liblz4-tool -y
# install go
ver="1.17.2"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
go version
echo -e "\e[1m\e[32m3. kutuphaneler indirilip yukleniyor... \e[0m" && sleep 1

# download binary
curl https://get.ignite.com/DecentralCardGame/Cardchain@latest! | sudo bash

# config
Cardchain config chain-id $CHAIN_ID
Cardchain config keyring-backend file

# init
Cardchain init $NODENAME --chain-id $CHAIN_ID

# download addrbook and genesis
wget -qO $HOME/.Cardchain/config/genesis.json "https://raw.githubusercontent.com/DecentralCardGame/Testnet1/main/genesis.json"


# set minimum gas price
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0ubpf\"/" $HOME/.Cardchain/config/app.toml

# set peers and seeds
PEERS="a506820ea90c5b0ddb9005ef720a121e9f6bbaeb@45.136.28.158:26658"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.Cardchain/config/config.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.Cardchain/config/config.toml

# add external (if dont use sentry), port is default
# external_address=$(wget -qO- eth0.me)
# sed -i -e "s/^external_address = \"\"/external_address = \"$external_address:26656\"/" $HOME/.Cardchain/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"

sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.Cardchain/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.Cardchain/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.Cardchain/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.Cardchain/config/app.toml

sleep 1

#Change port 43
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:36438\”%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:36437\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:6431\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:36436\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":36320\"%" $HOME/.Cardchain/config/config.toml
sed -i.bak -e "s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:9430\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:9431\"%" $HOME/.Cardchain/config/app.toml
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:36437\"%" $HOME/.Cardchain/config/client.toml
external_address=$(wget -qO- eth0.me)
sed -i.bak -e "s/^external_address *=.*/external_address = \"$external_address:36436\"/" $HOME/.Cardchain/config/config.toml

sleep 1 


sed -i.bak -e "s/indexer *=.*/indexer = \"null\"/g" $HOME/.Cardchain/config/config.toml
sed -i "s/index-events=.*/index-events=[\"tx.hash\",\"tx.height\",\"block.height\"]/g" $HOME/.Cardchain/config/app.toml

sleep 1

# reset
Cardchain tendermint unsafe-reset-all —home $HOME/.Cardchain

echo -e "\e[1m\e[32m4. Servisler baslatiliyor... \e[0m" && sleep 1
# create service
tee $HOME/Cardchain.service > /dev/null <<EOF
[Unit]
Description=Cardchain
After=network.target
[Service]
Type=simple
User=$USER
ExecStart=$(which Cardchain) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

sudo mv $HOME/Cardchain.service /etc/systemd/system/

# start service
sudo systemctl daemon-reload
sudo systemctl enable Cardchain
sudo systemctl restart Cardchain

echo '=============== KURULUM BASARIYLA TAMAMLANDI ==================='
echo -e 'Loglari kontrol et: \e[1m\e[32mjournalctl -ujournalctl -u Cardchain -f -o cat\e[0m'
echo -e 'Senkronizasyon durumu kontrol et: \e[1m\e[32mcurl -s localhost:26657/status | jq .result.sync_info\e[0m'