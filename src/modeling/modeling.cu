# include "modeling.cuh"

void Modeling::set_parameters()
{    
    get_GPU_initMem();

    nx = std::stoi(catch_parameter("x_samples", file));
    ny = std::stoi(catch_parameter("y_samples", file));
    nz = std::stoi(catch_parameter("z_samples", file));

    padb = 1;
    nSweeps = 8;
    meshDim = 3;
        
    nxx = nx + 2*padb;
    nyy = ny + 2*padb;
    nzz = nz + 2*padb;

    nPoints = nx*ny*nz;
    volsize = nxx*nyy*nzz;

    dx = std::stof(catch_parameter("x_spacing", file));
    dy = std::stof(catch_parameter("y_spacing", file));
    dz = std::stof(catch_parameter("z_spacing", file));

    export_receiver_output = str2bool(catch_parameter("export_receiver_output", file));
    export_wavefield_output = str2bool(catch_parameter("export_wavefield_output", file));

    receiver_output_folder = catch_parameter("receiver_output_folder", file); 
    wavefield_output_folder = catch_parameter("wavefield_output_folder", file);

    V = new float[nPoints]();
    S = new float[volsize]();
    T = new float[volsize]();

    import_binary_float(catch_parameter("vp_model_file", file), V, nPoints);

    Geometry * types[] = {new Regular(), new Circular()};

    geometry = types[std::stoi(catch_parameter("geometry_type", file))];

    geometry->file = file;

    geometry->set_geometry();

    total_shots = geometry->shots.total;
    total_nodes = geometry->nodes.total;

    check_geometry_overflow();

    wavefield_output_samples = nPoints;
    receiver_output_samples = geometry->nodes.total;

    receiver_output = new float[receiver_output_samples]();
    wavefield_output = new float[wavefield_output_samples]();

    dz2i = 1.0f / (dz*dz);
    dx2i = 1.0f / (dx*dx);
    dy2i = 1.0f / (dy*dy);

    dz2dx2 = dz2i * dx2i;
    dz2dy2 = dz2i * dy2i;
    dx2dy2 = dx2i * dy2i;

    dsum = dz2i + dx2i + dy2i;

    threadsPerBlock = 256;

	totalLevels = (nxx - 1) + (nyy - 1) + (nzz - 1);

    int sgnv[nSweeps][meshDim] = {{1,1,1}, {0,1,1}, {1,1,0}, {0,1,0}, {1,0,1}, {0,0,1}, {1,0,0}, {0,0,0}};
    int sgnt[nSweeps][meshDim] = {{1,1,1}, {-1,1,1}, {1,1,-1}, {-1,1,-1}, {1,-1,1}, {-1,-1,1}, {1,-1,-1}, {-1,-1,-1}};

	int * h_sgnv = new int [nSweeps * meshDim]();
	int * h_sgnt = new int [nSweeps * meshDim](); 

	for (int index = 0; index < nSweeps * meshDim; index++)
	{
		int j = index / nSweeps;
		int i = index % nSweeps;				

		h_sgnv[i + j * nSweeps] = sgnv[i][j];
		h_sgnt[i + j * nSweeps] = sgnt[i][j];
	}

	cudaMalloc((void**)&(d_sgnv), nSweeps*meshDim*sizeof(int));
	cudaMalloc((void**)&(d_sgnt), nSweeps*meshDim*sizeof(int));

	cudaMemcpy(d_sgnv, h_sgnv, nSweeps*meshDim*sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_sgnt, h_sgnt, nSweeps*meshDim*sizeof(int), cudaMemcpyHostToDevice);

	cudaMalloc((void**)&(d_T), volsize*sizeof(float));
	cudaMalloc((void**)&(d_S), volsize*sizeof(float));

    delete[] h_sgnt;
    delete[] h_sgnv;
}

