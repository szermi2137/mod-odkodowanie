# Mod JAR Recovery Toolkit Smart 2.0

Windowsowy toolkit analityczny dla modów Minecraft Java `.jar`. Zawiera Vineflower 1.12.0 oraz Tiny Remapper 0.10.4; pobiera mapowania Yarn dynamicznie z oficjalnego Fabric Maven i zapisuje provenance użytych narzędzi.

## Szybki start

1. Rozpakuj całe archiwum.
2. Wymagane: JDK 21 zalecane (Vineflower 1.12.0 wymaga Java 17+).
3. Uruchom `Check-Tools.bat`.
4. Przeciągnij plik moda `.jar` na `Recover-Mod.bat`.
5. Potwierdź dokładną wersję gry i wybierz remapowanie, jeśli wejściowy JAR rzeczywiście używa namespace `intermediary`.
6. Sprawdź `RECOVERY_REPORT.txt` i `RECOVERY_TOOLCHAIN.json` w katalogu wyniku. Zbiorcze wersje i hashe narzędzi są też w `TOOL_VERSIONS.json` i `SHA256SUMS.txt`.

Można też uruchomić bez GUI:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Recover-Mod.ps1 -JarPath "C:\mods\mod.jar" -GameVersion "1.21.4" -SourceNamespace intermediary -Remap
```

## Mapowania Yarn 1.20.1+

- `Download-Yarn-Mappings.bat`: najnowszy stabilny build każdego wydania release Minecrafta >=1.20.1, dla którego Fabric Maven publikuje Yarn.
- `Fetch-Yarn-For-Version.bat`: najnowszy build Yarn dla dokładnie podanej wersji gry.
- `Download-All-Yarn-Builds.bat`: wszystkie stabilne buildy; jest to opcja, która może zająć dużo miejsca.

Skrypt czyta oficjalne `maven-metadata.xml`, nie używa z góry ustalonej listy wersji. Snapshoty i RC są pomijane. Jeżeli brak mapowań dla danej wersji, narzędzie nie używa mapowań sąsiedniego wydania po cichu.

## Jak działa remapowanie

Dla `intermediary -> named` toolkit wybiera Yarn dokładnie dla wskazanej wersji. Do classpath Tiny Remappera dołącza referencję Minecrafta w namespace intermediary. Jeśli referencja nie znajduje się w `references\\<wersja>`, narzędzie pobiera oficjalny client JAR Mojang, pobiera mapowania Fabric Intermediary dla tej samej wersji i buduje referencyjny client JAR. Pobieranie wymaga połączenia z internetem.

Automatyczny przebieg nie traktuje wersji z ograniczenia w `fabric.mod.json` (np. `>=1.20.1`) jako dowodu dokładnej wersji kompilacji. Skrypt prosi o zatwierdzenie sugestii.

## Pliki wyniku

- `00-ORIGINAL-UNCHANGED-*.jar` — bitowo zachowana kopia wejścia.
- `00-ANNOTATED-ARCHIVE-ONLY-*.jar` — kopia z `META-INF/RECOVERY_TOOLCHAIN.json`; podpisy JAR mogą być nieważne, nie jest przeznaczona do instalacji.
- `01-source-original/` — surowa dekompilacja.
- `02-remapped-class-analysis-*.jar` — remapowane klasy do analizy.
- `03-source-named/` — źródła zdekompilowane z remapowanych klas.
- `04-resources-original/` — oryginalne zasoby bez klas.
- `RECOVERY_TOOLCHAIN.json` — toolchain, hashe, mapowania, wykryte metadane, biblioteki referencyjne i status etapów.
- `TOOL_VERSIONS.json` oraz `SHA256SUMS.txt` — manifest narzędzi dołączonych do całego toolkit-u.
- `RECOVERY_REPORT.txt` — czytelny raport.
- `JSON_VALIDATION_ISSUES.csv` — problematyczne JSON-y, jeśli istnieją.

## Ważne

Dekomplilacja jest rekonstrukcją, nie źródłem oryginalnym 1:1. Automatyczne remapowanie obsługuje przede wszystkim `intermediary -> named`. Mojmap/Forge/NeoForge, wielowersyjne reflection, refmapy, nested JAR-y i access wideners mogą wymagać specjalnego działania. Wyniku nie należy instalować jako zastępstwa oryginalnego moda bez naprawy zasobów i testu runtime.

Toolkit nie zmienia oryginału. Dopisanie provenance odbywa się tylko do osobnej kopii archiwalnej, ponieważ zmiana podpisanego JAR-a unieważnia podpis. Korzystaj i rozpowszechniaj odzyskany kod zgodnie z licencją oryginalnego moda.

## Oficjalne źródła

- Yarn: https://github.com/FabricMC/yarn (CC0 mappings)
- Yarn Maven: https://maven.fabricmc.net/net/fabricmc/yarn/maven-metadata.xml
- Intermediary Maven: https://maven.fabricmc.net/net/fabricmc/intermediary/maven-metadata.xml
- Vineflower: https://github.com/Vineflower/vineflower
- Tiny Remapper: https://github.com/FabricMC/tiny-remapper
- Mojang version manifest: https://piston-meta.mojang.com/mc/game/version_manifest_v2.json

## Testy tej paczki

Zobacz `docs/VALIDATION_NOTE.md`, gdzie oddzielono sprawdzenia wykonane faktycznie od rzeczy wymagających testu na Windows/Minecraft.
