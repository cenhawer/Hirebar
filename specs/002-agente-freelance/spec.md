# Feature Specification: Agente Freelance

**Feature Branch**: `docs/spec-002-agente-freelance`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is: describe lo que el agente Freelance hace hoy en el commit base de `develop`,
para que sirva de referencia contra regresiones. Las desviaciones de la constitución se listan al
final con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recibir proyectos que encajan (Priority: P1)

La persona quiere enterarse por Telegram de los proyectos freelance recién publicados en Workana y
Freelancer que encajan con su perfil, con poca competencia y presupuesto suficiente, antes de que
se llenen de propuestas.

**Why this priority**: es la razón de ser del agente; sin esto no hay propuestas que enviar.

**Independent Test**: con fixtures de Workana y Freelancer y un perfil de prueba, una búsqueda
produce una lista con los proyectos que pasan los filtros y respetan los cupos.

**Acceptance Scenarios**:

1. **Given** el agente prendido y al menos una plataforma activa con cupo, **When** se cumple el
   intervalo de búsqueda, **Then** se consultan las plataformas activas con cupo y se avisa una
   lista si algo pasó los filtros.
2. **Given** un proyecto en inglés, **When** se busca, **Then** no aparece.
3. **Given** un proyecto con una palabra bloqueada en cualquier parte, una palabra bloqueada o
   prohibida en el título, o un bot de WhatsApp de respuestas automáticas, **When** se busca,
   **Then** no aparece.
4. **Given** un proyecto con al menos dos términos fuertes en el título y las habilidades, **When**
   se busca, **Then** aparece marcado ENCAJA.
5. **Given** un proyecto ENCAJA de Workana con más de 35 propuestas, o RETO con más de 20, **When**
   se busca, **Then** no aparece.
6. **Given** un proyecto de Workana publicado hace más de 3 horas con más de 12 propuestas, **When**
   se busca, **Then** no aparece.
7. **Given** una plataforma con cupo agotado, **When** se busca, **Then** no se consulta y el panel
   indica "<plataforma> sin cupos".
8. **Given** que quedan 2 propuestas de cupo en Workana, **When** se arma la lista, **Then** incluye
   como máximo 2 proyectos de Workana.
9. **Given** un proyecto que ya se vio en una búsqueda anterior, **When** se vuelve a buscar dentro
   de los 14 días siguientes, **Then** no se vuelve a avisar.

---

### User Story 2 - Aprobar y que la IA envíe las propuestas (Priority: P1)

La persona aprueba la lista y la IA analiza la competencia, pone precio, redacta y envía cada
propuesta con su sesión, y le reporta el resultado con los cupos que quedan.

**Why this priority**: convierte los avisos en propuestas, que es el resultado que busca la persona.

**Independent Test**: con dobles de `AIRunner` y `Messenger`, aprobar una lista arma una ejecución
con los proyectos elegidos, el cupo diario y las reglas de propuestas, y publica el resumen.

**Acceptance Scenarios**:

1. **Given** una lista pendiente de menos de 24 horas, **When** la persona responde `si`, `si 1 3`
   o pulsa "Sí, enviar todas", **Then** la IA recibe los proyectos elegidos con la orden de enviar
   sin volver a preguntar.
2. **Given** una lista pendiente, **When** la persona responde `no`, **Then** la lista queda
   descartada.
3. **Given** el envío automático del agente prendido, **When** una búsqueda produce una lista,
   **Then** se aprueba sola completa y el aviso lo indica.
4. **Given** un proyecto aprobado, **When** la IA lo procesa, **Then** cotiza entre el promedio de la
   competencia y un 20% por debajo, o propone una fase 1 si el presupuesto no alcanza.
5. **Given** un proyecto cerrado, "Esperando depósito", solo para Preferred Freelancers o deshonesto,
   **When** la IA lo revisa, **Then** lo marca DESCARTADA con motivo y no envía nada.
6. **Given** una ejecución terminada, **When** la IA responde, **Then** llega a Telegram el estado
   de cada proyecto (ENVIADA con precio, plazo y competencia; PENDIENTE o DESCARTADA con motivo) y
   los cupos que quedan.

