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
    methodDropdown.Items = ["Wszystkie", "DFS (pierwszy sąsiad)", "DFS (losowy sąsiad)", ...
        "DFS (najmniejsza waga)", "DFS (najbliższe do celu)", "BFS (wszerz)", "Dijkstra", "A*", "Greedy Best-First Search"];
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
    iterationsLabel.Position = [480 18 70 25];

    iterationsInput = uieditfield(controlPanel, "numeric");
    iterationsInput.Position = [555 18 55 25];
    iterationsInput.RoundFractionalValues = "on";
    iterationsInput.Limits = [1 1000];
    iterationsInput.Value = 1;
    iterationsInput.Tooltip = "Liczba powtórzeń wyznaczenia trasy (dla algorytmów losowych)";

    % INPUT: NODE DOCELOWY
    targetLabel = uilabel(controlPanel);
    targetLabel.Text = "Cel ID:";
    targetLabel.Position = [345 18 55 25];

    targetInput = uieditfield(controlPanel, "numeric");
    targetInput.Position = [400 18 70 25];
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
    speedInput.Position = [1010 18 30 25];
    speedInput.RoundFractionalValues = "on";
    speedInput.Limits = [1 200];
    speedInput.Value = 25;
    speedInput.Tooltip = "Operacje/s";

    % STOPKA
    footerLabel = uilabel(fig);
    footerLabel.Position = [20 15 820 30];
    footerLabel.FontSize = 13;
    footerLabel.Text = "Ładowanie danych...";

    clearRouteButton = uibutton(fig, "push");
    clearRouteButton.Text = "Wyczyść";
    clearRouteButton.Position = [995 15 85 30];
    clearRouteButton.Enable = "off";

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
    clearRouteButton.ButtonPushedFcn = @(btn, event) clearLastRoute();

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
        footerLabel.Text = "Gotowe: " + formatDisplayNumber(numberOfNodes) + " węzłów, " + formatDisplayNumber(numberOfEdges) + " krawędzi";

        resetButton.Enable = "on";
        clearRouteButton.Enable = "on";
        copyButton.Enable = "off";

    catch ME
        footerLabel.Text = "Błąd ładowania danych: " + ME.message;
        resetButton.Enable = "off";
        clearRouteButton.Enable = "off";
        copyButton.Enable = "off";
        startInput.Enable = "off";
        targetInput.Enable = "off";
        findPathButton.Enable = "off";

        uialert(fig, ME.message, "Błąd ładowania danych");
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
        try
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
            footerLabel.Text = "Błąd: node startowy ID=" + formatDisplayNumber(startNode) + " nie istnieje.";
            return;
        end

        if ~ismember(targetNode, points.id)
            footerLabel.Text = "Błąd: node docelowy ID=" + formatDisplayNumber(targetNode) + " nie istnieje.";
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

        methodsToRun = resolveMethodsToRun(selectedMethod);
        runAllMethods = numel(methodsToRun) > 1;

        aggregatedCsv = "";
        for methodIdx = 1:numel(methodsToRun)
            methodName = methodsToRun(methodIdx);

            if runAllMethods
                footerLabel.Text = "Algorytm " + methodName + " (" + formatDisplayNumber(methodIdx) + "/" + formatDisplayNumber(numel(methodsToRun)) + ")...";
                drawnow limitrate;
            end

            try
                [didRun, methodCsv] = runMethodSearch(methodName, startNode, targetNode, numRepetitions, runAllMethods);
            catch ME
                footerLabel.Text = "Błąd przy algorytmie " + methodName + ": " + ME.message;
                didRun = false;
                methodCsv = "";
            end
            if ~didRun
                clear cleanupFindPathButton;
                clear cleanupNodeVisibility;
                clear cleanupEdgeStyle;
                return;
            end

            if runAllMethods
                % Aggregate CSVs: first method supplies header
                if methodIdx == 1
                    aggregatedCsv = methodCsv;
                else
                    lines = split(methodCsv, newline);
                    if numel(lines) > 1
                        dataLines = lines(2:end);
                        aggregatedCsv = aggregatedCsv + newline + strjoin(dataLines, newline);
                    end
                end
            else
                aggregatedCsv = methodCsv;
            end
        end

        % Set global lastResultsCsv so copy button uses aggregated content
        lastResultsCsv = aggregatedCsv;

        clear cleanupFindPathButton;
        clear cleanupNodeVisibility;
        clear cleanupEdgeStyle;
        return;
        catch ME
            footerLabel.Text = "Błąd: " + ME.message;
            try
                set(findPathButton, "Enable", "on");
            end
            return;
        end
    end

    function methodsToRun = resolveMethodsToRun(selectedMethod)
        if selectedMethod == "Wszystkie"
            methodsToRun = ["DFS (pierwszy sąsiad)", "DFS (losowy sąsiad)", ...
                "DFS (najmniejsza waga)", "DFS (najbliższe do celu)", "BFS (wszerz)", "Dijkstra", "A*", "Greedy Best-First Search"];
        else
            methodsToRun = selectedMethod;
        end
    end

    function [didRun, methodCsv] = runMethodSearch(selectedMethod, startNode, targetNode, numRepetitions, appendToExistingCsv)
        selectedMethod = strtrim(string(selectedMethod));
        isDfs = contains(selectedMethod, "DFS");
        if isDfs
            dfsVariant = resolveDfsVariant(selectedMethod);
            if dfsVariant == "unsupported"
                footerLabel.Text = "Algorytm " + selectedMethod + ...
                    " nie jest jeszcze zaimplementowany. Obecnie dostępne: 4 warianty DFS.";
                didRun = false;
                return;
            end
        else
            dfsVariant = "";
        end

        % Tablica do zbierania wyników z każdego powtórzenia
        allVisitedCounts = zeros(1, numRepetitions);
        allDistances = zeros(1, numRepetitions);
        allPathLengths = zeros(1, numRepetitions);
        allCpuTimes = zeros(1, numRepetitions);
        foundPathCount = 0;
        lastPathIds = [];
        lastVisitedNodeIds = [];

        % Animacja tylko dla pojedynczego powtórzenia
        animateSearch = speedModeCheckbox.Value && (numRepetitions == 1);

        % Pętla powtórzeń
        for repIdx = 1:numRepetitions
            if numRepetitions > 1
                footerLabel.Text = "Powtórzenie " + formatDisplayNumber(repIdx) + "/" + formatDisplayNumber(numRepetitions) + "...";
                drawnow limitrate;
            end

            graphData.points = points;
            graphData.idToIndexMap = idToIndexMap;
            graphData.neighborsByIndex = neighborsByIndex;
            graphData.neighborWeightsByIndex = neighborWeightsByIndex;

            callbackData.updateIterationFooter = @updateIterationFooter;
            callbackData.drawSearchPath = @drawSearchPath;
            callbackData.throttleSimulationStep = @throttleSimulationStep;

            if isDfs
                [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath, cpuTime] = runDfs( ...
                    startNode, targetNode, graphData, animateSearch, dfsVariant, callbackData);
            elseif selectedMethod == "Dijkstra"
                [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath, cpuTime] = runDijkstra( ...
                    startNode, targetNode, graphData, animateSearch, callbackData);
            elseif selectedMethod == "A*"
                [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath, cpuTime] = runAStar( ...
                    startNode, targetNode, graphData, animateSearch, callbackData);
            elseif selectedMethod == "Greedy Best-First Search"
                [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath, cpuTime] = runGreedyBestFirst( ...
                    startNode, targetNode, graphData, animateSearch, callbackData);
            elseif selectedMethod == "BFS (wszerz)"
                [pathIds, visitedNodeIds, visitedCount, operationCount, iterationCount, foundPath, cpuTime] = runBfs( ...
                    startNode, targetNode, graphData, animateSearch, callbackData);
            else
                footerLabel.Text = "Algorytm " + selectedMethod + " nie jest jeszcze zaimplementowany.";
                didRun = false;
                return;
            end
            totalDistance = graphPathDistance(pathIds, graphData);

            allVisitedCounts(repIdx) = visitedCount;
            allDistances(repIdx) = totalDistance;
            allPathLengths(repIdx) = numel(pathIds);
            allCpuTimes(repIdx) = cpuTime;

            if foundPath
                foundPathCount = foundPathCount + 1;
                lastPathIds = pathIds;
                lastVisitedNodeIds = visitedNodeIds;
            end
        end

        % Jeśli było jedno powtórzenie, narysuj ścieżkę
        if numRepetitions == 1 && foundPathCount > 0 && ~appendToExistingCsv
            drawFinalPath(lastPathIds);
            totalDistance = allDistances(1);
            visitedCount = allVisitedCounts(1);
            pathLength = allPathLengths(1);
            cpuTime = allCpuTimes(1);
            foundPath = true;
            footerLabel.Text = "Dystans: " + formatDistance(totalDistance) + " | Odwiedzone: " + formatDisplayNumber(visitedCount) + " | CPU: " + formatCpuTimeMs(cpuTime);
        else
            % Jeśli było wiele powtórzeń, pokaż statystykę
            if foundPathCount > 0
                avgVisited = mean(allVisitedCounts);
                avgDistance = mean(allDistances);
                avgPathLength = mean(allPathLengths);
                minVisited = min(allVisitedCounts);
                maxVisited = max(allVisitedCounts);

                avgCpu = mean(allCpuTimes);
                stdCpu = std(allCpuTimes);

                footerLabel.Text = "Średnia: " + formatDistance(avgDistance) + " | Odwiedzone: " + ...
                    formatDisplayNumber(round(avgVisited, 1), 1) + " (min: " + formatDisplayNumber(minVisited) + ", max: " + formatDisplayNumber(maxVisited) + ")" + " | CPU: " + formatCpuTimeMs(avgCpu) + " ± " + formatCpuTimeMs(stdCpu);

                % Użyj średnich do wyświetlenia
                totalDistance = avgDistance;
                visitedCount = round(avgVisited);
                pathLength = round(avgPathLength);
                foundPath = true;
            else
                footerLabel.Text = "Brak trasy w żadnym powtórzeniu (" + formatDisplayNumber(numRepetitions) + "x)";
                totalDistance = 0;
                visitedCount = 0;
                pathLength = 0;
                foundPath = false;
            end
        end

        methodCsv = updateCopyableResults( ...
            selectedMethod, startNode, targetNode, foundPath, lastPathIds, ...
            lastVisitedNodeIds, allVisitedCounts, allDistances, allPathLengths, allCpuTimes, numRepetitions, appendToExistingCsv);

        didRun = true;
    end

    function updateIterationFooter(iterationCount, operationCount)
        spinnerChars = ['|', '/', '-', '\'];
        spinnerChar = spinnerChars(mod(iterationCount - 1, numel(spinnerChars)) + 1);
        visitedCount = operationCount;
        footerLabel.Text = string(spinnerChar) + " odwiedzone: " + formatDisplayNumber(visitedCount);
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

    function outText = formatDistance(distanceMeters)
        outText = formatDisplayNumber(round(distanceMeters, 2), 2) + " m";
    end

    function outText = formatNodeIdList(nodeIds)
        if isempty(nodeIds)
            outText = "[]";
            return;
        end
        outText = "[" + strjoin(string(nodeIds), ", ") + "]";
    end

    function outText = formatDisplayNumber(value, decimals)
        if nargin < 2
            decimals = 0;
        end

        rawText = string(sprintf("%.*f", decimals, value));
        parts = split(rawText, ".");
        integerPart = parts(1);

        if startsWith(integerPart, "-")
            signPart = "-";
            integerDigits = extractAfter(integerPart, 1);
        else
            signPart = "";
            integerDigits = integerPart;
        end

        groupedInteger = regexprep(char(integerDigits), '(?<=\d)(?=(\d{3})+$)', ' ');

        if numel(parts) > 1 && decimals > 0
            outText = signPart + string(groupedInteger) + "." + parts(2);
        else
            outText = signPart + string(groupedInteger);
        end
    end

    function outText = formatCpuTimeMs(cpuSeconds)
        outText = formatDisplayNumber(round(cpuSeconds * 1000, 2), 2) + " ms";
    end

        function resultsCsv = updateCopyableResults(selectedMethod, startNode, targetNode, foundPath, ...
            pathIds, visitedNodeIds, allVisitedCounts, allDistances, allPathLengths, allCpuTimes, numRepetitions, appendToExistingCsv)

        if nargin < 13
            appendToExistingCsv = false;
        end

        % Format CSV z nagłówkiem i danymi z każdego powtórzenia
        headerRow = "algorytm,start,end,distance_m,visited_node_count,final_path_node_count,cpu_time_s,repetition_num";
        dataRows = strings(numRepetitions, 1);

        for i = 1:numRepetitions
            distanceValue = round(allDistances(i), 2);
            visitedCount = allVisitedCounts(i);
            pathNodeCount = allPathLengths(i);

            cpuValue = round(allCpuTimes(i), 6);
            dataRows(i) = string(selectedMethod) + "," + string(startNode) + "," + string(targetNode) + "," + ...
                      string(distanceValue) + "," + string(visitedCount) + "," + string(pathNodeCount) + "," + ...
                      string(cpuValue) + "," + string(i);
        end

        resultsCsv = strjoin([headerRow; dataRows], newline);

        % Włącz przycisk kopiowania
        copyButton.Enable = "on";

        % Wyświetl mini-podsumowanie w stopce
        if numRepetitions > 1
            avgDistance = mean(allDistances);
            avgCpu = mean(allCpuTimes);
            stdCpu = std(allCpuTimes);
            footerLabel.Text = "Średnia: " + formatDistance(avgDistance) + " | Powtórzenia: " + formatDisplayNumber(numRepetitions) + " | CPU: " + formatCpuTimeMs(avgCpu) + " ± " + formatCpuTimeMs(stdCpu);
        else
            footerLabel.Text = "Dystans: " + formatDistance(allDistances(1)) + " | Odwiedzone węzły: " + formatDisplayNumber(allVisitedCounts(1)) + " | CPU: " + formatCpuTimeMs(allCpuTimes(1));
        end
    end
    
    function copyResultsToClipboard()
        if ~isempty(lastResultsCsv)
            clipboard('copy', lastResultsCsv);
            footerLabel.Text = "✓ Wynik skopiowany do schowka";
        end
    end

    function clearLastRoute()
        clearSearchVisuals();
        footerLabel.Text = "Wyczyszczono ostatnio wyznaczoną trasę.";
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
