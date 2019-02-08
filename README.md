# Docker Rosa Linux Image

Install

    1. mkdir -p build
    2. cd build
    3. git clone https://github.com/SergeyDjam/docker-rosa.git
    4. cd docker-rosa
    5. sudo ./mkimage-urpmi.sh

Run docker container:
    
    docker build -t rootfs:rosa2014.1 .
    docker run -ti --rm --name rosa rootfs:rosa2014.1 /bin/bash
