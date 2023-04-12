# include <cmath>

# include "circular.hpp"

void Circular::set_geometry(std::string file)
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
        spacing = std::stof(catch_parameter("spacing", file));    
        splitted = split(catch_parameter("center", file), ',');

        zc = std::stof(splitted[0]);
        xc = std::stof(splitted[1]);
        yc = std::stof(splitted[2]);

        splitted = split(catch_parameter("offsets", file), ',');
        for (auto key : splitted) offsets.push_back(std::stof(key));    

        splitted = split(catch_parameter("nodes_nlines", file), ',');
        for (auto key : splitted) nlines.push_back(std::stoi(key));

        splitted = split(catch_parameter("nodes_SW", file), ',');
        for (auto key : splitted) SW.push_back(std::stof(key));

        splitted = split(catch_parameter("nodes_NW", file), ',');
        for (auto key : splitted) NW.push_back(std::stof(key));

        splitted = split(catch_parameter("nodes_SE", file), ',');
        for (auto key : splitted) SE.push_back(std::stof(key));
    
        set_circular();    
        set_regular(nodes);    

        if (reciprocity) 
            set_reciprocity();

        set_relational();
        export_coordinates();

        std::vector<std::string>().swap(splitted); 
    }    
}

void Circular::set_circular()
{
    std::vector<float> X, Y;

    shots.total = 0;

    for (float radius : offsets)
    {
        float theta = 0.0f;

        while (theta < 2.0f * 4.0f*atan(1.0f))
        {            
            X.push_back(radius*sin(theta) + xc);        
            Y.push_back(radius*cos(theta) + yc);        

            theta += acos(1.0f - powf(spacing, 2.0f) / (2.0f * powf(radius, 2.0f)));    

            shots.total += 1;
        }
    }

    shots.x = new float[shots.total]();
    shots.y = new float[shots.total]();
    shots.z = new float[shots.total]();

    for (int i = 0; i < shots.total; i++)
    {
        shots.x[i] = X[i]; 
        shots.y[i] = Y[i];
        shots.z[i] = zc;
    }

    std::vector<float>().swap(X);
    std::vector<float>().swap(Y);
    std::vector<float>().swap(offsets);
}

void Circular::set_relational()
{
    beg_relation = new int[shots.total]();
    end_relation = new int[shots.total]();

    for (int shot = 0; shot < shots.total; shot++)
    {
        beg_relation[shot] = 0;
        end_relation[shot] = nodes.total;
    }
}