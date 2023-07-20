# ifndef SCALAR_HPP
# define SCALAR_HPP

# include "../wave.cuh"

class Scalar : public Wave
{
private:


protected:

    void set_wavelet();

    virtual void set_model_parameters() = 0;
    virtual void set_wavefields() = 0;
    
public:

    virtual void forward_solver() = 0;
    virtual void initial_setup() = 0;
    virtual void free_space() = 0;
};

# endif