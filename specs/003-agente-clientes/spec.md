# Feature Specification: Agente Clientes

**Feature Branch**: `docs/spec-003-agente-clientes`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is: describe lo que el agente Clientes hace hoy en el commit base de `develop`,
para que sirva de referencia contra regresiones. Las desviaciones de la constitución se listan al
final con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recibir cada día la lista de correos a empresas y negocios (Priority: P1)

De lunes a viernes, la IA busca empresas donde la persona podría trabajar y negocios que podrían
necesitar software, redacta un correo corto para cada uno y le manda la lista por Telegram para que
la apruebe. En esta tarea no envía nada.

**Why this priority**: es el trabajo del agente; sin la lista no hay correos que aprobar.

**Independent Test**: con un doble de `AIRunner` que deja una lista fija en
`prospeccion/pendientes.json`, la tarea termina con esa lista en Telegram y sin ningún envío.

**Acceptance Scenarios**:

1. **Given** el agente prendido, **When** llega la hora de la tarea "Buscar empresas y negocios"
   (7 h, lunes a viernes, con 12 horas de tolerancia), **Then** la IA recibe la orden de preparar la
   lista del día y de no enviar ningún correo.
2. **Given** que la IA encontró empresas y negocios, **When** termina, **Then** la lista numerada
   (número, tipo, nombre y asunto) llega a Telegram con las respuestas de interés primero.
3. **Given** una empresa donde la persona ya trabajó, o que recibió un correo en los últimos 30 días,
   **When** la IA arma la lista, **Then** no la incluye.
4. **Given** una empresa sin correo de contacto público, **When** la IA arma la lista, **Then** no la
   incluye: nunca usa correos adivinados.
5. **Given** que alguien respondió con interés a un correo anterior, **When** la IA revisa Gmail,
   **Then** lo agrega a la lista como RESPUESTA con un borrador.
6. **Given** que no hay nada que proponer, **When** la IA termina, **Then** no se crea la lista.

---

### User Story 2 - Aprobar y enviar los correos (Priority: P1)

La persona aprueba todos los correos, algunos o ninguno, y la IA los envía desde su Gmail
exactamente como estaban en la lista.

**Why this priority**: convierte la lista en contactos reales.

**Independent Test**: `envia correos 1 3` aprueba esos números de la copia que la app guardó al
mostrar la lista y lanza el envío solo con ellos; `no correos` aparta la lista y no lanza nada.

**Acceptance Scenarios**:

1. **Given** una lista de correos del día, **When** la persona responde `envia correos`, **Then**
   se aprueban todos y la IA los envía.
2. **Given** una lista de correos, **When** la persona responde `envia correos 1 3`, **Then** la IA
   envía solo el 1 y el 3.
3. **Given** una lista de correos, **When** la persona responde `no correos`, **Then** no se envía
   nada y la lista se guarda aparte como descartada.
4. **Given** que no hay lista de correos, **When** la persona responde `envia correos`, **Then** se
   le responde que no hay correos pendientes.
5. **Given** correos aprobados, **When** la IA los envía, **Then** usa exactamente el destinatario,
   el asunto y el cuerpo de la lista, sin agregar destinatarios ni cambiar el texto.
6. **Given** un envío terminado, **When** la IA responde, **Then** llega a Telegram cuántos se
   enviaron por tipo y cuáles fallaron, y la lista queda vacía para que no se envíe dos veces.

---

### User Story 3 - Envío automático de seguimientos (Priority: P2)

Con el envío automático del agente prendido (con confirmación, spec `011`), los seguimientos a
empresas que ya recibieron un correo verificado se envían solos; los correos en frío y las respuestas
siempre esperan la aprobación.

**Why this priority**: ahorra el paso de aprobar seguimientos a contactos conocidos sin dejar salir
solo un correo a alguien nuevo.

**Independent Test**: con el envío automático prendido y una lista con tipos EMPRESA, NEGOCIO,
SEGUIMIENTO y RESPUESTA, solo se aprueban solos los SEGUIMIENTO a destinos ya contactados.

**Acceptance Scenarios**:

1. **Given** el envío automático prendido, **When** la lista está lista, **Then** se envían solos los
   seguimientos a destinos que ya recibieron un correo verificado del agente.
2. **Given** el envío automático prendido, **When** la lista trae correos en frío o respuestas,
   **Then** llegan en una lista aparte que espera tu "si".
3. **Given** el envío automático apagado, **When** la lista está lista, **Then** llega con
   destinatario, asunto y texto completos y no se envía nada sin `envia correos`.

---

### User Story 4 - Configurar el agente (Priority: P3)

La persona prende o apaga el agente, cambia el horario y el envío automático.

**Why this priority**: ajusta el agente, pero funciona con los valores por defecto.

**Independent Test**: cambiar cada ajuste y verificar que la siguiente tarea lo usa.

**Acceptance Scenarios**:

1. **Given** el agente prendido, **When** la persona lo apaga (interruptor, Ajustes o
   `agente clientes off`), **Then** no se ejecuta la tarea.
2. **Given** que la persona escribe `corre clientes`, **When** se procesa, **Then** la tarea corre en
   ese momento.
3. **Given** que la persona escribe `auto clientes si`, **When** se procesa, **Then** el envío
   automático queda prendido.

---

### Edge Cases

- El correo de la persona no tiene sesión en Chrome: la IA no puede enviar y lo reporta en la
  respuesta final.
