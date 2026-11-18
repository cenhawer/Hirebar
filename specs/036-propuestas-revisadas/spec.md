# Feature Specification: Propuestas con segundo agente revisor

**Feature Branch**: `feature/HB-036-propuestas-revisadas`

**Created**: 2026-11-18

**Status**: Draft

**Input**: Idea tomada de `ai-job-search-dev/ai-job-search`: su comando `/apply` usa un flujo
drafter-reviewer — un agente redacta, un segundo agente con contexto nuevo investiga la empresa y
critica el borrador, y recién ahí se arma la versión final. Hirebar hoy redacta en una sola pasada
(modo `draft`, perfil de redacción) y manda eso directo a Telegram para aprobar. Esta spec agrega el
segundo paso de revisión antes de mandar a aprobar, sin tocar el perfil de ejecución ni el modelo de
aprobación existente.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recibir una propuesta ya revisada, no solo redactada (Priority: P1)

Cuando Empleo, Freelance o Clientes preparan una postulación, propuesta, seguimiento o correo, un
segundo paso revisa el borrador contra la vacante/proyecto/hilo original y el perfil de la persona
antes de que Hirebar lo mande a Telegram para aprobar, y si encuentra un problema (un dato inventado,
un tono que no calza, algo que no responde lo que pide la vacante) lo corrige o lo marca, en vez de
mandar el primer borrador tal cual.

**Why this priority**: es el valor central de la idea: hoy un borrador flojo llega igual a
aprobación y la persona es quien tiene que notar el problema leyendo con cuidado.

**Independent Test**: con un doble de `AIRunner` que devuelve un borrador fijo en el paso de
redacción y una crítica fija en el paso de revisión, la tarea termina con la versión revisada (no la
original) esperando aprobación en Telegram, y ambos pasos quedan registrados.

**Acceptance Scenarios**:

1. **Given** un borrador que el redactor preparó para una vacante, **When** corre la revisión,
   **Then** el segundo paso recibe el borrador, el texto original de la vacante y el perfil, en un
   proceso de IA nuevo y separado del que redactó (contexto nuevo, no memoria compartida).
2. **Given** que la revisión encuentra una afirmación que no está respaldada por el perfil de la
   persona, **When** termina, **Then** esa afirmación se quita o se marca antes de llegar a Telegram,
   nunca se inventa un dato nuevo para justificarla (coherente con la regla de verificación de
   contenido ya existente para Clientes y Contenido).
3. **Given** que la revisión no encuentra problemas, **When** termina, **Then** el borrador original
   llega a aprobación sin cambios y sin demora perceptible adicional más allá del tiempo del segundo
   paso de IA.
4. **Given** que el paso de revisión falla o no responde, **When** se agota el tiempo de espera,
   **Then** Hirebar manda el borrador original a aprobación con un aviso de que no se pudo revisar,
   en vez de perder la propuesta o bloquear al agente.

---

### User Story 2 - Ver qué cambió entre el borrador y la versión revisada (Priority: P2)

Cuando la revisión corrige algo, la persona puede ver qué decía el borrador original y qué quedó
distinto, para confiar en el paso nuevo en vez de recibirlo como una caja negra.

**Why this priority**: sin esto, la persona no puede auditar si la revisión mejora o empeora las
cosas, y el registro de "nada sale sin rastro" (principio II) queda incompleto para este paso nuevo.

**Independent Test**: con un borrador y una revisión que cambia una frase, el registro de la
actividad para esa propuesta guarda las dos versiones y un resumen de qué cambió, recuperable sin
tener que leer los dos archivos de la IA a mano.

**Acceptance Scenarios**:

1. **Given** una propuesta que fue corregida en revisión, **When** la persona escribe el comando
   para ver el detalle de esa propuesta, **Then** ve el resumen de qué cambió entre el borrador y la
   versión final.
2. **Given** una propuesta que no fue corregida, **When** la persona revisa el detalle, **Then** ve
   que la revisión no encontró cambios, sin ambigüedad sobre si el paso corrió o no.

---

### User Story 3 - Prender o apagar la revisión por agente (Priority: P3)

La persona prende o apaga el paso de revisión por agente (Empleo, Freelance, Clientes) desde Ajustes,
para poder medir el costo extra de tokens antes de dejarlo prendido en todos.

**Why this priority**: la persona mencionó explícitamente que le preocupa el gasto de tokens; un
paso de IA adicional por cada propuesta duplica parte del costo, así que debe poder decidir dónde
vale la pena.

**Independent Test**: con la revisión apagada para Freelance y prendida para Empleo, una propuesta
de Freelance no dispara el segundo proceso de IA y una de Empleo sí, verificable contando cuántas
veces se invocó el doble de `AIRunner`.

**Acceptance Scenarios**:

