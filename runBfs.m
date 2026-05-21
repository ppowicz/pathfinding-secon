function [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath, cpuTime] = runBfs( ...
    startNode, targetNode, graphData, animateSearch, callbacks)

numberOfNodes = height(graphData.points);
visited = false(numberOfNodes, 1);
prev = nan(numberOfNodes, 1);
queue = [];

startIdx = graphData.idToIndexMap(startNode);
targetIdx = graphData.idToIndexMap(targetNode);

% initialize
queue(end+1) = startIdx; %#ok<AGROW>
visited(startIdx) = true;

pathIds = [];
visitedNodeIds = [];
operationCount = 0;
iterationCount = 0;
foundPath = false;

% High-resolution elapsed time measurement
startTimer = tic;

while ~isempty(queue)
    % dequeue
    u = queue(1);
    queue(1) = [];

    visitedNodeIds(end+1) = graphData.points.id(u); %#ok<AGROW>
    operationCount = operationCount + 1;
    iterationCount = iterationCount + 1;
    callbacks.updateIterationFooter(iterationCount, operationCount);

    if u == targetIdx
        foundPath = true;
        break;
    end

    neighbors = graphData.neighborsByIndex{u};
    weights = graphData.neighborWeightsByIndex{u}; %#ok<NASGU>
    for k = 1:numel(neighbors)
        vId = neighbors(k);
        v = graphData.idToIndexMap(vId);
        if ~visited(v)
            visited(v) = true;
            prev(v) = u;
            queue(end+1) = v; %#ok<AGROW>
        end
    end

    if animateSearch
        % reconstruct path to u (if any) for visualization
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
    % reconstruct full path from targetIdx to startIdx
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
