# Feature Specification: Asistente de primer uso

**Feature Branch**: `feature/HB-025-asistente-primer-uso`

**Created**: 2026-11-10

**Status**: Draft

**Input**: `docs/Plan.md`, fase 4. La primera configuración pedía abrir varias pantallas en orden y los
permisos de macOS aparecían a mitad de un flujo (el de reconocimiento de voz, al llegar la primera nota
de voz).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configurar sin editar archivos (Priority: P1)

La persona abre Hirebar por primera vez y un asistente la lleva por su nombre, la IA, Telegram, los
agentes y los permisos.

**Independent Test**: con una instalación nueva, el asistente se abre solo y al terminarlo el panel no
muestra pasos esenciales pendientes.

**Acceptance Scenarios**:

1. **Given** una instalación sin nombre, sin IA probada o sin Telegram conectado, **When** arranca
   Hirebar, **Then** se abre el asistente; si la persona ya lo cerró con "Terminar", no se vuelve a
   abrir solo.
2. **Given** el paso del motor de IA, **When** la persona elige una IA y pulsa **Probar**, **Then**
   Hirebar guarda la elección y la marca como probada solo si respondió; cambiar de IA vuelve a pedir
   la prueba.
3. **Given** el paso de Telegram, **When** la persona pega el token, escribe "hola" y confirma, **Then**
   el bot queda anclado igual que desde Ajustes.
4. **Given** el paso de agentes, **When** prende o apaga uno, **Then** queda guardado al momento.

### User Story 2 - Permisos pedidos en el asistente (Priority: P1)

**Acceptance Scenarios**:

1. **Given** el paso de permisos, **When** la persona pulsa **Permitir** en reconocimiento de voz o en
   notificaciones, **Then** macOS pide el permiso ahí y la fila muestra si quedó permitido o negado.
2. **Given** un permiso negado, **When** se muestra, **Then** se indica dónde activarlo en Ajustes del
   Sistema.

### User Story 3 - Lo que falta, visible en el panel (Priority: P2)

**Acceptance Scenarios**:

1. **Given** pasos pendientes, **When** se abre el panel, **Then** aparece "Falta configurar" con cada
   paso y un acceso al asistente; sin pendientes, la sección no aparece.
2. **Given** ninguna cuenta de contenido con video, **When** se calcula lo pendiente, **Then** el
   permiso de reconocimiento de voz no se pide.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Lo que falta configurar MUST calcularse en `HirebarApplication` (`SetupChecklist`) a
  partir de hechos (`SetupFacts`), sin E/S.
- **FR-002**: Los permisos MUST consultarse y pedirse por el puerto `SystemPermissions`.
- **FR-003**: La IA MUST contar como probada solo para el motor que pasó la prueba (`verifiedEngine`).
- **FR-004**: El asistente MUST abrirse solo mientras falte un paso esencial (nombre, IA probada,
  Telegram) y la persona no lo haya terminado (`setupDismissed`).

## Success Criteria *(mandatory)*

- **SC-001**: Una instalación nueva queda lista sin editar ningún JSON.
- **SC-002**: Tests de cada regla de `SetupChecklist` y de la persistencia de `verifiedEngine` y
  `setupDismissed`.
