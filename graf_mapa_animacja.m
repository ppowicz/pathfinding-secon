function graf_mapa_animacja()
% GRAF_MAPA_ANIMACJA
% Osobny program MATLAB (niezalezny od poprzednich):
% - dane punktow i krawedzi sa ladowane z:
%   graph-creation-app/points.csv oraz graph-creation-app/edges.csv
% - mapa jest ladowana tak jak w pathfinding_algorithms.m:
%   geobasemap(gx, "streets")
% - 1. klik/klawisz: punkty przechodza z losowych pozycji do poprawnych
% - 2. klik/klawisz: plynny fade i pojawia sie mapa

    rootDir = fileparts(mfilename('fullpath'));
    pointsPath = fullfile(rootDir, 'graph-creation-app', 'points.csv');
    edgesPath = fullfile(rootDir, 'graph-creation-app', 'edges.csv');

    if ~isfile(pointsPath)
        error('Nie znaleziono pliku: %s', pointsPath);
    end
    if ~isfile(edgesPath)
        error('Nie znaleziono pliku: %s', edgesPath);
    end

    pointsTbl = readtable(pointsPath);
    edgesTbl = readtable(edgesPath);

    requiredPointColumns = ["id", "lat", "lon"];
    requiredEdgeColumns = ["from_id", "to_id"];

    if ~all(ismember(requiredPointColumns, string(pointsTbl.Properties.VariableNames)))
        error('points.csv musi zawierac kolumny: id, lat, lon');
    end
    if ~all(ismember(requiredEdgeColumns, string(edgesTbl.Properties.VariableNames)))
        error('edges.csv musi zawierac kolumny: from_id, to_id');
    end

    pointIds = double(pointsTbl.id);
    lat = double(pointsTbl.lat);
    lon = double(pointsTbl.lon);

    validPointRows = isfinite(pointIds) & isfinite(lat) & isfinite(lon);
    pointIds = pointIds(validPointRows);
    lat = lat(validPointRows);
    lon = lon(validPointRows);

    if isempty(pointIds)
        error('Brak poprawnych punktow po filtracji danych.');
    end

    if numel(unique(pointIds)) ~= numel(pointIds)
        error('Kolumna id w points.csv musi miec unikalne wartosci.');
    end

    idToIdx = containers.Map('KeyType', 'double', 'ValueType', 'double');
    N = numel(pointIds);
    for i = 1:N
        idToIdx(pointIds(i)) = i;
    end

    fromId = double(edgesTbl.from_id);
    toId = double(edgesTbl.to_id);

    fromIdx = [];
    toIdx = [];
    for i = 1:numel(fromId)
        if isfinite(fromId(i)) && isfinite(toId(i)) && isKey(idToIdx, fromId(i)) && isKey(idToIdx, toId(i))
            a = idToIdx(fromId(i));
            b = idToIdx(toId(i));
            if a ~= b
                fromIdx(end+1,1) = a; %#ok<AGROW>
                toIdx(end+1,1) = b; %#ok<AGROW>
            end
        end
    end

    if isempty(fromIdx)
        error('Brak poprawnych krawedzi po dopasowaniu do points.csv');
    end

    latMargin = max(0.0005, (max(lat) - min(lat)) * 0.15);
    lonMargin = max(0.0005, (max(lon) - min(lon)) * 0.15);
    latLimits = [min(lat) - latMargin, max(lat) + latMargin];
    lonLimits = [min(lon) - lonMargin, max(lon) + lonMargin];

    rng('shuffle');
    randLat = latLimits(1) + rand(N,1) * (latLimits(2) - latLimits(1));
    randLon = lonLimits(1) + rand(N,1) * (lonLimits(2) - lonLimits(1));

    fig = figure('Color', 'w', 'Name', 'Graf -> Mapa (CSV)', 'NumberTitle', 'off');
    fig.Position(3:4) = [1150 760];

    % Warstwa mapy (docelowa), taka sama baza jak w pathfinding_algorithms.m
    gx = geoaxes(fig, 'Position', [0.08 0.08 0.84 0.84]);
    geobasemap(gx, "streets");
    hold(gx, 'on');
    geolimits(gx, latLimits, lonLimits);

    [trueEdgeLat, trueEdgeLon] = buildGeoEdgeVectors(lat, lon, fromIdx, toIdx);
    mapEdges = geoplot(gx, trueEdgeLat, trueEdgeLon, '-', ...
        'LineWidth', 1.6, 'Color', [0.05 0.20 0.55]);
    mapNodes = geoscatter(gx, lat, lon, 24, 'filled', ...
        'MarkerFaceColor', [0.05 0.35 0.95], ...
        'MarkerEdgeColor', [0.02 0.10 0.30]);

    mapEdges.Visible = 'off';
    mapNodes.Visible = 'off';

    % Warstwa animacji na bialym tle (na gorze)
    ax = axes('Parent', fig, 'Position', gx.Position, 'Color', 'none');
    hold(ax, 'on');
    xlim(ax, lonLimits);
    ylim(ax, latLimits);
    set(ax, 'XTick', [], 'YTick', [], 'Box', 'off');

    bg = patch(ax, ...
        [lonLimits(1), lonLimits(2), lonLimits(2), lonLimits(1)], ...
        [latLimits(1), latLimits(1), latLimits(2), latLimits(2)], ...
        'w', 'EdgeColor', 'none', 'FaceAlpha', 1);
    uistack(bg, 'bottom');

    [randEdgeX, randEdgeY] = buildXYEdgeVectors(randLon, randLat, fromIdx, toIdx);
    edgeColorBase = [0.10 0.10 0.10];
    nodeFaceBase = [0.10 0.45 0.85];
    nodeEdgeBase = [0.02 0.15 0.30];

    topEdges = plot(ax, randEdgeX, randEdgeY, '-', 'LineWidth', 1.8, 'Color', edgeColorBase);
    topNodes = scatter(ax, randLon, randLat, 62, 'filled', ...
        'MarkerFaceColor', nodeFaceBase, ...
        'MarkerEdgeColor', nodeEdgeBase, ...
        'LineWidth', 1.0);

    title(ax, 'Kliknij/klawisz: 1) ustaw poprawne pozycje  2) fade do mapy', ...
        'Color', [0.15 0.15 0.15], 'FontWeight', 'normal');

    state = 1;
    fig.WindowButtonDownFcn = @nextStep;
    fig.KeyPressFcn = @nextStep;

    function nextStep(~, ~)
        switch state
            case 1
                [trueEdgeX, trueEdgeY] = buildXYEdgeVectors(lon, lat, fromIdx, toIdx);
                set(topEdges, 'XData', trueEdgeX, 'YData', trueEdgeY);
                set(topNodes, 'XData', lon, 'YData', lat);
                drawnow;

                title(ax, 'Kliknij ponownie: fade-in mapy streets', ...
                    'Color', [0.15 0.15 0.15], 'FontWeight', 'normal');
                state = 2;

            case 2
                mapEdges.Visible = 'on';
                mapNodes.Visible = 'on';

                frames = linspace(0, 1, 60);
                for t = frames
                    bg.FaceAlpha = 1 - t;
                    topEdges.Color = blend(edgeColorBase, [1 1 1], t);
                    topNodes.MarkerFaceColor = blend(nodeFaceBase, [1 1 1], t);
                    topNodes.MarkerEdgeColor = blend(nodeEdgeBase, [1 1 1], t);
                    drawnow;
                    pause(0.016);
                end

                topEdges.Visible = 'off';
                topNodes.Visible = 'off';
                bg.Visible = 'off';
                ax.Visible = 'off';
                title(gx, 'Mapa wyswietlona', 'Color', [0.1 0.1 0.1]);
                state = 3;

            otherwise
                % brak akcji
        end
    end
end

function [edgeLat, edgeLon] = buildGeoEdgeVectors(lat, lon, fromIdx, toIdx)
    M = numel(fromIdx);
    edgeLat = nan(3*M, 1);
    edgeLon = nan(3*M, 1);
    for k = 1:M
        p = 3*(k-1) + 1;
        edgeLat(p) = lat(fromIdx(k));
        edgeLat(p+1) = lat(toIdx(k));
        edgeLon(p) = lon(fromIdx(k));
        edgeLon(p+1) = lon(toIdx(k));
    end
end

function [edgeX, edgeY] = buildXYEdgeVectors(x, y, fromIdx, toIdx)
    M = numel(fromIdx);
    edgeX = nan(3*M, 1);
    edgeY = nan(3*M, 1);
    for k = 1:M
        p = 3*(k-1) + 1;
        edgeX(p) = x(fromIdx(k));
        edgeX(p+1) = x(toIdx(k));
        edgeY(p) = y(fromIdx(k));
        edgeY(p+1) = y(toIdx(k));
    end
end

function c = blend(c1, c2, t)
    c = (1 - t) .* c1 + t .* c2;
end