void Modeling::set_slowness()
{
    for (int z = padb; z < nzz - padb; z++)
    {
        for (int y = padb; y < nyy - padb; y++)
        {
            for (int x = padb; x < nxx - padb; x++)
            {
                S[z + x*nzz + y*nxx*nzz] = 1.0f / V[(z - padb) + (x - padb)*nz + (y - padb)*nx*nz];
            }
        }
    }

    for (int z = 0; z < padb; z++)
    {
        for (int y = padb; y < nyy - padb; y++)
        {
            for (int x = padb; x < nxx - padb; x++)
            {
                S[z + x*nzz + y*nxx*nzz] = 1.0f / V[0 + (x - padb)*nz + (y - padb)*nx*nz];
                S[(nzz - z - 1) + x*nzz + y*nxx*nzz] = 1.0f / V[(nz - 1) + (x - padb)*nz + (y - padb)*nx*nz];
            }
        }
    }

    for (int x = 0; x < padb; x++)
    {
        for (int z = 0; z < nzz; z++)
        {
            for (int y = padb; y < nyy - padb; y++)
            {
                S[z + x*nzz + y*nxx*nzz] = S[z + padb*nzz + y*nxx*nzz];
                S[z + (nxx - x - 1)*nzz + y*nxx*nzz] = S[z + (nxx - padb - 1)*nzz + y*nxx*nzz];
            }
        }
    }

    for (int y = 0; y < padb; y++)
    {
        for (int z = 0; z < nzz; z++)
        {
            for (int x = 0; x < nxx; x++)
            {
                S[z + x*nzz + y*nxx*nzz] = S[z + x*nzz + padb*nxx*nzz];
                S[z + x*nzz + (nyy - y - 1)*nxx*nzz] = S[z + x*nzz + (nyy - padb - 1)*nxx*nzz];
            }
        }
    }

	cudaMemcpy(d_S, S, volsize*sizeof(float), cudaMemcpyHostToDevice);
}

