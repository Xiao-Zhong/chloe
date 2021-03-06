include("Utilities.jl")
include("Annotations.jl")

function mergeAdjacentFeaturesinModel!(genome_id, genome_length, strand, model::Array{Feature,1})
    f1_pointer = 1
    f2_pointer = 2
    while f2_pointer <= length(model)
        f1 = model[f1_pointer]
        f2 = model[f2_pointer]
        # if adjacent features are same type, merge them into a single feature
        if getFeatureType(f1) == getFeatureType(f2)
            f1.length += f2.length
            deleteat!(model, f2_pointer)
        else
            f1_pointer += 1
            f2_pointer += 1
        end
    end
    return FeatureArray(genome_id, genome_length, strand, model)
end

function writeGFF3(outfile, genemodel::FeatureArray)
    features = genemodel.features
    path_components = split(first(features).path, '/')
    id = path_components[1]
    if parse(Int, path_components[2]) > 1
        id = id * "-" * path_components[2]
    end
    parent = id
    start = first(features).start
    finish = last(features).start + last(features).length - 1
    length = finish - start + 1
    if genemodel.strand == '-'
        start = genemodel.genome_length - finish + 1
        if start < 1
            start += genemodel.genome_length
        end
        finish = start + length - 1
    end
    # gene
    write(outfile, join([genemodel.genome,"Chloe","gene",start,finish], "\t"))
    write(outfile, "\t", ".", "\t", genemodel.strand, "\t", ".", "\t", "ID=", id, ";Name=", split(first(features).path, '/')[1], "\n")
    # RNA product
    if getFeatureType(first(features)) == "CDS"
        write(outfile, join([genemodel.genome,"Chloe","mRNA",start,finish], "\t"))
        parent = id * ".mRNA"
        write(outfile, "\t", ".", "\t", genemodel.strand, "\t", ".", "\t", "ID=", parent, ";Parent=", id, "\n")
    elseif getFeatureType(first(features)) == "rRNA"
        write(outfile, join([genemodel.genome,"Chloe","rRNA",start,finish], "\t"))
        parent = id * ".rRNA"
        write(outfile, "\t", ".", "\t", genemodel.strand, "\t", ".", "\t", "ID=", id, parent, ";Parent=", id, "\n")
    elseif getFeatureType(first(features)) == "tRNA"
        write(outfile, join([genemodel.genome,"Chloe","tRNA",start,finish], "\t"))
        parent = id * ".tRNA"
        write(outfile, "\t", ".", "\t", genemodel.strand, "\t", ".", "\t", "ID=", parent, ";Parent=", id, "\n")
    end
    if genemodel.strand == '+'
        for feature in features
            type = getFeatureType(feature)
            if type == "tRNA" || type == "rRNA"
                type = "exon"
            end
            start = feature.start
            finish = feature.start + feature.length - 1
            length = finish - start + 1
            phase = ifelse(type == "CDS", string(feature.phase), ".")
            write(outfile, join([genemodel.genome,"Chloe",type,start,finish], "\t"))
            write(outfile, "\t", ".", "\t", genemodel.strand, "\t", phase, "\t", "ID=", feature.path, ";Parent=", parent, "\n")
        end
    else
        for feature in Iterators.reverse(features)
            type = getFeatureType(feature)
            if type == "tRNA" || type == "rRNA"
                type = "exon"
            end
            start = feature.start
            finish = feature.start + feature.length - 1
            length = finish - start + 1
            start = genemodel.genome_length - finish + 1
            if start < 1
                start += genemodel.genome_length
            end
            finish = start + length - 1
            phase = ifelse(type == "CDS", string(feature.phase), ".")
            write(outfile, join([genemodel.genome,"Chloe",type,start,finish], "\t"))
            write(outfile, "\t", ".", "\t", genemodel.strand, "\t", phase, "\t", "ID=", feature.path, ";Parent=", parent, "\n")
        end
    end
    write(outfile, "###\n")
end

for infile in ARGS
    fstrand_features, rstrand_features = readFeatures(infile)
    # for each strand
    # group into gene models
    fstrand_models = groupFeaturesIntoGeneModels(fstrand_features)
    models_as_feature_arrays = Array{FeatureArray}(undef, 0)
    for model in fstrand_models
        push!(models_as_feature_arrays, mergeAdjacentFeaturesinModel!(fstrand_features.genome, fstrand_features.genome_length, '+', model))
    end

    rstrand_models = groupFeaturesIntoGeneModels(rstrand_features)
    for model in rstrand_models
        push!(models_as_feature_arrays, mergeAdjacentFeaturesinModel!(fstrand_features.genome, fstrand_features.genome_length, '-', model))
    end

    # interleave gene models from both strands
    sort!(models_as_feature_arrays, by = m->m.features[1].start)

    # write models in GFF3 format
    open(fstrand_features.genome * ".gff3", "w") do outfile
        write(outfile, "##gff-version 3.2.1\n")
        for model in models_as_feature_arrays
            writeGFF3(outfile, model)
        end
    end
end
