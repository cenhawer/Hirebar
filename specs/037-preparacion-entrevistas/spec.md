# Feature Specification: Preparación de entrevista

**Feature Branch**: `feature/HB-037-preparacion-entrevistas`

**Created**: 2026-11-18

**Status**: Draft

**Input**: Idea tomada de `ai-job-search-dev/ai-job-search`: su comando `/interview` genera un
paquete de preparación por fase y puede simular una entrevista. Hirebar hoy no tiene nada de esto;
el Analista (`specs/006-agente-analista`) ya informa a la persona en modo solo lectura/redacción sin
enviar nada, así que esta funcionalidad se agrega como un nuevo comando de ese mismo agente, sin
crear un agente nuevo ni tocar los que envían o postulan.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pedir el paquete de preparación para una postulación concreta (Priority: P1)

Cuando a la persona la llaman a entrevista por una vacante que postuló con Hirebar, escribe
`entrevista <identificador o palabras de la vacante>` en Telegram y recibe un documento con lo
necesario para prepararse: resumen de la vacante y la empresa, preguntas probables según el rol, y
los puntos de su propio perfil que más conectan con lo que pide esa vacante.

**Why this priority**: es el valor principal de la idea — hoy la persona prepara entrevistas a mano,
sin ayuda de lo que Hirebar ya sabe de la vacante y de su propio perfil.

**Independent Test**: con una vacante ya registrada en el historial de postulaciones y un doble de
`AIRunner` en modo lectura, el comando termina con un archivo Markdown en
`entrevistas/<identificador>.md` y su resumen llegando a Telegram, sin enviar ni escribir nada fuera
de esa carpeta.

**Acceptance Scenarios**:

1. **Given** una vacante que la persona postuló antes con Empleo o Freelance, **When** escribe
   `entrevista <identificador>`, **Then** la IA lee la vacante original guardada, el perfil de la
   persona y, si hace falta, revisa información pública de la empresa con el navegador, y prepara el
   documento sin postular, enviar ni comentar nada.
2. **Given** que el documento quedó listo, **When** termina, **Then** Hirebar manda a Telegram un
   resumen corto (de qué vacante es, cuántas preguntas trae) y la ruta del archivo completo.
3. **Given** que la persona escribe `entrevista` sin identificador y tiene una sola postulación
   activa en entrevista, **When** se procesa, **Then** se usa esa postulación sin pedir más datos.
4. **Given** que la persona escribe `entrevista` sin identificador y tiene varias postulaciones
   activas, **When** se procesa, **Then** Hirebar pide que especifique cuál, listando las que tiene.
5. **Given** que no hay ninguna vacante que coincida con lo que la persona escribió, **When** se
   procesa, **Then** Hirebar avisa que no la encontró y no inventa un documento sobre una vacante
   que no existe en su historial.

---

### User Story 2 - Simular una ronda de entrevista por texto (Priority: P2)

Después de tener el paquete de preparación, la persona le pide a Hirebar que simule una ronda de
entrevista por Telegram: la IA hace preguntas una por una en el rol de entrevistador, la persona
responde por texto, y al final recibe comentarios sobre sus respuestas.

**Why this priority**: practicar es tan valioso como tener las preguntas, pero depende de que el
paquete de preparación (US1) ya exista.

**Independent Test**: con un paquete de preparación ya generado y un doble de `AIRunner`, el comando
de simular entrevista intercambia 3 turnos de pregunta/respuesta por Telegram y termina con un
comentario final, sin acciones de envío ni escritura fuera de la carpeta de la entrevista.

**Acceptance Scenarios**:

1. **Given** un paquete de preparación ya generado, **When** la persona escribe `simula entrevista
   <identificador>`, **Then** recibe la primera pregunta por Telegram y la conversación queda en
   modo simulación hasta que la persona la termine o responda todas las preguntas del paquete.
2. **Given** la simulación en curso, **When** la persona responde una pregunta, **Then** recibe la
   siguiente pregunta o, si ya no quedan, el comentario final sobre el conjunto de respuestas.
3. **Given** que la persona escribe "termina" durante la simulación, **When** se procesa,
   **Then** la simulación se cierra con el comentario de lo que alcanzó a responder, sin dejarla a
   medias de forma silenciosa.

