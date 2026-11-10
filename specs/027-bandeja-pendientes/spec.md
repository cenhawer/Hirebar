# Feature Specification: Bandeja de pendientes

**Feature Branch**: `feature/HB-027-bandeja-pendientes`

**Created**: 2026-11-10

**Status**: Draft

**Input**: Constitución (paridad de canales: nada exclusivo de Telegram). Las listas por aprobar y las
publicaciones listas solo se podían ver y aprobar desde Telegram.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Aprobar listas desde la Mac (Priority: P1)

La persona abre "Pendientes de aprobar" desde el panel y ve cada lista con sus envíos.

**Independent Test**: los tests aprueban, eligen y descartan listas con el motor y un runner de IA de
prueba.

**Acceptance Scenarios**:

1. **Given** listas pendientes, **When** se abre la bandeja, **Then** se ve cada lista con el título del
   modo, la fecha y sus envíos numerados con destino, plataforma, encaje y texto; las listas hechas,
   descartadas o vacías no aparecen.
2. **Given** una lista, **When** la persona aprueba todos, elige algunos o descarta, **Then** se usa el
   mismo caso de uso que Telegram (copia aprobada, cupo diario, pausas y verificación) y la IA corre
   solo sobre lo elegido.
3. **Given** ningún envío elegido, **When** se mira la bandeja, **Then** "Aprobar elegidos" está
   deshabilitado.

### User Story 2 - Vista previa de publicaciones (Priority: P1)

**Acceptance Scenarios**:

1. **Given** una cuenta de contenido con borrador, **When** se abre la bandeja, **Then** se ve el texto,
   las láminas en orden y el video (el final si existe, si no la vista previa).
2. **Given** ese borrador, **When** la persona publica o lo descarta, **Then** se usa el mismo flujo que
   `publica` y `post salta` en Telegram.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La bandeja MUST mostrar las listas pendientes y los borradores de contenido.
- **FR-002**: Aprobar, elegir, descartar, publicar y saltar MUST usar los mismos casos de uso que
  Telegram.
- **FR-003**: La selección MUST traducirse a los números que entiende el caso de uso (vacío = todos).
- **FR-004**: La lógica de la bandeja MUST vivir en `HirebarApplication` y probarse sin interfaz.

## Success Criteria *(mandatory)*

- **SC-001**: Tests de listado, selección, aprobación parcial, descarte, vista previa, publicar y saltar.
