#!/bin/bash

set -ex

install_ubuntu() {
    apt-get update
    apt-get install -y wget
    apt-get install -y libopenblas-dev

    DEB_ROCM_REPO=http://repo.radeon.com/rocm/apt/debian
    # Add rocm repository
    wget -qO - $DEB_ROCM_REPO/rocm.gpg.key | apt-key add -
    echo "deb [arch=amd64] $DEB_ROCM_REPO xenial main" > /etc/apt/sources.list.d/rocm.list
    apt-get update --allow-insecure-repositories

    DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated \
                   rocm-dev \
                   rocm-libs \
                   rocm-utils \
                   rocfft \
                   miopen-hip \
                   miopengemm \
                   rocblas \
                   rocm-profiler \
                   cxlactivitylogger

    # hotfix a bug in hip's cmake files, this has been fixed in
    # https://github.com/ROCm-Developer-Tools/HIP/pull/516 but for
    # some reason it has not included in the latest rocm release
    if [[ -f /opt/rocm/hip/cmake/FindHIP.cmake ]]; then
        sudo sed -i 's/\ -I${dir}/\ $<$<BOOL:${dir}>:-I${dir}>/' /opt/rocm/hip/cmake/FindHIP.cmake
    fi
    
    # HIP has a bug that drops DEBUG symbols in generated MakeFiles.
    # https://github.com/ROCm-Developer-Tools/HIP/pull/588
    if [[ -f /opt/rocm/hip/cmake/FindHIP.cmake ]]; then
        sudo sed -i 's/set(_hip_build_configuration "${CMAKE_BUILD_TYPE}")/string(TOUPPER _hip_build_configuration "${CMAKE_BUILD_TYPE}")/' /opt/rocm/hip/cmake/FindHIP.cmake
    fi
}

install_centos() {
    echo "Not implemented yet"
    exit 1
}
 
install_hip_thrust() {
    # Needed for now, will be replaced soon
    git clone --recursive https://github.com/ROCmSoftwarePlatform/Thrust.git /data/Thrust
    rm -rf /data/Thrust/thrust/system/cuda/detail/cub-hip
    git clone --recursive https://github.com/ROCmSoftwarePlatform/cub-hip.git /data/Thrust/thrust/system/cuda/detail/cub-hip
}

# Install an updated version of rocRand that's PyTorch compatible.
install_rocrand() {
    mkdir -p /opt/rocm/debians
    curl https://s3.amazonaws.com/ossci-linux/rocrand-1.8.0-Linux.deb -o /opt/rocm/debians/rocrand.deb 
    dpkg -i /opt/rocm/debians/rocrand.deb
}

# Install rocSPARSE/hipSPARSE that will be released soon - can co-exist w/ hcSPARSE which will be removed soon
install_hipsparse() {
    mkdir -p /opt/rocm/debians
    curl https://s3.amazonaws.com/ossci-linux/rocsparse-0.1.2.114-Linux.deb -o /opt/rocm/debians/rocsparse.deb
    curl https://s3.amazonaws.com/ossci-linux/hipsparse-0.1.2.55-Linux.deb -o /opt/rocm/debians/hipsparse.deb
    dpkg -i /opt/rocm/debians/rocsparse.deb
    dpkg -i /opt/rocm/debians/hipsparse.deb
}

# Install custom hcc containing two compiler fixes relevant to PyTorch
install_customhcc() {
    HIP_VERSION="1.5.18354"
    mkdir -p /opt/rocm/debians
    curl https://s3.amazonaws.com/ossci-linux/hcc-1.2.18272-Linux.deb -o /opt/rocm/debians/hcc-Linux.deb
    curl "https://s3.amazonaws.com/ossci-linux/hip_base-$HIP_VERSION.deb" -o /opt/rocm/debians/hip_base.deb
    curl "https://s3.amazonaws.com/ossci-linux/hip_doc-$HIP_VERSION.deb" -o /opt/rocm/debians/hip_doc.deb
    curl "https://s3.amazonaws.com/ossci-linux/hip_samples-$HIP_VERSION.deb" -o /opt/rocm/debians/hip_samples.deb
    curl "https://s3.amazonaws.com/ossci-linux/hip_hcc-$HIP_VERSION.deb" -o /opt/rocm/debians/hip_hcc.deb
    dpkg -i /opt/rocm/debians/hcc-Linux.deb
    dpkg -i /opt/rocm/debians/hip_base.deb
    dpkg -i /opt/rocm/debians/hip_doc.deb
    dpkg -i /opt/rocm/debians/hip_samples.deb
    dpkg -i /opt/rocm/debians/hip_hcc.deb

    if [[ -f /opt/rocm/hip/cmake/FindHIP.cmake ]]; then
        sudo sed -i 's/\ -I${dir}/\ $<$<BOOL:${dir}>:-I${dir}>/' /opt/rocm/hip/cmake/FindHIP.cmake
    fi
}

# Install Python packages depending on the base OS
if [ -f /etc/lsb-release ]; then
  install_ubuntu
elif [ -f /etc/os-release ]; then
  install_centos
else
  echo "Unable to determine OS..."
  exit 1
fi

install_hip_thrust
install_rocrand
install_hipsparse
install_customhcc
