if [ $(command -v apt-get) ]; then
    apt-get install -y git
else
    yum install -y git
fi
