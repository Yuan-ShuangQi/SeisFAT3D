# ifndef MODELING_HPP
# define MODELING_HPP

# include <chrono>
# include <cuda.h>
# include <cassert>
# include <cuda_runtime.h>
# include <sys/resource.h>

# include "../geometry/geometry.hpp"
# include "../geometry/regular/regular.hpp"
# include "../geometry/circular/circular.hpp"
# include "../geometry/streamer/streamer.hpp"

class Modeling
{
private:

    std::chrono::_V2::system_clock::time_point ti, tf;

protected:

    std::string title;

    int RAM, vRAM, ivRAM;

    int receiver_output_samples;
    int wavefield_output_samples;

    bool export_receiver_output;
    bool export_wavefield_output;

    std::string receiver_output_file;
    std::string wavefield_output_file;
    std::string receiver_output_folder;
    std::string wavefield_output_folder;

    float * receiver_output = nullptr;
    float * wavefield_output = nullptr;

    float dh;
    int nx, ny, nz, nPoints;

    float * S = nullptr;
    float * V = nullptr;
    float * K = nullptr;
    float * B = nullptr;
    float * M = nullptr;
    float * L = nullptr;

    Geometry * geometry;

    void get_RAM_usage();
    void get_GPU_usage();
    void get_vRAM_init();

public: 

    int shot_id;

    int total_shots;
    int total_nodes;

    virtual void initial_setup() = 0;
    virtual void set_components() = 0;
    virtual void forward_solver() = 0;
    virtual void build_outputs() = 0;

    virtual void set_parameters(std::string file); 

    void set_runtime();
    void get_runtime();
    void info_message();
    void export_outputs();
};

# endif