# Feature Specification: Política de datos

**Feature Branch**: `feature/HB-029-politica-datos`

**Created**: 2026-11-10

**Status**: Draft

**Input**: Constitución (datos de la persona mínimos y con plazo). Las ejecuciones, listas, métricas e
historiales se limpiaban con plazos escritos en el código, y las grabaciones de voz y los videos
armados no se borraban nunca.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Retención definida en un solo lugar (Priority: P1)

**Independent Test**: la limpieza corre sobre una carpeta temporal con archivos viejos y recientes y
solo borra lo que la política vence.

**Acceptance Scenarios**:

1. **Given** `Resources/retencion.json`, **When** arranca Hirebar, **Then** la política se valida
   (versión y plazos positivos) y llega a la limpieza, a las listas y a los turnos del programador; sin
   ese archivo la app avisa que está incompleta.
2. **Given** grabaciones de voz (`grabacion.*`, `mi-voz.*`) más viejas que su plazo, **When** corre la
   limpieza del domingo, **Then** se borran; las recientes y el guion se conservan.
3. **Given** videos armados (`reel.mp4`, `vista-previa.mp4`), borradores descartados y listas de correos
   descartadas más viejos que su plazo, **When** corre la limpieza, **Then** se borran.
4. **Given** ejecuciones, informes, seguimientos terminados, métricas e historiales, **When** corre la
   limpieza, **Then** se aplican los plazos y tamaños de la política.

### User Story 2 - La persona sabe qué se borra y cuándo (Priority: P2)

**Acceptance Scenarios**:

1. **Given** la guía de uso, **When** la persona busca qué guarda Hirebar, **Then** encuentra cada tipo
   de dato con su plazo y dónde cambiarlo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Los plazos de retención MUST vivir en `Resources/retencion.json` con `schemaVersion`.
- **FR-002**: La limpieza semanal MUST borrar grabaciones de voz, videos armados, borradores y listas
  descartadas vencidos, además de lo que ya limpiaba.
- **FR-003**: La limpieza MUST NOT borrar guiones, borradores vigentes ni archivos recientes.
- **FR-004**: La guía MUST listar qué se borra y cuándo.

## Success Criteria *(mandatory)*

- **SC-001**: Cero plazos de retención en el código (`Housekeeping`, `BatchStore`,
  `FileRunStateRepository`).
- **SC-002**: Tests de la limpieza con archivos viejos y recientes en carpetas temporales.
