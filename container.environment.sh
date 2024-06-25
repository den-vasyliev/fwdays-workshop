# Description: Containerization workshop
####
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# Install stress tool
sudo apt-get install stress

#####
# Create a unified/cg1 cgroup
sudo mkdir /sys/fs/cgroup/unified
sudo mount -t cgroup2 none /sys/fs/cgroup/unified
sudo cgcreate -g cpuset,memory:unified/cg1
#####
# Check the cgroup
sudo cgget -g cpuset unified/cg1
sudo cgget -g memory unified/cg1

#####
# Set the CPU and memory limits
sudo cgset -r memory.max=100M unified/cg1
sudo cgexec -g cpu:unified/cg1 top
sudo cgset -r memory.max=100K unified/cg1

#####
# Run the stress tool
sudo cgexec -g cpu:unified/cg1 stress --cpu 4 --timeout 60
htop
sudo cgset -r cpuset.cpus=0-2 unified/cg1

#####
# Create a container rootfs
mkdir rootfs
docker run busybox
docker ps -a
docker export b70ea04e6ed7 | tar xf - -C rootfs
sudo unshare --pid --fork chroot rootfs sh
# Copy the stress tool to the rootfs
cp /usr/bin/stress rootfs
# Run the stress tool in the container
sudo cgexec -g cpu:unified/cg1 unshare --mount-proc --pid --fork chroot rootfs sh
####
#
# Create a container spec and run the container
runc spec
sudo runc run demo
# Add command to run in the container
"sh", "-c", "while true; do { echo -e 'HTTP/1.1 200 OK\n\nVersion: v1.0.0'; }|nc -vlp 8080;done"
runc run demo
# Kill the container
runc kill demo KILL
#
### Containerize the application
#
FROM busybox
CMD while true; do { echo -e 'HTTP/1.1 200 OK\n\nVersion: v1.0.0'; }|nc -vlp 8080;done
EXPOSE 8080
# Build the container
docker build .
# Add token to the docker login
echo $GITHUB_TOKEN | docker login ghcr.io --username den-vasyliev --password-stdin


### Install Skopeo and Dive
brew install skopeo dive
brew install dive

### Build the container image and analyze it with Dive
dive build . 
# CI option to run Dive
CI=true dive ghcr.io/den-vasyliev/fwdays-workshop:v1.0.1
#
# Skopeo commands to check different container images speecifications
skopeo --override-os linux copy docker://quay.io/quay/busybox:latest oci:/tmp/busybox-oci
skopeo --override-os linux copy docker://quay.io/quay/busybox:latest dir:/tmp/busybox-dir
