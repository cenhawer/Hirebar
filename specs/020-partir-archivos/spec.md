# Feature Specification: Partir archivos

**Feature Branch**: `feature/HB-020-partir-archivos`

**Created**: 2026-11-10

**Status**: Draft

**Input**: Constitución (código legible, cero comentarios). `Controller`, `Commands`, `Settings` y
`Telegram` pasaban de 300 líneas y quedaban comentarios `//` y `///` en código interno.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Archivos de una sola responsabilidad (Priority: P1)

Quien mantiene Hirebar encuentra cada caso de uso en un archivo corto que dice lo que hace.

**Independent Test**: un test recorre `Sources` y falla si un archivo pasa de 300 líneas.

**Acceptance Scenarios**:

1. **Given** el `Controller`, **When** se parte, **Then** quedan la cola y el estado
   (`Controller`), las corridas (`ControllerRuns`), la práctica y las pausas (`ControllerApprovals`),
   los resultados (`ControllerResults`) y los cupos (`ControllerQuota`).
2. **Given** los comandos, **When** se parten, **Then** quedan el despacho (`Commands`), el estado y las
   pausas (`StatusCommands`), los agentes (`AgentCommands`) y el contenido (`ContentCommands`).
3. **Given** Ajustes y Telegram, **When** se parten, **Then** el modelo, las vistas y los editores de
   Ajustes viven en archivos propios, y la lectura de mensajes y los envíos de Telegram en extensiones.
4. **Given** una función de más de 50 líneas o complejidad mayor a 10 (`runNext`, `save` de Ajustes),
   **When** se toca, **Then** se divide en pasos con nombre.

### User Story 2 - Código sin comentarios (Priority: P1)

**Independent Test**: un test recorre `Sources` y falla si encuentra una línea que empieza con `//`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Ningún archivo de `Sources` MUST pasar de 300 líneas.
- **FR-002**: El código de `Sources` MUST NOT llevar comentarios; `Package.swift` conserva solo la
  línea `swift-tools-version`, que SwiftPM exige.
- **FR-003**: El comportamiento MUST NOT cambiar; la suite completa MUST pasar.

## Success Criteria *(mandatory)*

- **SC-001**: `SourceShapeTests` en verde: cero archivos de más de 300 líneas y cero comentarios.
