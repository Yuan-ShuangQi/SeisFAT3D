# ifndef EIKONAL_CUH
# define EIKONAL_CUH

# include "../modeling.hpp"

# define INF 1e6f
# define EPS 1e-6f
# define BLOCK_LENGTH 4

# define MEM(index) _mem[index]
# define SOL(i,j,k) _sol[i][j][k]
# define SPD(i,j,k) _spd[i][j][k]

class Eikonal : public Modeling
{
private:

    float * vp = nullptr;

    float * T = nullptr;
    
    int pdx, pdy, pdz; 
    int nxx, nyy, nzz;
    int volsize, padb;

    int eikonal_type;

    void pad_expansion();
    void fdm_expansion();

    void pad_reduction();
    void fdm_reduction();

    void get_travelTimes();
    void get_firstArrivals();

    /* Podvin and Lecomte method components */

    float * K = nullptr;
    
    float * d_K = nullptr;
    float * d_nK = nullptr;
    float * d_nT = nullptr;
    float * d_T = nullptr;
    float * d_S = nullptr;

    void PAL_init();
    void PAL_solver();
    void PAL_parameters();
    void PAL_components();

    /* Fast Sweeping Method components */

    int i, j, k;
    int sgnvx, sgnvy, sgnvz;
    int sgntx, sgnty, sgntz;

    float dxi, dyi, dzi;
    float dx2i, dy2i, dz2i, dsum;
    float dz2dx2, dz2dy2, dx2dy2;

    void FSM_init();
    void FSM_solver();
    void FSM_parameters();
    void FSM_components();

    void init_sweep();
    void full_sweep();    
    void inner_sweep();

    /* Fast Iterative Method components */

    int blksize;
    int nblk, nit;
    int nbx, nby, nbz;
    uint nActiveBlock;

    uint * h_list = nullptr;
    bool * h_mask = nullptr; 
    bool * h_listed = nullptr;
    bool * h_listVol = nullptr; 
    float * h_slow = nullptr; 
    float * h_time = nullptr; 
    
    uint * d_list = nullptr;
    bool * d_mask = nullptr;
    bool * d_con = nullptr;
    bool * d_listVol = nullptr;
    float * d_slow = nullptr;
    float * d_time = nullptr; 
    float * t_time = nullptr;

    void FIM_init();
    void FIM_solver();
    void FIM_parameters();
    void FIM_components();

public:

    void initial_setup();
    void set_components();
    void forward_solver();
    void build_outputs();    

    void set_parameters(std::string file);
};

__global__ void PAL_kernel(float * S, float * T, float * K, float * nT, float h, int nxx, int nyy, int nzz);
__global__ void PAL_expansion(float * K, float * nK, int nxx, int nyy, int nzz);
__global__ void PAL_update(float * T, float * nT, float * K, float * nK, int N);

__global__ void run_solver(float* spd, bool* mask, const float *sol_in, float *sol_out, bool *con, uint* list, int xdim, int ydim, int zdim, float dh, int nIter, uint nActiveBlock);
__global__ void run_reduction(bool *con, bool *listVol, uint *list, uint nActiveBlock);
__global__ void run_check_neighbor(float* spd, bool* mask, const float *sol_in, float *sol_out, bool *con, uint* list, int xdim, int ydim, int zdim, float dh, uint nActiveBlock, uint nTotalBlock);
__device__ float get_time_eikonal(float a, float b, float c, float h, float s);

# endif
