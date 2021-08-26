#include <cuda.h>
#include <cuda_runtime_api.h>
#include <iostream>
#include "cuda_scatter.h"

namespace NAMESPACE
{

extern "C" __global__ void ScatterFP16(const __half *features_rw, const int *indices_rw, const int *valid_rw, __half *output_rw,
                                    int spatialShape0, int spatialShape1, int spatialShape2,
                                    int max_voxels, int batch_size, int num_features)
{
    int idx    = threadIdx.x + blockIdx.x * blockDim.x;
    int stride = blockDim.x * gridDim.x;

    for(int i = idx; i < max_voxels * batch_size; i += stride)
    {
        const int batch_id = i / max_voxels;
        const int voxel_id_per_batch = i % max_voxels;
        if(voxel_id_per_batch>=valid_rw[batch_id]) continue;

        int3 coor = reinterpret_cast<const int3*>(indices_rw)[i];
        int output_vol = spatialShape0 * spatialShape1 * spatialShape2;


        // out shape: (bs, c, x, y, z)
        __half *outPerBatch = output_rw + batch_id * num_features * output_vol;
        int offset = coor.x * spatialShape1 * spatialShape2 + coor.y * spatialShape2 + coor.z;

        for(int j = 0; j < num_features; ++j)
            outPerBatch[j * output_vol + offset] = features_rw[i * num_features + j];
	}

}


void cuda_scatter_fp16(const __half *features_rw, const int *indices_rw, const int *valid_rw, __half *output_rw, std::vector<int> spatialShape_rw,
                        int max_voxels, int batch_size, int num_features)
{
    int blockSize;   // The launch configurator returned block size
    int minGridSize; // The minimum grid size needed to achieve the
                        // maximum occupancy for a full device launch
    checkCudaErrors(cudaOccupancyMaxPotentialBlockSize(&minGridSize, &blockSize, ScatterFP16));
    minGridSize = std::min(minGridSize, DivUp(max_voxels * batch_size, blockSize));

    ScatterFP16<<<minGridSize, blockSize>>>(features_rw, indices_rw, valid_rw, output_rw, spatialShape_rw[0], spatialShape_rw[1], spatialShape_rw[2], max_voxels, batch_size, num_features);
    cudaDeviceSynchronize();

}

} //namespace