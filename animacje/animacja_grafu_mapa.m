function animacja_grafu_mapa(truePoints, edges, mapInput)
% ANIMACJA_GRAFU_MAPA
% 1) Start: punkty losowo na bialym tle, polaczone wg edges
% 2) 1. klik/klawisz: punkty ustawiane w poprawne wspolrzedne
% 3) 2. klik/klawisz: plynny fade-in mapy
%
% Wejscie:
%   truePoints : Nx2 [x y] poprawne wspolrzedne punktow
%   edges      : Mx2 indeksy punktow (1-based)
%   mapInput   : (opcjonalnie)
%                - sciezka do obrazka mapy (np. 'mapa.png')
%                - albo macierz obrazu (HxWx3 / HxW)
%
% Przyklad:
%   P = [0 0; 2 1; 4 0; 3 3; 1 3];
%   E = [1 2; 2 3; 2 4; 4 5; 5 1];
%   animacja_grafu_mapa(P, E, 'mapa.png');

    if nargin < 2
        error('Podaj co najmniej truePoints i edges.');
    end
    if nargin < 3
        mapInput = [];
    end

    validateattributes(truePoints, {'numeric'}, {'2d', 'ncols', 2, 'nonempty', 'finite', 'real'});
    validateattributes(edges, {'numeric'}, {'2d', 'ncols', 2, 'integer', 'positive'});

    n = size(truePoints, 1);
    if any(edges(:) > n)
        error('W edges sa indeksy wieksze niz liczba punktow.');
    end

    % Zakres osi na podstawie poprawnych wspolrzednych
    minXY = min(truePoints, [], 1);
    maxXY = max(truePoints, [], 1);
    span = max(maxXY - minXY, 1);
    margin = 0.15 * max(span);
    xlimVals = [minXY(1)-margin, maxXY(1)+margin];
    ylimVals = [minXY(2)-margin, maxXY(2)+margin];

    % Losowe polozenie startowe punktow w tym samym obszarze
    rng('shuffle');
    randPoints = [ ...
        xlimVals(1) + rand(n,1) * (xlimVals(2)-xlimVals(1)), ...
        ylimVals(1) + rand(n,1) * (ylimVals(2)-ylimVals(1)) ...
    ];

    % Figura i os
    fig = figure('Color', 'w', 'Name', 'Animacja grafu i mapy', 'NumberTitle', 'off');
    ax = axes('Parent', fig, 'Color', 'w');
    hold(ax, 'on');
    axis(ax, 'equal');
    xlim(ax, xlimVals);
    ylim(ax, ylimVals);
    set(ax, 'XTick', [], 'YTick', [], 'Box', 'off');

    % Mapa (na starcie niewidoczna)
    hMap = gobjects(1);
    hasMap = false;
    if ~isempty(mapInput)
        try
            if ischar(mapInput) || isstring(mapInput)
                mapImg = imread(mapInput);
            elseif isnumeric(mapInput)
                mapImg = mapInput;
            else
                error('Nieobslugiwany typ mapInput.');
            end

            hMap = image(ax, ...
                'XData', [xlimVals(1), xlimVals(2)], ...
                'YData', [ylimVals(1), ylimVals(2)], ...
                'CData', mapImg, ...
                'AlphaData', 0, ...
                'Visible', 'off');
            uistack(hMap, 'bottom');
            hasMap = true;
        catch ME
            warning('Nie udalo sie zaladowac mapy: %s', ME.message);
        end
    end

    % Krawedzie grafu (na losowych pozycjach)
    m = size(edges,1);
    hEdges = gobjects(m,1);
    for i = 1:m
        a = edges(i,1);
        b = edges(i,2);
        hEdges(i) = line(ax, ...
            [randPoints(a,1), randPoints(b,1)], ...
            [randPoints(a,2), randPoints(b,2)], ...
            'Color', [0.15 0.15 0.15], 'LineWidth', 1.8);
    end

    % Punkty
    hNodes = scatter(ax, randPoints(:,1), randPoints(:,2), 52, ...
        'MarkerFaceColor', [0.10 0.45 0.85], ...
        'MarkerEdgeColor', [0.02 0.15 0.30], ...
        'LineWidth', 0.9);

    title(ax, 'Kliknij lub nacisnij dowolny klawisz: 1) ustaw punkty, 2) pokaz mape', ...
        'Color', [0.1 0.1 0.1], 'FontWeight', 'normal');

    % Stan animacji
    state = 1;

    fig.WindowButtonDownFcn = @advance;
    fig.KeyPressFcn = @advance;

    function advance(~, ~)
        switch state
            case 1
                % Pierwszy klik: ustawienie punktow do poprawnych wspolrzednych
                set(hNodes, 'XData', truePoints(:,1), 'YData', truePoints(:,2));
                for k = 1:m
                    a = edges(k,1);
                    b = edges(k,2);
                    set(hEdges(k), 'XData', [truePoints(a,1), truePoints(b,1)], ...
                                   'YData', [truePoints(a,2), truePoints(b,2)]);
                end
                title(ax, 'Kliknij lub nacisnij dowolny klawisz: fade-in mapy', ...
                    'Color', [0.1 0.1 0.1], 'FontWeight', 'normal');
                drawnow;
                state = 2;

            case 2
                % Drugi klik: plynny fade-in mapy
                if hasMap && isgraphics(hMap)
                    set(hMap, 'Visible', 'on');
                    alphaFrames = linspace(0, 1, 50);
                    for a = alphaFrames
                        set(hMap, 'AlphaData', a);
                        drawnow;
                        pause(0.018);
                    end
                end
                title(ax, 'Mapa wyswietlona', 'Color', [0.1 0.1 0.1], 'FontWeight', 'normal');
                state = 3;

            otherwise
                % Kolejne klikniecia nic nie robia
        end
    end
end
