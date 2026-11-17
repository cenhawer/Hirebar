---

description: "Tareas de implementación: macOS 26 y Swift 6"
---

# Tasks: macOS 26 y Swift 6

## Plataforma

- [x] T001 `swift-tools-version` 6.2, `platforms: [.macOS(.v26)]`, `defaultIsolation(MainActor.self)` en la app y `LSMinimumSystemVersion` 26.0 (FR-001)
- [x] T002 README con los requisitos actuales (FR-001)

## Concurrencia

- [x] T003 Coordinadores del motor y puertos `Clock`, `AIRunner`, `MediaRenderer` y `ExecutionAlerts` en el actor principal; respuestas de `ChatChannel` en cierres `@MainActor @Sendable` (FR-002)
- [x] T004 Telegram serializa el cuerpo antes de cambiar de hilo; descarga de la nota de voz con `async/await` (FR-002, FR-004)
- [x] T005 `WebFrameCapture` y el armado del video con `async/await`; `ReelRenderer` partido en cuatro archivos; mezclado con las APIs async de AVFoundation (FR-002, FR-004)
- [x] T006 Tests del motor `@MainActor` con `setUp`/`tearDown` `async` (FR-005)

## Interfaz

- [x] T007 `PanelModel`, `SettingsModel` y `ChannelSettingsModel` con `@Observable`; vistas con `@Bindable`; `onChange` y `Text` actuales (FR-003)

## Cierre

- [x] T008 Tests de plataforma y de Observation (SC-002, SC-003)
- [x] T009 Compilación limpia sin advertencias y suite completa (SC-001, FR-005)
