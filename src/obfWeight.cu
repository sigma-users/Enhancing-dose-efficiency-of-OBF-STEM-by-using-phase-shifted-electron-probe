#include <stdio.h>
#include <thrust/complex.h>
#include <cuda_runtime.h>
#include <complex>

__device__ __constant__ float PI_F = 3.14159265358979323846f;

/**
 * Aperture function.
*/
__device__ int aperture(float kx, float ky, float k_max) {
    float distance = sqrt(kx * kx + ky * ky);
    return (distance < k_max) ? 1 : 0;
}

/**
 * Aberration function.
*/
__device__ float chi(float kx, float ky, float lam, float df, float cs) {
    float k2 = kx * kx + ky * ky;
    return PI_F * lam * k2 * (0.5 * cs * lam * lam * k2 - df);
}

/**
 * Lens transfer function.
*/
__device__ thrust::complex<float> transfer_function(float kx, float ky, float k_max, float lam, float df, float cs) {
    int a = aperture(kx, ky, k_max);
    return (a == 0) ? thrust::complex<float>(0, 0) : thrust::exp(thrust::complex<float>(0, -chi(kx, ky, lam, df, cs)));
}

/**
 * Sinc function.
*/
__device__ float sinc(float x) {
    return (fabs(x) < 1e-8) ? 1.0f : sin(x) / (x);
}

/**
 * Aperture overlap function
*/
__device__ thrust::complex<float> aperture_overlap(float kx, float ky, float qx, float qy, float k_max,
float thickness, float lam, float df, float cs) {

    float q2 = qx * qx + qy * qy;
    if (q2 > 4 * k_max * k_max) return thrust::complex<float> (0.0, 0.0);
    thrust::complex<float> transfer_val = transfer_function(kx, ky, k_max, lam, df, cs);
    float wt1 = thickness * PI_F * lam * (kx * qx + ky * qy - (qx * qx + qy * qy) / 2);
    float wt2 = -thickness * PI_F * lam * (kx * qx + ky * qy + (qx * qx + qy * qy) / 2);
    float thickness_filter_1 = sinc(wt1);
    float thickness_filter_2 = sinc(wt2);

    return thickness_filter_1 * thrust::conj(transfer_val) * transfer_function(kx - qx, ky - qy, k_max, lam, df, cs)
    - thickness_filter_2 * transfer_val * thrust::conj(transfer_function(kx + qx, ky + qy, k_max, lam, df, cs));
}

// Transfer function.
__global__ void obf_weight_kernel(long n, long nkx, long nky, float dkx, float dky, float kx_offset, float ky_offset,
long nqx, long nqy, float dqx, float dqy, float qx_offset, float qy_offset,
float k_max, float thickness, float lam, float df, float cs, thrust::complex<float> *out)
{
  long index = (long)blockIdx.x * (long)blockDim.x + (long)threadIdx.x;
  long stride = (long)blockDim.x * (long)gridDim.x;
  for (long i = index; i < n; i += stride) {
        long i_total = i;
        long iq = i_total / (nky * nkx * nqy);
        long rem1 = i_total % (nky * nkx * nqy);
        long iqy = rem1 / (nky * nkx);
        long rem2 = rem1 % (nky * nkx);
        long ikx = rem2 / nky;
        long iky = rem2 % nky;
        
        float qx = qx_offset + dqx * (float)iq;
        float qy = qy_offset + dqy * (float)iqy;
        float kx = kx_offset + dkx * (float)ikx;
        float ky = ky_offset + dky * (float)iky;

        out[i] =  aperture_overlap(kx, ky, qx, qy, k_max, thickness, lam, df, cs);
  }
}

/**
 * Host main routine
 */
std::complex<float> * obfWeight(long nkx, long nky, float dkx, float dky, float kx_offset, float ky_offset,
long nqx, long nqy, float dqx, float dqy, float qx_offset, float qy_offset,
float k_max, float thickness, float lam, float df, float cs) {
    // Error code to check return values for CUDA calls
    cudaError_t err = cudaSuccess;

    long N = nkx * nky * nqx * nqy;

    // Allocate the host output vector
    std::complex<float> *h_out = (std::complex<float> *)malloc(N * (long)sizeof(std::complex<float>));

    if (h_out == NULL)
    {
        fprintf(stderr, "Failed to allocate host output memory.\n");
        exit(EXIT_FAILURE);
    }

    // Allocate the device output vector C
    thrust::complex<float> *d_out = NULL;
    err = cudaMalloc((void **)&d_out, N * (long)sizeof(thrust::complex<float>));

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to allocate device output memory.\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    // Launch the Vector Add CUDA Kernel
    int threadsPerBlock = 256;
    int blocksPerGrid =(N + threadsPerBlock - 1) / threadsPerBlock;
    obf_weight_kernel<<<blocksPerGrid, threadsPerBlock>>>(N, nkx, nky, dkx, dky, kx_offset, ky_offset, nqx, nqy, dqx, dqy, qx_offset, qy_offset, k_max, thickness, lam, df, cs, d_out);
    cudaDeviceSynchronize();
    err = cudaGetLastError();

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to launch obfWeight kernel (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    // Copy the device result vector in device memory to the host result vector
    // in host memory.
    err = cudaMemcpy(h_out, d_out, N * (long)sizeof(thrust::complex<float>), cudaMemcpyDeviceToHost);
    cudaThreadSynchronize();

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to copy vector C from device to host (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaFree(d_out);

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to free device vector C (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    return h_out;
}
