function totalDistance = graphPathDistance(nodePathIds, graphData)
totalDistance = 0;
if numel(nodePathIds) < 2
    return;
end

for p = 1:(numel(nodePathIds) - 1)
    fromId = nodePathIds(p);
    toId = nodePathIds(p + 1);
    fromIdx = graphData.idToIndexMap(fromId);
    neighbors = graphData.neighborsByIndex{fromIdx};
    weights = graphData.neighborWeightsByIndex{fromIdx};
    neighborPos = find(neighbors == toId, 1);
    if isempty(neighborPos)
        continue;
    end
    totalDistance = totalDistance + weights(neighborPos);
end
end
