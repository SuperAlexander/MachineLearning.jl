abstract DecisionNode

type DecisionTreeOptions

end

type DecisionLeaf <: DecisionNode
    probs::Vector{Float64}
end

type DecisionBranch <: DecisionNode
    feature::Int
    value::Float64
    left::DecisionNode
    right::DecisionNode
end

type DecisionTree
    root::DecisionNode
    classes::Vector
    options::DecisionTreeOptions
end

function train(x::Array{Float64,2}, y::Vector, opts::DecisionTreeOptions)
    classes = sort(unique(y))
    classes_map = Dict(classes, 1:length(classes))
    y_mapped = [classes_map[v] for v=y]
    DecisionTree(train_branch(x, y_mapped, length(classes)), classes, opts)
end

function train_branch(x::Array{Float64,2}, y::Vector{Int}, num_classes::Int)
    if length(y)<=1
        probs = zeros(num_classes)
        for i=1:length(y)
            probs[y[i]] += 1.0/length(y)
        end
        return DecisionLeaf(probs)
    end

    score        = Inf
    best_feature = 1
    split_loc    = 1
    for feature = 1:size(x,2)
        i_sorted = sortperm(x[:,feature])
        g, loc = split_location(y[i_sorted], num_classes)
        if g<score 
            score        = g
            best_feature = feature
            split_loc    = loc
        end
    end
    i_sorted   = sortperm(x[:,best_feature])
    left_locs  = i_sorted[1:split_loc]
    right_locs = i_sorted[split_loc+1:length(i_sorted)]
    left       = train_branch(x[left_locs, :], y[left_locs],  num_classes)
    right      = train_branch(x[right_locs,:], y[right_locs], num_classes)
    DecisionBranch(best_feature, x[i_sorted[split_loc], best_feature], left, right)
end

function split_location(y::Vector{Int}, num_classes::Int)
    counts_left  = zeros(num_classes)
    counts_left[y[1]]=1
    counts_right = zeros(num_classes)
    for i=2:length(y)
        counts_right[y[i]]+=1
    end
    loc   = 1
    score = gini(counts_left)+gini(counts_right)
    for i=2:length(y)-1
        counts_left[y[i]]+=1
        counts_right[y[i]]-=1
        g = gini(counts_left)+gini(counts_right)
        if g<score
            score = g
            loc   = i
        end
    end
    score, loc
end

function gini(counts::Vector{Float64})
    1-sum((counts/sum(counts)).^2)
end

function predict_probs(tree::DecisionTree, sample::Vector{Float64})
    node = tree.root
    while typeof(node)==DecisionBranch
        if sample[node.feature]<=node.value
            node=node.left
        else
            node=node.right
        end
    end
    node.probs
end

function predict_probs(tree::DecisionTree, samples::Array{Float64, 2})
    probs = Array(Float64, size(samples, 1), length(tree.classes))
    for i=1:size(samples, 1)
        probs[i,:] = predict_probs(tree, vec(samples[i,:]))
    end
    probs
end

function predict(tree::DecisionTree, sample::Vector{Float64})
    probs = predict_probs(tree, sample)
    tree.classes[minimum(find(x->x==maximum(probs), probs))]
end

function predict(tree::DecisionTree, samples::Array{Float64, 2})
    [predict(tree, vec(samples[i,:])) for i=1:size(samples,1)]
end