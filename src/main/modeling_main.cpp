# include "../modeling/podvin_and_lecomte/podvin_and_lecomte.cuh"
# include "../modeling/fast_sweeping_method/accurate_FSM.cuh"
# include "../modeling/fast_iterative_method/block_FIM.cuh"

int main(int argc, char **argv)
{
    std::vector<Modeling *> modeling = 
    {
        new Podvin_and_Lecomte(),
        new Block_FIM(),
        new Accurate_FSM(),        
    };
    
    for (int file = 0; file < argc; file++)
        std::cout<<argv[file]<<std::endl;
        


    // auto file = std::string(argv[1]);
    // auto type = std::stoi(catch_parameter("modeling_type", file));

    // modeling[type]->file = file;

    // modeling[type]->set_parameters();
    // modeling[type]->set_runtime();

    // for (int shot = 0; shot < modeling[type]->total_shots; shot++)
    // {
    //     modeling[type]->shot_id = shot;

    //     modeling[type]->info_message();
    //     modeling[type]->initial_setup();
    //     modeling[type]->forward_solver();
    //     modeling[type]->build_outputs();
    //     modeling[type]->export_outputs();
    // }

    // modeling[type]->get_runtime();
    // modeling[type]->free_space();    

    return 0;
}