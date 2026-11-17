# Feature Specification: Agente Analista

**Feature Branch**: `docs/spec-006-agente-analista`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is: describe lo que el agente Analista hace hoy en el commit base de `develop`,
para que sirva de referencia contra regresiones. Las desviaciones de la constitución se listan al
final con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recibir el análisis de la semana (Priority: P1)

Cada domingo, la persona recibe por Telegram los números de la semana de cada agente, comparados con
la semana anterior, y un informe completo en su carpeta. El Analista solo informa: no cambia nada.

**Why this priority**: es la única vista consolidada de qué funciona y qué no.

**Independent Test**: con métricas y registros de prueba de dos semanas y un doble de `AIRunner`, la
tarea termina con el resumen en Telegram, `informes/<AAAA-SNN>.md` escrito y ningún archivo de
configuración modificado.

**Acceptance Scenarios**:

1. **Given** el agente prendido, **When** llega el domingo a las 18 h (con 30 horas de tolerancia),
   **Then** la IA recibe la orden de cerrar la semana, analizar métricas y registros de cada agente y
   escribir el informe, sin cambiar reglas, perfiles ni configuración.
2. **Given** el informe escrito, **When** termina la IA, **Then** llega a Telegram el resumen, los
   números clave por agente y la ruta del informe.
3. **Given** que la persona escribe `informe`, **When** se procesa, **Then** el análisis se arma ya.
4. **Given** el informe, **When** la persona lo abre, **Then** trae un resumen de 3 líneas, una
   sección por agente con su tabla y la comparación con la semana anterior, y observaciones que son
   hechos, no órdenes.

---

### User Story 2 - Anotar hechos para el análisis (Priority: P2)

La persona anota durante la semana cosas que Hirebar no ve (una entrevista, una llamada) y el
Analista las usa en el informe.

**Why this priority**: completa el embudo con lo que pasa fuera de los portales.

**Independent Test**: `anota entrevista con Acme el jueves` agrega un evento con fecha y semana en
`metricas-radar.json`.

**Acceptance Scenarios**:

1. **Given** que la persona escribe `anota <texto>` (o `anotar`, `nota`), **When** se procesa,
   **Then** se guarda el texto con fecha y semana, y se responde "Anotado para el informe del
   domingo."
2. **Given** que la persona escribe `anota` sin texto, **When** se procesa, **Then** se le muestra un
   ejemplo.

---

### User Story 3 - Ver los números de la semana en el panel (Priority: P2)

El panel muestra en el detalle de cada agente sus números de la semana en curso.

**Why this priority**: da una lectura rápida sin esperar al domingo.

**Independent Test**: con un `metricas-claude.json` de prueba, el detalle de cada agente muestra sus
números con las etiquetas de su embudo.

**Acceptance Scenarios**:

1. **Given** números de la semana en `metricas-claude.json`, **When** se abre el detalle de Empleo,
   Freelance o Clientes, **Then** se ve "Esta semana:" seguido de su embudo (Empleo: postuladas,
   vistas, respuestas, entrevistas; Freelance: enviadas, leídas, respuestas, ganados; Clientes:
   correos, seguimientos, respuestas).
2. **Given** un número en cero que no es el primero del embudo, **When** se muestra, **Then** se
   omite.

---

### Edge Cases

- No hay métricas de la semana: el informe lo dice y la respuesta llega igual.
- La sesión de la IA venció o la ejecución pasa de una hora: igual que en Empleo (spec
  `001-agente-empleo`).
- El domingo la Mac está apagada: el análisis corre al despertar si no pasaron 30 horas.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La tarea "Análisis semanal" MUST correr a las horas configuradas (domingo 18 h por
  defecto, con 30 horas de tolerancia) y con `informe`.
- **FR-002**: La IA MUST recibir la orden explícita de solo analizar: no cambiar reglas, perfiles,
  agentes ni configuración, y no proponer cambios automáticos; sus permisos MUST limitarla a escribir en
  `informes/`.
- **FR-003**: La IA MUST leer `metricas-radar.json`, `metricas-claude.json`, `seguimiento.json`,
  `historial-propuestas.md`, `postulaciones.md`, `lotes.json`, `cupos.json`,
  `prospeccion/prospectos.md` y `agentes/*.json`.
- **FR-004**: La IA MUST medir, por agente, el embudo definido en `instrucciones-semanal.md` y
  compararlo con la semana anterior.
- **FR-005**: La IA MUST escribir `informes/<AAAA-SNN>.md` (semana ISO) y responder un resumen de
  máximo 2.000 caracteres con la ruta del informe.
- **FR-006**: `anota <texto>` MUST guardar el texto con fecha y semana en los eventos de
  `metricas-radar.json`.
- **FR-007**: La app MUST contar por semana en `metricas-radar.json` los avisados, los avisados RETO,
  los aprobados y las listas descartadas de Empleo y Freelance.
- **FR-008**: El panel MUST mostrar en el detalle de Empleo, Freelance y Clientes los números de la
  semana en curso tomados de `metricas-claude.json`.
- **FR-009**: Los domingos desde la hora de limpieza, o el lunes, con la IA libre, la app MUST
  ejecutar una vez por semana la limpieza de datos.

### Key Entities

- **Semana**: clave ISO `AAAA-SNN`.
- **Métricas de la app**: por semana y tipo de tarea, contadores de avisados, RETO, aprobados y listas
  descartadas; más la lista de eventos anotados.
- **Métricas de la IA**: por semana y sección (empleo, freelance, prospección), los contadores que
  suma la IA al terminar cada tarea.
- **Informe**: `informes/<AAAA-SNN>.md`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El análisis no modifica ningún archivo fuera de `informes/`.
- **SC-002**: Cada informe compara cada número con la semana anterior cuando hay datos de ambas.
- **SC-003**: Una nota anotada aparece en los eventos de su semana.
- **SC-004**: El análisis corre una vez por semana aunque la Mac haya estado dormida el domingo,
  dentro de la tolerancia.

## Assumptions

- Las métricas de la IA dependen de que cada tarea las sume al terminar; si una tarea no las sumó, el
  informe no las tiene.
- Los valores numéricos de esta spec son los del código actual; la spec
  `024-textos-y-valores-fuera-del-codigo` los lleva a configuración.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| Las métricas de Clientes y Contenido solo existen si la IA las anota; la app no cuenta sus listas ni sus envíos | II | `028-vista-actividad` |
| Las métricas no tienen `schemaVersion` | IV | `022-version-datos` |
| Los eventos anotados y los informes no tienen retención | IV | `029-politica-datos` |
| Las etiquetas del embudo están escritas en el código | VI | `024-textos-y-valores-fuera-del-codigo` |
| El flujo del análisis no tiene tests | VII | `019-tests-engine` |

## Hallazgos sin principio asociado

- `instrucciones-semanal.md` le indica a la IA leer `linkedin/`, pero el agente Contenido guarda todo
  en `contenido/<cuenta>/`: hoy el Analista no ve las publicaciones. Se corrige en
  `024-textos-y-valores-fuera-del-codigo`, junto con las demás rutas escritas en las reglas.