---

### User Story 3 - Seguimientos y respuestas de clientes (Priority: P2)

Dos veces al día, la IA revisa las propuestas activas: si un cliente respondió, se lo muestra a la
persona con una respuesta propuesta; si a las 48 horas no hay respuesta, propone un seguimiento con su
texto. Nada se envía sin aprobación.

**Why this priority**: una propuesta sin seguimiento pierde contra la competencia; una respuesta de
cliente sin atender pierde el proyecto.

**Independent Test**: con un doble de `AIRunner`, la tarea se lanza a las horas configuradas y su
respuesta llega a Telegram salvo que empiece con `SIN_NOVEDADES`.

**Acceptance Scenarios**:

1. **Given** el agente prendido, **When** llega una hora de la tarea "Seguimientos de propuestas"
   (10 y 16 h por defecto, con 3 horas de tolerancia), **Then** la IA revisa `seguimiento.json`.
2. **Given** un cliente que respondió, **When** la IA lo detecta, **Then** propone una respuesta con
   su texto que nunca se aprueba sola, aunque el envío automático esté prendido.
3. **Given** una propuesta enviada hace 48 horas, sin respuesta, con el proyecto abierto y algo nuevo
   que aportar, **When** la IA la revisa, **Then** propone un único seguimiento con su texto; se envía
   con exactamente ese texto al aprobarlo o con el envío automático de Freelance.
4. **Given** que es después de las 15 h, **When** corre la tarea, **Then** la IA también revisa el
   estado de las postulaciones de empleo de los últimos 21 días.
5. **Given** que no hubo nada, **When** la IA responde `SIN_NOVEDADES`, **Then** no se envía nada
   por Telegram.

---

### User Story 4 - Revisar los portales freelance que agregó la persona (Priority: P2)

Igual que en Empleo (spec `001-agente-empleo`, historia 3), con los portales freelance propios y la
tarea "Revisar tus portales freelance" (9, 13 y 17 h por defecto).

**Why this priority**: amplía la cobertura a plataformas sin adaptador (por ejemplo, Upwork).

**Independent Test**: con un doble de `AIRunner` que deja hallazgos fijos, la tarea produce una lista
pendiente y no envía nada.

**Acceptance Scenarios**:

1. **Given** al menos un portal freelance propio activo, **When** llega la hora de la tarea,
   **Then** la IA los revisa con la orden de no enviar y los hallazgos llegan como lista pendiente.

---

### User Story 5 - Configurar el agente y ver los cupos (Priority: P3)

La persona prende o apaga el agente, cambia la frecuencia, las plataformas activas, el cupo diario y
el horario, y ve en el panel los cupos de cada plataforma.

**Why this priority**: ajusta el agente, pero funciona con los valores por defecto.

**Independent Test**: cambiar cada ajuste y verificar que la siguiente búsqueda o tarea lo usa; con
un `cupos.json` de prueba, el panel muestra los cupos y su renovación.

**Acceptance Scenarios**:

1. **Given** el agente prendido, **When** la persona lo apaga, **Then** no se busca ni se ejecutan
   sus tareas, y el panel muestra "apagado".
2. **Given** que la persona pone 10 minutos de frecuencia en Ajustes, **When** guarda, **Then** se
   guarda 15, que es el mínimo.
3. **Given** un `cupos.json` con cupos de Workana y Freelancer, **When** se abre el detalle del
   agente, **Then** se ven los restantes, el total y la fecha de renovación de cada uno.
4. **Given** que pasó la fecha de renovación, **When** se consulta el cupo, **Then** se muestra
   "renovado (sin contar)" y la plataforma vuelve a consultarse.

---

### Edge Cases

- Una plataforma no responde: se pasa a la siguiente.
- Las dos plataformas están sin cupo: no se busca y el panel lo indica.
- `cupos.json` no tiene datos de una plataforma: se busca sin límite de cupo para ella.
- No se puede leer la página de un proyecto de Workana: el proyecto se descarta en esa búsqueda.
- La sesión de la IA venció, una ejecución pasa de una hora o la app se reinicia con una lista en
  curso: igual que en Empleo (spec `001-agente-empleo`).
