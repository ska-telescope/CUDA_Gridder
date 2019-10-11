ARG NVIDIA_BASE_IMAGE=nvidia/cuda:10.1-devel
ARG NVIDIA_RUNTIME_IMAGE=nvidia/cuda:10.1-runtime

# vanilla Ubuntu image used as builder
FROM $NVIDIA_BASE_IMAGE AS build

LABEL \
      author="Piers Harding <piers@ompka.net>" \
      description="SKA Gridder" \
      license="Apache2.0" \
      registry="library/piersharding/ska-gridder" \
      vendor="None" \
      org.skatelescope.team="NZAPP" \
      org.skatelescope.version="0.0.1" \
      org.skatelescope.website="http://github.com/ska-telescope/CUDA_Gridder/"

# Disable prompts from apt.
ENV DEBIAN_FRONTEND noninteractive

# just show what CUDA runfile we are using
RUN \
    echo "Building with: $CUDA_VERSION"

# now install dependencies for CUDA runfile install
RUN apt-get update && \
    apt-get  -yq --no-install-recommends install \
      clang-8 \
      cmake \
      git \
      && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN \
    mkdir -p /app

# copy over project ready for build
COPY *.cu *.h *.cpp Makefile CMakeLists.txt /app/
COPY .git /app/.git/

# build gridder application
RUN \
    cd /app && make build

# Now - create a clean image without build environment
FROM $NVIDIA_RUNTIME_IMAGE

# copy in built gridder app
COPY --from=build /app/build/gridder /app/gridder

# copy in boot strap shellscript that does ldconfig and runs gridder
COPY entrypoint.sh /entrypoint.sh

# Setup the entrypoint or environment
ENTRYPOINT ["/entrypoint.sh"]

# Run - default is gridder
CMD ["gridder"]

# vim:set ft=dockerfile:
