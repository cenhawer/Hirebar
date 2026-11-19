# Feature Specification: Fiverr y un filtro freelance más abierto

**Feature Branch**: `feature/HB-038-fiverr-freelance`

**Created**: 2026-11-17

**Status**: Draft

**Input**: Recupera el cambio local "add fiver" (rama `respaldo/add-fiver`), escrito sobre la
estructura anterior a la v0.2.0 y que no entró en la release. La persona quiere más propuestas
freelance enviadas y quiere enterarse de lo que pasa en su cuenta de vendedor de Fiverr sin que
Hirebar escriba ahí.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fiverr se revisa en los seguimientos, solo para leer (Priority: P1)

**Independent Test**: con Fiverr prendido, el mensaje de la revisión de seguimientos pide revisar
Fiverr según el punto 5 de las reglas; con Fiverr apagado, pide saltarlo. La tarea de envío no
menciona Fiverr.

**Acceptance Scenarios**:

1. **Given** una instalación nueva, **When** la persona abre los portales de Freelance, **Then** ve
   Workana, Freelancer y Fiverr, los tres prendidos, y Fiverr no se busca como portal.
2. **Given** Fiverr prendido, **When** corre la revisión de seguimientos, **Then** el mensaje a la IA
   pide revisar también Fiverr solo para leer y avisar (punto 5 de `instrucciones-seguimiento.md`).
3. **Given** Fiverr apagado, **When** corre la revisión de seguimientos, **Then** el mensaje pide
   saltar el punto 5.
4. **Given** las reglas de seguimientos, **When** la IA revisa Fiverr, **Then** solo lee mensajes,
   pedidos y reseñas, avisa con un borrador en la respuesta final, anota en la sección `fiverr` de
   `seguimiento.json` y no pone nada de Fiverr en la lista de propuestas; la tarea corre con el
   perfil de redacción (no puede actuar).
5. **Given** la persona tiene la versión de `instrucciones-seguimiento.md` de la v0.2.0 sin editar,
   **When** arranca Hirebar, **Then** se reemplaza por la nueva; si la editó, se respeta.
6. **Given** el menú o el panel del agente Freelance, **When** se muestran, **Then** aparece el estado
   de Fiverr ("mensajes y pedidos en los seguimientos" o "apagado").

### User Story 2 - Filtro freelance más abierto (Priority: P1)

**Independent Test**: proyectos de landing en Angular/HTML/CSS, "de Excel a un sistema" e IA con
núcleo backend pasan el filtro; un proyecto de IA sin backend se descarta con su motivo.

**Acceptance Scenarios**:

1. **Given** el perfil de búsqueda por defecto, **When** llega un proyecto "Landing page en Angular
   con HTML y CSS" o "Migrar Excel a un sistema con base de datos", **Then** queda como RETO.
2. **Given** un proyecto cuyo título habla de IA y que no tiene palabras del stack fuerte en el
   título ni al menos dos en todo el texto, **When** se clasifica, **Then** se descarta con el
   motivo "IA sin backend (<palabra>)".
3. **Given** un proyecto de IA con núcleo backend (API, base de datos), **When** se clasifica,
   **Then** pasa.
4. **Given** una búsqueda en Workana o Freelancer, **When** termina, **Then** el registro tiene una
   línea con los motivos de descarte agrupados (los más frecuentes primero, con un ejemplo),
   incluidos "solo Preferred o privado", "en inglés", "pago por hora muy bajo" y "presupuesto muy
   bajo".
5. **Given** un lote freelance aprobado, **When** la IA lo envía, **Then** aplica los criterios de
   envío de `instrucciones-freelance.md` (pago no verificado, webs y landings, Excel a sistema, IA
   con backend, ante la duda enviar); el mensaje de la tarea no los repite.

### User Story 3 - Las personas que ya usan Hirebar reciben el cambio una vez (Priority: P1)

**Independent Test**: un workspace de la v0.2.0 arranca con la versión nueva y queda con el filtro
abierto, el cupo freelance en al menos 12 y un respaldo; un segundo arranque no cambia nada.

**Acceptance Scenarios**:

