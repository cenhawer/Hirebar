# Feature Specification: Telegram y comandos

**Feature Branch**: `docs/spec-008-telegram-y-comandos`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is transversal: describe cómo Hirebar se conecta a Telegram, vincula el chat de la
persona, recibe textos, botones y notas de voz, interpreta los comandos y responde, en el commit base
de `develop`. Los comandos propios de cada agente se detallan en su spec; aquí está el canal y lo
común. Las desviaciones de la constitución se listan al final con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configurar el bot y vincular el chat (Priority: P1)

La persona crea un bot con @BotFather, pega su token en Hirebar y le escribe `/start` desde el
celular. Desde ahí, ese chat es el único que Hirebar escucha.

**Why this priority**: sin el canal, la persona no puede aprobar nada desde el celular.

**Independent Test**: con un doble de la API de Telegram, guardar un token válido inicia el sondeo; el
primer mensaje vincula su chat y los mensajes de otros chats se ignoran.

**Acceptance Scenarios**:

1. **Given** el menú o el panel, **When** la persona elige "Configurar bot de Telegram…", **Then**
   ve los pasos para crear el bot y un campo para pegar el token.
2. **Given** un token que no tiene la forma `<5 o más dígitos>:<30 o más caracteres>`, **When** la
   persona lo guarda, **Then** se le dice que no parece válido y no se guarda.
3. **Given** un token con la forma correcta, **When** se guarda, **Then** queda en el Llavero, se
   olvida el chat vinculado, empieza el sondeo y se le pide enviar `/start` al bot.
4. **Given** que no hay chat vinculado, **When** llega el primer mensaje de cualquier chat, **Then**
   ese chat queda vinculado y recibe la confirmación con la lista de comandos.
5. **Given** un chat vinculado, **When** llega un mensaje de otro chat, **Then** se ignora y se anota
   en el registro.
6. **Given** que la persona elige "Volver a vincular el chat", **When** lo elige, **Then** se olvida
   el chat sin pedir confirmación y el siguiente mensaje que reciba el bot lo vincula de nuevo.
7. **Given** que la persona elige "Enviar aviso de prueba", **When** Telegram está listo, **Then**
   llega al chat un mensaje de prueba con el mismo contenido de `estado`; si no, se le pide
   configurar el bot y enviarle `/start`.

---

### User Story 2 - Recibir avisos y responder con botones o texto (Priority: P1)

Hirebar le manda a la persona listas, resúmenes, imágenes, videos y PDF; ella responde con los
botones o escribiendo, y puede citar un aviso viejo para que la respuesta aplique a ese.

**Why this priority**: es la forma en que la persona aprueba todo lo que hacen los agentes.

**Independent Test**: con un doble de la API, una lista sale con sus botones; pulsar "Sí" produce la
misma aprobación que escribir `si` citando ese mensaje.

**Acceptance Scenarios**:

1. **Given** una lista nueva, **When** se avisa, **Then** el mensaje lleva los botones "Sí, postular
   a todas" (Empleo) o "Sí, enviar todas" (los demás) y "No", y queda asociado a la lista.
2. **Given** que la persona pulsa un botón, **When** llega, **Then** se confirma "Recibido" y la
   acción aplica a la lista de ese mensaje.
3. **Given** que la persona responde citando un aviso, **When** escribe `si` o `no`, **Then** la
   acción aplica a la lista de ese aviso y no a la más reciente.
4. **Given** una lista aprobada o descartada, **When** se procesa, **Then** se le quitan los botones
   al mensaje.
5. **Given** un texto de más de 4.000 caracteres o un pie de foto de más de 1.000, **When** se envía,
   **Then** se recorta a ese largo.
6. **Given** fotos, un video o un PDF, **When** se envían, **Then** llegan como archivos al chat con
   su pie.

---

### User Story 3 - Dar órdenes por texto (Priority: P1)

La persona maneja Hirebar escribiendo comandos simples, sin tildes ni mayúsculas obligatorias.

**Why this priority**: es el control remoto de todos los agentes.

**Independent Test**: con una tabla de textos de entrada y la acción esperada, cada texto produce
esa acción contra dobles de los casos de uso.

**Acceptance Scenarios**:

1. **Given** cualquier comando, **When** se escribe con mayúsculas o tildes, **Then** se interpreta
   igual.
2. **Given** que la persona escribe `estado`, **When** se procesa, **Then** recibe qué está haciendo
   la IA, los cupos, el estado de las búsquedas y el de cada agente.
3. **Given** que la persona escribe `agentes`, **When** se procesa, **Then** recibe cada agente con
   prendido o apagado, envío automático y próxima ejecución.
4. **Given** que la persona escribe `agente clientes off`, **When** se procesa, **Then** el agente se
   apaga y se confirma.
5. **Given** que la persona escribe `corre <agente>`, **When** se procesa, **Then** corren ya su
   búsqueda (si tiene) y todas sus tareas.
6. **Given** que la persona escribe `auto si` o `auto no`, **When** se procesa, **Then** cambia el
   envío automático de Empleo y Freelance y se responde el estado de Empleo, Freelance y Clientes.
7. **Given** que la persona escribe `auto clientes si`, **When** se procesa, **Then** cambia solo el
   de Clientes.
8. **Given** un texto que no es ningún comando, **When** llega, **Then** se responde la lista
   completa de comandos.

---

### User Story 4 - Mandar notas de voz (Priority: P2)

La persona manda una nota de voz o un audio y Hirebar lo usa para narrar el video que espera voz
(spec `004-agente-contenido`, historia 3).

**Why this priority**: solo lo usa el video narrado.

**Independent Test**: con un doble de la API, una actualización con `voice` produce un mensaje con el
identificador del archivo y extensión `oga`.