- Telegram no está configurado: igual que en Empleo.

## Requirements *(mandatory)*

### Functional Requirements

**Búsqueda**

- **FR-001**: El agente MUST buscar en Workana y Freelancer, si están activas y con cupo, cada
  `searchEveryMinutes` minutos (20 por defecto; Ajustes no deja bajar de 15), empezando 1 minuto
  después de abrir la app.
- **FR-002**: Workana MUST usar las consultas de `search-profile.json` en español y considerar solo
  proyectos de las últimas 12 horas; Freelancer MUST leer las 300 publicaciones activas más
  recientes en español y considerar solo las de las últimas 24 horas.
- **FR-003**: El clasificador MUST descartar el proyecto si está en inglés, si tiene una palabra
  bloqueada en cualquier parte, una palabra bloqueada o prohibida en el título, un bot de WhatsApp
  de respuestas automáticas en el título, términos fuera de perfil en el título, un stack bloqueado
  con menos de tres términos fuertes en el título, o es solo de frontend sin términos fuertes.
- **FR-004**: El clasificador MUST marcar ENCAJA con dos términos fuertes en el título, o uno en el
  título y dos en total sin términos de reto en el título, o cuatro en total sin reto en el título
  ni términos fuera de perfil; MUST marcar RETO cuando hay al menos un término fuerte o de reto en
  el título y dos en total, o dos fuertes en total sin términos fuera de perfil.
- **FR-005**: Las habilidades del perfil MUST alimentar el clasificador: "domino" se suma a los
  fuertes, "conozco" a los de reto y "evito" a las palabras bloqueadas del título.
- **FR-006**: Workana MUST descartar presupuestos "menos de USD 15" o "menos de USD 50" y proyectos
  "Esperando depósito"; Freelancer MUST descartar proyectos no públicos, solo para Preferred
  Freelancers, inactivos, y los que no alcanzan `minHourlyUSD` (por hora) o `minFixedUSD` (precio
  fijo).
- **FR-007**: El agente MUST descartar por competencia: en Workana, ENCAJA con más de 35 propuestas,
  RETO con más de 20, o más de 12 propuestas con más de 3 horas de publicado; en Freelancer, ENCAJA
  con más de 80 ofertas o RETO con más de 60.
- **FR-008**: El agente MUST avisar como máximo 5 proyectos por búsqueda, ordenados por encaje y
  competencia, sin pasar los cupos restantes de cada plataforma.
- **FR-009**: El agente MUST recordar durante 14 días los proyectos vistos y no volver a avisarlos.
- **FR-010**: El aviso MUST numerar cada proyecto con su encaje, título, detalle (plataforma,
  antigüedad, propuestas u ofertas, presupuesto, pago verificado) y enlace, mostrar los cupos y
  ofrecer los botones "Sí, enviar todas" y "No".

**Cupos**

- **FR-011**: Los cupos MUST leerse de `cupos.json` (restantes, total, renovación, última revisión),
  que actualiza la IA con lo que muestra cada plataforma.
- **FR-012**: Si no hay fecha de renovación, Workana MUST renovar 7 días después de la última
  revisión y Freelancer el día 14 de cada mes.
- **FR-013**: Una plataforma con cupo agotado y sin renovar MUST quedar fuera de la búsqueda.

**Propuestas**

- **FR-014**: La aprobación, la cola y el envío automático MUST funcionar como en Empleo (spec
  `001-agente-empleo`, FR-012 a FR-014).
- **FR-015**: La IA MUST recibir los proyectos elegidos, el cupo diario del agente (5 por defecto) y
  las reglas de `instrucciones-freelance.md`: precio entre el promedio de la competencia y un 20% por
  debajo o una fase 1, texto de 100 a 150 palabras con el riesgo concreto del proyecto, cómo lo
  haría, un resultado real de `perfil.md`, precio y plazo, y una pregunta técnica; sin emojis ni
  datos de contacto externos.
- **FR-016**: La IA MUST registrar cada propuesta en `historial-propuestas.md`, agregar las enviadas
  a `seguimiento.json`, actualizar `cupos.json` y sumar sus números en `metricas-claude.json`.