---

### Edge Cases

- ¿Qué pasa si la persona pide preparación para una vacante que nunca pasó por Hirebar (la aplicó
  por fuera)? → fuera de alcance de esta spec: el comando solo trabaja sobre postulaciones que
  Hirebar registró; se documenta la limitación en la guía, no se intenta adivinar.
- ¿Qué pasa si la revisión de información pública de la empresa no encuentra nada? → el documento
  se genera igual, con esa sección marcada como "sin información pública encontrada", nunca con
  datos inventados sobre la empresa.
- ¿Qué pasa si la persona pide simular una entrevista sin haber generado antes el paquete de
  preparación (US2 sin US1)? → Hirebar avisa que primero hace falta `entrevista <identificador>` y
  no improvisa preguntas sin el paquete.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hirebar MUST reconocer el comando `entrevista <identificador>` en Telegram y
  resolverlo contra el historial de postulaciones ya registrado por Empleo o Freelance.
- **FR-002**: La IA que prepara el documento MUST correr en `RunProfile.read` o `draft` restringido
  a la carpeta `entrevistas/`, sin acceso a acciones de envío, postulación o publicación.
- **FR-003**: El documento MUST incluir, como mínimo: resumen de la vacante y la empresa, preguntas
  probables agrupadas por tipo (técnicas, de experiencia, culturales), y los puntos del perfil de la
  persona que más conectan con lo que pide la vacante.
- **FR-004**: Si la persona no da un identificador y hay más de una postulación activa, Hirebar MUST
  pedir que especifique cuál antes de generar nada.
- **FR-005**: Si no hay ninguna vacante que coincida, Hirebar MUST avisarlo sin generar un documento
  con información inventada.
- **FR-006**: El comando `simula entrevista <identificador>` MUST requerir que ya exista un paquete
  de preparación para ese identificador (dependencia de FR-001 a FR-003).
- **FR-007**: Durante la simulación, cada pregunta y respuesta MUST intercambiarse por el canal ya
  existente (Telegram o notificación de macOS como respaldo), sin un canal nuevo.
- **FR-008**: La persona MUST poder terminar la simulación en cualquier momento con una palabra de
  comando (`termina`), recibiendo un comentario final sobre lo que alcanzó a responder.
- **FR-009**: Ni la preparación ni la simulación MUST contar para el cupo diario de envíos del
  agente (`PlatformQuota`); no son un envío.

### Key Entities

- **InterviewPackage**: identificador de la vacante, resumen, lista de preguntas por categoría y los
  puntos del perfil destacados; se guarda en `entrevistas/<identificador>.md` (o `.json` + render,
  según `research.md`).
- **InterviewSimulation**: estado de una simulación en curso — paquete asociado, índice de la
  pregunta actual, respuestas recibidas — vivo solo mientras la persona no termina o no agota las
  preguntas.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de los documentos generados incluyen las tres secciones mínimas de FR-003,
  verificable con un test de integración sobre una vacante y un perfil de prueba fijos.
- **SC-002**: Ninguna simulación ni preparación de entrevista queda registrada como envío en
  `PlatformQuota` ni en el cupo diario del agente.
- **SC-003**: El comando `entrevista` sin identificador, con varias postulaciones activas, nunca
  genera un documento sin que la persona haya elegido cuál, verificable con un test de
  `CommandParser`/`ControllerInbox`.

## Assumptions

- Esta funcionalidad vive en el agente Analista existente como nuevos modos/comandos, no como un
  agente nuevo en `AgentKind`: no envía nada, solo informa, que es exactamente el contrato ya
  definido para Analista.
- El identificador de vacante es el mismo que ya usa el historial de postulaciones de Empleo y
  Freelance (no se inventa un esquema de IDs nuevo).
- La revisión de información pública de la empresa, cuando corre, usa el mismo mecanismo de lectura
  con navegador que ya usan los comandos `social`/`portalScan*`, con las mismas restricciones de
  contenido-no-es-instrucción (principio III); con un motor de IA que no soporte leer con navegador
  (ver limitación de Codex/Gemini en Ajustes → Motor de IA), esa sección del documento queda como
  "sin información pública encontrada" en vez de fallar todo el comando.
