# ifndef ADJOINT_STATE_CUH
# define ADJOINT_STATE_CUH

# include "tomography.hpp"

class Adjoint_State : public Tomography
{
private:

    int total_levels;
    int nSweeps, meshDim;
    int nThreads, nBlocks;

    float cell_area;

    float * m = nullptr;
    float * v = nullptr;

    float * d_T = nullptr;

    float * d_source = nullptr;
    float * h_source = nullptr;

    float * d_adjoint = nullptr;
    float * h_adjoint = nullptr;

    float * gradient = nullptr;

    void initialization();
    void set_specifications();

    void apply_inversion_technique();

    int iDivUp(int a, int b);

public:

    void optimization();
};

__global__ void adjoint_state_kernel(float * T, float * adjoint, float * source, int level, int xOffset, int yOffset, int xSweepOffset, 
                                     int ySweepOffset, int zSweepOffset, int nxx, int nyy, int nzz, float dx, float dy, float dz);
# endif
