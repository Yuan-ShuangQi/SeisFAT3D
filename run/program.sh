#!/bin/bash

io="../src/utils/input_output/io.cpp"

geometry="../src/geometry/geometry.cpp"
regular="../src/geometry/regular/regular.cpp"
circular="../src/geometry/circular/circular.cpp"

modeling="../src/modeling/modeling.cpp"

eikonal="../src/modeling/eikonal_equation/eikonal.cpp"
pod="../src/modeling/eikonal_equation/podvin_and_lecomte/podvin_and_lecomte.cu"
fsm="../src/modeling/eikonal_equation/fast_sweeping_method/fast_sweeping_method.cu"
fim="../src/modeling/eikonal_equation/fast_iterative_method/fast_iterative_method.cu"

wave="../src/modeling/wave_equation/wave.cu"
scalar="../src/modeling/wave_equation/scalar/scalar.cpp"
scalar_iso="../src/modeling/wave_equation/scalar/fdm_isotropic/scalar_isotropic.cu"
acoustic="../src/modeling/wave_equation/acoustic/acoustic.cpp"
acoustic_iso="../src/modeling/wave_equation/acoustic/fdm_isotropic/acoustic_isotropic.cu"
elastic="../src/modeling/wave_equation/elastic/elastic.cpp"
elastic_iso="../src/modeling/wave_equation/elastic/fdm_isotropic/elastic_isotropic.cu"

modeling_main="../src/main/modeling_main.cpp"

# inversion="../src/inversion/inversion.cu"
# inversion_main="../src/main/inversion_main.cpp"

# migration="../src/migration/migration.cpp"
# kirchhoff="../src/migration/kirchhoff/kirchhoff.cpp"
# migration_main="../src/main/migration_main.cpp"

geometry_all="$geometry $regular $circular"

eikonal_all="$eikonal $pod $fim $fsm"
wave_all="$wave $scalar $scalar_iso $acoustic $acoustic_iso $elastic $elastic_iso"

modeling_all="$modeling $eikonal_all $wave_all $modeling_main"

flags="-Xcompiler=-fopenmp --std=c++11 --relocatable-device-code=true -lm -O3"

USER_MESSAGE="
Usage:\n
    $ $0 -compile        # Create executables 
    $ $0 -modeling       # Perform eikonal solver          
    $ $0 -inversion      # Perform adjoint-state tomography
    $ $0 -migration      # Perform kirchhoff depth migration   
"

[ -z "$1" ] && 
{
	echo -e "\nYou didn't provide any parameter!" 
	echo -e "Type $0 -help for more info\n"
    exit 1 
}

case "$1" in

-h) 

	echo -e "$USER_MESSAGE"
	exit 0
;;

-compile) 

    echo -e "Compiling the stand-alone executables!\n"

    echo -e "../bin/\033[31mmodeling.exe\033[m" 
    nvcc $io $geometry_all $modeling_all $flags -o ../bin/modeling.exe

    # echo -e "../bin/\033[31minversion.exe\033[m" 
    # nvcc $io $geometry $regular $circular $modeling $inversion $inversion_main $flags -o ../bin/inversion.exe

    # echo -e "../bin/\033[31mmigration.exe\033[m"
    # nvcc $io $geometry $regular $circular $modeling $eikonal $migration $kirchhoff $migration_main $flags -o ../bin/migration.exe

	exit 0
;;

-modeling) 

    ./../bin/modeling.exe parameters.txt

	exit 0
;;

-inversion) 
    
    ./../bin/inversion.exe parameters.txt

	exit 0
;;

-migration) 
    
    ./../bin/migration.exe parameters.txt

	exit 0
;;

* ) 

	echo -e "\033[31mERRO: Option $1 unknown!\033[m"
	echo -e "\033[31mType $0 -h for help \033[m"
	
    exit 3
;;

esac
