# Notatka walidacyjna

## Co zostało rzeczywiście sprawdzone

- `vineflower-1.12.0.jar`, `tiny-remapper-0.10.4-fat.jar`, oba zcache'owane JAR-y Yarn oraz biblioteki referencyjne otwierają się jako archiwa ZIP/JAR.
- JAR-y mapowań zawierają `mappings/mappings.tiny`, z nagłówkiem Tiny v2 `intermediary -> named`.
- Hashe SHA-256 w `SHA256SUMS.txt` zgadzają się z dołączonymi plikami binarnymi.
- JSON w pakiecie (w tym `TOOL_VERSIONS.json`) parsuje się poprawnie.
- Ręcznie sprawdzono pipeline Java na testowym `nopush-1.0.0.jar`: Tiny Remapper 0.10.4 zakończył remapowanie `intermediary -> named`, zachował 3 klasy; Vineflower 1.12.0 wygenerował 3 pliki `.java`; wynikowy JAR przeszedł test integralności ZIP.

## Czego nie potwierdzono

- W tym środowisku nie ma Windows PowerShell/Windows CMD, więc skrypty `.ps1` i `.bat` nie mogły zostać uruchomione end-to-end na Windowsie. Zostały sprawdzone statycznie, ale mogą wymagać drobnych poprawek na konkretnej konfiguracji Windows.
- Nie wykonano testu uruchomieniowego Minecrafta z odzyskanymi modami. Toolkit produkuje materiały do analizy, nie gwarantuje kompilowalnego projektu ani działania mixinów.
- Dynamiczne pobieranie nowych mapowań i referencji wymaga Internetu. W paczce offline są mapowania Yarn dla 1.21.4 i 1.21.8; pozostałe wersje są pobierane na żądanie.

## Bezpieczne użycie

- `00-ORIGINAL-UNCHANGED-*.jar` pozostaje niezmienioną kopią wejścia.
- `00-ANNOTATED-ARCHIVE-ONLY-*.jar` to wyłącznie kopia archiwalna z manifestem narzędzi. Dodanie wpisu do `META-INF` może unieważnić podpis JAR-a; nie instaluj tej kopii.
- Remapowany JAR jest oznaczony jako materiał analityczny. Tiny Remapper nie gwarantuje pełnego remapowania refmap, dowolnych stringów refleksyjnych, plików access widener czy nested JAR-ów.
- Dekompilacja nie odzyskuje oryginalnych komentarzy i może nie zachować pierwotnych nazw zmiennych. Przestrzegaj licencji moda przed kopiowaniem lub rozpowszechnianiem kodu.