- Se responde `envia correos` cuando la lista del día anterior sigue sin enviar: se envía esa lista.
- `si correos`, `ok correos`, `dale correos` y `aprueba correos` aprueban la lista igual que
  `envia correos`; `no correos` la descarta.
- La sesión de la IA venció, una ejecución pasa de una hora o la app se reinicia durante un envío:
  igual que en Empleo (spec `001-agente-empleo`).

## Requirements *(mandatory)*

### Functional Requirements

**Lista del día**

- **FR-001**: La tarea "Buscar empresas y negocios" MUST correr a las horas configuradas (7 h por
  defecto), solo de lunes a viernes, con 12 horas de tolerancia si la Mac estaba dormida.
- **FR-002**: La IA MUST recibir la orden explícita de no enviar ningún correo en esta tarea.
- **FR-003**: La IA MUST incluir solo empresas y negocios reales con correo de contacto público,
  excluir empresas donde la persona trabajó y las que recibieron un correo en los últimos 30 días.
- **FR-004**: Cada correo MUST ser de 5 a 7 líneas: por qué esa empresa, qué puede aportar la persona
  con un resultado real de `perfil.md`, una pregunta y la línea de baja "Si no te interesa, responde
  'no' y no te vuelvo a escribir."
- **FR-005**: La IA MUST revisar Gmail y agregar las respuestas con interés como tipo RESPUESTA con un
  borrador.
- **FR-006**: La lista MUST quedar en `prospeccion/pendientes.json` con fecha y, por correo: número,
  tipo (EMPRESA, NEGOCIO, SEGUIMIENTO, RESPUESTA), nombre, web, correo, asunto y cuerpo.
- **FR-007**: La lista numerada MUST llegar a Telegram con las respuestas de interés primero.

**Aprobación y envío**

- **FR-008**: La persona MUST poder aprobar todos los correos (`envia correos`), algunos
  (`envia correos 1 3`) o ninguno (`no correos`).
- **FR-009**: Al aprobar, la app MUST guardar lo aprobado de la copia que mostró (destinatario, asunto
  y texto) fuera del workspace y lanzar la tarea "Enviar correos aprobados" con esos correos en el
  pedido.
- **FR-010**: Al descartar, la app MUST guardar la lista como `prospeccion/descartados-<marca>.json`
  y no lanzar ningún envío.
- **FR-011**: La IA MUST enviar solo los aprobados, desde el Gmail de la persona, exactamente con el
  destinatario, asunto y cuerpo de la lista.
- **FR-012**: La IA MUST registrar cada envío en `prospeccion/prospectos.md`, vaciar
  `pendientes.json` al terminar y sumar los envíos en `metricas-claude.json`.

**Envío automático**

- **FR-013**: Con el envío automático prendido, la app MUST aprobar solos solo los seguimientos a
  destinos con un correo verificado previo del agente.
- **FR-014**: Los correos en frío y los de tipo RESPUESTA MUST esperar siempre la aprobación de la
  persona.
- **FR-014a**: El envío MUST incluir solo los correos aprobados que caben en el cupo diario de Clientes
  (10 por defecto); los demás quedan sin enviar.

**Configuración**

- **FR-015**: La persona MUST poder prender o apagar el agente, cambiar el horario y el envío
  automático desde el panel, Ajustes o Telegram, y correrlo ya con `corre clientes`.

### Key Entities

- **Correo propuesto**: número, tipo (EMPRESA, NEGOCIO, SEGUIMIENTO, RESPUESTA), nombre, web, correo,
  asunto y cuerpo; vive en `prospeccion/pendientes.json` hasta que se envía o se descarta.
- **Aprobación**: los correos aprobados de la lista mostrada; viven en `estado/aprobados/<lote>.json`,
  fuera del workspace.
- **Prospecto contactado**: fecha, empresa, correo y tipo; vive en `prospeccion/prospectos.md`.
- **Ajustes del agente (AgentSettings)**: como en la spec `001-agente-empleo`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ningún correo se envía durante la tarea de búsqueda.
- **SC-002**: Ningún correo enviado difiere en destinatario, asunto o cuerpo del que estaba en la
  lista aprobada.
- **SC-003**: Ninguna empresa recibe dos correos dentro de 30 días.
- **SC-004**: Ningún correo de tipo RESPUESTA se envía sin la aprobación de la persona, con o sin
  envío automático.
- **SC-005**: Con el envío automático apagado, ningún correo se envía sin un `envia correos`.
- **SC-006**: Una lista enviada no se vuelve a enviar.

## Assumptions

- La persona tiene sesión iniciada en Gmail en su Chrome.
- La IA encuentra los correos de contacto en las páginas públicas de cada empresa o negocio.
- La persona es responsable de que el envío de correos en frío cumpla las normas de su país; la
  línea de baja en cada correo es la única medida que aplica hoy el agente.
- Los valores numéricos de esta spec son los del código actual; la spec
  `024-textos-y-valores-fuera-del-codigo` los lleva a configuración.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| La aprobación de correos no tiene una vista de historia para la persona | II | `028-vista-actividad` |
| Las listas descartadas (`descartados-<marca>.json`) no tienen retención | IV | `029-politica-datos` |
| El motor del agente no tiene tests | VII | `019-tests-engine` |

## Hallazgos sin principio asociado

- `si`, `ok` y `no` se usan tanto para listas de avisos como para correos (anti-patrón de
  `AGENTS.md`). Se resuelve en `013-parser-comandos`.
