function [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath, cpuTime] = runGreedyBestFirst( ...
    startNode, targetNode, graphData, animateSearch, callbacks)

numberOfNodes = height(graphData.points);
visited = false(numberOfNodes, 1);
prev = nan(numberOfNodes, 1);

startIdx = graphData.idToIndexMap(startNode);
targetIdx = graphData.idToIndexMap(targetNode);

% priority queue implemented as list of indices and their heuristic values
pq = [];
pqH = [];

% initialize
hStart = geoDistanceMeters(graphData.points.lat(startIdx), graphData.points.lon(startIdx), ...
    graphData.points.lat(targetIdx), graphData.points.lon(targetIdx));
pq(end+1) = startIdx; %#ok<AGROW>
pqH(end+1) = hStart; %#ok<AGROW>
visited(startIdx) = true;

pathIds = [];
visitedNodeIds = [];
operationCount = 0;
iterationCount = 0;
foundPath = false;

% High-resolution elapsed time measurement
startTimer = tic;

while ~isempty(pq)
    % pop element with smallest heuristic
    [~, pos] = min(pqH);
    u = pq(pos);
    pq(pos) = [];
    pqH(pos) = [];

    visitedNodeIds(end+1) = graphData.points.id(u); %#ok<AGROW>
    operationCount = operationCount + 1;
    iterationCount = iterationCount + 1;
    callbacks.updateIterationFooter(iterationCount, operationCount);

    if u == targetIdx
        foundPath = true;
        break;
    end

    neigh = graphData.neighborsByIndex{u};
    weights = graphData.neighborWeightsByIndex{u}; %#ok<NASGU>
    for k = 1:numel(neigh)
        vId = neigh(k);
        v = graphData.idToIndexMap(vId);
        if ~visited(v)
            visited(v) = true;
            prev(v) = u;
            h = geoDistanceMeters(graphData.points.lat(v), graphData.points.lon(v), ...
                graphData.points.lat(targetIdx), graphData.points.lon(targetIdx));
            pq(end+1) = v; %#ok<AGROW>
            pqH(end+1) = h; %#ok<AGROW>
        end
    end

    if animateSearch
        cur = u;
        curPathIdx = [];
        while ~isnan(cur)
            curPathIdx(end+1) = cur; %#ok<AGROW>
            cur = prev(cur);
            if isempty(cur)
                break;
            end
        end
        curPathIdx = fliplr(curPathIdx);
        if numel(curPathIdx) >= 2
            callbacks.drawSearchPath(graphData.points.id(curPathIdx));
        end
        callbacks.throttleSimulationStep();
    end
end

if foundPath
    idxPath = [];
    cur = targetIdx;
    while ~isnan(cur)
        idxPath(end+1) = cur; %#ok<AGROW>
        if cur == startIdx
            break;
        end
        cur = prev(cur);
        if isempty(cur)
            break;
        end
    end
    idxPath = fliplr(idxPath);
    pathIds = graphData.points.id(idxPath);
else
    pathIds = [];
end

visitedCount = numel(visitedNodeIds);

% finalize elapsed time (seconds)
cpuTime = toc(startTimer);
end

function distanceMeters = geoDistanceMeters(latA, lonA, latB, lonB)
R = 6371000;
dlat = deg2rad(latB - latA);
dlon = deg2rad(lonB - lonA);
a = sin(dlat/2).^2 + cos(deg2rad(latA)).*cos(deg2rad(latB)).*sin(dlon/2).^2;
c = 2 * atan2(sqrt(a), sqrt(1 - a));
distanceMeters = R * c;
end
