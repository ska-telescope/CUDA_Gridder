
# Gridder- CUDA Implementation
###### Note: currently only supported by NVIDIA GPUs (limitation of CUDA)
---
##### Instructions for installation of this software (includes profiling, linting, building, and unit testing):
1. Ensure you have an NVIDIA based GPU (**mandatory!**)
2. Install the [CUDA](https://developer.nvidia.com/cuda-downloads) toolkit and runtime (refer to link for download/installation procedure)
3. Install [Valgrind](http://valgrind.org/) (profiling, memory checks, memory leaks etc.)
   ```bash
   $ sudo apt install valgrind
   ```
4. Install [Cmake](https://cmake.org/)/[Makefile](https://www.gnu.org/software/make/) (build tools)
   ```bash
   $ sudo apt install cmake
   ```
5. Install [Google Test](https://github.com/google/googletest) (unit testing) - See [this tutorial](https://www.eriksmistad.no/getting-started-with-google-test-on-ubuntu/) for tutorial on using Google Test library
   ```bash
   $ sudo apt install libgtest-dev
   $ cd /usr/src/gtest
   $ sudo cmake CMakeLists.txt
   $ sudo make
   $ sudo cp *.a /usr/lib
   ```
6. Install [Cppcheck](http://cppcheck.sourceforge.net/) (linting)
   ```bash
   $ sudo apt install cppcheck
   ```
7. Configure the code for usage (**modify gridder config**)
8. Create local execution folder
    ```bash
   $ mkdir build && cd build
   ```
9. Build gridder project (from project folder)
   ```bash
   $ cmake .. -DCMAKE_BUILD_TYPE=Release && make
   ```
10. **Important: set -CDMAKE_BUILD_TYPE=Debug if planning to run Valgrind. Debug mode disables compiler optimizations, which is required for Valgrind to perform an optimal analysis.**
---
##### Instructions for usage of this software (includes executing, testing, linting, and profiling):
To perform memory checking, memory leak analysis, and profiling using [Valgrind](http://valgrind.org/docs/manual/quick-start.html), execute the following (assumes you are in the appropriate *build* folder (see step 5 above):
```bash
$ valgrind --leak-check=yes -v ./gridder
```
To execute linting, execute the following commands (assumes you are in the appropriate source code folder):
```bash
$ cppcheck --enable=all main.cpp
$ cppcheck --enable=all gridder.cu
```
To execute the gridder (once configured and built), execute the following command (also assumes appropriate *build* folder):
```bash
$ ./gridder
```

## Running in Containers

### Install Nvidia Container Runtime

First, the NVIDIA runtime for Docker must be install, and checked.

Instructions from https://github.com/NVIDIA/nvidia-docker :
```
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
  sudo apt-key add -

curl -s -L https://nvidia.github.io/nvidia-docker/ubuntu18.04/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update

sudo apt-get install -y nvidia-container-toolkit

sudo systemctl restart docker
```

Test the runtime:
```
docker run --gpus all nvidia/cuda:9.0-base nvidia-smi
# or: docker run -e NVIDIA_VISIBLE_DEVICES=all nvidia/cuda:9.0-base nvidia-smi
```

Now install the docker runtime hook:
```
sudo apt-get install -y nvidia-docker2
```
See https://github.com/NVIDIA/k8s-device-plugin#preparing-your-gpu-nodes for more details.


### Build the Image

Build the image with:
```
make image
```
This will take some time, as it needs to pull down the large Nvidia docker base images.

### Test Image

Put test data files in project root directory - el82-el70_kernels.zip  el82-el70_visibilities.zip .

Then unpack with:
```
make test_data
```

Once the test data is in place and the image has been built, it can be tested with:
```
make test
```

### Run Sample for docker-compose

Run:
```
$ make up
IMAGE=cuda-gridder:latest docker-compose up
Creating network "cuda_gridder_default" with the default driver
Creating gridder_test ... done
Attaching to gridder_test
gridder_test    | >>> UPDATE: Determining memory requirements for convolution kernels...
gridder_test    | >>> UPDATE: Requirements analysis complete...
gridder_test    | >>> UPDATE: Allocating resources for grid and convolution kernels...
gridder_test    | >>> UPDATE: Resource allocation successful...
gridder_test    | >>> UPDATE: Loading kernels...
gridder_test    | >>> UPDATE: Loading kernels complete...
gridder_test    | >>> UPDATE: Loading visibilities...
gridder_test    | >>> UPDATE: Loading visibilities complete...
gridder_test    | >>> UPDATE: LOADING IN CONVOLUTION KERNEL SAMPLES...
gridder_test    | >>> UPDATE: Performing W-Projection based convolutional gridding...
gridder_test    | >>> INFO: Using 1954 blocks, 1024 threads, for 2000000 visibilities...
gridder_test    | >>> UPDATE: GPU accelerated gridding completed in 159.707047 milliseconds...
gridder_test    | UPDATE >>> IGNORING iFFT and CC...
gridder_test    | UPDATE >>> COPYING GRID BACK TO CPU....
gridder_test    | PIPELINE COMPLETE....
gridder_test    | >>> UPDATE: Gridding complete...
gridder_test    | >>> UPDATE: Saving grid to file...
gridder_test    | >>> UPDATE: Save successful...
gridder_test    | >>> UPDATE: Cleaning up allocated resources...
gridder_test    | >>> UPDATE: Cleaning complete, exiting...
gridder_test exited with code 0
```

Use `make down` to clean up.

### Running on Kubernetes

Running on Kubernetes can be done in a number of ways, that all boil down to changing the container runtime.  This can be done using Docker, ContainerD, and CRI-O, however, at time of writing the most flexible way that enabled a non-nvidia default  runtime to be configured, and use a RunTimeClass configuration for the Pod descriptor, is CRI-O.

In addition to the setup described above for installing the container runtime for Docker, complete the following:

### Install CRI-O

Firstly ensure CRI-O is installed by following the Instructions here: https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cri-o

Enable and start CRI-O  with ` sudo systemctl enable crio && sudo systemctl start crio`

Amend the configuration in `/etc/crio/crio.conf` to be something similar to:
```
...
  [crio.runtime.runtimes.runc]
  runtime_path = "/usr/lib/cri-o-runc/sbin/runc"
  runtime_type = ""

  [crio.runtime.runtimes.nvidia]
  runtime_path = "/usr/bin/nvidia-container-runtime"
  runtime_type = ""
...
registries = [
    "docker.io",
    "quay.io",
]

insecure_registries = ['localhost:5000']
...
```
Then restart CRI-O with `sudo systemctl restart crio` .

Next, install `podman` with `sudo apt install podman`, and configure `/etc/containers/registries.conf`:
```
[registries.search]
registries = ['docker.io']

# If you need to access insecure registries, add the registry's fully-qualified name.
# An insecure registry is one that does not have a valid SSL certificate or only does HTTP.
[registries.insecure]
registries = ['localhost:5000']
```

Finally, install `crictl` as described here: https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md


### CRI-O Fix Kubernetes Configuration

Kubernetes must be configured to use CRI-O.  For Minikube (which was used for testing at K8s v1.16), this is achieved with something like:
```
sudo minikube start --vm-driver=none --container-runtime=cri-o --extra-config=kubelet.cgroup-driver=systemd
```

### Alternatively using ContainerD

It is possible to use the containerd runtime.  The simplest method of setting this up is currently by following the instructions here: https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd .

Once the basic containerd install is complete, the configuration needs to be modified to include the nvidia runtime.

Edit `/etc/containerd/config.toml`, and add the following:
```
...
# after      [plugins.cri.containerd.untrusted_workload_runtime]
      [plugins.cri.containerd.runtimes.nvidia]
        runtime_type = "io.containerd.runtime.v1.linux"
        runtime_engine = "/usr/bin/nvidia-container-runtime"
        runtime_root = ""
...
```

Restart containerd with: `sudo systemctl restart containerd`.  It is best to do this after the Minikube instance has been stopped and deleted.

As for CRI-O ensure that `crictl` is installed as described here: https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md

### containerd Fix Kubernetes Configuration

Kubernetes must be configured to use containerd.  For Minikube (which was used for testing at K8s v1.16), this is achieved with something like:
```
sudo minikube start --vm-driver=none --container-runtime=containerd
```


### Define the RunTimeClass

A RunTimeClass is required to direct running Pods towards the `nvidia` runtime.  This is created with something like:
```
cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1beta1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
EOF
```

### Run the Helm chart

Once the nvidia integration for Kubernetes is complete, the example Helm chart can be launched with:
```
$ make deploy
ubectl describe namespace "default" || kubectl create namespace "default"
Name:         default
Labels:       <none>
Annotations:  <none>
Status:       Active

No resource quota.

No resource limits.
==> Linting charts/cuda-gridder/
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, no failures
job.batch/gridder-cuda-gridder-test created

$ kubectl get all
NAMESPACE     NAME                                            READY   STATUS      RESTARTS   AGE    IP                NODE       NOMINATED
 NODE   READINESS GATES
default       pod/gridder-cuda-gridder-test-zsqw6             0/1     Completed   0          17m    192.168.150.144   minikube   <none>
        <none>
...
$ $ make logs
---------------------------------------------------
Logs for pod/gridder-cuda-gridder-test-zsqw6
kubectl -n default logs pod/gridder-cuda-gridder-test-zsqw6
kubectl -n default get pod/gridder-cuda-gridder-test-zsqw6 -o jsonpath={.spec.initContainers[*].name}
---------------------------------------------------
Main Pod logs for pod/gridder-cuda-gridder-test-zsqw6
---------------------------------------------------
Container: gridder
>>> UPDATE: Determining memory requirements for convolution kernels...
>>> UPDATE: Requirements analysis complete...
>>> UPDATE: Allocating resources for grid and convolution kernels...
>>> UPDATE: Resource allocation successful...
>>> UPDATE: Loading kernels...
>>> UPDATE: Loading kernels complete...
>>> UPDATE: Loading visibilities...
>>> UPDATE: Loading visibilities complete...
>>> UPDATE: LOADING IN CONVOLUTION KERNEL SAMPLES...
>>> UPDATE: Performing W-Projection based convolutional gridding...
>>> INFO: Using 1954 blocks, 1024 threads, for 2000000 visibilities...
>>> UPDATE: GPU accelerated gridding completed in 162.384644 milliseconds...
UPDATE >>> IGNORING iFFT and CC...
UPDATE >>> COPYING GRID BACK TO CPU....
PIPELINE COMPLETE....
>>> UPDATE: Gridding complete...
>>> UPDATE: Saving grid to file...
>>> UPDATE: Save successful...
>>> UPDATE: Cleaning up allocated resources...
>>> UPDATE: Cleaning complete, exiting...
---------------------------------------------------
---------------------------------------------------
```

Cleanup with `make delete`
