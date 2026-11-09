# Smart Recovery 2.1 — dodatki

- Dodano `Verify-Package.bat`, który uruchamia kontrolę integralności.
- `scripts/Verify-Package.ps1` weryfikuje SHA-256 plików wymienionych w `SHA256SUMS.txt` oraz sprawdza, czy dołączone narzędzia, mapowania i referencyjne JAR-y dają się otworzyć jako archiwa.
- Kontrola nie uruchamia Minecrafta i nie potwierdza zgodności runtime; to test integralności paczki.
- Poprzednia zawartość toolkit-u została zachowana.
