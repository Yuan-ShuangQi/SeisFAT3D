## Modeling Benchmark:

### The following test was performed using a laptop with the configuration below:

* CPU: AMD Ryzen 5 2500U with Radeon Vega Mobile Gfx (8) @ 2.000GHz
* GPU: NVIDIA GeForce GTX 1050 Mobile 4GB 
* RAM: 16 GB       
___

First of all, you have to compile the code to generate the executables. Make sure you're inside the run folder.

```console
SeisFAT3D/run$ ./program -compile
```

After that, you just need to perform the test.

```console
SeisFAT3D/run$ ./program -test_modeling
```
The results will appear in .png images, as follows

### Objective: Verify cinematic and waveform in homogeneous shearless media (salt water benchmark)  

<p align="center">
  <img alt="Light" src=https://github.com/phbastosa/SeisFAT3D/assets/44127778/8fbfedb6-2b68-4ba8-bb4f-df9d8eecb054
 width="30%">
&nbsp; &nbsp; 
  <img alt="Dark" src=https://github.com/phbastosa/SeisFAT3D/assets/44127778/caae709c-1174-4f28-9190-9b82b0ddee2e width="30%">
&nbsp; &nbsp; 
  <img alt="Dark" src=https://github.com/phbastosa/SeisFAT3D/assets/44127778/5d34d7c8-e002-4246-a579-c5e9bb5ce46b width="30%">
</p>

<p align="center">
  <img alt="Light" src=https://github.com/phbastosa/SeisFAT3D/assets/44127778/eb59e94e-b5f8-4b38-8b72-f8909e368c3d width="30%">
&nbsp; &nbsp; 
  <img alt="Dark" src=https://github.com/phbastosa/SeisFAT3D/assets/44127778/69d4a009-2507-4553-a4a7-cbd0aa278bdf width="30%">
&nbsp; &nbsp; 
  <img alt="Dark" src=https://github.com/phbastosa/SeisFAT3D/assets/44127778/b8f52fdf-f782-4bab-9078-9665b18dcac5 width="30%">
</p>

Results are shown in seismograms for each isotropic media implemented

![seismograms](https://github.com/phbastosa/SeisFAT3D/assets/44127778/9c0f682c-885e-48a0-9aa2-08f91cc9b025)

### Performance analysis:

|  Type                    |  Elapsed time  | RAM usage  | GPU memory usage | 
| ------------------------ | -------------- | ---------- | ---------------- |
| Scalar isotropic media   |     84.7 s     |   543 MB   |      430 MB      | 
| Acoustic isotropic media |     91.5 s     |   543 MB   |      642 MB      | 
| Elastic isotropic media  |    387.9 s     |   543 MB   |     1384 MB      |  



