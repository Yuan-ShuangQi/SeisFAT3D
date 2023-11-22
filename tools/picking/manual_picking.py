import numpy as np
import segyio as sgy
import matplotlib as mpl
import matplotlib.pyplot as plt

mpl.use("Qt5Agg")

from sys import argv
from matplotlib.widgets import Cursor
from scipy.interpolate import interp1d

def catch_parameter(filename, target):
    file = open(filename,'r')
    for line in file.readlines():
        if line[0] != '#':
            splitted = line.split()
            if len(splitted) != 0:
                if splitted[0] == target: 
                    return splitted[2]

class Pick():
    def __init__(self):
        self.x = np.array([])
        self.t = np.array([])

class ManualPicking(Pick):
    
    def __init__(self, data_path, gain):
        
        self.gain = gain

        self.data = sgy.open(data_path, ignore_geometry = True)

        self.traces = [self.data.attributes(13)[self.data.tracecount-1][0]]

        self.nt = self.data.attributes(115)[0][0]
        self.dt = self.data.attributes(117)[0][0] * 1e-6

        self.sx = self.data.attributes(73)[:] * 1e-5
        self.sy = self.data.attributes(77)[:] * 1e-5

        self.gx = self.data.attributes(81)[:] * 1e-5
        self.gy = self.data.attributes(85)[:] * 1e-5

        self.seismic = self.data.trace.raw[:].T

        self.picks = []
        self.gathers = []

        for i in range(len(self.traces)):
            self.picks.append(Pick())
            self.gathers.append(self.seismic[:,sum(self.traces[:i]):sum(self.traces[:i+1])])

        self.current_plot = 0

        for i in range(len(self.traces)):
            while True:
                if self.current_plot == i:
                    print("Close plot windows to interpolate picks")
                    self.plot_figures()
                    self.interpolation()
                    self.plot_figures()

                    self.entry = str(input("Continue picking? (y or n) "))
                    if self.entry in "nN":
                        self.save_picks()
                        break

            self.current_plot += 1

    def plot_geometry(self):
        
        fig, ax = plt.subplots(dpi = 100, tight_layout = True)        
        manager = plt.get_current_fig_manager()
        manager.window.setGeometry(0,0,500,500) 

        ax.plot(self.gx, self.gy, "ob", markersize = 1, alpha = 0.6, label = "Nodes position")

        for i in range(len(self.traces)):
            if self.current_plot == i:
                trace_slicer = slice(sum(self.traces[:i]), sum(self.traces[:i+1]))
                ax.plot(self.gx[trace_slicer], self.gy[trace_slicer], "og", markersize = 3, label = "Active gather")

        ax.plot(self.sx, self.sy, "or", markersize = 5, label = "Shots position")

        ax.set_title("Acquisition Geometry")
        ax.set_xlabel("UTM E [km]")
        ax.set_ylabel("UTM N [km]")
        ax.legend(loc = "lower left")
        
        fig.tight_layout()

    def plot_seismic(self):

        self.fig, self.ax = plt.subplots(dpi = 100, tight_layout = True)

        tloc = np.linspace(0, self.nt, 21)
        tlab = np.around(tloc*self.dt, decimals = 2)

        manager = plt.get_current_fig_manager()
        manager.window.setGeometry(600,0,1200,900) 
        
        self.cursor = Cursor(self.ax, horizOn = True, vertOn = True, color = "green", linewidth = 1)

        self.ax.set_title(f"Gather {self.current_plot+1}")
        self.ax.set_xlabel("Shot index")
        self.ax.set_ylabel("Time [s]")

        for i in range(len(self.traces)):
            if self.current_plot == i:
                
                scale = self.gain * np.std(self.gathers[i])
                
                self.ax.imshow(self.gathers[i], aspect = "auto", cmap = "Greys", vmin = -scale, vmax = scale)
                self.ax.plot(self.picks[i].x, self.picks[i].t, "or")

                self.ax.set_yticks(tloc)
                self.ax.set_yticklabels(tlab)

                xloc = np.linspace(0, self.traces[i]-1, 9, dtype = int)
                xlab = np.linspace(1, self.traces[i], 9, dtype = int)

                self.ax.set_xticks(xloc)
                self.ax.set_xticklabels(xlab)

                self.fig.tight_layout()

                self.fig.canvas.mpl_connect("key_press_event", self.pick_data)

    def pick_data(self, event):

        for i in range(len(self.traces)):
            if self.current_plot == i:

                if event.key == "t":
                    self.picks[i].x = np.append(self.picks[i].x, np.abs(int(event.xdata)))
                    self.picks[i].t = np.append(self.picks[i].t, event.ydata)       

                    print(f"Pick (x,t) = ({self.picks[i].x[-1]:.0f}, {self.picks[i].t[-1]*self.dt:.3f}) picked")

                elif event.key == "d":
                    
                    print(f"Pick (x,t) = ({self.picks[i].x[-1]:.0f}, {self.picks[i].t[-1]*self.dt:.3f}) deleted")

                    self.picks[i].x = self.picks[i].x[:-1]
                    self.picks[i].t = self.picks[i].t[:-1]    
                    
                self.ax.plot(self.picks[i].x, self.picks[i].t, "or")
    
    def plot_figures(self):
        plt.close("all")
        self.plot_seismic()
        self.plot_geometry()
        plt.show()

    def interpolation(self):
        for i in range(len(self.traces)):
            
            if len(self.picks[i].x) < 3:
                return None
            
            if self.current_plot == i:
                
                x = np.arange(np.min(self.picks[i].x), np.max(self.picks[i].x) + 1)        

                f = interp1d(self.picks[i].x, self.picks[i].t, kind = "slinear")

                t = f(x)

                self.picks[i].x = x.copy()
                self.picks[i].t = t.copy()

    def save_picks(self):
        # if style == "3D":
        #     output_file = f"{self.picks_path}_shotGather_3D.txt"
        # else:
        output_file = f"{self.picks_path}_shotGather_{self.current_plot+1}.txt"

        with open(output_file, "a") as file:
            for i in range(len(self.traces)):
                if self.current_plot == i:
                    for n in range(len(self.picks[i].x)):
                        file.write(f"{self.picks[i].x[n] + sum(self.traces[:i]):.0f}, {self.picks[i].t[n] * self.dt:.3f}\n")            
        
        file.close()

#---------------------------------------------------------------------

file = argv[1]

data_folder = catch_parameter(file, "obs_data_folder")
data_prefix = catch_parameter(file, "obs_data_prefix")

data_gain = 0.1

ManualPicking(data_folder + data_prefix + "1.segy", data_gain)

