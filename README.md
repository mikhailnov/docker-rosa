# Docker Rosa Linux Image


Run docker container:
    
    docker build -t rootfs:rosa2014.1 .
    docker run -ti --rm --name rosa rootfs:rosa2014.1 /bin/bash
