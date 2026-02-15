#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <numpy/arrayobject.h>
#include <complex>
#include <cstdlib>
#include <cstring>

#include "obfweight.hpp"

static PyObject* weight(PyObject* self, PyObject* args) {
    long Nqx, Nqy, Nkx, Nky;
    double qx_min, dqx, qy_min, dqy, kx_min, dkx, ky_min, dky;
    double lam, kmax, thickness;
    double df, cs;

    if (!PyArg_ParseTuple(
            args, "ddlddlddlddlddddd",
            &qx_min,
            &dqx,
            &Nqx,
            &qy_min,
            &dqy,
            &Nqy,
            &kx_min,
            &dkx,
            &Nkx,
            &ky_min,
            &dky,
            &Nky,
            &lam,
            &kmax,
            &thickness,
            &df,
            &cs
        )) {
        return NULL;
    }

    // CUDA 側呼び出し（float にキャスト）
    std::complex<float>* output = obfWeight(
        Nkx, Nky,
        static_cast<float>(dkx),
        static_cast<float>(dky),
        static_cast<float>(kx_min),
        static_cast<float>(ky_min),
        Nqx, Nqy,
        static_cast<float>(dqx),
        static_cast<float>(dqy),
        static_cast<float>(qx_min),
        static_cast<float>(qy_min),
        static_cast<float>(kmax),
        static_cast<float>(thickness),
        static_cast<float>(lam),
        static_cast<float>(df),
        static_cast<float>(cs)
    );

    if (!output) {
        PyErr_SetString(PyExc_RuntimeError, "obfWeight returned NULL");
        return NULL;
    }

    npy_intp dims[4] = {Nqx, Nqy, Nkx, Nky};
    PyObject* arr_obj = PyArray_SimpleNew(4, dims, NPY_COMPLEX64);
    if (!arr_obj) {
        free(output);
        return NULL;
    }

    auto* arr_data =
        reinterpret_cast<std::complex<float>*>(PyArray_DATA((PyArrayObject*)arr_obj));
    long N = Nqx * Nqy * Nkx * Nky;
    std::memcpy(arr_data, output, sizeof(std::complex<float>) * N);

    free(output);

    return arr_obj;
}

static PyMethodDef obfMethods[] = {
    {"weight", weight, METH_VARARGS,
     "Calculate the OBF weights using CUDA.\n\n"
     "Args:\n"
     "    qx_min, dqx, Nqx, qy_min, dqy, Nqy, kx_min, dkx, Nkx, ky_min, dky, Nky,\n"
     "    lam, kmax, thickness, df, cs\n"
     "Returns:\n"
     "    numpy.ndarray (complex64) with shape (Nqx, Nqy, Nkx, Nky).\n"},
    {NULL, NULL, 0, NULL}
};

static struct PyModuleDef obfModule = {
    PyModuleDef_HEAD_INIT,
    "obf_cuda",
    "CUDA-based OBF weight computation",
    -1,
    obfMethods
};

PyMODINIT_FUNC PyInit_obf_cuda(void) {
    import_array();
    return PyModule_Create(&obfModule);
}
