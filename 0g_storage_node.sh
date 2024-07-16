#!/bin/bash

# Function to check if a command exists
exists() {
  command -v "$1" >/dev/null 2>&1
}

# Install dependencies
echo -e '\n\e[42mInstalling dependencies\e[0m\n'
sudo apt-get update
sudo apt-get install -y git cargo clang cmake build-essential

# Install Rustup
echo -e '\n\e[42mInstalling Rustup\e[0m\n'
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# Install Go
echo -e '\n\e[42mInstalling Go\e[0m\n'
cd $HOME
ver="1.22.0"
sudo rm -rf /usr/local/go
sudo curl -fsSL "https://golang.org/dl/go$ver.linux-amd64.tar.gz" | sudo tar -C /usr/local -xzf -
grep -qxF 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' ~/.bash_profile || echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bash_profile
source ~/.bash_profile
go version

# Build binary
echo -e '\n\e[42mBuilding binary\e[0m\n'
cd $HOME
git clone -b v0.3.3 https://github.com/0glabs/0g-storage-node.git
cd 0g-storage-node
git submodule update --init
cargo build --release
sudo mv "$HOME/0g-storage-node/target/release/zgs_node" /usr/local/bin

# Set up environment variables
echo -e '\n\e[42mSetting up environment variables\e[0m\n'
ENR_ADDRESS=$(wget -qO- eth0.me)
echo "export ENR_ADDRESS=${ENR_ADDRESS}"
cat <<EOF >> ~/.bash_profile
export ENR_ADDRESS=${ENR_ADDRESS}
export ZGS_CONFIG_FILE="$HOME/0g-storage-node/run/config.toml"
export ZGS_LOG_DIR="$HOME/0g-storage-node/run/log"
export ZGS_LOG_CONFIG_FILE="$HOME/0g-storage-node/run/log_config"
EOF
source ~/.bash_profile

# Store miner key
read -p "Enter your private key for miner_key configuration: " PRIVATE_KEY && echo

# Create network & DB directory
echo -e '\n\e[42mCreating network and DB directories\e[0m\n'
mkdir -p "$HOME/0g-storage-node/network" "$HOME/0g-storage-node/db"

# Update config file
echo -e '\n\e[42mUpdating config file\e[0m\n'
sed -i 's|^\s*#\?\s*network_dir\s*=.*|network_dir = "/root/0g-storage-node/network"|' "$ZGS_CONFIG_FILE"
sed -i "s|^\s*#\?\s*network_enr_address\s*=.*|network_enr_address = \"$ENR_ADDRESS\"|" "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*network_enr_tcp_port\s*=.*|network_enr_tcp_port = 1234|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*network_enr_udp_port\s*=.*|network_enr_udp_port = 1234|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*network_libp2p_port\s*=.*|network_libp2p_port = 1234|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*network_discovery_port\s*=.*|network_discovery_port = 1234|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*network_target_peers\s*=.*|network_target_peers = 50|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*blockchain_rpc_endpoint\s*=.*|blockchain_rpc_endpoint = "https://og-testnet-jsonrpc.blockhub.id"|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*log_contract_address\s*=.*|log_contract_address = "0x8873cc79c5b3b5666535C825205C9a128B1D75F1"|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*log_sync_start_block_number\s*=.*|log_sync_start_block_number = 802|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*rpc_enabled\s*=\s*true|rpc_enabled = true|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*rpc_listen_address\s*=\s*"0.0.0.0:5678"|rpc_listen_address = "0.0.0.0:5678"|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*db_dir\s*=.*|db_dir = "/root/0g-storage-node/db"|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*log_config_file\s*=.*|log_config_file = "/root/0g-storage-node/run/log_config"|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*log_directory\s*=.*|log_directory = "/root/0g-storage-node/run/log"|' "$ZGS_CONFIG_FILE"
sed -i 's|^\s*#\?\s*mine_contract_address\s*=.*|mine_contract_address = "0x85F6722319538A805ED5733c5F4882d96F1C7384"|' "$ZGS_CONFIG_FILE"
sed -i "s|^\s*#\?\s*miner_key\s*=.*|miner_key = \"$PRIVATE_KEY\"|" "$ZGS_CONFIG_FILE"

# Create service file
echo -e '\n\e[42mCreating service file\e[0m\n'
sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=0G Storage Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=/usr/local/bin/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Start storage node
echo -e '\n\e[42mStarting storage node\e[0m\n'
sudo systemctl daemon-reload
sudo systemctl enable zgs
sudo systemctl start zgs
sudo systemctl status zgs

echo -e '\n\e[42mStorage Node Installation Complete\e[0m\n'
