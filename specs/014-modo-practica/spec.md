# Feature Specification: Modo práctica

**Feature Branch**: `feature/HB-014-modo-practica`

**Created**: 2026-11-09

**Status**: Draft

**Input**: Constitución, principio II. La persona no tiene forma de ver qué haría un agente con su
configuración sin que envíe de verdad.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Probar un agente sin que envíe (Priority: P1)

La persona prende el modo práctica de un agente; el agente busca, redacta y propone como siempre, la
persona aprueba, y en lugar de enviar recibe la lista de lo que habría hecho.

**Why this priority**: permite confiar en un agente antes de dejarlo enviar, sobre todo con el envío
automático.

**Independent Test**: con Empleo en práctica, aprobar una lista; no se lanza la IA, llega "Modo
práctica: Empleo no envió nada. Habría hecho N" y queda `ejecuciones/<lote>.practica.json`.

**Acceptance Scenarios**:

1. **Given** un agente en práctica, **When** se aprueba una lista (a mano o con envío automático),
   **Then** no corre ninguna ejecución, llega el resumen de lo que habría hecho y queda el registro.
2. **Given** un agente en práctica, **When** corren sus tareas de lectura y redacción, **Then** corren
   igual que siempre, porque no envían.
3. **Given** una lista en práctica, **When** termina, **Then** no consume el cupo diario.
4. **Given** el panel, el menú, Ajustes o `practica <agente> si/no`, **When** la persona cambia el
   modo, **Then** se aplica y queda en el registro con el origen.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Un agente en modo práctica MUST NOT lanzar ninguna ejecución `act`; MUST guardar lo
  aprobado en `ejecuciones/<lote>.practica.json` y avisar qué habría hecho.
- **FR-002**: Las tareas de lectura y redacción MUST correr igual en práctica.
- **FR-003**: Una lista en práctica MUST liberar su lugar en el cupo diario.
- **FR-004**: El modo MUST cambiarse desde el panel, el menú, Ajustes y Telegram, y cada cambio MUST
  quedar en el registro con su origen.
- **FR-005**: `agentes` MUST mostrar qué agentes están en práctica.

## Success Criteria *(mandatory)*

- **SC-001**: Con un agente en práctica, ninguna acción sale a un portal, correo o red.