1. **Given** la revisión apagada para un agente, **When** ese agente prepara una propuesta,
   **Then** se manda a aprobación el borrador tal cual, sin segundo paso ni su costo de tokens.
2. **Given** la revisión prendida para un agente, **When** ese agente prepara una propuesta,
   **Then** corre el segundo paso como en US1.

---

### Edge Cases

- ¿Qué pasa si la revisión decide que la propuesta completa no vale la pena (ej. detecta que la
  vacante en realidad no encaja)? → la revisión no descarta nada por su cuenta: solo corrige texto.
  Descartar sigue siendo decisión de la persona en Telegram, igual que hoy (principio II: nada sale
  ni se descarta sin la persona, salvo las reglas de rechazo determinista ya existentes).
- ¿Qué pasa si el paso de revisión intenta escribir fuera de su carpeta o usar una herramienta de
  envío? → corre con el mismo perfil `draft` restringido que el redactor, sin acceso a acciones de
  envío (principio III: separar leer/redactar de actuar).
- ¿Qué pasa con el cupo diario del agente mientras corre la revisión? → la revisión no cuenta como
  un envío nuevo; el cupo se sigue contando solo en el paso de ejecución, sin cambios a
  `ExecutionPlanner`/`PlatformQuota`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Tras el paso de redacción existente (modo `draft`), Hirebar MUST lanzar un segundo
  proceso de IA independiente, con contexto nuevo (sin el historial del primer proceso), que recibe
  el borrador, el texto original de la vacante/proyecto/hilo y el perfil de la persona.
- **FR-002**: El paso de revisión MUST correr con el mismo `RunProfile.draft` del redactor (lectura y
  escritura solo en su carpeta de trabajo), nunca con `RunProfile.act`.
- **FR-003**: Si la revisión encuentra una afirmación no respaldada por el perfil, Hirebar MUST
  descartar esa afirmación de la versión final en vez de inventar un respaldo, igual que la regla ya
  vigente para Clientes y Contenido.
- **FR-004**: Si la revisión no encuentra problemas, la versión que llega a aprobación MUST ser
  idéntica al borrador original, sin reescrituras cosméticas no pedidas.
- **FR-005**: Si el paso de revisión falla o se agota el tiempo de espera (mismo límite que
  `EngineCheck.timeout` o el que defina `research.md`), Hirebar MUST mandar el borrador original a
  aprobación con un aviso explícito de que no se pudo revisar, sin bloquear al agente ni perder la
  propuesta.
- **FR-006**: El registro de actividad de cada propuesta revisada MUST guardar el borrador original,
  la versión final y un resumen de qué cambió (o que no cambió nada).
- **FR-007**: La persona MUST poder prender o apagar el paso de revisión por agente (Empleo,
  Freelance, Clientes) desde Ajustes, con el valor guardado en la configuración del agente
  (`AgentStore`), no en código.
- **FR-008**: Con la revisión apagada para un agente, Hirebar MUST comportarse exactamente como hoy:
  un solo paso de redacción, sin el costo de tokens del segundo proceso.

### Key Entities

- **ReviewedDraft**: el borrador original, la versión final y el resumen de cambios de una
  propuesta; vive junto al registro de actividad existente de esa propuesta.
- **ReviewOutcome**: resultado del paso de revisión — `approved_as_is`, `corrected` o
  `skipped_timeout` — usado para decidir qué versión llega a Telegram y qué se registra.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las propuestas de un agente con revisión prendida llegan a Telegram con una
  `ReviewedDraft` registrada (borrador + versión final + resumen), verificable con un test de
  integración sobre un doble de `AIRunner`.
- **SC-002**: Ninguna propuesta se bloquea ni se pierde cuando el paso de revisión falla: el
  borrador original siempre llega a aprobación dentro del mismo tiempo de espera ya configurado para
  los pasos de IA.
- **SC-003**: Con la revisión apagada, el número de invocaciones a `AIRunner` por propuesta vuelve a
  ser exactamente 1 (el mismo de hoy), medible contando llamadas al doble de prueba.

## Assumptions

- El segundo paso usa el mismo motor de IA configurado en Ajustes (Claude/Codex/Gemini/Otra IA, ver
  `specs/007-motor-ia`), no un motor distinto; si el motor elegido no soporta leer con navegador eso
  ya está cubierto por la limitación existente documentada en Ajustes → Motor de IA, no por esta
  spec.
- "Contexto nuevo" significa un proceso de IA separado (otra invocación del CLI), no memoria
  compartida entre redactor y revisor, siguiendo el patrón del proyecto de referencia y el principio
  III de Hirebar (fases separadas, sin estado compartido entre lectura y redacción).
- El costo adicional de tokens es aceptado por la persona por agente vía el ajuste de FR-007; esta
  spec no agrega un límite de gasto nuevo (eso, si se necesita, es una spec aparte).
