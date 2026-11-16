# Feature Specification: Accesibilidad

**Feature Branch**: `feature/HB-030-accesibilidad`

**Created**: 2026-11-16

**Status**: Draft

**Input**: Constitución (la app la puede usar cualquier persona). El panel no tenía etiquetas de
VoiceOver, el estado "en pausa" o "trabajando" se distinguía solo por color (naranja) y los textos
usaban tamaños fijos en vez de estilos semánticos que respetan el tamaño de letra del sistema.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - VoiceOver lee el panel (Priority: P1)

**Independent Test**: con VoiceOver activo, cada fila de agente, el interruptor de encendido, el
botón de Telegram y los botones del pie anuncian su nombre y su estado sin abrir nada.

**Acceptance Scenarios**:

1. **Given** un agente apagado, en pausa o trabajando, **When** VoiceOver enfoca su fila, **Then**
   anuncia el nombre del agente y su estado (apagado / en pausa: motivo / trabajando / próximo: …) en
   una sola etiqueta, sin depender del color.
2. **Given** el interruptor de encendido de un agente, **When** VoiceOver lo enfoca, **Then** anuncia
   "Encendido para <agente>" o "Apagado para <agente>", no solo "interruptor".
3. **Given** el botón de Telegram en el encabezado, **When** VoiceOver lo enfoca, **Then** anuncia si
   Telegram está conectado o si falta configurarlo.

### User Story 2 - El estado nunca depende solo del color (Priority: P1)

**Acceptance Scenarios**:

1. **Given** un agente en pausa, **When** se muestra en el panel, **Then** el ícono de pausa y el
   texto del motivo acompañan el color naranja (ya existente); nadie necesita distinguir colores para
   saber que está en pausa.
2. **Given** la IA ocupada (`claudeBusy`), **When** se muestra el punto de estado del encabezado,
   **Then** un ícono o texto accesible indica "ocupada" además del color naranja/verde.

### User Story 3 - Los textos escalan con el tamaño de letra del sistema (Priority: P2)

**Acceptance Scenarios**:

1. **Given** los textos del panel que usan `.font(.system(size:))`, **When** se audita el archivo,
   **Then** usan estilos semánticos (`.caption`, `.caption2`, `.footnote`, `.subheadline`, `.headline`)
   en vez de tamaños fijos, salvo los que ya dependen de un tamaño exacto por diseño (puntos de
   estado, íconos monoespaciados).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Cada fila de agente MUST expone una etiqueta de accesibilidad única que describe
  nombre y estado (apagado, en pausa con motivo, trabajando, o próximo turno) sin depender del color.
- **FR-002**: El interruptor de encendido de cada agente MUST anuncia su estado y a qué agente
  pertenece.
- **FR-003**: El botón de Telegram del encabezado y el punto de estado de la IA MUST comunican su
  estado por texto o ícono, no solo por color.
- **FR-004**: Los textos del panel y de la bandeja de pendientes MUST usan estilos de fuente
  semánticos en vez de `.font(.system(size:))` fijo, salvo donde el tamaño es parte del diseño
  (puntos de estado de 6pt, chevron de 9pt).

## Success Criteria *(mandatory)*

- **SC-001**: Tests sobre la función que compone la etiqueta de accesibilidad de una fila para cada
  combinación de estado (apagado, en pausa, trabajando, normal).
- **SC-002**: `grep -c "font(.system(size:" Sources/Hirebar/PanelView.swift` baja a los casos
  documentados como excepción.