1. **Given** un `search-profile.json` sin versión o de la versión 1, **When** arranca Hirebar,
   **Then** se respalda en `respaldos/`, se quitan de `titleNever` y `offProfile` las palabras de
   `Resources/migraciones.json`, se agregan las de `stretch` que falten y queda en la versión 2 sin
   tocar sus demás campos.
2. **Given** `agentes/freelance.json` con un cupo diario menor que el mínimo de
   `Resources/migraciones.json`, **When** arranca, **Then** el cupo sube al mínimo; un cupo mayor o
   sin cupo no se toca, y los demás agentes no cambian.
3. **Given** la persona vuelve a agregar una palabra después de la migración, **When** arranca de
   nuevo, **Then** su cambio se respeta.
4. **Given** una instalación nueva, **When** arranca, **Then** la plantilla ya viene abierta y en la
   versión actual, y no se migra ni se respalda.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `fiverr` MUST ser una fuente freelance que se prende y apaga como Workana y
  Freelancer, con título "Fiverr", sin búsqueda propia.
- **FR-002**: La revisión de seguimientos (`followUp`, perfil de redacción) MUST pedir revisar
  Fiverr en modo lectura cuando está prendido y saltarlo cuando está apagado; la tarea de envío
  (`followUpSend`) MUST NOT actuar en Fiverr.
- **FR-003**: `Resources/inicial/instrucciones-seguimiento.md` MUST traer el punto 5 de Fiverr y la
  sección `fiverr` del registro; la versión de la v0.2.0 MUST figurar entre las versiones conocidas
  para actualizarse si no se editó. Lo mismo para `instrucciones-freelance.md`.
- **FR-004**: El perfil de búsqueda por defecto MUST quitar de `titleNever` las palabras de IA, web
  y `firebase`, quitar de `offProfile` research, investigación, catálogo y excel, y agregar a
  `stretch` página web, sitio web, landing, landing page, html, css y excel.
- **FR-005**: El cupo diario por defecto de Freelance MUST ser 12, el radar freelance MUST listar
  hasta `radares.freelance.proyectosPorLista` = 8 proyectos (`Resources/motor.json`) y Workana MUST
  aceptar proyectos de hasta `workanaMaxAgeMinutes` = 1440 minutos, con el registro en horas
  calculado desde ese valor.
- **FR-006**: `FreelanceClassifier.verdict` MUST devolver el encaje y el motivo de descarte;
  `classify` MUST delegar en él. Las palabras de IA MUST vivir en `aiWords` del perfil de búsqueda.
- **FR-007**: Workana y Freelancer MUST juntar los descartes y registrar un resumen agrupado con
  `FreelanceClassifier.summary`. Los motivos MUST pasar por el String Catalog.
- **FR-008**: La migración MUST usar el mecanismo versionado del workspace (`WorkspaceSchema`
  versión 2, respaldo previo, una sola vez), con las listas y el cupo mínimo en
  `Resources/migraciones.json`; MUST NOT usar `UserDefaults`.
- **FR-009**: Los criterios para enviar propuestas MUST vivir en
  `Resources/inicial/instrucciones-freelance.md`, no en el código.

## Success Criteria *(mandatory)*

- **SC-001**: Tests del mensaje de seguimientos con Fiverr prendido y apagado, de que la tarea que
  lee Fiverr no puede actuar y de que Fiverr no es un portal que se busca.
- **SC-002**: Tests de `verdict` (IA sin backend, IA con backend, landing, Excel a sistema, motivos)
  y de `summary` (orden, ejemplo, límite).
- **SC-003**: Tests de que Workana y Freelancer juntan sus descartes con fixtures guardados.
- **SC-004**: Tests de la migración: respaldo, listas, versión, cupo, una sola vez, instalación
  nueva y archivo `migraciones.json` inválido.
- **SC-005**: Test de que la plantilla de seguimientos de la v0.2.0 se reemplaza y una editada no.
- **SC-006**: Tests de que los criterios de envío están en `instrucciones-freelance.md` y no en el
  mensaje de la tarea, y de los valores de `motor.json`, `perfil-busqueda.json` y el cupo por
  defecto.
