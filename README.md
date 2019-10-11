
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
