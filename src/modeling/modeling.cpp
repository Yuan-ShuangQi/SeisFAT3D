# include "modeling.hpp"

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
    vRAM = (int) ((totalMem - freeMem) / (1024 * 1024));
    vRAM -= ivRAM;
}

void Modeling::get_GPU_initMem()
{
	size_t freeMem, totalMem;
	cudaMemGetInfo(&freeMem, &totalMem);
    ivRAM = (int) ((totalMem - freeMem) / (1024 * 1024));
}

void Modeling::check_geometry_overflow()
{
    for (int shot = 0; shot < total_shots; shot++)
    {
        if ((geometry->shots.x[shot] < 0) && (geometry->shots.x[shot] > (nx-1)*dx) && 
            (geometry->shots.y[shot] < 0) && (geometry->shots.y[shot] > (ny-1)*dy) &&
            (geometry->shots.z[shot] < 0) && (geometry->shots.z[shot] > (nz-1)*dz))       
        throw std::invalid_argument("\033[31mError: shots geometry overflow!\033[0;0m");
    }

    for (int node = 0; node < total_nodes; node++)
    {
        if ((geometry->nodes.x[node] < 0) && (geometry->nodes.x[node] > (nx-1)*dx) && 
            (geometry->nodes.y[node] < 0) && (geometry->nodes.y[node] > (ny-1)*dy) &&
            (geometry->nodes.z[node] < 0) && (geometry->nodes.z[node] > (nz-1)*dz))       
        throw std::invalid_argument("\033[31mError: nodes geometry overflow!\033[0;0m");
    }
}

void Modeling::set_runtime()
{
    ti = std::chrono::system_clock::now();
}

void Modeling::get_runtime()
{
    tf = std::chrono::system_clock::now();

    std::chrono::duration<double> elapsed_seconds = tf - ti;

    std::cout<<"\nRun time: "<<elapsed_seconds.count()<<" s."<<std::endl;
}

void Modeling::info_message()
{
    get_RAM_usage();
    get_GPU_usage();

    auto clear = system("clear");
        
    std::cout<<"Model dimensions (z = "<<(nz-1)*dz<<", x = "<<(nx-1)*dx<<", y = "<<(ny-1)*dy<<") m\n\n";

    std::cout<<"Shot "<<shot_id+1<<" of "<<geometry->shots.total;

    std::cout<<" at position (z = "<<geometry->shots.z[shot_id]<<", x = " 
                                   <<geometry->shots.x[shot_id]<<", y = " 
                                   <<geometry->shots.y[shot_id]<<") m\n\n";

    std::cout<<"Memory usage: \n";
    std::cout<<"RAM = "<<RAM<<" Mb\n";
    std::cout<<"GPU = "<<vRAM<<" Mb\n\n";
}

void Modeling::set_parameters()
{    
    get_GPU_initMem();

    nx = std::stoi(catch_parameter("x_samples", file));
    ny = std::stoi(catch_parameter("y_samples", file));
    nz = std::stoi(catch_parameter("z_samples", file));

    nb = std::stoi(catch_parameter("n_boundary", file));

    dx = std::stof(catch_parameter("x_spacing", file));
    dy = std::stof(catch_parameter("y_spacing", file));
    dz = std::stof(catch_parameter("z_spacing", file));

    export_receiver_output = str2bool(catch_parameter("export_receiver_output", file));
    export_wavefield_output = str2bool(catch_parameter("export_wavefield_output", file));

    receiver_output_folder = catch_parameter("receiver_output_folder", file); 
    wavefield_output_folder = catch_parameter("wavefield_output_folder", file);

    set_model_parameters();
    set_model_boundaries();    

    Geometry * types[] = {new Regular(), new Circular()};

    geometry = types[std::stoi(catch_parameter("geometry_type", file))];

    geometry->file = file;

    geometry->set_geometry();

    total_shots = geometry->shots.total;
    total_nodes = geometry->nodes.total;

    check_geometry_overflow();
    
    set_wavefields();        
    
    set_outputs();
}

void Modeling::export_outputs()
{
    if (export_receiver_output) 
        export_binary_float(receiver_output_file, receiver_output, receiver_output_samples);
    
    if (export_wavefield_output) 
        export_binary_float(wavefield_output_file, wavefield_output, wavefield_output_samples);
}

