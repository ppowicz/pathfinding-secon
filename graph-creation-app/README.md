# SECON Pathfinding

Statyczna aplikacja do ręcznego tworzenia grafu kampusu na mapie hybrydowej (satelita + półprzezroczysta warstwa kafelkowa OpenStreetMap).

## Wymagania

- Chrome lub Edge (File System Access API)
- lokalny serwer HTTP (nie otwierać przez `file://`)

## Uruchomienie

```bash
cd pathfinding-secon
python3 -m http.server 8080
```

Następnie otwórz: `http://localhost:8080`

## Sterowanie

Na dole panelu bocznego jest stały panel, który pokazuje aktualnie dostępne skróty i akcje myszy zależnie od trybu/stanu.

#### `Tryb punktów`
- `LMB` na mapie: dodaje punkt
- `RMB` na punkcie: usuwa punkt i powiązane połączenia
- Dwuklik na punkcie: edycja opcjonalnej nazwy
- Przeciągnięcie punktu: zmiana położenia punktu

#### `Tryb połączeń`
- `LMB` na punkcie: wybiera źródło połączenia
- `LMB` na drugim punkcie: tworzy połączenie
- `RMB` podczas aktywnego rysowania: anuluje tworzenie połączenia
- `RMB` na istniejącym połączeniu: usuwa połączenie

Klawisz `Tab` przełącza tryb punkty/połączenia

## Pliki danych

Po kliknięciu `Wybierz Folder Danych` aplikacja zapisuje na bieżąco:

- `settings.json`
- `points.csv`
- `edges.csv`

Format:

- `points.csv`: `id,lat,lon,name`
- `edges.csv`: `id,from_id,to_id,distance_m`

Krawędzie są nieskierowane i bez duplikatów.
