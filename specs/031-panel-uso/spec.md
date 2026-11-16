# Feature Specification: Uso del panel

**Feature Branch**: `feature/HB-031-panel-uso`

**Created**: 2026-11-16

**Status**: Draft

**Input**: Constitución (la persona entiende lo que ve sin saber programar). El panel crecía sin
límite con la lista de agentes (sin `ScrollView`) y algunos mensajes de error mostraban el formato de
archivo (`JSON`) en vez de explicar el problema en términos de la persona.

**Nota**: las zonas de clic de la fila de agente (expandir vs. encender) ya quedaron separadas en
`specs/030-accesibilidad` (`.accessibilityElement`/`.contentShape` solo sobre el nombre y el chevron,
el interruptor fuera de ese gesto). Esta spec no repite ese cambio.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El panel no crece sin límite (Priority: P1)

**Independent Test**: con más agentes de los que entran en la pantalla, el panel se queda en una
altura fija y la lista de agentes se desplaza por dentro.

**Acceptance Scenarios**:

1. **Given** la lista de secciones y agentes del panel, **When** su alto suma más que el alto máximo
   definido, **Then** la lista se desplaza dentro de un `ScrollView` propio; el encabezado y el pie
   quedan siempre visibles.

### User Story 2 - Los mensajes no usan jerga técnica (Priority: P2)

**Acceptance Scenarios**:

1. **Given** el perfil guardado no se puede leer, **When** la persona lo ve en Ajustes, **Then** el
   mensaje explica el problema ("tu perfil quedó dañado y no se pudo leer") sin nombrar el formato de
   archivo (`JSON`).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La lista de agentes del panel MUST vive dentro de un `ScrollView` con alto máximo; el
  encabezado y el pie MUST quedan fuera de ese scroll.
- **FR-002**: Los mensajes de error de lectura del perfil MUST describen el problema para la persona,
  sin nombrar `JSON` ni otro formato de archivo.

## Success Criteria *(mandatory)*

- **SC-001**: `grep -c "JSON válido" Resources/Localizable.xcstrings` da 0.
- **SC-002**: Revisión visual: el panel con los 6 agentes actuales se ve igual que antes (el límite de
  alto no corta contenido con el catálogo de agentes de hoy).
