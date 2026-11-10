# Feature Specification: Versión de los datos

**Feature Branch**: `feature/HB-022-version-datos`

**Created**: 2026-11-10

**Status**: Draft

**Input**: Constitución y `.claude/rules/swift.md` (persistencia con `schemaVersion` y migración con
respaldo; nada de estado en `UserDefaults`). Los archivos del workspace no tenían versión y el estado
de corrida vivía en `UserDefaults`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Archivos con versión y migración segura (Priority: P1)

**Independent Test**: un workspace con archivos sin versión se migra al arrancar y queda un respaldo
de cada uno.

**Acceptance Scenarios**:

1. **Given** `config.json`, `perfil.json`, `agentes/<agente>.json` o `contenido/cuentas.json` sin
   versión, **When** arranca Hirebar, **Then** se copian a `respaldos/` y se reescriben con
   `schemaVersion` sin perder datos; las cuentas pasan a objeto con la lista en `cuentas`.
2. **Given** archivos que ya tienen la versión actual, **When** arranca, **Then** no se tocan ni se
   respaldan.
3. **Given** un archivo de una versión más nueva, **When** arranca o se guarda, **Then** no se migra ni
   se sobrescribe.

### User Story 2 - Estado de corrida en el workspace (Priority: P1)

**Acceptance Scenarios**:

1. **Given** una instalación anterior con vistos de los radares, turnos ya ejecutados, cuenta que
   espera voz y posición de lectura de Telegram en `UserDefaults`, **When** arranca, **Then** pasan a
   `estado/corrida.json` y las claves viejas se borran.
2. **Given** el estado de corrida, **When** se reinicia la app, **Then** un turno ya ejecutado no se
   repite y Telegram sigue desde su posición; los turnos de más de 14 días se olvidan.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Los archivos de configuración, perfil, agentes, cuentas y estado de corrida MUST llevar
  `schemaVersion` al guardarse.
- **FR-002**: La migración MUST respaldar cada archivo antes de reescribirlo y MUST NOT cambiar sus
  campos.
- **FR-003**: Un archivo de versión más nueva MUST NOT sobrescribirse.
- **FR-004**: Hirebar MUST NOT guardar estado en `UserDefaults`; el offset de Telegram llega al
  adaptador por el puerto `ChatOffsetStore`.

## Success Criteria *(mandatory)*

- **SC-001**: Cero usos de `UserDefaults` en `Sources` fuera de la migración que borra las claves
  viejas.
- **SC-002**: Tests de migración, respaldo, versión más nueva y paso de `UserDefaults` al workspace.
