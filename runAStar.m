function [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath] = runAStar( ...
    startNode, targetNode, graphData, animateSearch, callbacks)

numberOfNodes = height(graphData.points);
g = inf(numberOfNodes, 1);
f = inf(numberOfNodes, 1);
cameFrom = nan(numberOfNodes, 1);
closed = false(numberOfNodes, 1);

startIdx = graphData.idToIndexMap(startNode);
targetIdx = graphData.idToIndexMap(targetNode);

g(startIdx) = 0;
f(startIdx) = geoDistanceMeters( ...
    graphData.points.lat(startIdx), graphData.points.lon(startIdx), ...
    graphData.points.lat(targetIdx), graphData.points.lon(targetIdx));

openSet = startIdx;

pathIds = [];
visitedNodeIds = [];
operationCount = 0;
iterationCount = 0;
foundPath = false;

while ~isempty(openSet)
    [~, pos] = min(f(openSet));
    u = openSet(pos);

    openSet(pos) = [];
    if closed(u)
        continue;
    end
    closed(u) = true;
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
        if closed(v)
            continue;
        end

        tentativeG = g(u) + weights(k);
        if tentativeG < g(v)
            cameFrom(v) = u;
            g(v) = tentativeG;
            h = geoDistanceMeters( ...
                graphData.points.lat(v), graphData.points.lon(v), ...
                graphData.points.lat(targetIdx), graphData.points.lon(targetIdx));
            f(v) = g(v) + h;
            if ~any(openSet == v)
                openSet(end + 1) = v; %#ok<AGROW>
            end
        end
    end

    if animateSearch
        currentPath = reconstructPath(cameFrom, startIdx, u, graphData);
        if numel(currentPath) >= 2
            callbacks.drawSearchPath(currentPath);
        end
        callbacks.throttleSimulationStep();
    end
end

if foundPath
    pathIds = reconstructPath(cameFrom, startIdx, targetIdx, graphData);
else
    pathIds = [];
end

visitedCount = numel(visitedNodeIds);

end

function pathIds = reconstructPath(cameFrom, startIdx, endIdx, graphData)
idxPath = [];
cur = endIdx;
while ~isnan(cur)
    idxPath(end + 1) = cur; %#ok<AGROW>
    if cur == startIdx
        break;
    end
    cur = cameFrom(cur);
    if isempty(cur)
        break;
    end
end
idxPath = fliplr(idxPath);
pathIds = graphData.points.id(idxPath);
end

function distanceMeters = geoDistanceMeters(latA, lonA, latB, lonB)
R = 6371000;
dlat = deg2rad(latB - latA);
dlon = deg2rad(lonB - lonA);
a = sin(dlat/2).^2 + cos(deg2rad(latA)).*cos(deg2rad(latB)).*sin(dlon/2).^2;
c = 2 * atan2(sqrt(a), sqrt(1 - a));
distanceMeters = R * c;
end
