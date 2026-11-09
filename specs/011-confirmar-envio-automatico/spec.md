# Feature Specification: Confirmar el envío automático

**Feature Branch**: `feature/HB-011-confirmar-envio-automatico`

**Created**: 2026-11-09

**Status**: Draft

**Input**: Constitución, principio II. Hoy el envío automático de Empleo, Freelance y Clientes se
prende con una casilla del panel, del menú o de Ajustes, o con `auto si` en Telegram, sin explicar qué
pasa después. Esta spec pide una confirmación explícita que dice qué hará cada agente sin esperar a la
persona y qué nunca sale solo.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Saber qué se prende antes de prenderlo (Priority: P1)

La persona prende el envío automático solo después de leer qué hará cada agente sin esperar su "si".

**Why this priority**: con el envío automático la IA actúa en nombre de la persona sin que vea cada
envío; un toque por error no debe bastar.

**Independent Test**: escribir `auto empleo si` en Telegram; llega la explicación con "Sí, prender" y
"No", y Empleo sigue apagado hasta pulsar "Sí, prender".

**Acceptance Scenarios**:

1. **Given** el envío automático apagado, **When** la persona lo prende desde el panel, el menú o
   Ajustes, **Then** aparece una confirmación con lo que hará cada agente y lo que nunca sale solo, y
   solo se prende si confirma.
2. **Given** `auto si` o `auto <agente> si` en Telegram, **When** llega, **Then** se responde con la
   explicación y los botones "Sí, prender" y "No"; nada cambia hasta "Sí, prender".
3. **Given** la confirmación, **When** la persona cancela, **Then** el envío automático sigue apagado y
   el resto de lo editado en Ajustes se guarda igual.
4. **Given** el envío automático prendido, **When** la persona lo apaga desde cualquier lugar, **Then**
   se apaga sin preguntar.
5. **Given** un cambio confirmado, **When** se aplica, **Then** el registro anota qué agente se prendió
   y desde dónde.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Prender el envío automático de Empleo, Freelance o Clientes MUST pedir una confirmación
  explícita en la Mac (panel, menú y Ajustes) y en Telegram (botón "Sí, prender").
- **FR-002**: La confirmación MUST decir qué hace cada agente sin esperar a la persona y que nunca
  salen solos las respuestas a clientes, las publicaciones, los correos en frío ni los seguimientos a
  alguien nuevo, y que el cupo diario sigue igual.
- **FR-003**: Apagar el envío automático MUST aplicarse sin confirmación.
- **FR-004**: Cada cambio MUST quedar en el registro con el agente y el origen (la Mac, Ajustes o
  Telegram).
- **FR-005**: Los agentes sin envío automático (Contenido, Perfil, Analista) MUST NOT poder prenderlo
  por ningún camino.

## Success Criteria *(mandatory)*

- **SC-001**: Ningún envío automático se prende sin una confirmación explícita de la persona.
- **SC-002**: El 100% de los cambios de envío automático queda en el registro con su origen.

## Assumptions

- La confirmación en Telegram la puede dar solo la cuenta anclada (spec `012-canal-de-mensajes`).
