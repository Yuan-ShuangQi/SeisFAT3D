# include "adjoint_state.cuh"

int Adjoint_State::iDivUp(int a, int b) 
{ 
    return ( (a % b) != 0 ) ? (a / b + 1) : (a / b); 
}

void Adjoint_State::set_specific_parameters()
{
    nSweeps = 8;
    meshDim = 3;

	totalLevels = (modeling->nxx - 1) + (modeling->nyy - 1) + (modeling->nzz - 1);

    inversion_method = "[1] - Adjoint State first arrival tomography";

    source = new float[modeling->volsize]();
    adjoint = new float[modeling->volsize]();

    proposed_model = new float[modeling->nPoints]();

    cudaMalloc((void**)&(d_T), modeling->volsize*sizeof(float));
    cudaMalloc((void**)&(d_source), modeling->volsize*sizeof(float));
    cudaMalloc((void**)&(d_adjoint), modeling->volsize*sizeof(float));
}

void Adjoint_State::apply_inversion_technique()
{
    cell_volume = modeling->dx * modeling->dy * modeling->dz;

    modeling->expand_boundary(modeling->wavefield_output, modeling->T);

    int sidx = (int)(modeling->geometry->shots.x[modeling->shot_id] / modeling->dx) + modeling->nbxl;
    int sidy = (int)(modeling->geometry->shots.y[modeling->shot_id] / modeling->dy) + modeling->nbyl;

    for (int index = 0; index < modeling->volsize; index++) 
    {
        source[index] = 0.0f;    
        adjoint[index] = 1e6f;

        int k = (int) (index / (modeling->nxx*modeling->nzz));        
        int j = (int) (index - k*modeling->nxx*modeling->nzz) / modeling->nzz;    
        int i = (int) (index - j*modeling->nzz - k*modeling->nxx*modeling->nzz);  

        if ((i == 0) || (i == modeling->nzz - 1) || 
            (j == 0) || (j == modeling->nxx - 1) || 
            (k == 0) || (k == modeling->nyy - 1))  
        {    
            adjoint[index] = 0.0f;        
        }
    }

    for (int node = 0; node < modeling->total_nodes; node++)
    {
        int current_node = node + modeling->shot_id*modeling->total_nodes;

        int i = (int)(modeling->geometry->nodes.z[node] / modeling->dz) + modeling->nbzu;
        int j = (int)(modeling->geometry->nodes.x[node] / modeling->dx) + modeling->nbxl;
        int k = (int)(modeling->geometry->nodes.y[node] / modeling->dy) + modeling->nbyl;

        int index = i + j*modeling->nzz + k*modeling->nxx*modeling->nzz;

        source[index] += (dobs[current_node] - modeling->T[index]) / cell_volume; 
        source[index + 1] += (dobs[current_node] - modeling->T[index + 1]) / cell_volume; 
        source[index + modeling->nzz] += (dobs[current_node] - modeling->T[index + modeling->nzz]) / cell_volume;         
        source[index + 1 + modeling->nzz] += (dobs[current_node] - modeling->T[index + 1 + modeling->nzz]) / cell_volume; 
        source[index + modeling->nxx*modeling->nzz] += (dobs[current_node] - modeling->T[index + modeling->nxx*modeling->nzz]) / cell_volume; 
        source[index + 1 + modeling->nxx*modeling->nzz] += (dobs[current_node] - modeling->T[index + 1 + modeling->nxx*modeling->nzz]) / cell_volume; 
        source[index + modeling->nzz + modeling->nxx*modeling->nzz] += (dobs[current_node] - modeling->T[index + modeling->nzz + modeling->nxx*modeling->nzz]) / cell_volume; 
        source[index + 1 + modeling->nzz + modeling->nxx*modeling->nzz] += (dobs[current_node] - modeling->T[index + 1 + modeling->nzz + modeling->nxx*modeling->nzz]) / cell_volume;     
    }

	cudaMemcpy(d_T, modeling->T, modeling->volsize*sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpy(d_source, source, modeling->volsize*sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpy(d_adjoint, adjoint, modeling->volsize*sizeof(float), cudaMemcpyHostToDevice);

    for (int sweepCount = 0; sweepCount < meshDim; sweepCount++)
    {
        for (int sweep = 0; sweep < nSweeps; sweep++)
        { 
            int start = (sweep == 3 || sweep == 5 || sweep == 6 || sweep == 7) ? totalLevels : meshDim;
            int end = (start == meshDim) ? totalLevels + 1 : meshDim - 1;
            int incr = (start == meshDim) ? true : false;

            int xSweepOff = (sweep == 3 || sweep == 4) ? modeling->nxx : 0;
            int ySweepOff = (sweep == 2 || sweep == 5) ? modeling->nyy : 0;
            int zSweepOff = (sweep == 1 || sweep == 6) ? modeling->nzz : 0;
            
            for (int level = start; level != end; level = (incr) ? level + 1 : level - 1)
            {			
                int xs = max(1, level - (modeling->nyy + modeling->nzz));	
                int ys = max(1, level - (modeling->nxx + modeling->nzz));

                int xe = min(modeling->nxx, level - (meshDim - 1));
                int ye = min(modeling->nyy, level - (meshDim - 1));	
            
                int xr = xe - xs + 1;
                int yr = ye - ys + 1;

                int nThreads = xr * yr;
                    
                dim3 bs(16, 16, 1);

                if (nThreads < modeling->threadsPerBlock) { bs.x = xr; bs.y = yr; } 

                dim3 gs(iDivUp(xr, bs.x), iDivUp(yr , bs.y), 1);

                adjoint_state_kernel<<<gs,bs>>>(d_adjoint, d_source, d_T, level, xs, ys, xSweepOff, ySweepOff, zSweepOff, 
                                                modeling->nxx, modeling->nyy, modeling->nzz, modeling->dx, modeling->dy, modeling->dz);

                cudaDeviceSynchronize();
            }
        }
    }
    
    cudaMemcpy(adjoint, d_adjoint, modeling->volsize*sizeof(float), cudaMemcpyDeviceToHost);

    for (int index = 0; index < modeling->nPoints; index++) 
    {
        int k = (int) (index / (modeling->nx*modeling->nz));        
        int j = (int) (index - k*modeling->nx*modeling->nz) / modeling->nz;    
        int i = (int) (index - j*modeling->nz - k*modeling->nx*modeling->nz);  

        int indp = (i + modeling->nbzu) + (j + modeling->nbxl)*modeling->nzz + (k + modeling->nbyl)*modeling->nxx*modeling->nzz;

        gradient[index] += adjoint[indp]*modeling->T[indp]*modeling->S[indp]*modeling->S[indp]*cell_volume / modeling->total_shots;
    }
}

void Adjoint_State::gradient_preconditioning()
{       
    if (smooth)
    { 
        int aux_nx = modeling->nx + 2*smoother_samples;
        int aux_ny = modeling->ny + 2*smoother_samples;
        int aux_nz = modeling->nz + 2*smoother_samples;

        int aux_nPoints = aux_nx*aux_ny*aux_nz;

        float * grad_aux = new float[aux_nPoints]();
        float * grad_smooth = new float[aux_nPoints]();

        for (int index = 0; index < modeling->nPoints; index++)
        {
            int k = (int) (index / (modeling->nx*modeling->nz));        
            int j = (int) (index - k*modeling->nx*modeling->nz) / modeling->nz;    
            int i = (int) (index - j*modeling->nz - k*modeling->nx*modeling->nz);          

            int ind_filt = (i + smoother_samples) + (j + smoother_samples)*aux_nz + (k + smoother_samples)*aux_nx*aux_nz;

            grad_aux[ind_filt] = gradient[i + j*modeling->nz + k*modeling->nx*modeling->nz];
        }

        smooth_volume(grad_aux, grad_smooth, aux_nx, aux_ny, aux_nz);

        for (int index = 0; index < modeling->nPoints; index++)
        {
            int k = (int) (index / (modeling->nx*modeling->nz));        
            int j = (int) (index - k*modeling->nx*modeling->nz) / modeling->nz;    
            int i = (int) (index - j*modeling->nz - k*modeling->nx*modeling->nz);          

            int ind_filt = (i + smoother_samples) + (j + smoother_samples)*aux_nz + (k + smoother_samples)*aux_nx*aux_nz;

            gradient[i + j*modeling->nz + k*modeling->nx*modeling->nz] = grad_smooth[ind_filt];
        }
    
        delete[] grad_aux;
        delete[] grad_smooth;
    }

    float gmax = 0.0f;
    for (int index = 0; index < modeling->nPoints; index++)
    {
        if (gmax < fabsf(gradient[index]))
            gmax = fabsf(gradient[index]);
    }

    for (int index = 0; index < modeling->nPoints; index++)
        gradient[index] = (max_slowness_variation / gmax) * gradient[index];
}

void Adjoint_State::optimization()  
{
    float a1 = 0.0f;
    float a2 = 0.4f; // 0.2
    float a3 = 0.9f; // 0.6

    float f1 = residuo.back();
    float f2 = objective_function(a2);
    float f3 = objective_function(a3);

    float Dt = (a2*a3*a3 + a1*a2*a2 + a1*a1*a3) - (a2*a2*a3 + a1*a3*a3 + a1*a1*a2);
    float Db = (f2*a3*a3 + f1*a2*a2 + f3*a1*a1) - (f1*a3*a3 + f3*a2*a2 + a1*a1*f2);
    float Dc = (a2*f3 + a1*f2 + f1*a3) - (f2*a3 + a1*f3 + a2*f1);

    float b = Db/Dt;
    float c = Dc/Dt;

    float alpha = -0.5*b/c;

    if (alpha > 1.0f) alpha = 1.0f;
    if (alpha < 0.0f) alpha = 0.1f; 

    for (int index = 0; index < modeling->nPoints; index++)
        dm[index] = alpha*gradient[index];

    max_slowness_variation *= powf(0.85f, static_cast<float>(iteration)); // 0.9    
}

float Adjoint_State::objective_function(float alpha)
{
    for (int index = 0; index < modeling->nPoints; index++)    
        proposed_model[index] = model[index] + alpha*gradient[index];

    modeling->expand_boundary(proposed_model, modeling->S);
    
    for (int shot = 0; shot < modeling->total_shots; shot++)
    {
        modeling->shot_id = shot;

        modeling->initial_setup();
        modeling->forward_solver();
        modeling->build_outputs();

        extract_calculated_data();
    }

    float square_difference = 0.0f;
    for (int i = 0; i < n_data; i++)
        square_difference += powf(dobs[i] - dcal[i], 2.0f);

    return sqrtf(square_difference);
}


__global__ void adjoint_state_kernel(float * adjoint, float * source, float * T, int level, int xOffset, int yOffset, int xSweepOffset, int ySweepOffset, 
                                     int zSweepOffset, int nxx, int nyy, int nzz, float dx, float dy, float dz)
{
	int x = (blockIdx.x * blockDim.x + threadIdx.x) + xOffset;
	int y = (blockIdx.y * blockDim.y + threadIdx.y) + yOffset;

	if ((x < nxx) && (y < nyy)) 
	{
		int z = level - (x + y);
		
		if ((z >= 0) && (z < nzz))	
		{
			int i = (int)abs(z - zSweepOffset);
			int j = (int)abs(x - xSweepOffset);
			int k = (int)abs(y - ySweepOffset);

            if ((i > 0) && (i < nzz - 1) && (j > 0) && (j < nxx - 1) && (k > 0) && (k < nyy - 1))
            {
                float a1 = -1.0f*(T[i + j*nzz + k*nxx*nzz] - T[i + (j-1)*nzz + k*nxx*nzz]) / dx;                                                
                float ap1 = (a1 + abs(a1)) / 2.0f;
                float am1 = (a1 - abs(a1)) / 2.0f;

                float a2 = -1.0f*(T[i + (j+1)*nzz + k*nxx*nzz] - T[i + j*nzz + k*nxx*nzz]) / dx;
                float ap2 = (a2 + abs(a2)) / 2.0f;
                float am2 = (a2 - abs(a2)) / 2.0f;

                float b1 = -1.0f*(T[i + j*nzz + k*nxx*nzz] - T[i + j*nzz + (k-1)*nxx*nzz]) / dy;
                float bp1 = (b1 + abs(b1)) / 2.0f;
                float bm1 = (b1 - abs(b1)) / 2.0f;

                float b2 = -1.0f*(T[i + j*nzz + (k+1)*nxx*nzz] - T[i + j*nzz + k*nxx*nzz]) / dy;
                float bp2 = (b2 + abs(b2)) / 2.0f;
                float bm2 = (b2 - abs(b2)) / 2.0f;

                float c1 = -1.0f*(T[i + j*nzz + k*nxx*nzz] - T[(i-1) + j*nzz + k*nxx*nzz]) / dz;
                float cp1 = (c1 + abs(c1)) / 2.0f;
                float cm1 = (c1 - abs(c1)) / 2.0f;

                float c2 = -1.0f*(T[(i+1) + j*nzz + k*nxx*nzz] - T[i + j*nzz + k*nxx*nzz]) / dz;        
                float cp2 = (c2 + abs(c2)) / 2.0f;
                float cm2 = (c2 - abs(c2)) / 2.0f;

                float d = (ap2 - am1)/dx + (bp2 - bm1)/dy + (cp2 - cm1)/dz;

                if (fabsf(d) < 1e-6f)
                {
                    adjoint[i + j*nzz + k*nxx*nzz] = 0.0f;    
                }
                else
                {
                    float e = (ap1*adjoint[i + (j-1)*nzz + k*nxx*nzz] - am2*adjoint[i + (j+1)*nzz + k*nxx*nzz]) / dx +
                              (bp1*adjoint[i + j*nzz + (k-1)*nxx*nzz] - bm2*adjoint[i + j*nzz + (k+1)*nxx*nzz]) / dy +
                              (cp1*adjoint[(i-1) + j*nzz + k*nxx*nzz] - cm2*adjoint[(i+1) + j*nzz + k*nxx*nzz]) / dz;

                    float f = (e + source[i + j*nzz + k*nxx*nzz]) / d;

                    if (adjoint[i + j*nzz + k*nxx*nzz] > f) 
                        adjoint[i + j*nzz + k*nxx*nzz] = f;
                }
            }
        }
    }
}
