function cluster = clusterBAdist(cluster, clustRange)

for i = clustRange
   cluster(i).BAdist =  unique(cluster(i).BA);
    for j = cluster(i).BAdist
       cluster(i).BAdist(2,j==cluster(i).BAdist(1,:)) = length(find(cluster(i).BA == j));       
    end
    cluster(i).BAdist(2,cluster(i).BAdist(1,:)==cluster(i).BA(end)) = ...
        cluster(i).BAdist(2,cluster(i).BAdist(1,:)==cluster(i).BA(end)) - 1; % removes a exess isntance that accounts for the BA of the centroid.    
end