void Modeling::initial_setup()
{
    int sidx = (int)(geometry->shots.x[shot_id] / dx) + padb;
    int sidy = (int)(geometry->shots.y[shot_id] / dy) + padb;
    int sidz = (int)(geometry->shots.z[shot_id] / dz) + padb;

    int sId = sidz + sidx*nzz + sidy*nxx*nzz;

    for (int index = 0; index < volsize; index++) T[index] = 1e6f;

    T[sId] = S[sId] * sqrtf(powf((sidx-padb)*dx - geometry->shots.x[shot_id], 2.0f) + powf((sidy-padb)*dy - geometry->shots.y[shot_id], 2.0f) + powf((sidz-padb)*dz - geometry->shots.z[shot_id], 2.0f));

    T[sId + 1] = S[sId] * sqrtf(powf((sidx-padb)*dx - geometry->shots.x[shot_id], 2.0f) + powf((sidy-padb)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)+1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - 1] = S[sId] * sqrtf(powf((sidx-padb)*dx - geometry->shots.x[shot_id], 2.0f) + powf((sidy-padb)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)-1)*dz - geometry->shots.z[shot_id], 2.0f));

    T[sId + nzz] = S[sId] * sqrtf(powf(((sidx-padb)+1)*dx - geometry->shots.x[shot_id], 2.0f) + powf((sidy-padb)*dy - geometry->shots.y[shot_id], 2.0f) + powf((sidz-padb)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - nzz] = S[sId] * sqrtf(powf(((sidx-padb)-1)*dx - geometry->shots.x[shot_id], 2.0f) + powf((sidy-padb)*dy - geometry->shots.y[shot_id], 2.0f) + powf((sidz-padb)*dz - geometry->shots.z[shot_id], 2.0f));
    
    T[sId + nxx*nzz] = S[sId] * sqrtf(powf((sidx-padb)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)+1)*dy - geometry->shots.y[shot_id], 2.0f) + powf((sidz-padb)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - nxx*nzz] = S[sId] * sqrtf(powf((sidx-padb)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)-1)*dy - geometry->shots.y[shot_id], 2.0f) + powf((sidz-padb)*dz - geometry->shots.z[shot_id], 2.0f));
    
    T[sId + 1 + nzz] = S[sId] * sqrtf(powf(((sidx-padb)+1)*dx - geometry->shots.x[shot_id], 2.0f) + powf((sidy-padb)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)+1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId + 1 - nzz] = S[sId] * sqrtf(powf(((sidx-padb)+1)*dx - geometry->shots.x[shot_id], 2.0f) + powf((sidy-padb)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)-1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - 1 + nzz] = S[sId] * sqrtf(powf(((sidx-padb)-1)*dx - geometry->shots.x[shot_id], 2.0f) + powf((sidy-padb)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)+1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - 1 - nzz] = S[sId] * sqrtf(powf(((sidx-padb)-1)*dx - geometry->shots.x[shot_id], 2.0f) + powf((sidy-padb)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)-1)*dz - geometry->shots.z[shot_id], 2.0f));
    
    T[sId + 1 + nxx*nzz] = S[sId] * sqrtf(powf((sidx-padb)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)+1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)+1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId + 1 - nxx*nzz] = S[sId] * sqrtf(powf((sidx-padb)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)-1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)+1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - 1 + nxx*nzz] = S[sId] * sqrtf(powf((sidx-padb)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)+1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)-1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - 1 - nxx*nzz] = S[sId] * sqrtf(powf((sidx-padb)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)-1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)-1)*dz - geometry->shots.z[shot_id], 2.0f));
    
    T[sId + nzz + nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)+1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)+1)*dy - geometry->shots.y[shot_id], 2.0f) + powf((sidz-padb)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId + nzz - nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)+1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)-1)*dy - geometry->shots.y[shot_id], 2.0f) + powf((sidz-padb)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - nzz + nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)-1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)+1)*dy - geometry->shots.y[shot_id], 2.0f) + powf((sidz-padb)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - nzz - nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)-1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)-1)*dy - geometry->shots.y[shot_id], 2.0f) + powf((sidz-padb)*dz - geometry->shots.z[shot_id], 2.0f));
    
    T[sId + 1 + nzz + nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)+1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)+1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)+1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId + 1 - nzz + nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)-1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)+1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)+1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId + 1 + nzz - nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)+1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)-1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)+1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId + 1 - nzz - nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)-1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)-1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)+1)*dz - geometry->shots.z[shot_id], 2.0f));

    T[sId - 1 + nzz + nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)+1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)+1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)-1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - 1 - nzz + nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)-1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)+1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)-1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - 1 + nzz - nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)+1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)-1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)-1)*dz - geometry->shots.z[shot_id], 2.0f));
    T[sId - 1 - nzz - nxx*nzz] = S[sId] * sqrtf(powf(((sidx-padb)-1)*dx - geometry->shots.x[shot_id], 2.0f) + powf(((sidy-padb)-1)*dy - geometry->shots.y[shot_id], 2.0f) + powf(((sidz-padb)-1)*dz - geometry->shots.z[shot_id], 2.0f));

    t0 = T[sId];

	cudaMemcpy(d_T, T, volsize*sizeof(float), cudaMemcpyHostToDevice);
}

void Modeling::forward_solver()
{
    for (int sweep = 0; sweep < nSweeps; sweep++)
	{ 
		int start = (sweep == 3 || sweep == 5 || sweep == 6 || sweep == 7) ? totalLevels : meshDim;
		int end = (start == meshDim) ? totalLevels + 1 : meshDim - 1;
		int incr = (start == meshDim) ? true : false;

		int xSweepOff = (sweep == 3 || sweep == 4) ? nxx : 0;
		int ySweepOff = (sweep == 2 || sweep == 5) ? nyy : 0;
		int zSweepOff = (sweep == 1 || sweep == 6) ? nzz : 0;
		
		for (int level = start; level != end; level = (incr) ? level + 1 : level - 1)
		{			
			int xs = max(1, level - (nyy + nzz));	
			int ys = max(1, level - (nxx + nzz));

			int xe = min(nxx, level - (meshDim - 1));
			int ye = min(nyy, level - (meshDim - 1));	
		
			int xr = xe - xs + 1;
			int yr = ye - ys + 1;

			int nThreads = xr * yr;
				
			dim3 bs(16, 16, 1);

			if (nThreads < threadsPerBlock) { bs.x = xr; bs.y = yr; } 

			dim3 gs(iDivUp(xr, bs.x), iDivUp(yr , bs.y), 1);
			
            int sgni = sweep + 0*nSweeps;
            int sgnj = sweep + 1*nSweeps;
            int sgnk = sweep + 2*nSweeps;

			fast_sweeping_kernel<<<gs,bs>>>(d_S, d_T, d_sgnt, d_sgnv, sgni, sgnj, sgnk, level, xs, ys, 
                                            xSweepOff, ySweepOff, zSweepOff, nxx, nyy, nzz, dx, dy, dz, 
                                            dx2i, dy2i, dz2i, dz2dx2, dz2dy2, dx2dy2, dsum);
			
            cudaDeviceSynchronize();
		}
	}

    cudaMemcpy(T, d_T, volsize*sizeof(float), cudaMemcpyDeviceToHost);
}

