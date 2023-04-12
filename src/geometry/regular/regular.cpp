# include "regular.hpp"

void Regular::set_geometry(std::string file)
{
    reciprocity = str2bool(catch_parameter("reciprocity", file));
    import_geometry = str2bool(catch_parameter("import_geometry", file));

    shots_file = catch_parameter("shots_file", file);
    nodes_file = catch_parameter("nodes_file", file);
    relational = catch_parameter("relational", file);

    if (import_geometry) 
    {
        import_coordinates();
    }
    else
    {
        std::vector<std::string> names = {"shots", "nodes"};
    
        for (auto name : names)
        {
            splitted = split(catch_parameter(name + "_nlines", file), ',');
            for (auto key : splitted) nlines.push_back(std::stoi(key));

            splitted = split(catch_parameter(name + "_SW", file), ',');
            for (auto key : splitted) SW.push_back(std::stof(key));

            splitted = split(catch_parameter(name + "_NW", file), ',');
            for (auto key : splitted) NW.push_back(std::stof(key));

            splitted = split(catch_parameter(name + "_SE", file), ',');
            for (auto key : splitted) SE.push_back(std::stof(key));

            if (name == std::string("shots")) set_regular(shots);
            if (name == std::string("nodes")) set_regular(nodes);
        }

        if (reciprocity) 
            set_reciprocity();

        set_relational();
        export_coordinates();
    }   
}

void Regular::set_relational()
{
    beg_relation = new int[shots.total]();
    end_relation = new int[shots.total]();

    for (int shot = 0; shot < shots.total; shot++)
    {
        beg_relation[shot] = 0;
        end_relation[shot] = nodes.total;
    }
}


