
// Copyright 2019 Adam Campbell, Seth Hall, Andrew Ensor
// Copyright 2019 High Performance Computing Research Laboratory, Auckland University of Technology (AUT)

// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:

// 1. Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.

// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// 3. Neither the name of the copyright holder nor the names of its
// contributors may be used to endorse or promote products derived from this
// software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#ifdef __cplusplus
extern "C" {
#endif

#ifndef GRIDDER_H_
#define GRIDDER_H_

#include <cuda.h>
#include <cuda_runtime_api.h>
#include <device_launch_parameters.h>
#include <cufft.h>

#ifndef SINGLE_PRECISION
	#define SINGLE_PRECISION 0
#endif



// Define global precisions
#ifndef PRECISION
	#if SINGLE_PRECISION
		#define PRECISION float
		#define PRECISION2 float2
		#define PRECISION3 float3
		#define PRECISION4 float4
		#define CUFFT_P2P CUFFT_C2C
	#else
		#define PRECISION double
		#define PRECISION2 double2
		#define PRECISION3 double3
		#define PRECISION4 double4
		#define CUFFT_P2P CUFFT_Z2Z
	#endif
#endif




	// Define function macros
#if SINGLE_PRECISION
	#define SIN(x) sinf(x)
	#define COS(x) cosf(x)
	#define ABS(x) fabs(x)
	#define SQRT(x) sqrtf(x)
	#define ROUND(x) roundf(x)
	#define CEIL(x) ceilf(x)
	#define MAKE_PRECISION2(x,y) make_float2(x,y)
	#define MAKE_PRECISION3(x,y,z) make_float3(x,y,z)
	#define MAKE_PRECISION4(x,y,z,w) make_float4(x,y,z,w)
	#define CUFFT_EXECUTE_P2P(a,b,c,d) cufftExecC2C(a,b,c,d)
#else
	#define SIN(x) sin(x)
	#define COS(x) cos(x)
	#define ABS(x) abs(x)
	#define SQRT(x) sqrt(x)
	#define ROUND(x) round(x)
	#define CEIL(x) ceil(x)
	#define MAKE_PRECISION2(x,y) make_double2(x,y)
	#define MAKE_PRECISION3(x,y,z) make_double3(x,y,z)
	#define MAKE_PRECISION4(x,y,z,w) make_double4(x,y,z,w)
	#define CUFFT_EXECUTE_P2P(a,b,c,d) cufftExecZ2Z(a,b,c,d)
#endif


	#define C 299792458.0

	#define CUDA_CHECK_RETURN(value) check_cuda_error_aux(__FILE__,__LINE__, #value, value)

	#define CUFFT_SAFE_CALL(err) cufft_safe_call(err, __FILE__, __LINE__)

	typedef struct Config {
		int grid_size;
		double cell_size;
		bool right_ascension;
		bool force_zero_w_term;
		double frequency_hz;
		int oversampling;
		double uv_scale;
		int num_visibilities;
		char *grid_real_dest_file;
		char *grid_imag_dest_file;
		char *kernel_real_source_file;
		char *kernel_imag_source_file;
		char *kernel_support_file;
		char *visibility_source_file;
		int gpu_max_threads_per_block;
		int gpu_max_threads_per_block_dimension;
		bool time_gridding;
		bool perform_iFFT_CC;
		int num_wproj_kernels;
		double max_w;
		double w_scale;
	} Config;

	typedef struct Visibility {
		PRECISION u;
		PRECISION v;
		PRECISION w;
	} Visibility;

	typedef struct Complex {
		PRECISION real;
		PRECISION imag;
	} Complex;

	void init_config(Config *config);

	void save_grid_to_file(Config *config, Complex *grid);

	bool load_visibilities(Config *config, Visibility **vis_uvw, Complex **vis_intensities);

	void execute_gridding(Config *config, Complex *grid, Visibility *vis_uvw, 
		Complex *vis_intensities, int num_visibilities, Complex *kernel,
		int2 *kernel_supports, int num_kernel_samples, double *prolate);

	void execute_CUDA_iFFT(Config *config, double2 *grid);


	__global__ void gridding(double2 *grid, const double2 *kernel, const int2 *supports,
		const double3 *vis_uvw, const double2 *vis, const int num_vis, const int oversampling,
		const int grid_size, const double uv_scale, const double w_scale);

	__global__ void fftshift_2D(double2 *grid, const int width);

	__global__ void execute_convolution_correction(double2 *grid, const double *prolate, const int grid_size);

	__device__ double2 complex_mult(const double2 z1, const double2 z2);

	bool load_kernel(Config *config, Complex *kernel, int2 *kernel_supports);

	void create_1D_half_prolate(double *prolate, int grid_size);

	double calc_spheroidal_sample(double nu);

	int read_kernel_supports(Config *config, int2 *kernel_supports);

	void clean_up(Complex **grid, Visibility **vis_uvw, Complex **vis_intensities,
		Complex **kernel, int2 **kernel_supports, double **prolate);

	static void check_cuda_error_aux(const char *file, unsigned line, const char *statement, cudaError_t err);

	static void cufft_safe_call(cufftResult err, const char *file, const int line);

	static const char* cuda_get_error_enum(cufftResult error);

#endif /* GRIDDER_H_ */

#ifdef __cplusplus
}
#endif
