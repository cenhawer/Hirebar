---
paths:
  - "Sources/**/*.swift"
  - "Tests/**/*.swift"
  - "Package.swift"
---

# Swift en Hirebar

Prevalece sobre la regla global de Swift en lo que difiere.

## Arquitectura

- Hexagonal, no Domain/Data/Presentation: `HirebarDomain`, `HirebarApplication` con los puertos, un
  target por familia de adaptadores y la app como raíz de composición (`ARCHITECTURE.md` §3).
- Domain y Application no usan `FileManager`, `Process`, `URLSession`, `UserDefaults`, `Timer` ni
  APIs de AppKit o SwiftUI: lo que hace E/S entra por un puerto.
- Solo la raíz de composición instancia adaptadores. Prohibido `static let shared` fuera de ella.
- Un import entre targets que no está en `Package.swift` es un error de diseño, no algo que se
  agrega para que compile.

## Persistencia

- Sin SwiftData: archivos del workspace a través de repositorios de `HirebarStorage`, con
  `schemaVersion` y migración con respaldo.
- Nada de estado en `UserDefaults` salvo preferencias de interfaz.

## Comentarios y textos

- Cero comentarios, sin excepción de "porqué". Solo `///` en contratos públicos que consume un
  sistema externo.
- Ningún texto para la persona como literal: String Catalog, incluidas las respuestas de Telegram.
- Plazos, umbrales, listas de palabras y rutas en configuración o datos, nunca como literal.

## Concurrencia

- `async`/`await` y actores; `@MainActor` en todo lo que toca interfaz.
- Sin `DispatchSemaphore` ni callbacks nuevos; el código existente que los usa se migra al tocarlo.

## Tests

- Contra puertos con dobles de prueba y fixtures en `Tests/Fixtures/`; nunca red, IA, Chrome o
  Telegram reales.
- El nombre del test describe el escenario de la spec que cubre.

## Antes de terminar

- `swift build`, `scripts/coverage.sh` y `scripts/lint.sh origin/develop` en verde.
