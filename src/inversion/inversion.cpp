# include "inversion.hpp"

void Inversion::set_parameters()
{
    max_iteration = std::stoi(catch_parameter("max_iteration", file));
    max_variation = std::stof(catch_parameter("max_slowness_variation", file));

    obs_data_folder = catch_parameter("obs_data_folder", file);
    obs_data_prefix = catch_parameter("obs_data_prefix", file);

    update_smooth = str2bool(catch_parameter("smooth_per_iteration", file));
    smoother_samples = std::stoi(catch_parameter("gaussian_filter_samples", file));
    smoother_stdv = std::stoi(catch_parameter("gaussian_filter_stdv", file));
    
    convergence_map_folder = catch_parameter("convergence_folder", file);
    estimated_model_folder = catch_parameter("estimated_model_folder", file);

    export_model_per_iteration = str2bool(catch_parameter("export_model_per_iteration", file));    

    set_forward_modeling();

    modeling->file = file;
    modeling->set_parameters();

    set_inversion_volumes();

    modeling->set_runtime();
}

void Inversion::print_information()
{
    auto clear = system("clear");

    std::cout << "\033[1mSeisFAT3D\033[m - Inversion program\n\n";

    std::cout << "Model dimensions: (z = " << (modeling->nz-1)*modeling->dz << 
                                  ", x = " << (modeling->nx-1)*modeling->dx << 
                                  ", y = " << (modeling->ny-1)*modeling->dy << ") m\n\n";

    std::cout << "Inversion type: \033[1m" << type_message << "\033[m\n\n";

    std::cout << "Running shot " << modeling->shot_index+1 << " of " << modeling->total_shots;

    std::cout << " at position (z = " << modeling->geometry->shots.z[modeling->shot_index] << 
                             ", x = " << modeling->geometry->shots.x[modeling->shot_index] << 
                             ", y = " << modeling->geometry->shots.y[modeling->shot_index] << ") m\n\n";

    if (iteration == max_iteration)
    { 
        std::cout<<"------- Checking final residuo ------------\n\n";
    }
    else
        std::cout<<"------- Computing iteration "<<iteration+1<<" of "<<max_iteration<<" ------------\n\n";

    if (iteration > 0) std::cout<<"Previous residuo: "<<residuo.back()<<"\n\n";    
}

void Inversion::forward_modeling()
{
    for (int shot = 0; shot < modeling->total_shots; shot++)
    {
        modeling->shot_index = shot;

        modeling->set_initial_conditions();

        modeling->forward_propagation();

        extract_calculated_data();
        
        if (iteration != max_iteration)
            adjoint_propagation();
    }
}

void Inversion::check_convergence()
{
    get_objective_function();

    if ((iteration >= max_iteration))
    {
        std::cout << "\nFinal residuo: "<< residuo.back() <<"\n\n";
        converged = true;
    }
    else
    {
        iteration += 1;
        converged = false;
    }
}

void Inversion::optimization()
{
    float gmax = 0.0f;
    float gdot = 0.0f;
    for (int index = 0; index < modeling->nPoints; index++)
    {
        if (gmax < fabsf(gradient[index]))
            gmax = fabsf(gradient[index]);

        gdot += gradient[index]*gradient[index];
    }

    float gamma = max_variation;

    float lambda = 0.5f * residuo.back() / gdot;     
    
    float alpha = (lambda*gmax > gamma) ? (gamma / (lambda*gmax)) : 1.0f; 

    for (int index = 0; index < modeling->nPoints; index++)
        variation[index] = alpha*lambda*gradient[index];        
}