**Seguimientos**

- **FR-017**: La tarea "Seguimientos de propuestas" MUST correr a las horas configuradas (10 y 16 h
  por defecto, con 3 horas de tolerancia) y seguir `instrucciones-seguimiento.md`.
- **FR-018**: La IA MUST proponer como máximo un seguimiento por propuesta, a las 48 horas, solo si
  aporta algo nuevo y el proyecto sigue abierto; la tarea "Enviar seguimientos aprobados" MUST enviar
  solo los aprobados, con el texto aprobado.
- **FR-019**: Las respuestas de clientes MUST llegar a Telegram como propuestas con su texto y nunca se
  aprueban ni se envían solas.

**Portales propios, configuración y estado**

- **FR-020**: La tarea "Revisar tus portales freelance" MUST funcionar como la de Empleo (spec
  `001-agente-empleo`, FR-017 y FR-018).
- **FR-021**: La persona MUST poder prender o apagar el agente y cambiar la frecuencia, las
  plataformas activas, el cupo diario, el horario y el envío automático desde el panel, Ajustes o
  Telegram.
- **FR-022**: El panel MUST mostrar la última búsqueda (con las plataformas sin cupo), la próxima
  ejecución, los números de la semana y los cupos de cada plataforma con su renovación.

### Key Entities

- **Proyecto (Hit)**: identificador por plataforma, plataforma, encaje, título, enlace, detalle y
  competencia.
- **Perfil de búsqueda freelance (FreelanceProfile)**: consultas de Workana, términos fuertes y de
  reto, palabras bloqueadas, prohibidas y fuera de perfil, stack bloqueado, frontend, palabras de bot
  de WhatsApp, presupuesto mínimo fijo y por hora.
- **Cupo (PlatformQuota)**: restantes, total, renovación y última revisión por plataforma.
- **Propuesta en seguimiento**: plataforma, título, enlace, fecha de envío, leída, respondió,
  seguimientos y estado; vive en `seguimiento.json`.
- **Lista (Batch)**, **Habilidad (Skill)**, **Ajustes del agente (AgentSettings)** y **Portal propio
  (CustomPortal)**: como en la spec `001-agente-empleo`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un proyecto que encaja aparece en Telegram en la primera búsqueda después de su
  publicación (a lo sumo `searchEveryMinutes` minutos más el tiempo de la búsqueda).
- **SC-002**: Ningún proyecto se avisa dos veces dentro de 14 días.
- **SC-003**: Ningún proyecto avisado viola un filtro de idioma, palabras, presupuesto o competencia,
  contra los fixtures de cada plataforma.
- **SC-004**: Ninguna lista supera 5 proyectos ni el cupo restante de una plataforma.
- **SC-005**: Ninguna respuesta de cliente se contesta sin la persona.
- **SC-006**: Con el envío automático apagado, ninguna propuesta de una lista se envía sin un `si`.

## Assumptions

- La persona tiene sesión iniciada en Workana y Freelancer en su Chrome.
- Workana entrega los resultados de búsqueda embebidos en la página y Freelancer expone su API
  pública de proyectos activos sin iniciar sesión.
- El tipo de cambio de Freelancer viene con cada proyecto y se usa para pasar el presupuesto a USD.
- Los valores numéricos de esta spec son los del código actual; la spec
  `024-textos-y-valores-fuera-del-codigo` los lleva a configuración.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| Sin modo práctica | II | `014-modo-practica` |
| Los proyectos vistos se guardan en `UserDefaults` | IV | `022-version-datos` |
| Intervalos, máximos de competencia, presupuestos mínimos, ventanas y listas de idioma escritos en el código | VI | `024-textos-y-valores-fuera-del-codigo` |
| El motor del agente no tiene tests | VII | `019-tests-engine` |

## Hallazgos sin principio asociado

- Workana y Freelancer arman una lista de proyectos "de respaldo" que la búsqueda nunca usa: es
  código sin efecto. Se resuelve en `020-partir-archivos`, eliminándolo o usándolo según lo que diga
  esa spec.
