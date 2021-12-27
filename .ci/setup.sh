if [ $(command -v apt-get) ]; then
    sudo apt-get install -y git
else
    sudo yum install -y git
fi