void Inversion::update_smoothing()
{
    if (update_smooth)
    { 
        int aux_nx = modeling->nx + 2*smoother_samples;
        int aux_ny = modeling->ny + 2*smoother_samples;
        int aux_nz = modeling->nz + 2*smoother_samples;

        int aux_nPoints = aux_nx*aux_ny*aux_nz;

        float * variation_aux = new float[aux_nPoints]();
        float * variation_smooth = new float[aux_nPoints]();

        for (int index = 0; index < modeling->nPoints; index++)
        {
            int k = (int) (index / (modeling->nx*modeling->nz));        
            int j = (int) (index - k*modeling->nx*modeling->nz) / modeling->nz;    
            int i = (int) (index - j*modeling->nz - k*modeling->nx*modeling->nz);          

            int ind_filt = (i + smoother_samples) + (j + smoother_samples)*aux_nz + (k + smoother_samples)*aux_nx*aux_nz;

            variation_aux[ind_filt] = variation[i + j*modeling->nz + k*modeling->nx*modeling->nz];
        }

        gaussian_smoothing(variation_aux, variation_smooth, aux_nx, aux_ny, aux_nz);

        for (int index = 0; index < modeling->nPoints; index++)
        {
            int k = (int) (index / (modeling->nx*modeling->nz));        
            int j = (int) (index - k*modeling->nx*modeling->nz) / modeling->nz;    
            int i = (int) (index - j*modeling->nz - k*modeling->nx*modeling->nz);          

            int ind_filt = (i + smoother_samples) + (j + smoother_samples)*aux_nz + (k + smoother_samples)*aux_nx*aux_nz; 

            variation[i + j*modeling->nz + k*modeling->nx*modeling->nz] = variation_smooth[ind_filt];
        }
    
        delete[] variation_aux;
        delete[] variation_smooth;
    }
}

void Inversion::model_update()
{
    update_smoothing();

    update_specifications();    

    for (int index = 0; index < modeling->nPoints; index++)    
        gradient[index] = 0.0f;

    if (export_model_per_iteration)
    {
        std::string model_iteration_path = estimated_model_folder + "model_iteration_" + std::to_string(iteration) + "_" + std::to_string(modeling->nz) + "x" + std::to_string(modeling->nx) + "x" + std::to_string(modeling->ny) + ".bin";

        export_binary_float(model_iteration_path, modeling->model, modeling->nPoints);
    }
}

void Inversion::export_results()
{
    std::string estimated_model_path = estimated_model_folder + "final_model_" + std::to_string(modeling->nz) + "x" + std::to_string(modeling->nx) + "x" + std::to_string(modeling->ny) + ".bin";
    std::string convergence_map_path = convergence_map_folder + "convergence_" + std::to_string(iteration) + "_iterations.txt"; 

    export_binary_float(estimated_model_path, modeling->model, modeling->nPoints);

    std::ofstream resFile(convergence_map_path, std::ios::out);
    
    for (int r = 0; r < residuo.size(); r++) 
        resFile << residuo[r] << "\n";

    resFile.close();

    std::cout<<"Text file "<<convergence_map_path<<" was successfully written."<<std::endl;

    modeling->get_runtime();
}

void Inversion::gaussian_smoothing(float * input, float * output, int nx, int ny, int nz)
{
    int init = smoother_samples / 2;
    int nPoints = nx * ny * nz;
    int nKernel = smoother_samples * smoother_samples * smoother_samples;

    float pi = 4.0f * atanf(1.0f); 

    float * kernel = new float[nKernel]();

    # pragma omp parallel for
    for (int i = 0; i < nPoints; i++) 
        output[i] = input[i];

    int mid = (int)(smoother_samples / 2); 

    kernel[mid + mid*smoother_samples + mid*smoother_samples*smoother_samples] = 1.0f;

    if (smoother_stdv != 0.0f)
    {
        float sum = 0.0f;

        for (int y = -init; y <= init; y++)
        {
            for (int x = -init; x <= init; x++)
            {
                for (int z = -init; z <= init; z++)
                {          
                    int index = (z+init) + (x+init)*smoother_samples + (y+init)*smoother_samples*smoother_samples; 
                    
                    float r = sqrtf(x*x + y*y + z*z);

                    kernel[index] = 1.0f / (pi*smoother_stdv) * expf(-((r*r)/(2.0f*smoother_stdv*smoother_stdv)));
        
                    sum += kernel[index]; 
                }
            }
        }

        for (int i = 0; i < nKernel; i++) 
            kernel[i] /= sum;
    }
        
    for (int k = init; k < ny - init; k++)
    {   
        for (int j = init; j < nx - init; j++)
        {
            for (int i = init; i < nz - init; i++)
            {       
                float accum = 0.0f;
                
                for (int yk = 0; yk < smoother_samples; yk++)
                {      
                    for (int xk = 0; xk < smoother_samples; xk++)
                    {      
                        for (int zk = 0; zk < smoother_samples; zk++)
                        {   
                            int index = zk + xk*smoother_samples + yk*smoother_samples*smoother_samples;   
                            int partial = (i-init+zk) + (j-init+xk)*nz + (k-init+yk)*nx*nz; 

                            accum += input[partial] * kernel[index];
                        }        
                    }
                }
                
                output[i + j*nz + k*nx*nz] = accum;
            }
        }   
    }

    delete[] kernel;
}

