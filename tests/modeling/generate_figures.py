import sys; sys.path.append("../src/")

import numpy as np
import matplotlib.pyplot as plt
import functions as pyf

path_SPS = "../inputs/geometry/modeling_test_SPS.txt"
path_RPS = "../inputs/geometry/modeling_test_RPS.txt"
path_XPS = "../inputs/geometry/modeling_test_XPS.txt"

nx = 321
ny = 201
nz = 81 

dx = 25.0
dy = 25.0
dz = 25.0

model_vp = pyf.read_binary_volume(nz, nx, ny, f"../inputs/models/modeling_test_vp_model_{nz}x{nx}x{ny}_{dx:.0f}m.bin")
model_vs = pyf.read_binary_volume(nz, nx, ny, f"../inputs/models/modeling_test_vs_model_{nz}x{nx}x{ny}_{dx:.0f}m.bin")
model_rho = pyf.read_binary_volume(nz, nx, ny, f"../inputs/models/modeling_test_rho_model_{nz}x{nx}x{ny}_{dx:.0f}m.bin")

dh = np.array([dx, dy, dz])
slices = np.array([0.5*nz, 0.5*ny, 0.5*nx], dtype = int)

pyf.plot_model_3D(model_vp, dh, slices, shots = path_SPS, 
                  nodes = path_RPS, adjx = 0.8, dbar = 1.5,
                  cblab = "P wave velocity [km/s]", 
                  vmin = 1000, vmax = 3000)
plt.savefig("modeling_test_vp.png", dpi = 300)

pyf.plot_model_3D(model_vs, dh, slices, shots = path_SPS, 
                  nodes = path_RPS, adjx = 0.8, dbar = 1.5,
                  cblab = "S wave velocity [km/s]",
                  vmin = 1000, vmax = 3000)
plt.savefig("modeling_test_vs.png", dpi = 300)

pyf.plot_model_3D(model_rho, dh, slices, shots = path_SPS, 
                  nodes = path_RPS, adjx = 0.8, dbar = 1.5,
                  cblab = "Density [g/cm³]",
                  vmin = 1000, vmax = 3000)
plt.savefig("modeling_test_rho.png", dpi = 300)

nt = 5001
dt = 1e-3

ns = 4
nr = 157

xloc = np.linspace(0, nr-1, 5)
xlab = np.linspace(50, 7950, 5, dtype = int)

tloc = np.linspace(0, nt-1, 11)
tlab = np.linspace(0, (nt-1)*dt, 11)

fig, ax = plt.subplots(ncols = 4, figsize = (16,6))

for i in range(ns):
    
    eikonal = pyf.read_binary_array(nr, f"../outputs/syntheticData/eikonal_iso_nStations157_shot_{i+1}.bin")
    elastic = pyf.read_binary_matrix(nt, nr, f"../outputs/syntheticData/elastic_iso_nStations157_nSamples5001_shot_{i+1}.bin")

    scale = 0.9*np.std(elastic)

    ax[i].imshow(elastic, aspect = "auto", cmap = "Greys", vmin = -scale, vmax = scale)
    ax[i].plot(eikonal / dt, "--")

    ax[i].set_xticks(xloc)
    ax[i].set_yticks(tloc)
    ax[i].set_xticklabels(xlab)    
    ax[i].set_yticklabels(tlab)    
    ax[i].set_ylabel("Time [s]", fontsize = 15)
    ax[i].set_xlabel("Distance [m]", fontsize = 15)
    
plt.tight_layout()
plt.savefig("modeling_test_results.png", dpi = 300)

SPS = np.loadtxt(path_SPS, dtype = float, delimiter = ",")
RPS = np.loadtxt(path_RPS, dtype = float, delimiter = ",")
XPS = np.loadtxt(path_XPS, dtype = int, delimiter = ",")

eikonal_an = np.zeros(nr)

v = np.array([1500, 1700, 1900, 2300, 3000])
z = np.array([400, 400, 400, 400])

fig, ax = plt.subplots(nrows = 4, figsize = (10,7))

for i in range(ns):

    eikonal_nu = pyf.read_binary_array(nr, f"../outputs/syntheticData/eikonal_iso_nStations{nr}_shot_{i+1}.bin")

    x = np.sqrt((SPS[i,0] - RPS[XPS[i,1]:XPS[i,2],0])**2 + (SPS[i,1] - RPS[XPS[i,1]:XPS[i,2],1])**2)

    refractions = pyf.get_analytical_refractions(v,z,x)
    
    for k in range(nr):
        
        eikonal_an[k] = min(x[k]/v[0], np.min(refractions[:,k]))

    ax[i].plot(eikonal_an - eikonal_nu, "k")

    ax[i].set_ylabel("(Ta - Tn) [ms]", fontsize = 15)
    ax[i].set_xlabel("Channel index", fontsize = 15)
    
    ax[i].set_yticks(np.linspace(-0.005, 0.005, 5))
    ax[i].set_yticklabels(np.linspace(-5, 5, 5, dtype = float))

    ax[i].set_xticks(np.linspace(0, nr, 11))
    ax[i].set_xticklabels(np.linspace(0, nr, 11, dtype = int))

    ax[i].set_xlim([0, nr])

    ax[i].invert_yaxis()

fig.tight_layout()
plt.savefig("modeling_test_accuracy.png", dpi = 200)
