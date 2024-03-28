# include "modeling.hpp"

void Modeling::set_runtime()
{
    ti = std::chrono::system_clock::now();
}

void Modeling::get_runtime()
{
    tf = std::chrono::system_clock::now();

    std::chrono::duration<double> elapsed_seconds = tf - ti;

    std::ofstream runTimeFile("elapsedTime.txt", std::ios::in | std::ios::app);
    runTimeFile << "#------------------------------------------------------------------\n";
    runTimeFile << "# Run Time [s]; RAM usage [MB]; GPU memory usage [MB]\n";
    runTimeFile << std::to_string(elapsed_seconds.count()) + ";" + std::to_string(RAM) + ";" + std::to_string(vRAM) + "\n";
    runTimeFile << "#------------------------------------------------------------------\n";
    runTimeFile.close();

    std::cout<<"\nRun time: "<<elapsed_seconds.count()<<" s."<<std::endl;
}

void Modeling::get_RAM_usage()
{
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    RAM = (int) (usage.ru_maxrss / 1024);
}

void Modeling::get_GPU_usage()
{
	size_t freeMem, totalMem;
	cudaMemGetInfo(&freeMem, &totalMem);
    vRAM = (int) ((totalMem - freeMem) / (1024 * 1024)) - ivRAM;
}

void Modeling::get_GPU_initMem()
{
	size_t freeMem, totalMem;
	cudaMemGetInfo(&freeMem, &totalMem);
    ivRAM = (int) ((totalMem - freeMem) / (1024 * 1024));
}

void Modeling::expand_boundary(float * input, float * output)
{
    for (int y = nbyl; y < nyy - nbyr; y++)
    {
        for (int x = nbxl; x < nxx - nbyr; x++)
        {
            for (int z = nbzu; z < nzz - nbzd; z++)
            {
                output[z + x*nzz + y*nxx*nzz] = input[(z - nbzu) + (x - nbxl)*nz + (y - nbyl)*nx*nz];       
            }
        }
    }

    for (int y = nbyl; y < nyy - nbyr; y++)
    {
        for (int x = nbxl; x < nxx - nbyr; x++)
        {
            for (int z = 0; z < nbzu; z++)
            {
                output[z + x*nzz + y*nxx*nzz] = input[0 + (x - nbxl)*nz + (y - nbyl)*nx*nz];
            }
        }
    }

    for (int y = nbyl; y < nyy - nbyr; y++)
    {
        for (int x = nbxl; x < nxx - nbyr; x++)
        {
            for (int z = nzz - nbzd; z < nzz; z++)
            {
                output[z + x*nzz + y*nxx*nzz] = input[(nz - 1) + (x - nbxl)*nz + (y - nbyl)*nx*nz];
            }
        }
    }

    for (int y = nbyl; y < nyy - nbyr; y++)
    {
        for (int x = nbxl; x < nxx - nbyr; x++)
        {
            for (int z = nzz - nbzd; z < nzz; z++)
            {
                output[z + x*nzz + y*nxx*nzz] = input[(nz - 1) + (x - nbxl)*nz + (y - nbyl)*nx*nz];
            }
        }
    }

    for (int y = nbyl; y < nyy - nbyr; y++)
    {
        for (int x = 0; x < nbxl; x++)
        {
            for (int z = 0; z < nzz; z++)
            {
                output[z + x*nzz + y*nxx*nzz] = output[z + nbxl*nzz + y*nxx*nzz];
            }
        }
    }

    for (int y = nbyl; y < nyy - nbyr; y++)
    {
        for (int x = nxx-nbxr; x < nxx; x++)
        {
            for (int z = 0; z < nzz; z++)
            {
                output[z + x*nzz + y*nxx*nzz] = output[z + (nxx - nbxr - 1)*nzz + y*nxx*nzz];
            }
        }
    }

    for (int y = 0; y < nbyl; y++)
    {
        for (int x = 0; x < nxx; x++)
        {
            for (int z = 0; z < nzz; z++)
            {
                output[z + x*nzz + y*nxx*nzz] = output[z + x*nzz + nbyl*nxx*nzz];
            }
        }
    }

    for (int y = nyy - nbyr; y < nyy; y++)
    {
        for (int x = 0; x < nxx; x++)
        {
            for (int z = 0; z < nzz; z++)
            {
                output[z + x*nzz + y*nxx*nzz] = output[z + x*nzz + (nyy - nbyr - 1)*nxx*nzz];
            }
        }
    }
}

void Modeling::reduce_boundary(float * input, float * output)
{
    for (int index = 0; index < nPoints; index++)
    {
        int y = (int) (index / (nx*nz));         
        int x = (int) (index - y*nx*nz) / nz;    
        int z = (int) (index - x*nz - y*nx*nz);  

        output[z + x*nz + y*nx*nz] = input[(z + nbzu) + (x + nbxl)*nzz + (y + nbyl)*nxx*nzz];
    }
}

