# ifndef ELASTIC_CUH
# define ELASTIC_CUH

# include "../modeling.hpp"

# define FDM1 6.97545e-4f 
# define FDM2 9.57031e-3f 
# define FDM3 7.97526e-2f 
# define FDM4 1.19628906f 

class Elastic : public Modeling
{
private:

    void set_wavelet();
    void set_boundaries();
    void set_properties();
    void set_specifications();

protected:

    float fmax, bd;

    int tlag, nThreads;
    int sBlocks, nBlocks;

    float * P = nullptr;
    float * d_P = nullptr;

    float * TT = nullptr;
    float * d_T = nullptr;

    float * d_Vx = nullptr;
    float * d_Vy = nullptr;
    float * d_Vz = nullptr;

    float * d_Txx = nullptr;
    float * d_Tyy = nullptr;
    float * d_Tzz = nullptr;
    
    float * d_Txz = nullptr;
    float * d_Tyz = nullptr;
    float * d_Txy = nullptr;

    float * d1D = nullptr;
    float * d2D = nullptr;
    float * d3D = nullptr;

    int * rIdx = nullptr;
    int * rIdy = nullptr;
    int * rIdz = nullptr;

    int * current_xrec = nullptr;
    int * current_yrec = nullptr;
    int * current_zrec = nullptr;

    float * wavelet = nullptr;

    float * seismogram = nullptr;

    Modeling * eikonal = nullptr;

    virtual void set_conditions() = 0;

public:

    void initialization();
    void forward_solver();

    virtual void propagation() = 0;

    void export_synthetic_data();
};

__global__ void compute_seismogram(float * P, int * rIdx, int * rIdy, int * rIdz, float * seismogram, int spread, int tId, int tlag, int nt, int nxx, int nzz);

__device__ float get_boundary_damper(float * damp1D, float * damp2D, float * damp3D, int i, int j, int k, int nxx, int nyy, int nzz, int nabc);

# endif