function [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath] = runDijkstra( ...
    startNode, targetNode, graphData, animateSearch, callbacks)

numberOfNodes = height(graphData.points);
dist = inf(numberOfNodes, 1);
prevIdx = nan(numberOfNodes, 1);
visited = false(numberOfNodes, 1);

startIdx = graphData.idToIndexMap(startNode);
targetIdx = graphData.idToIndexMap(targetNode);

dist(startIdx) = 0;

pathIds = [];
visitedNodeIds = [];
operationCount = 0;
iterationCount = 0;
foundPath = false;

while true
    unvisitedIdx = find(~visited);
    if isempty(unvisitedIdx)
        break;
    end

    [minVal, localPos] = min(dist(unvisitedIdx));
    if isinf(minVal)
        break;
    end

    u = unvisitedIdx(localPos);
    visited(u) = true;
    visitedNodeIds(end + 1) = graphData.points.id(u); %#ok<AGROW>
    operationCount = operationCount + 1;
    iterationCount = iterationCount + 1;
    callbacks.updateIterationFooter(iterationCount, operationCount);

    if u == targetIdx
        foundPath = true;
        break;
    end

    neighbors = graphData.neighborsByIndex{u};
    weights = graphData.neighborWeightsByIndex{u};
    for k = 1:numel(neighbors)
        v = graphData.idToIndexMap(neighbors(k));
        if visited(v)
            continue;
        end

        alt = dist(u) + weights(k);
        if alt < dist(v)
            dist(v) = alt;
            prevIdx(v) = u;
        end
    end

    if animateSearch
        currentPath = reconstructPath(prevIdx, startIdx, u, graphData);
        if numel(currentPath) >= 2
            callbacks.drawSearchPath(currentPath);
        end
        callbacks.throttleSimulationStep();
    end
end

if foundPath
    pathIds = reconstructPath(prevIdx, startIdx, targetIdx, graphData);
else
    pathIds = [];
end

visitedCount = numel(visitedNodeIds);

end

function pathIds = reconstructPath(prevIdx, startIdx, endIdx, graphData)
idxPath = [];
cur = endIdx;
while ~isnan(cur)
    idxPath(end + 1) = cur; %#ok<AGROW>
    if cur == startIdx
        break;
    end
    cur = prevIdx(cur);
    if isempty(cur)
        break;
    end
end
idxPath = fliplr(idxPath);
pathIds = graphData.points.id(idxPath);
end
