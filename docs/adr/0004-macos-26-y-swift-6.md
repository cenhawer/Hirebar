# ADR-0004: macOS 26 y Swift 6 como base

## Estado

Aceptado · 2026-11-05

## Contexto

`Package.swift` declara `platforms: [.macOS(.v13)]` y `swift-tools-version:5.9`. Eso impide usar
`@Observable` (macOS 14), el SwiftUI actual para la barra de menú y las ventanas, Liquid Glass
(macOS 26) y el modo de lenguaje de Swift 6 con concurrencia estricta. El motor usa
`DispatchSemaphore` y callbacks donde hoy alcanza `async`/`await`. La última versión de macOS es la
27, pero en GitHub Actions su SDK solo está en la imagen `xcode-27`, que sigue en preview; la imagen
estable `macos-26` trae Xcode 26.

## Decisión

La versión mínima es macOS 26, con Swift 6 y concurrencia estricta (`swift-tools-version` 6). La
interfaz usa SwiftUI con `@Observable` y el estilo del sistema, incluido Liquid Glass. Se sube a
macOS 27 cuando la imagen `xcode-27` de GitHub Actions deje de ser preview.

## Consecuencias

- La app no corre en Macs con macOS anterior a 26.
- Se elimina el código de compatibilidad y `ObservableObject` pasa a `@Observable` (spec
  `018-macos-26-swift-6`).
- La concurrencia estricta obliga a resolver los datos compartidos entre hilos que hoy usan
  `@unchecked Sendable` y semáforos.
- El CI sigue en `macos-26`, sin depender de una imagen en preview.

## Alternativas consideradas

| Alternativa | Por qué no |
|---|---|
| Mantener macOS 13 | Deja fuera `@Observable`, Liquid Glass y el SwiftUI actual |
| macOS 27 ya | Cada PR dependería de la imagen `xcode-27`, que sigue en preview |

## Referencias

- Constitución, restricciones técnicas.
- `ARCHITECTURE.md` §1.
- `docs/Plan.md`, decisión D8 y spec `018-macos-26-swift-6`.
