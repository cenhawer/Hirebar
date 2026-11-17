# Feature Specification: macOS 26 y Swift 6

**Feature Branch**: `feature/HB-018-macos-26-swift-6`

**Created**: 2026-11-10

**Status**: Draft

**Input**: ADR-0004 y constitución. El paquete declara macOS 13 y `swift-tools-version` 5.9: no hay
comprobación de carreras de datos, la interfaz usa `ObservableObject` y el video depende de
semáforos y de APIs de AVFoundation obsoletas.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Concurrencia comprobada por el compilador (Priority: P1)

Quien mantiene Hirebar compila con Swift 6 en modo estricto y el compilador rechaza cualquier acceso
a estado compartido sin aislamiento.

**Independent Test**: una compilación limpia de fuentes y tests termina sin errores ni advertencias.

**Acceptance Scenarios**:

1. **Given** el paquete, **When** se compila, **Then** usa `swift-tools-version` 6.2, modo Swift 6 y
   `platforms: [.macOS(.v26)]`.
2. **Given** los coordinadores del motor (`Controller`, radares, programador, configuración del canal,
   avisos y guardia de ejecución), **When** se compilan, **Then** están aislados al actor principal y
   las constantes que comparten son `nonisolated`.
3. **Given** un puerto con respuesta diferida (chat, IA, medios, reloj), **When** entrega el resultado,
   **Then** lo hace en el actor principal con un cierre `@MainActor @Sendable`.
4. **Given** la app, **When** se compila, **Then** su código está aislado al actor principal por
   defecto.

### User Story 2 - Interfaz con Observation (Priority: P1)

**Acceptance Scenarios**:

1. **Given** el panel, Ajustes y la configuración del canal, **When** cambian sus datos, **Then** las
   vistas se actualizan con modelos `@Observable` y `@Bindable`, sin `ObservableObject` ni
   `@Published`.

### User Story 3 - Video narrado con async/await (Priority: P2)

**Acceptance Scenarios**:

1. **Given** el armado del video, **When** graba las escenas, **Then** la captura web corre en el actor
   principal con `async/await`, sin semáforos, y el grabado de cuadros y el mezclado de sonido son
   funciones `async`.
2. **Given** el mezclado de voz y música, **When** se exporta, **Then** usa `load(.duration)`,
   `loadTracks(withMediaType:)` y `export(to:as:)`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El paquete MUST declarar macOS 26 como mínimo y compilar en modo Swift 6; el bundle MUST
  declarar `LSMinimumSystemVersion` 26.0.
- **FR-002**: El código MUST compilar sin errores ni advertencias de concurrencia ni de APIs
  obsoletas.
- **FR-003**: Los modelos de interfaz MUST usar Observation (`@Observable`, `@Bindable`).
- **FR-004**: El código MUST NOT usar `DispatchSemaphore` para esperar trabajo del actor principal ni
  APIs de AVFoundation obsoletas.
- **FR-005**: El comportamiento para la persona MUST NOT cambiar; la suite completa MUST pasar.

## Success Criteria *(mandatory)*

- **SC-001**: Compilación limpia de fuentes y tests con cero advertencias.
- **SC-002**: Cero `ObservableObject`, `@Published` y `@ObservedObject` en `Sources` (test).
- **SC-003**: `Package.swift` e `Info.plist` declaran macOS 26 (test).
