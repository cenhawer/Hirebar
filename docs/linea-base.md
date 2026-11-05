# Línea base

Estado del código en el commit `96e7a97`. La cobertura sale del CI (`macos-26`, Swift 6.3.3), que es quien aprueba o rechaza un PR; el resto se midió en el worker (Swift 6.4.2) con `--scratch-path ~/Library/Caches/hirebar-build`.

| Medida | Resultado |
|---|---|
| `swift build` | Compila, 21 s |
| `swift test` | 36 tests, 0 fallos |
| Cobertura de líneas medidas en `Sources` (CI) | 35,63 % |
| Archivos de `Sources` sin ningún test (CI) | 26 de 57 (todo `HirebarEngine` y la app) |
| gitleaks sobre todo el historial | Sin secretos |
| swift-format (4 espacios, 140 columnas) | ~700 avisos |
| SwiftLint (`.swiftlint.yml`) | 92 comentarios prohibidos, 54 líneas largas, 53 nombres cortos, 14 funciones con complejidad alta |
| Grafo de Graphify | 1303 nodos, 2904 aristas, 74 comunidades |

Los avisos de lint existentes se corrigen por spec; CI solo rechaza violaciones en las líneas que cambia cada PR. El mínimo de cobertura (`.coverage-minimum`) parte de la medida del CI. Con otra versión de Swift la cifra local puede variar, porque cada compilador instrumenta un conjunto distinto de archivos.