void Modeling::check_geometry_overflow()
{
    for (int shot = 0; shot < total_shots; shot++)
    {
        if ((geometry->shots.x[shot] < 0) || (geometry->shots.x[shot] > (nx-1)*dx) || 
            (geometry->shots.y[shot] < 0) || (geometry->shots.y[shot] > (ny-1)*dy) ||
            (geometry->shots.z[shot] < 0) || (geometry->shots.z[shot] > (nz-1)*dz))       
        throw std::invalid_argument("\033[31mError: shots geometry overflow!\033[0;0m");
    }

    for (int node = 0; node < total_nodes; node++)
    {
        if ((geometry->nodes.x[node] < 0) || (geometry->nodes.x[node] > (nx-1)*dx) || 
            (geometry->nodes.y[node] < 0) || (geometry->nodes.y[node] > (ny-1)*dy) ||
            (geometry->nodes.z[node] < 0) || (geometry->nodes.z[node] > (nz-1)*dz))       
        throw std::invalid_argument("\033[31mError: nodes geometry overflow!\033[0;0m");
    }
}

void Modeling::set_parameters()
{
    set_generals();

    set_specifics();

    set_geometry();
    
    set_boundary();     
    
    set_models();

    set_volumes();

    get_RAM_usage();
    get_GPU_usage();
}

void Modeling::set_generals()
{
    get_GPU_initMem();

    threadsPerBlock = 256;

    nx = std::stoi(catch_parameter("x_samples", file));
    ny = std::stoi(catch_parameter("y_samples", file));
    nz = std::stoi(catch_parameter("z_samples", file));
    
    dx = std::stof(catch_parameter("x_spacing", file));
    dy = std::stof(catch_parameter("y_spacing", file));
    dz = std::stof(catch_parameter("z_spacing", file));

    nPoints = nx*ny*nz;

    export_receiver_output = str2bool(catch_parameter("export_receiver_output", file));
    export_wavefield_output = str2bool(catch_parameter("export_wavefield_output", file));

    receiver_output_folder = catch_parameter("receiver_output_folder", file); 
    wavefield_output_folder = catch_parameter("wavefield_output_folder", file);
}

void Modeling::set_geometry()
{
    std::vector<Geometry *> possibilities = 
    {
        new Regular(), 
        new Circular()
    };

    auto type = std::stoi(catch_parameter("geometry_type", file));

    geometry = possibilities[type];

    geometry->file = file;

    geometry->set_geometry();

    total_shots = geometry->shots.total;
    total_nodes = geometry->nodes.total;

    check_geometry_overflow();

    std::vector<Geometry *>().swap(possibilities); 
}

void Modeling::set_boundary()
{
    nxx = nx + nbxl + nbxr;
    nyy = ny + nbyl + nbyr;
    nzz = nz + nbzu + nbzd;

    volsize = nxx*nyy*nzz;
}

void Modeling::get_information()
{
    auto clear = system("clear");
        
    std::cout<<"Model dimensions (z = "<<(nz-1)*dz<<", x = "<<(nx-1)*dx<<", y = "<<(ny-1)*dy<<") m\n\n";

    std::cout<<"Shot "<<shot_index+1<<" of "<<total_shots;

    std::cout<<" at position (z = "<<geometry->shots.z[shot_index]<<", x = " 
                                   <<geometry->shots.x[shot_index]<<", y = " 
                                   <<geometry->shots.y[shot_index]<<") m\n\n";

    std::cout<<"Memory usage: \n";
    std::cout<<"RAM = "<<RAM<<" Mb\n";
    std::cout<<"GPU = "<<vRAM<<" Mb\n\n";

    std::cout<<"Modeling tyep: "<<type_message<<"\n\n";
}

void Modeling::set_configuration()
{
    sidx = (int)(geometry->shots.x[shot_index] / dx) + nbxl;
    sidy = (int)(geometry->shots.y[shot_index] / dy) + nbyl;
    sidz = (int)(geometry->shots.z[shot_index] / dz) + nbzu;

    source_index = sidz + sidx*nzz + sidy*nxx*nzz;

    initialization();

    get_RAM_usage();
    get_GPU_usage();
}

// void Eikonal::build_outputs()
// {
//     get_travel_times();
//     get_first_arrivals();
// }

// void Eikonal::export_outputs()
// {
//     if (export_receiver_output) 
//         export_binary_float(receiver_output_file, receiver_output, receiver_output_samples);
    
//     if (export_wavefield_output) 
//         export_binary_float(wavefield_output_file, wavefield_output, wavefield_output_samples);
// }
