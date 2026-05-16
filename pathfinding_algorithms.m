function pathfinding_algorithms()
    % OKNO PROGRAMU
    fig = uifigure("Name", "Mapa grafowa kampusu");
    fig.Position = [100 100 1100 800];

    % PANEL KONTROLNY
    controlPanel = uipanel(fig);
    controlPanel.Position = [20 710 1060 70];
    controlPanel.Title = "Sterowanie";

    % DROPDOWN: METODA PATHFINDINGU
    methodLabel = uilabel(controlPanel);
    methodLabel.Text = "Algorytm:";
    methodLabel.Position = [20 18 70 25];

    methodDropdown = uidropdown(controlPanel);
    methodDropdown.Position = [90 18 100 25];
    methodDropdown.Items = ["DFS (pierwszy sąsiad)", "DFS (losowy sąsiad)", ...
        "DFS (najmniejsza waga)", "DFS (najbliższe do celu)", "Dijkstra", "A*", "D*", "Greedy Best-First Search"];
    methodDropdown.Value = "DFS (pierwszy sąsiad)";

    % INPUT: NODE STARTOWY
    startLabel = uilabel(controlPanel);
    startLabel.Text = "Start ID:";
    startLabel.Position = [200 18 65 25];

    startInput = uieditfield(controlPanel, "numeric");
    startInput.Position = [265 18 70 25];
    startInput.RoundFractionalValues = "on";
    startInput.Limits = [1 Inf];
    startInput.Enable = "off";

    % INPUT: LICZBA POWTÓRZEŃ
    iterationsLabel = uilabel(controlPanel);
    iterationsLabel.Text = "Powtórzenia:";
    iterationsLabel.Position = [345 18 70 25];

    iterationsInput = uieditfield(controlPanel, "numeric");
    iterationsInput.Position = [415 18 70 25];
    iterationsInput.RoundFractionalValues = "on";
    iterationsInput.Limits = [1 1000];
    iterationsInput.Value = 1;
    iterationsInput.Tooltip = "Liczba powtórzeń wyznaczenia trasy (dla algorytmów losowych)";

    % INPUT: NODE DOCELOWY
    targetLabel = uilabel(controlPanel);
    targetLabel.Text = "Cel ID:";
    targetLabel.Position = [495 18 55 25];

    targetInput = uieditfield(controlPanel, "numeric");
    targetInput.Position = [550 18 70 25];
    targetInput.RoundFractionalValues = "on";
    targetInput.Limits = [1 Inf];
    targetInput.Enable = "off";

    % PRZYCISK WYZNACZANIA TRASY
    findPathButton = uibutton(controlPanel, "push");
    findPathButton.Text = "Wyznacz trasę";
    findPathButton.Position = [630 18 125 25];
    findPathButton.Enable = "off";

    % OPCJE PRĘDKOŚCI SYMULACJI
    speedModeCheckbox = uicheckbox(controlPanel);
    speedModeCheckbox.Text = "Limituj prędkość";
    speedModeCheckbox.Position = [770 18 110 25];
    speedModeCheckbox.Value = false;

    speedSlider = uislider(controlPanel);
    speedSlider.Position = [890 31 100 3];
    speedSlider.Limits = [1 200];
    speedSlider.Value = 25;
    speedSlider.MajorTicks = [1 25 50 100 150 200];
    speedSlider.MinorTicks = [];
    speedInput = uieditfield(controlPanel, "numeric");
    speedInput.Position = [990 18 70 25];
    speedInput.RoundFractionalValues = "on";
    speedInput.Limits = [1 200];
    speedInput.Value = 25;
    speedInput.Tooltip = "Operacje/s";

    % STOPKA
    footerLabel = uilabel(fig);
    footerLabel.Position = [20 15 820 30];
    footerLabel.FontSize = 13;
    footerLabel.Text = "Ładowanie danych...";

    % POLE WYNIKÓW (UKRYTE - dane dostępne przez przycisk Kopiuj)
    resultsTextArea = uitextarea(fig);
    resultsTextArea.Position = [20 50 860 45];
    resultsTextArea.Value = {''};
    resultsTextArea.Visible = "off";
    resultsTextArea.Editable = "off";
    resultsTextArea.FontName = "Consolas";
    resultsTextArea.FontSize = 11;

    % Przycisk kopiowania wyniku
    copyButton = uibutton(fig, "push");
    copyButton.Text = "Kopiuj wynik";
    copyButton.Position = [900 50 85 30];
    copyButton.Enable = "off";
    copyButton.ButtonPushedFcn = @(btn, event) copyResultsToClipboard();

    resetButton = uibutton(fig, "push");
    resetButton.Text = "Resetuj widok";
    resetButton.Position = [995 50 85 30];
    resetButton.Enable = "off";

    % MAPA
    mapPanel = uipanel(fig);
    mapPanel.Position = [20 100 1060 600];

    gx = geoaxes(mapPanel);
    gx.Position = [0.03 0.03 0.94 0.94];

    geobasemap(gx, "streets");
    hold(gx, "on");

    % Zmienne do zapamiętania pełnego widoku grafu
    graphLatLimits = [];
    graphLonLimits = [];

    % Zmienne na dane
    points = table();
    edges = table();
    isSpeedSyncInProgress = false;
    idToIndexMap = containers.Map("KeyType", "double", "ValueType", "double");
    neighborsByIndex = {};
    neighborWeightsByIndex = {};
    nodePlot = gobjects(0);
    startMarkerPlot = gobjects(0);
    targetMarkerPlot = gobjects(0);
    startLabelText = gobjects(0);
    targetLabelText = gobjects(0);
    searchPathLine = gobjects(0);
    resultPathLine = gobjects(0);
    edgePlot = gobjects(0);
    edgeLat = [];
    edgeLon = [];
    edgeFromIdx = [];
    edgeToIdx = [];
    edgeOriginalColors = zeros(0, 3);
    lastResultsCsv = "";  % Zmienna do przechowywania wyniku CSV do kopiowania

    % Przycisk resetu widoku
    resetButton.ButtonPushedFcn = @(btn, event) resetMapView();

    % Przycisk wyznaczania trasy
    findPathButton.ButtonPushedFcn = @(btn, event) handleFindPath();
    startInput.ValueChangedFcn = @(src, event) refreshStartTargetPreview();
    targetInput.ValueChangedFcn = @(src, event) refreshStartTargetPreview();
    speedModeCheckbox.ValueChangedFcn = @(src, event) handleSpeedModeToggle();
    speedSlider.ValueChangedFcn = @(src, event) syncSpeedControls("slider", speedSlider.Value);
    speedInput.ValueChangedFcn = @(src, event) syncSpeedControls("input", speedInput.Value);
    syncSpeedControls("slider", speedSlider.Value);

    % AUTOMATYCZNE ŁADOWANIE DANYCH
    try
        points = readtable("graph-creation-app/points.csv");
        edges = readtable("graph-creation-app/edges.csv");

        % Walidacja podstawowych kolumn
        requiredPointColumns = ["id", "lat", "lon", "name"];
        requiredEdgeColumns = ["id", "from_id", "to_id", "distance_m"];

        if ~all(ismember(requiredPointColumns, string(points.Properties.VariableNames)))
            error("Plik points.csv musi zawierać kolumny: id, lat, lon, name");
        end

        if ~all(ismember(requiredEdgeColumns, string(edges.Properties.VariableNames)))
            error("Plik edges.csv musi zawierać kolumny: id, from_id, to_id, distance_m");
        end

        numberOfNodes = height(points);
        numberOfEdges = height(edges);
        minEdgeDistance = min(edges.distance_m);
        maxEdgeDistance = max(edges.distance_m);
        [idToIndexMap, neighborsByIndex, neighborWeightsByIndex] = buildGraphStructures();

        % RYSOWANIE KRAWĘDZI (wydajność: jedna geoplot zamiast 1000+ obiektów)
        edgeLat = [];
        edgeLon = [];
        edgeFromIdx = [];
        edgeToIdx = [];
        edgeOriginalColors = zeros(0, 3);
        
        for i = 1:numberOfEdges
            fromId = edges.from_id(i);
            toId = edges.to_id(i);

            fromIdx = find(points.id == fromId, 1);
            toIdx = find(points.id == toId, 1);

            if isempty(fromIdx) || isempty(toIdx)
                warning("Pominięto krawędź ID=%d, bo nie znaleziono węzła from_id=%d lub to_id=%d.", ...
                    edges.id(i), fromId, toId);
                continue;
            end

            if maxEdgeDistance > minEdgeDistance
                normalizedDistance = (edges.distance_m(i) - minEdgeDistance) / ...
                    (maxEdgeDistance - minEdgeDistance);
            else
                normalizedDistance = 0.5;
            end

            % Skalowanie nieliniowe sqrt(x): lepiej rozdziela krótsze krawędzie,
            % gdy w danych występuje pojedynczy długi outlier.
            colorFactor = sqrt(normalizedDistance);

            % Krótsze krawędzie = bardziej zielone, dłuższe = bardziej czerwone.
            edgeColor = [colorFactor, 1 - colorFactor, 0];

            % Dodaj współrzędne z NaN separatorem
            edgeLat = [edgeLat; points.lat(fromIdx); points.lat(toIdx); NaN];
            edgeLon = [edgeLon; points.lon(fromIdx); points.lon(toIdx); NaN];
            edgeFromIdx = [edgeFromIdx; fromIdx];
            edgeToIdx = [edgeToIdx; toIdx];
            edgeOriginalColors = [edgeOriginalColors; edgeColor];
        end
        
        % Narysuj wszystkie krawędzie jednym geoplot
        if ~isempty(edgeLat)
            edgePlot = geoplot(gx, edgeLat, edgeLon, "-", "LineWidth", 1.2, "Color", [0.7 0.7 0]);
        end

        % RYSOWANIE WĘZŁÓW
        nodePlot = geoscatter(gx, points.lat, points.lon, 20, "filled");

        % DATATIPY ZAMIAST STAŁYCH PODPISÓW
        % Po kliknięciu/najechaniu w trybie datatip MATLAB pokaże ID i nazwę.
        nodePlot.DataTipTemplate.DataTipRows(1).Label = "Lat";
        nodePlot.DataTipTemplate.DataTipRows(2).Label = "Lon";

        idRow = dataTipTextRow("ID", points.id);
        nameRow = dataTipTextRow("Nazwa", string(points.name));

        nodePlot.DataTipTemplate.DataTipRows(end+1) = idRow;
        nodePlot.DataTipTemplate.DataTipRows(end+1) = nameRow;

        % OBLICZENIE PEŁNEGO WIDOKU GRAFU
        latMargin = max(0.0005, (max(points.lat) - min(points.lat)) * 0.15);
        lonMargin = max(0.0005, (max(points.lon) - min(points.lon)) * 0.15);

        graphLatLimits = [min(points.lat) - latMargin, max(points.lat) + latMargin];
        graphLonLimits = [min(points.lon) - lonMargin, max(points.lon) + lonMargin];

        resetMapView();

        % USTAWIENIE DOMYŚLNYCH WARTOŚCI INPUTÓW
        if numberOfNodes >= 1
            startInput.Value = points.id(1);
            targetInput.Value = points.id(end);
        end

        startInput.Enable = "on";
        targetInput.Enable = "on";
        findPathButton.Enable = "on";
        refreshStartTargetPreview();

        % STOPKA PO ZAŁADOWANIU
        footerLabel.Text = "Gotowe: " + numberOfNodes + " węzłów, " + numberOfEdges + " krawędzi";

        resetButton.Enable = "on";
        copyButton.Enable = "off";

    catch ME
        footerLabel.Text = "Błąd ładowania danych: " + ME.message;
        resetButton.Enable = "off";
        copyButton.Enable = "off";
        startInput.Enable = "off";
        targetInput.Enable = "off";
        findPathButton.Enable = "off";

        uialert(fig, ME.message, "Błąd ładowania danych");
    end

    function [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath] = runDijkstra(startNode, targetNode, animateSearch)
        numberOfNodes = height(points);
        dist = inf(numberOfNodes, 1);
        prevIdx = nan(numberOfNodes, 1);
        visited = false(numberOfNodes, 1);

        startIdx = idToIndexMap(startNode);
        targetIdx = idToIndexMap(targetNode);

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

            % Mark visited
            visited(u) = true;
            visitedNodeIds(end+1) = points.id(u); %#ok<AGROW>
            operationCount = operationCount + 1;
            iterationCount = iterationCount + 1;
            updateIterationFooter(iterationCount, operationCount);

            % If we've reached the target, stop
            if u == targetIdx
                foundPath = true;
                break;
            end

            % Relax neighbors
            neigh = neighborsByIndex{u};
            weights = neighborWeightsByIndex{u};
            for k = 1:numel(neigh)
                vId = neigh(k);
                v = idToIndexMap(vId);
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
                % Reconstruct current shortest path to u for visualization
                cur = u;
                curPath = [];
                while ~isnan(cur)
                    curPath(end+1) = points.id(cur); %#ok<AGROW>
                    cur = prevIdx(cur);
                end
                curPath = fliplr(curPath);
                if numel(curPath) >= 2
                    drawSearchPath(curPath);
                end
                throttleSimulationStep();
            end
        end

        % Reconstruct final path from target to start
        if ~isnan(prevIdx(targetIdx)) || startIdx == targetIdx
            if dist(targetIdx) < Inf
                idxPath = [];
                cur = targetIdx;
                while ~isnan(cur)
                    idxPath(end+1) = cur; %#ok<AGROW>
                    if cur == startIdx
                        break;
                    end
                    cur = prevIdx(cur);
                    if isempty(cur)
                        break;
                    end
                end
                idxPath = fliplr(idxPath);
                pathIds = points.id(idxPath);
                foundPath = ~isempty(pathIds);
            end
        else
            pathIds = [];
            foundPath = false;
        end

        visitedCount = numel(visitedNodeIds);
    end

    objectCount = numel(findall(gx));
    fprintf("Liczba obiektów na mapie: %d\n", objectCount);

    % RESET WIDOKU
    function resetMapView()
        if ~isempty(graphLatLimits) && ~isempty(graphLonLimits)
            geolimits(gx, graphLatLimits, graphLonLimits);
        end
    end

    % OBSŁUGA PRZYCISKU WYZNACZ TRASĘ
    function handleFindPath()
        selectedMethod = strtrim(string(methodDropdown.Value));
        startNode = startInput.Value;
        targetNode = targetInput.Value;
        numRepetitions = round(iterationsInput.Value);

        if isnan(startNode) || isnan(targetNode)
            footerLabel.Text = "Błąd: wpisz poprawny numer node'a startowego i docelowego.";
            return;
        end

        if startNode == targetNode
            footerLabel.Text = "Start i cel są takie same. Wybierz dwa różne węzły.";
            return;
        end

        if ~ismember(startNode, points.id)
            footerLabel.Text = "Błąd: node startowy ID=" + startNode + " nie istnieje.";
            return;
        end

        if ~ismember(targetNode, points.id)
            footerLabel.Text = "Błąd: node docelowy ID=" + targetNode + " nie istnieje.";
            return;
        end

        clearSearchVisuals();
        updateStartTargetMarkers(startNode, targetNode);

        isDfs = contains(selectedMethod, "DFS");
        if isDfs
            dfsVariant = resolveDfsVariant(selectedMethod);
            if dfsVariant == "unsupported"
                footerLabel.Text = "Algorytm " + selectedMethod + ...
                    " nie jest jeszcze zaimplementowany. Obecnie dostępne: 4 warianty DFS.";
                return;
            end
        else
            dfsVariant = "";
        end

        findPathButton.Enable = "off";
        cleanupFindPathButton = onCleanup(@() set(findPathButton, "Enable", "on"));
        setRemainingNodesVisible(false);
        cleanupNodeVisibility = onCleanup(@() setRemainingNodesVisible(true));
        setEdgeIterationStyle(true);
        cleanupEdgeStyle = onCleanup(@() setEdgeIterationStyle(false));

        % Tablica do zbierania wyników z każdego powtórzenia
        allVisitedCounts = zeros(1, numRepetitions);
        allDistances = zeros(1, numRepetitions);
        allPathLengths = zeros(1, numRepetitions);
        foundPathCount = 0;
        lastPathIds = [];
        lastVisitedNodeIds = [];

        % Animacja tylko dla pojedynczego powtórzenia
        animateSearch = speedModeCheckbox.Value && (numRepetitions == 1);

        % Pętla powtórzeń
        for repIdx = 1:numRepetitions
            if numRepetitions > 1
                footerLabel.Text = "Powtórzenie " + repIdx + "/" + numRepetitions + "...";
                drawnow limitrate;
            end

            if isDfs
                [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath] = runDfs( ...
                    startNode, targetNode, animateSearch, dfsVariant);
            elseif selectedMethod == "Dijkstra"
                [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath] = runDijkstra( ...
                    startNode, targetNode, animateSearch);
            else
                footerLabel.Text = "Algorytm " + selectedMethod + " nie jest jeszcze zaimplementowany.";
                return;
            end
            totalDistance = calculatePathDistance(pathIds);

            allVisitedCounts(repIdx) = visitedCount;
            allDistances(repIdx) = totalDistance;
            allPathLengths(repIdx) = numel(pathIds);

            if foundPath
                foundPathCount = foundPathCount + 1;
                lastPathIds = pathIds;
                lastVisitedNodeIds = visitedNodeIds;
            end
        end

        % Jeśli było jedno powtórzenie, narysuj ścieżkę
        if numRepetitions == 1 && foundPathCount > 0
            drawFinalPath(lastPathIds);
            totalDistance = allDistances(1);
            visitedCount = allVisitedCounts(1);
            pathLength = allPathLengths(1);
            foundPath = true;
            footerLabel.Text = "Dystans: " + string(round(totalDistance, 2)) + " m | Odwiedzone: " + visitedCount;
        else
            % Jeśli było wiele powtórzeń, pokaż statystykę
            if foundPathCount > 0
                avgVisited = mean(allVisitedCounts);
                avgDistance = mean(allDistances);
                avgPathLength = mean(allPathLengths);
                minVisited = min(allVisitedCounts);
                maxVisited = max(allVisitedCounts);

                footerLabel.Text = "Średnia: " + string(round(avgDistance, 2)) + " m | Odwiedzone: " + ...
                    string(round(avgVisited, 1)) + " (min: " + minVisited + ", max: " + maxVisited + ")";

                % Użyj średnich do wyświetlenia
                totalDistance = avgDistance;
                visitedCount = round(avgVisited);
                pathLength = round(avgPathLength);
                foundPath = true;
            else
                footerLabel.Text = "Brak trasy w żadnym powtórzeniu (" + numRepetitions + "x)";
                totalDistance = 0;
                visitedCount = 0;
                pathLength = 0;
                foundPath = false;
            end
        end

        updateCopyableResults( ...
            selectedMethod, startNode, targetNode, foundPath, lastPathIds, ...
            lastVisitedNodeIds, allVisitedCounts, allDistances, allPathLengths, numRepetitions);

        clear cleanupFindPathButton;
        clear cleanupNodeVisibility;
        clear cleanupEdgeStyle;
    end

    function [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath] = runDfs( ...
            startNode, targetNode, animateSearch, dfsVariant)
        numberOfNodes = height(points);
        visited = false(numberOfNodes, 1);
        pathIds = [];
        visitedNodeIds = [];
        operationCount = 0;
        iterationCount = 0;
        foundPath = false;

        stackNodeIds = startNode;
        startIdx = idToIndexMap(startNode);
        visited(startIdx) = true;
        visitedNodeIds = startNode;
        operationCount = 1;
        iterationCount = 1;

        updateIterationFooter(iterationCount, operationCount);
        if animateSearch
            drawSearchPath(stackNodeIds);
            throttleSimulationStep();
        end

        while ~isempty(stackNodeIds)
            currentNodeId = stackNodeIds(end);

            if currentNodeId == targetNode
                pathIds = stackNodeIds;
                foundPath = true;
                break;
            end

            [nextNodeId, hasUnvisitedNeighbor] = firstUnvisitedNeighbor( ...
                currentNodeId, visited, dfsVariant, targetNode);

            if hasUnvisitedNeighbor
                nextNodeIdx = idToIndexMap(nextNodeId);
                visited(nextNodeIdx) = true;
                stackNodeIds(end + 1) = nextNodeId; %#ok<AGROW>
                visitedNodeIds(end + 1) = nextNodeId; %#ok<AGROW>

                operationCount = operationCount + 1;
                iterationCount = iterationCount + 1;
                updateIterationFooter(iterationCount, operationCount);

                if animateSearch
                    drawSearchPath(stackNodeIds);
                    throttleSimulationStep();
                end
            else
                stackNodeIds(end) = [];
                iterationCount = iterationCount + 1;
                updateIterationFooter(iterationCount, operationCount);

                if animateSearch
                    drawSearchPath(stackNodeIds);
                    drawnow limitrate;
                end
            end
        end
        visitedCount = numel(visitedNodeIds);
    end

    function [nextNodeId, hasUnvisitedNeighbor] = firstUnvisitedNeighbor(nodeId, visited, dfsVariant, targetNode)
        nextNodeId = NaN;
        hasUnvisitedNeighbor = false;

        currentIdx = idToIndexMap(nodeId);
        neighbors = neighborsByIndex{currentIdx};
        neighborWeights = neighborWeightsByIndex{currentIdx};

        if isempty(neighbors)
            return;
        end

        unvisitedIdx = [];
        for k = 1:numel(neighbors)
            if ~visited(idToIndexMap(neighbors(k)))
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
                % Wybierz sąsiada, którego współrzędne są najbliżej celu
                if ~isKey(idToIndexMap, targetNode)
                    chosenPosition = unvisitedIdx(1);
                else
                    targetIdx = idToIndexMap(targetNode);
                    tLat = points.lat(targetIdx);
                    tLon = points.lon(targetIdx);
                    R = 6371000; % promien ziemi
                    dists = zeros(1, numel(unvisitedIdx));
                    for u = 1:numel(unvisitedIdx)
                        neighId = neighbors(unvisitedIdx(u));
                        neighIdx = idToIndexMap(neighId);
                        nLat = points.lat(neighIdx);
                        nLon = points.lon(neighIdx);
                        dlat = deg2rad(nLat - tLat);
                        dlon = deg2rad(nLon - tLon);
                        a = sin(dlat/2).^2 + cos(deg2rad(tLat)).*cos(deg2rad(nLat)).*sin(dlon/2).^2;
                        c = 2*atan2(sqrt(a), sqrt(1-a));
                        dists(u) = R * c;
                    end
                    [~, order] = sort(dists, "ascend");
                    chosenPosition = unvisitedIdx(order(1));
                end
            otherwise
                chosenPosition = unvisitedIdx(1);
        end

        nextNodeId = neighbors(chosenPosition);
        hasUnvisitedNeighbor = true;
    end

    function updateIterationFooter(iterationCount, operationCount)
        spinnerChars = ['|', '/', '-', '\'];
        spinnerChar = spinnerChars(mod(iterationCount - 1, numel(spinnerChars)) + 1);
        visitedCount = operationCount;
        footerLabel.Text = string(spinnerChar) + " odwiedzone: " + visitedCount;
        drawnow limitrate;
    end

    function drawSearchPath(nodePathIds)
        if ~isempty(searchPathLine) && isgraphics(searchPathLine)
            delete(searchPathLine);
        end

        if numel(nodePathIds) < 2
            searchPathLine = gobjects(0);
            return;
        end

        [pathLat, pathLon] = nodePathToCoordinates(nodePathIds);
        searchPathLine = geoplot(gx, pathLat, pathLon, "-", ...
            "Color", [0.95 0.1 0.1], "LineWidth", 3.0);
    end

    function drawFinalPath(nodePathIds)
        if ~isempty(searchPathLine) && isgraphics(searchPathLine)
            delete(searchPathLine);
            searchPathLine = gobjects(0);
        end

        if ~isempty(resultPathLine) && isgraphics(resultPathLine)
            delete(resultPathLine);
        end

        if numel(nodePathIds) < 2
            return;
        end

        [pathLat, pathLon] = nodePathToCoordinates(nodePathIds);
        resultPathLine = geoplot(gx, pathLat, pathLon, "-", ...
            "Color", [0.95 0.1 0.1], "LineWidth", 3.5);
    end

    function [pathLat, pathLon] = nodePathToCoordinates(nodePathIds)
        pathLat = zeros(1, numel(nodePathIds));
        pathLon = zeros(1, numel(nodePathIds));
        for p = 1:numel(nodePathIds)
            pointIdx = idToIndexMap(nodePathIds(p));
            pathLat(p) = points.lat(pointIdx);
            pathLon(p) = points.lon(pointIdx);
        end
    end

    function totalDistance = calculatePathDistance(nodePathIds)
        totalDistance = 0;
        if numel(nodePathIds) < 2
            return;
        end

        for p = 1:(numel(nodePathIds) - 1)
            fromId = nodePathIds(p);
            toId = nodePathIds(p + 1);
            fromIdx = idToIndexMap(fromId);
            neighbors = neighborsByIndex{fromIdx};
            weights = neighborWeightsByIndex{fromIdx};
            neighborPos = find(neighbors == toId, 1);
            if isempty(neighborPos)
                continue;
            end
            totalDistance = totalDistance + weights(neighborPos);
        end
    end

    function outText = formatDistance(distanceMeters)
        outText = string(round(distanceMeters, 2)) + " m";
    end

    function outText = formatNodeIdList(nodeIds)
        if isempty(nodeIds)
            outText = "[]";
            return;
        end
        outText = "[" + strjoin(string(nodeIds), ", ") + "]";
    end

    function updateCopyableResults(selectedMethod, startNode, targetNode, foundPath, ...
            pathIds, visitedNodeIds, allVisitedCounts, allDistances, allPathLengths, numRepetitions)
        
        % Format CSV z nagłówkiem i danymi z każdego powtórzenia
        headerRow = "algorytm,start,end,distance_m,visited_node_count,final_path_node_count,repetition_num";
        csvLines = [headerRow];
        
        for i = 1:numRepetitions
            distanceValue = round(allDistances(i), 2);
            visitedCount = allVisitedCounts(i);
            pathNodeCount = allPathLengths(i);
            
            dataRow = string(selectedMethod) + "," + string(startNode) + "," + string(targetNode) + "," + ...
                      string(distanceValue) + "," + string(visitedCount) + "," + string(pathNodeCount) + "," + ...
                      string(i);
            
            csvLines = [csvLines; dataRow];
        end
        
        lastResultsCsv = strjoin(csvLines, newline);
        
        % Włącz przycisk kopiowania
        copyButton.Enable = "on";
        
        % Wyświetl mini-podsumowanie w stopce
        if numRepetitions > 1
            avgDistance = mean(allDistances);
            footerLabel.Text = "Średnia: " + string(round(avgDistance, 2)) + " m | Powtórzenia: " + numRepetitions;
        else
            footerLabel.Text = "Dystans: " + string(round(allDistances(1), 2)) + " m | Odwiedzone węzły: " + string(allVisitedCounts(1));
        end
    end
    
    function copyResultsToClipboard()
        if ~isempty(lastResultsCsv)
            clipboard('copy', lastResultsCsv);
            footerLabel.Text = "✓ Wynik skopiowany do schowka";
        end
    end

    function clearSearchVisuals()
        if ~isempty(searchPathLine) && isgraphics(searchPathLine)
            delete(searchPathLine);
        end
        if ~isempty(resultPathLine) && isgraphics(resultPathLine)
            delete(resultPathLine);
        end
        searchPathLine = gobjects(0);
        resultPathLine = gobjects(0);
    end

    function refreshStartTargetPreview()
        if isempty(points) || height(points) == 0
            return;
        end

        startNode = startInput.Value;
        targetNode = targetInput.Value;
        if isnan(startNode) || isnan(targetNode)
            return;
        end

        if ~ismember(startNode, points.id) || ~ismember(targetNode, points.id)
            return;
        end

        updateStartTargetMarkers(startNode, targetNode);
    end

    function updateStartTargetMarkers(startNodeId, targetNodeId)
        if ~isempty(startMarkerPlot) && isgraphics(startMarkerPlot)
            delete(startMarkerPlot);
        end
        if ~isempty(targetMarkerPlot) && isgraphics(targetMarkerPlot)
            delete(targetMarkerPlot);
        end
        if ~isempty(startLabelText) && isgraphics(startLabelText)
            delete(startLabelText);
        end
        if ~isempty(targetLabelText) && isgraphics(targetLabelText)
            delete(targetLabelText);
        end

        startIdx = idToIndexMap(startNodeId);
        targetIdx = idToIndexMap(targetNodeId);

        startLat = points.lat(startIdx);
        startLon = points.lon(startIdx);
        targetLat = points.lat(targetIdx);
        targetLon = points.lon(targetIdx);

        startMarkerPlot = geoscatter(gx, startLat, startLon, 120, ...
            "filled", "MarkerFaceColor", [0 0.4 1], ...
            "MarkerEdgeColor", [0 0 0], "LineWidth", 1.2);
        targetMarkerPlot = geoscatter(gx, targetLat, targetLon, 120, ...
            "filled", "MarkerFaceColor", [0.62 0.2 0.9], ...
            "MarkerEdgeColor", [0 0 0], "LineWidth", 1.2);

        startLabelText = text(gx, startLon, startLat, " Start", ...
            "Color", [0 0 0], "FontWeight", "bold", ...
            "FontSize", 12, "BackgroundColor", [1 1 1]);
        targetLabelText = text(gx, targetLon, targetLat, " Cel", ...
            "Color", [0 0 0], "FontWeight", "bold", ...
            "FontSize", 12, "BackgroundColor", [1 1 1]);
    end

    function setRemainingNodesVisible(isVisible)
        if ~isempty(nodePlot) && isgraphics(nodePlot)
            if isVisible
                nodePlot.Visible = "on";
            else
                nodePlot.Visible = "off";
            end
        end
    end

    function [mapIdToIndex, nodeNeighbors, nodeNeighborWeights] = buildGraphStructures()
        numberOfNodes = height(points);
        mapIdToIndex = containers.Map("KeyType", "double", "ValueType", "double");
        nodeNeighbors = cell(numberOfNodes, 1);
        nodeNeighborWeights = cell(numberOfNodes, 1);

        for idx = 1:numberOfNodes
            mapIdToIndex(points.id(idx)) = idx;
        end

        for edgeIdx = 1:height(edges)
            fromId = edges.from_id(edgeIdx);
            toId = edges.to_id(edgeIdx);

            if ~isKey(mapIdToIndex, fromId) || ~isKey(mapIdToIndex, toId)
                continue;
            end

            fromIdx = mapIdToIndex(fromId);
            toIdx = mapIdToIndex(toId);
            edgeWeight = edges.distance_m(edgeIdx);

            nodeNeighbors{fromIdx}(end + 1) = toId; %#ok<AGROW>
            nodeNeighborWeights{fromIdx}(end + 1) = edgeWeight; %#ok<AGROW>
            nodeNeighbors{toIdx}(end + 1) = fromId; %#ok<AGROW>
            nodeNeighborWeights{toIdx}(end + 1) = edgeWeight; %#ok<AGROW>
        end

        for idx = 1:numberOfNodes
            if ~isempty(nodeNeighbors{idx})
                [uniqueNeighbors, uniquePos] = unique(nodeNeighbors{idx}, "stable");
                nodeNeighbors{idx} = uniqueNeighbors;
                nodeNeighborWeights{idx} = nodeNeighborWeights{idx}(uniquePos);
            end
        end
    end

    function dfsVariant = resolveDfsVariant(selectedMethod)
        switch selectedMethod
            case "DFS (pierwszy sąsiad)"
                dfsVariant = "first";
            case "DFS (losowy sąsiad)"
                dfsVariant = "random";
            case "DFS (najmniejsza waga)"
                dfsVariant = "minweight";
            case "DFS (najbliższe do celu)"
                dfsVariant = "closest";
            otherwise
                dfsVariant = "unsupported";
        end
    end

    function setEdgeIterationStyle(isIteration)
        if isempty(edgePlot) || ~isgraphics(edgePlot)
            return;
        end
        
        if isIteration
            edgePlot.Color = [0 0 0];  % Czarny podczas iteracji
        else
            % Przywróć żółty (ton neutralny, bo mamy mix kolorów)
            edgePlot.Color = [0.7 0.7 0];
        end
    end

    function handleSpeedModeToggle()
        syncSpeedControls("slider", speedSlider.Value);
    end

    function syncSpeedControls(source, rawValue)
        if isSpeedSyncInProgress
            return;
        end
        isSpeedSyncInProgress = true;

        currentOps = max(1, min(200, round(rawValue)));

        if source == "slider"
            speedSlider.Value = currentOps;
            speedInput.Value = currentOps;
        else
            speedInput.Value = currentOps;
            speedSlider.Value = currentOps;
        end

        if speedModeCheckbox.Value
            speedSlider.Enable = "on";
            speedInput.Enable = "on";
            speedInput.BackgroundColor = [1 1 1];
            speedInput.FontColor = [0 0 0];
            speedInput.Tooltip = "Limit aktywny: " + string(currentOps) + " operacji/s";
        else
            speedSlider.Enable = "off";
            speedInput.Enable = "off";
            speedInput.BackgroundColor = [0.96 0.96 0.96];
            speedInput.FontColor = [0.35 0.35 0.35];
            speedInput.Tooltip = "Limit wyłączony (pełna prędkość). Wybrana wartość: " + ...
                string(currentOps) + " operacji/s";
        end

        isSpeedSyncInProgress = false;
    end

    function modeDescription = currentSpeedModeDescription()
        if speedModeCheckbox.Value
            modeDescription = string(round(speedSlider.Value)) + " operacji/s";
        else
            modeDescription = "pełna prędkość";
        end
    end

    function throttleSimulationStep()
        if ~speedModeCheckbox.Value
            return;
        end
        opsPerSecond = max(1, round(speedSlider.Value));
        pause(1 / opsPerSecond);
    end
end
