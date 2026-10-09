#!/bin/bash
<< 'EOF'
Author: Alex Pieken
Purpose: This is preferred security configurations for when spinning up an EC2 application-hosting server.
Note the ssh-config-altering section. This is ONLY For servers whose connections are authenticated via ssh key files.
EOF

# Check if script is being run as root
if  [ "$EUID" -ne 0 ]
    then echo "make sure to run as root."
    exit
fi

# update and upgrade
echo  "==================== UPDATE && UPGRADE ========================"
sudo dnf update

echo "=========== RESTRICTING SSH TO KEY AUTH ONLY  ============="
# disable password authentication 
sudo sed -i 's/^[[:space:]]*#[[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/I' /etc/ssh/ssh_config

#disable host-based & GSSAPI auth 
sudo sed -i '/HostbasedAuthentication/s/^[[:space:]] *#[[:space:]]*//' /etc/ssh/ssh_config
sudo sed -i '/GSSAPIAuthentication/s/^[[:space:]] *#[[:space:]]*//' /etc/ssh/ssh_config

# verify no other auth methods are allowed
echo "All of these should say no:"
cat /etc/ssh/ssh_config | grep Auth

# use dnf for installing networking security tools
echo "============= INSTALLING NETWORKING CONFIG PACKAGES ============"
sudo dnf install iptables-services -y
sudo systemctl enable iptables && sudo systemctl start iptables

echo "============ CONFIGURING IPTABLES ============="
# allow loopback comms
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# stateful tracking
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# AWS-specific for their metadata service
sudo iptables -A OUTPUT -d 169.254.169.254 -j ACCEPT

# allow inbound 22, 80, 443, 53
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT

# allow outbound of the same
sudo iptables -A OUTPUT -p tcp -m multiport --dports 22,80,443,53 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT

# Lock down the rest of the firewall
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT DROP

# save it 
sudo service iptables save

echo "--------------------------------------------"
echo "Verify network config:"
sudo iptables -L -v -n

echo "=============== INSTALLING DOCKER ==================="
sudo dnf install docker -y
sudo usermod -aG docker ec2-user # be able to run docker without sudo
sudo systemctl start docker
sudo systemctl enable docker
echo "Verify the docker installation:"
docker info
echo "setup complete on this end."