void Modeling::build_outputs()
{
    get_travelTimes();
    get_firstArrivals();
}

void Modeling::get_travelTimes()
{
    for (int index = 0; index < nPoints; index++)
    {
        int y = (int) (index / (nx*nz));         
        int x = (int) (index - y*nx*nz) / nz;    
        int z = (int) (index - x*nz - y*nx*nz);  

        wavefield_output[z + x*nz + y*nx*nz] = T[(z + padb) + (x + padb)*nzz + (y + padb)*nxx*nzz];
    }

    wavefield_output_file = wavefield_output_folder + "time_volume_" + std::to_string(nz) + "x" + std::to_string(nx) + "x" + std::to_string(ny) + "_shot_" + std::to_string(shot_id+1) + ".bin";
}

void Modeling::get_firstArrivals()
{
    for (int r = 0; r < total_nodes; r++)
    {
        float x = geometry->nodes.x[r];
        float y = geometry->nodes.y[r];
        float z = geometry->nodes.z[r];

        float x0 = floorf(x / dx) * dx;
        float y0 = floorf(y / dy) * dy;
        float z0 = floorf(z / dz) * dz;

        float x1 = floorf(x / dx) * dx + dx;
        float y1 = floorf(y / dy) * dy + dy;
        float z1 = floorf(z / dz) * dz + dz;

        int id = ((int)(z / dz)) + ((int)(x / dx))*nz + ((int)(y / dy))*nx*nz;

        float c000 = wavefield_output[id];
        float c001 = wavefield_output[id + 1];
        float c100 = wavefield_output[id + nz]; 
        float c101 = wavefield_output[id + 1 + nz]; 
        float c010 = wavefield_output[id + nx*nz]; 
        float c011 = wavefield_output[id + 1 + nx*nz]; 
        float c110 = wavefield_output[id + nz + nx*nz]; 
        float c111 = wavefield_output[id + 1 + nz + nx*nz];

        float xd = (x - x0) / (x1 - x0);
        float yd = (y - y0) / (y1 - y0);
        float zd = (z - z0) / (z1 - z0);

        float c00 = c000*(1 - xd) + c100*xd;    
        float c01 = c001*(1 - xd) + c101*xd;    
        float c10 = c010*(1 - xd) + c110*xd;    
        float c11 = c011*(1 - xd) + c111*xd;    

        float c0 = c00*(1 - yd) + c10*yd;
        float c1 = c01*(1 - yd) + c11*yd;

        receiver_output[r] = c0*(1 - zd) + c1*zd;
    }

    receiver_output_file = receiver_output_folder + "data_" + std::to_string(geometry->nodes.total) + "_shot_" + std::to_string(shot_id+1) + ".bin";
}

