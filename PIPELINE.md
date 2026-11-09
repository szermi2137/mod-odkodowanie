# Pipeline krok po kroku

1. Walidacja JAR-a jako ZIP, obliczenie SHA-256 i wykrycie metadanych.
2. Sugestia wersji Minecrafta na podstawie nazwy JAR-a lub metadanych; człowiek zatwierdza exact version.
3. Heurystyka namespace: intermediary / Yarn named / Mojmap / unknown. W przypadku wątpliwości narzędzie pyta.
4. Vineflower dekompiluje wejściowy JAR do `01-source-original`.
5. Nie-klasowe zasoby są kopiowane do `04-resources-original`; JSON i MCmeta są parsowane.
6. Dla namespace intermediary: pobranie najnowszego stabilnego Yarn builda dla dokładnego wydania; pobranie lub utworzenie klienta Minecrafta w intermediary; Tiny Remapper zmienia klasy na Yarn named.
7. Vineflower dekompiluje remapowany JAR do `03-source-named`.
8. `RECOVERY_TOOLCHAIN.json` zapisuje wersje narzędzi, hash wejścia, mapowania, namespace, statusy i ostrzeżenia.
9. Obok oryginału tworzy się osobna kopia archiwalna z wbudowanym JSON-em provenance. Oryginał pozostaje bez zmian.

Ten pipeline jest narzędziem do analizy. Nie próbuje automatycznie tworzyć gotowego do dystrybucji projektu modowego, naprawiać wszystkich mixinów/refmap ani gwarantować kompatybilności runtime.
