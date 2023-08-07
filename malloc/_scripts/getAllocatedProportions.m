function [proportions, fairness_index] = getAllocatedProportions(allocationMatrix)
    num_apps = max(allocationMatrix, [], "all");
    num_allocated = zeros(1, num_apps);
    total_allocated = sum(allocationMatrix > 0, "all");
    for i = 1:num_apps
        num_allocated(i) = sum(allocationMatrix == i, "all");
    end
    proportions = num_allocated / total_allocated;
    fairness_index = (sum(num_allocated)^2) / (num_apps * sum(num_allocated.^2));
end