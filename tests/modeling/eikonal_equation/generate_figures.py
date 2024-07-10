import numpy as np
import matplotlib.pyplot as plt

from sys import path
path.append("../src/")
import functions

#-------------------------------------------------------------------------

nx = 881
ny = 881
nz = 201

dx = 25
dy = 25
dz = 25

model = functions.read_binary_volume(nz, nx, ny, f"../inputs/models/testModel_{nz}x{nx}x{ny}_{dx}m.bin")

shots_file = "../inputs/geometry/xyz_shots_position.txt"
nodes_file = "../inputs/geometry/xyz_nodes_position.txt"

slices = np.array([nz/2, nx/2, ny/2], dtype = int)
dh = np.array([dx, dy, dz])

travel_time_volume = functions.read_binary_volume(nz, nx, ny, "../outputs/snapshots/fim_time_volume_201x881x881_shot_1.bin")

functions.plot_model_3D(model, dh, slices,
                        eikonal = travel_time_volume,
                        shots = shots_file, 
                        nodes = nodes_file,
                        scale = 2.8,
                        adjx = 0.75,
                        dbar = 1.60)

plt.savefig(f"vp_model_eikonal_equation_test.png", dpi = 200)

#-------------------------------------------------------------------------

shots = np.loadtxt(nodes_file, delimiter = ',')
nodes = np.loadtxt(shots_file, delimiter = ',')  

v = np.array([1500, 2000, 3000, 4000])
z = np.array([1000, 1500, 2000])

x = np.sqrt((nodes[:,0] - shots[0])**2 + (nodes[:,1] - shots[1])**2)

refractions = functions.get_analytical_refractions(v, z, x)
direct_wave = x / v[0]

fba = np.zeros(len(x))

for i in range(len(x)):
    fba[i] = np.min([direct_wave[i], refractions[0,i], refractions[1,i], refractions[2,i]])

n = len(nodes)

dh = np.array([100, 50, 25], dtype = int)

pod = np.zeros((len(dh), n))
fim = np.zeros((len(dh), n))
fsm = np.zeros((len(dh), n))

for i in range(len(dh)):
    
    pod[i] = np.fromfile(f"../outputs/seismograms/{dh[i]}m_pod_data_nRec1256_shot_1.bin", dtype = np.float32, count = n)
    fim[i] = np.fromfile(f"../outputs/seismograms/{dh[i]}m_fim_data_nRec1256_shot_1.bin", dtype = np.float32, count = n)
    fsm[i] = np.fromfile(f"../outputs/seismograms/{dh[i]}m_fsm_data_nRec1256_shot_1.bin", dtype = np.float32, count = n)

offset = np.arange(n)

colors = ["blue", "orange", "green"]
styles = ["dashed", "dotted", "solid"]
titles = ["Podvin & Lecomte (1991)", "Jeong & Whitaker (2008)", "Detrixhe et al. (2013) | Noble et al. (2014)"]

xloc = np.linspace(0, n, 11, dtype = int)

fig, ax = plt.subplots(nrows = 3, ncols = 2, figsize = (15,8))

ax[0,0].plot(fba, color = "black")
ax[1,0].plot(fba, color = "black")
ax[2,0].plot(fba, color = "black")

for k in range(len(dh)):
    ax[0,0].plot(offset, pod[k], linestyle = styles[k], color = colors[0])
    ax[1,0].plot(offset, fim[k], linestyle = styles[k], color = colors[1])
    ax[2,0].plot(offset, fsm[k], linestyle = styles[k], color = colors[2])
    ax[0,1].plot(offset, fba - pod[k], linestyle = styles[k], color = colors[0])
    ax[1,1].plot(offset, fba - fim[k], linestyle = styles[k], color = colors[1])
    ax[2,1].plot(offset, fba - fsm[k], linestyle = styles[k], color = colors[2])

    for i in range(len(dh)):
        ax[i,0].set_xlabel("Trace index", fontsize= 15)
        ax[i,0].set_ylabel("Time [s]", fontsize = 15)
        ax[i,0].set_title(titles[i], fontsize = 18)

        ax[i,1].set_xlabel("Trace index", fontsize = 15)
        ax[i,1].set_ylabel("Diff = Ta - Tn [s]", fontsize = 15)
        ax[i,1].set_title(titles[i], fontsize = 18)

    for i in range(2):
        ax[k,i].set_xticks(xloc)
        ax[k,i].set_xticklabels(xloc)
        ax[k,i].set_xlim([0,n])

    ax[k,0].set_ylim([5.6, 6.4])
    ax[k,0].invert_yaxis()

plt.tight_layout()
plt.savefig(f"eikonal_equation_accuracy_test.png", dpi = 200)

#-------------------------------------------------------------------------

benchmark = np.loadtxt("elapsedTime.txt", delimiter = ";", comments = "#")

bench_pod = benchmark[:3]
bench_fim = benchmark[3:6]
bench_fsm = benchmark[6:]

yaxis = ["Elapsed time [s]", "RAM usage [MB]", "GPU memory usage [MB]"]

xloc = [0, 1, 2]
xlab = ["2.9", "19.6", "156.1"]

fig, ax = plt.subplots(nrows = 3,ncols = 1, figsize = (10,9))

for i in range(len(dh)):
    ax[i].plot(bench_pod[:,i], "o--", label = "Podvin & Lecomte (1991)")
    ax[i].plot(bench_fim[:,i], "o--", label = "Jeong & Whitaker (2008)")
    ax[i].plot(bench_fsm[:,i], "o--", label = "Detrixhe et al. (2013) | Noble et al. (2014)")

    ax[i].set_xticks(xloc)
    ax[i].set_xticklabels(xlab)

    ax[i].legend(loc = "upper left")
    ax[i].set_ylabel(yaxis[i], fontsize = 15)
    ax[i].set_xlabel("Total samples in model [x 10⁶]", fontsize = 15)

plt.tight_layout()
plt.savefig(f"eikonal_equation_benchmark_test.png", dpi = 200)
