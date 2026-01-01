#pragma once

#include <complex>

std::complex<float>* obfWeight(
    long nkx, long nky, float dkx, float dky, float kx_offset, float ky_offset,
    long nqx, long nqy, float dqx, float dqy, float qx_offset, float qy_offset,
    float k_max, float thickness,
    float lam,
    float df,
    float cs
);