void Modeling::free_space()
{
    cudaFree(d_T);
    cudaFree(d_S);

    cudaFree(d_sgnt);
    cudaFree(d_sgnv);

    delete[] T;
    delete[] S;
    delete[] V;
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

void Modeling::get_RAM_usage()
{
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    RAM = (int) (usage.ru_maxrss / 1024);
}

void Modeling::get_GPU_initMem()
{
	size_t freeMem, totalMem;
	cudaMemGetInfo(&freeMem, &totalMem);
    ivRAM = (int) ((totalMem - freeMem) / (1024 * 1024));
}

void Modeling::get_GPU_usage()
{
	size_t freeMem, totalMem;
	cudaMemGetInfo(&freeMem, &totalMem);
    vRAM = (int) ((totalMem - freeMem) / (1024 * 1024));
    vRAM -= ivRAM;
}

void Modeling::export_outputs()
{
    if (export_receiver_output) export_binary_float(receiver_output_file, receiver_output, receiver_output_samples);
    if (export_wavefield_output) export_binary_float(wavefield_output_file, wavefield_output, wavefield_output_samples);
}

int Modeling::iDivUp(int a, int b) 
{ 
    return ( (a % b) != 0 ) ? (a / b + 1) : (a / b); 
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

__global__ void fast_sweeping_kernel(float * S, float * T, int * sgnt, int * sgnv, int sgni, int sgnj, int sgnk, 
                                     int level, int xOffset, int yOffset, int xSweepOffset, int ySweepOffset, int zSweepOffset, 
                                     int nxx, int nyy, int nzz, float dx, float dy, float dz, float dx2i, float dy2i, float dz2i, 
                                     float dz2dx2, float dz2dy2, float dx2dy2, float dsum)
{
	int x = (blockIdx.x * blockDim.x + threadIdx.x) + xOffset;
	int y = (blockIdx.y * blockDim.y + threadIdx.y) + yOffset;

    float ta, tb, tc, t1, t2, t3, Sref;
    float t1D1, t1D2, t1D3, t1D, t2D1, t2D2, t2D3, t2D, t3D;

	if ((x <= nxx) && (y <= nyy)) 
	{
		int z = level - (x + y);
		
		if ((z > 0) && (z <= nzz))	
		{
			int i = abs(z - zSweepOffset);
			int j = abs(x - xSweepOffset);
			int k = abs(y - ySweepOffset);

			if ((i > 0) && (i < nzz-1) && (j > 0) && (j < nxx-1) && (k > 0) && (k < nyy-1))
			{		
				int i1 = i - sgnv[sgni];
				int j1 = j - sgnv[sgnj];
				int k1 = k - sgnv[sgnk];

				int ijk = i + j*nzz + k*nxx*nzz;
				
				float tv = T[(i - sgnt[sgni]) + j*nzz + k*nxx*nzz];
				float te = T[i + (j - sgnt[sgnj])*nzz + k*nxx*nzz];
				float tn = T[i + j*nzz + (k - sgnt[sgnk])*nxx*nzz];

				float tev = T[(i - sgnt[sgni]) + (j - sgnt[sgnj])*nzz + k*nxx*nzz];
				float ten = T[i + (j - sgnt[sgnj])*nzz + (k - sgnt[sgnk])*nxx*nzz];
				float tnv = T[(i - sgnt[sgni]) + j*nzz + (k - sgnt[sgnk])*nxx*nzz];
				
				float tnve = T[(i - sgnt[sgni]) + (j - sgnt[sgnj])*nzz + (k - sgnt[sgnk])*nxx*nzz];

				t1D1 = tv + dz * min(S[i1 + max(j-1,1)*nzz   + max(k-1,1)*nxx*nzz], 
								 min(S[i1 + max(j-1,1)*nzz   + min(k,nyy-1)*nxx*nzz], 
								 min(S[i1 + min(j,nxx-1)*nzz + max(k-1,1)*nxx*nzz],
									 S[i1 + min(j,nxx-1)*nzz + min(k,nyy-1)*nxx*nzz])));                                     

				t1D2 = te + dx * min(S[max(i-1,1)   + j1*nzz + max(k-1,1)*nxx*nzz], 
								 min(S[min(i,nzz-1) + j1*nzz + max(k-1,1)*nxx*nzz],
								 min(S[max(i-1,1)   + j1*nzz + min(k,nyy-1)*nxx*nzz], 
									 S[min(i,nzz-1) + j1*nzz + min(k,nyy-1)*nxx*nzz])));                    

				t1D3 = tn + dy * min(S[max(i-1,1)   + max(j-1,1)*nzz   + k1*nxx*nzz], 
								 min(S[max(i-1,1)   + min(j,nxx-1)*nzz + k1*nxx*nzz],
								 min(S[min(i,nzz-1) + max(j-1,1)*nzz   + k1*nxx*nzz], 
									 S[min(i,nzz-1) + min(j,nxx-1)*nzz + k1*nxx*nzz])));

				t1D = min(t1D1, min(t1D2, t1D3));

                //------------------- 2D operators - 4 points operator ---------------------------------------------------------------------------------------------------
                t2D1 = 1e6; t2D2 = 1e6; t2D3 = 1e6;

                // XZ plane ----------------------------------------------------------------------------------------------------------------------------------------------
                Sref = min(S[i1 + j1*nzz + max(k-1,1)*nxx*nzz], S[i1 + j1*nzz + min(k, nyy-1)*nxx*nzz]);
                
                if ((tv < te + dx*Sref) && (te < tv + dz*Sref))
                {
                    ta = tev + te - tv;
                    tb = tev - te + tv;

                    t2D1 = ((tb*dz2i + ta*dx2i) + sqrtf(4.0f*Sref*Sref*(dz2i + dx2i) - dz2i*dx2i*(ta - tb)*(ta - tb))) / (dz2i + dx2i);
                }

                // YZ plane -------------------------------------------------------------------------------------------------------------------------------------------------------------
                Sref = min(S[i1 + max(j-1,1)*nzz + k1*nxx*nzz], S[i1 + min(j,nxx-1)*nzz + k1*nxx*nzz]);

                if((tv < tn + dy*Sref) && (tn < tv + dz*Sref))
                {
                    ta = tv - tn + tnv;
                    tb = tn - tv + tnv;
                    
                    t2D2 = ((ta*dz2i + tb*dy2i) + sqrtf(4.0f*Sref*Sref*(dz2i + dy2i) - dz2i*dy2i*(ta - tb)*(ta - tb))) / (dz2i + dy2i); 
                }

                // XY plane -------------------------------------------------------------------------------------------------------------------------------------------------------------
                Sref = min(S[max(i-1,1) + j1*nzz + k1*nxx*nzz],S[min(i,nzz-1) + j1*nzz + k1*nxx*nzz]);

                if((te < tn + dy*Sref) && (tn < te + dx*Sref))
                {
                    ta = te - tn + ten;
                    tb = tn - te + ten;

                    t2D3 = ((ta*dx2i + tb*dy2i) + sqrtf(4.0f*Sref*Sref*(dx2i + dy2i) - dx2i*dy2i*(ta - tb)*(ta - tb))) / (dx2i + dy2i);
                }

                t2D = min(t2D1, min(t2D2, t2D3));

                //------------------- 3D operators - 8 point operator ---------------------------------------------------------------------------------------------------
                t3D = 1e6;

                Sref = S[i1 + j1*nzz + k1*nxx*nzz];

                ta = te - 0.5f*tn + 0.5f*ten - 0.5f*tv + 0.5f*tev - tnv + tnve;
                tb = tv - 0.5f*tn + 0.5f*tnv - 0.5f*te + 0.5f*tev - ten + tnve;
                tc = tn - 0.5f*te + 0.5f*ten - 0.5f*tv + 0.5f*tnv - tev + tnve;

                if (min(t1D, t2D) > max(tv, max(te, tn)))
                {
                    t2 = 9.0f*Sref*Sref*dsum; 
                    
                    t3 = dz2dx2*(ta - tb)*(ta - tb) + dz2dy2*(tb - tc)*(tb - tc) + dx2dy2*(ta - tc)*(ta - tc);
                    
                    if (t2 >= t3)
                    {
                        t1 = tb*dz2i + ta*dx2i + tc*dy2i;        
                        
                        t3D = (t1 + sqrtf(t2 - t3)) / dsum;
                    }
                }

				T[ijk] = min(T[ijk], min(t1D, min(t2D, t3D)));
            }
        }
    }
}
