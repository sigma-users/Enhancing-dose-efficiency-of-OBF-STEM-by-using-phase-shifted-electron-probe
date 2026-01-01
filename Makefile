# Makefile (project root)
CUDA_PATH ?= /usr/local/cuda
NVCC      := $(CUDA_PATH)/bin/nvcc
NVCCFLAGS := -O3 -Xcompiler -fPIC

INCLUDES  := -Iinclude
LIB_NAME  := libobfweight.a
OBJ       := obfWeight.o

all: $(LIB_NAME)

$(OBJ): src/obfWeight.cu include/obfweight.hpp
	$(NVCC) $(NVCCFLAGS) $(INCLUDES) -c $< -o $@

$(LIB_NAME): $(OBJ)
	ar cru $@ $^
	ranlib $@

clean:
	rm -f $(OBJ) $(LIB_NAME)
