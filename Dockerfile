# Dockerfile to create Rosa linux base images
# Create base image with mkimage-urpmi.sh script
#

FROM scratch

#ENV TARROOTFS https://github.com/sibsau/docker-rosa/raw/master/rootfs.tar.xz /
#ENV TARROOTFS rootfs.tar.xz

#ADD ${TARROOTFS} /
ADD rootfs.tar.xz /

#CMD ["/bin/bash"]
