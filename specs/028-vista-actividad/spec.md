# Feature Specification: Vista de actividad

**Feature Branch**: `feature/HB-028-vista-actividad`

**Created**: 2026-11-10

**Status**: Draft

**Input**: `docs/Plan.md`, fase 5. Hirebar guarda cada envío verificado y lo que habría hecho un agente en
práctica, pero la persona solo lo veía abriendo archivos.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver cada envío (Priority: P1)

La persona abre **Actividad** desde el panel o el menú y ve cada envío: qué se hizo, a quién, cuándo,
qué agente y con qué texto.

**Independent Test**: con una verificación y un registro de práctica guardados, la actividad lista las
entradas con su destino, fecha y texto.

**Acceptance Scenarios**:

1. **Given** una lista ejecutada y verificada, **When** se abre Actividad, **Then** cada acción hecha
   aparece como enviada con su destino, fecha, agente y el texto enviado.
2. **Given** una acción que no coincidió con lo aprobado, **When** se abre Actividad, **Then** aparece
   marcada como tal, con ícono y texto, no solo color.
3. **Given** un agente en modo práctica, **When** se abre Actividad, **Then** aparece lo que habría
   enviado, marcado como práctica.
4. **Given** acciones pendientes, descartadas o que faltaron en el registro, **When** se abre
   Actividad, **Then** no aparecen como envíos.

### User Story 2 - Filtrar (Priority: P2)

**Acceptance Scenarios**:

1. **Given** la actividad, **When** la persona elige un agente y un período (hoy, 7 días, 30 días o
   todo), **Then** solo ve esas entradas, de la más nueva a la más vieja.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La actividad MUST armarse con lo que ya guarda Hirebar: verificaciones de `estado/` y
  registros de práctica de `ejecuciones/`, sin archivos nuevos.
- **FR-002**: `ActivityRepository` MUST vivir en `HirebarApplication` y su implementación en
  `HirebarStorage`.
- **FR-003**: El filtro por agente y período MUST ser lógica pura de la aplicación.
- **FR-004**: La vista MUST NOT leer disco en cada refresco: lee al abrir y al tocar **Actualizar**.

## Success Criteria *(mandatory)*

- **SC-001**: Tests del armado (enviado, no coincidió, práctica, ignorados) y del filtro.
