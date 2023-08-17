# ifndef LEAST_SQUARES_CUH
# define LEAST_SQUARES_CUH

# include "../tomography.hpp"

class Least_Squares : public Tomography
{
private:

    int tk_order;   
    float lambda;

    int M, N, NNZ;

    int nx_tomo;  
    int ny_tomo;  
    int nz_tomo; 

    float dx_tomo;
    float dy_tomo;
    float dz_tomo;

    std::vector<int> iG;
    std::vector<int> jG;
    std::vector<float> vG;

    size_t ray_path_estimated_samples;

    int * iA = nullptr;
    int * jA = nullptr;
    float * vA = nullptr;
    float * B = nullptr;
    float * x = nullptr; 

    float * illumination;

    bool write_illumination_per_iteration;
    std::string illumination_folder;

    void initial_setup();
    void compute_gradient();
    void export_illumination();
    void gradient_ray_tracing();
    void apply_regularization();
    void solve_linear_system_lscg();
    void slowness_variation_rescaling();

public:

    void optimization();
    void set_parameters();
    void forward_modeling();
};

# endif