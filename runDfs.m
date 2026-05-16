function [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath] = runDfs( ...
    startNode, targetNode, graphData, animateSearch, dfsVariant, callbacks)

numberOfNodes = height(graphData.points);
visited = false(numberOfNodes, 1);
pathIds = [];
visitedNodeIds = [];
operationCount = 0;
iterationCount = 0;
foundPath = false;

stackNodeIds = startNode;
startIdx = graphData.idToIndexMap(startNode);
visited(startIdx) = true;
visitedNodeIds = startNode;
operationCount = 1;
iterationCount = 1;

callbacks.updateIterationFooter(iterationCount, operationCount);
if animateSearch
    callbacks.drawSearchPath(stackNodeIds);
    callbacks.throttleSimulationStep();
end

while ~isempty(stackNodeIds)
    currentNodeId = stackNodeIds(end);

    if currentNodeId == targetNode
        pathIds = stackNodeIds;
        foundPath = true;
        break;
    end

    [nextNodeId, hasUnvisitedNeighbor] = firstUnvisitedNeighbor( ...
        currentNodeId, visited, dfsVariant, targetNode, graphData);

    if hasUnvisitedNeighbor
        nextNodeIdx = graphData.idToIndexMap(nextNodeId);
        visited(nextNodeIdx) = true;
        stackNodeIds(end + 1) = nextNodeId; %#ok<AGROW>
        visitedNodeIds(end + 1) = nextNodeId; %#ok<AGROW>

        operationCount = operationCount + 1;
        iterationCount = iterationCount + 1;
        callbacks.updateIterationFooter(iterationCount, operationCount);

        if animateSearch
            callbacks.drawSearchPath(stackNodeIds);
            callbacks.throttleSimulationStep();
        end
    else
        stackNodeIds(end) = [];
        iterationCount = iterationCount + 1;
        callbacks.updateIterationFooter(iterationCount, operationCount);

        if animateSearch
            callbacks.drawSearchPath(stackNodeIds);
            drawnow limitrate;
        end
    end
end

visitedCount = numel(visitedNodeIds);

end

function [nextNodeId, hasUnvisitedNeighbor] = firstUnvisitedNeighbor(nodeId, visited, dfsVariant, targetNode, graphData)
nextNodeId = NaN;
hasUnvisitedNeighbor = false;

currentIdx = graphData.idToIndexMap(nodeId);
neighbors = graphData.neighborsByIndex{currentIdx};
neighborWeights = graphData.neighborWeightsByIndex{currentIdx};

if isempty(neighbors)
    return;
end

unvisitedIdx = [];
for k = 1:numel(neighbors)
    if ~visited(graphData.idToIndexMap(neighbors(k)))
        unvisitedIdx(end + 1) = k; %#ok<AGROW>
    end
end

if isempty(unvisitedIdx)
    return;
end

switch dfsVariant
    case "first"
        chosenPosition = unvisitedIdx(1);
    case "random"
        chosenPosition = unvisitedIdx(randi(numel(unvisitedIdx)));
    case "minweight"
        [~, localOrder] = sort(neighborWeights(unvisitedIdx), "ascend");
        chosenPosition = unvisitedIdx(localOrder(1));
    case "closest"
        if ~isKey(graphData.idToIndexMap, targetNode)
            chosenPosition = unvisitedIdx(1);
        else
            targetIdx = graphData.idToIndexMap(targetNode);
            targetLat = graphData.points.lat(targetIdx);
            targetLon = graphData.points.lon(targetIdx);
            distances = zeros(1, numel(unvisitedIdx));
            for u = 1:numel(unvisitedIdx)
                neighIdx = graphData.idToIndexMap(neighbors(unvisitedIdx(u)));
                distances(u) = geoDistanceMeters( ...
                    graphData.points.lat(neighIdx), graphData.points.lon(neighIdx), ...
                    targetLat, targetLon);
            end
            [~, order] = sort(distances, "ascend");
            chosenPosition = unvisitedIdx(order(1));
        end
    otherwise
        chosenPosition = unvisitedIdx(1);
end

nextNodeId = neighbors(chosenPosition);
hasUnvisitedNeighbor = true;
end

function distanceMeters = geoDistanceMeters(latA, lonA, latB, lonB)
R = 6371000;
dlat = deg2rad(latB - latA);
dlon = deg2rad(lonB - lonA);
a = sin(dlat/2).^2 + cos(deg2rad(latA)).*cos(deg2rad(latB)).*sin(dlon/2).^2;
c = 2 * atan2(sqrt(a), sqrt(1 - a));
distanceMeters = R * c;
end