**Acceptance Scenarios**:

1. **Given** una nota de voz, un audio o un video circular, **When** llega del chat vinculado,
   **Then** se descarga (si pesa más de 500 bytes) con su extensión (`oga`, la del archivo o `mp4`) y
   pasa al flujo del video narrado.

---

### Edge Cases

- Telegram no responde o el token es inválido: el sondeo reintenta cada 15 segundos sin avisar.
- El token cambia: el sondeo vuelve a empezar desde el primer mensaje pendiente.
- La app se reinicia: retoma desde el último mensaje procesado, sin repetir comandos.
- Telegram no está configurado: los avisos salen por ntfy.sh si hay un tema configurado (se elimina
  en la spec `012-canal-de-mensajes`).
- `envia`, `enviar`, `envialos`, `envie`, `si`, `dale`, `ok`, `aprobado` o `aprueba` junto a la
  palabra `correos` aprueban correos, y `no correos` los descarta; en cambio `listo correos`,
  `postula correos` o `aplica correos` aprueban la última lista de avisos.

## Requirements *(mandatory)*

### Functional Requirements

**Canal**

- **FR-001**: El token MUST guardarse solo en el Llavero de macOS y validarse por su forma antes de
  guardarlo.
- **FR-002**: Hirebar MUST recibir mensajes con sondeo largo (`getUpdates`, 50 segundos, solo
  mensajes y botones), recordar el último procesado entre reinicios y reintentar cada 15 segundos si
  falla.
- **FR-003**: El primer chat que escribe sin chat vinculado MUST quedar vinculado; los demás MUST
  ignorarse.
- **FR-004**: Hirebar MUST poder enviar textos (hasta 4.000 caracteres, con botones), fotos, videos
  (hasta 300 segundos de subida) y documentos (pie de hasta 1.000 caracteres), y quitar los botones de
  un mensaje.
- **FR-005**: El menú y el panel MUST ofrecer "Configurar bot de Telegram…", "Enviar aviso de
  prueba" y "Volver a vincular el chat", y mostrar si Telegram está sin configurar, esperando
  `/start` o conectado.

**Comandos**

- **FR-006**: Los textos MUST normalizarse (minúsculas, sin tildes, sin espacios al borde) antes de
  interpretarse; la primera palabra es el verbo.
- **FR-007**: Los botones MUST traer el identificador de su lista (`si:<lista>`, `no:<lista>`) y
  responderse con "Recibido".
- **FR-008**: Una respuesta que cita un mensaje MUST aplicar a la lista de ese mensaje.
- **FR-009**: Hirebar MUST reconocer los comandos de `ARCHITECTURE.md` §4.2: aprobar y descartar
  listas, `estado`, `agentes`, `agente <nombre> on/off`, `corre <nombre>`, `auto [<nombre>] si/no`,
  `buscar`, `seguimientos`, `informe`, `anota`, los de correos, contenido, video y perfil.
- **FR-010**: Los nombres de agente MUST aceptar sinónimos (por ejemplo, `trabajo` para Empleo,
  `correos` para Clientes, `hv` para Perfil).
- **FR-011**: Un texto que no es comando MUST responderse con la lista de comandos.
- **FR-012**: Las notas de voz, audios y videos circulares del chat vinculado MUST pasar al flujo
  del video narrado.

### Key Entities

- **Mensaje entrante (TelegramMessage)**: chat, texto, mensaje citado, identificador de botón y, si
  es audio, el identificador del archivo y su extensión.
- **Chat vinculado**: identificador del único chat que Hirebar escucha, en `config.json`.
- **Token del bot**: en el Llavero, cuenta `telegram-bot`.
- **Último mensaje procesado**: en `UserDefaults` (`telegram.offset`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ningún mensaje de un chat distinto del vinculado produce una acción.
- **SC-002**: Ningún comando se ejecuta dos veces después de un reinicio.
- **SC-003**: Pulsar un botón y escribir el comando equivalente citando el mismo mensaje producen la
  misma acción.
- **SC-004**: Todo texto que no es comando recibe la lista de comandos.

## Assumptions

- La persona crea el bot con @BotFather y le escribe `/start` antes que nadie.
- La API de Telegram permite sondeo largo sin servidor propio.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| El chat se vincula con el primer mensaje que llega, de quien sea | Restricciones técnicas (vínculo por código) | `012-canal-de-mensajes` |
| Sin Telegram, los avisos salen por un tema público de ntfy.sh | IV | `012-canal-de-mensajes` |
| `si`, `ok`, `no` y `envia` sirven a la vez para listas y para correos | — (anti-patrón de `AGENTS.md`) | `013-parser-comandos` |
| La lectura de comandos está mezclada con las acciones en un mismo archivo | VIII | `013-parser-comandos` · `017-arquitectura-hexagonal` |
| El último mensaje procesado se guarda en `UserDefaults` | IV | `022-version-datos` |
| La lista de comandos y las respuestas están escritas en el código | VI | `024-textos-y-valores-fuera-del-codigo` |
| El cliente usa `Thread`, `DispatchSemaphore` y un singleton | VIII | `017-arquitectura-hexagonal` · `018-macos-26-swift-6` |
| La lectura de comandos no tiene tests | VII | `013-parser-comandos` |

## Hallazgos sin principio asociado

- `auto si` sin nombre cambia Empleo y Freelance pero no Clientes, aunque la respuesta muestra los
  tres. Se define en `013-parser-comandos`.
- El token se valida solo por su forma: un token mal copiado con la forma correcta se guarda y el
  sondeo falla en silencio cada 15 segundos. Se resuelve en `012-canal-de-mensajes`, que lo verifica
  contra Telegram al guardarlo.
