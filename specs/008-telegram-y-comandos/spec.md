# Feature Specification: Telegram y comandos

**Feature Branch**: `docs/spec-008-telegram-y-comandos`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is transversal: describe cómo Hirebar se conecta a Telegram, vincula el chat de la
persona, recibe textos, botones y notas de voz, interpreta los comandos y responde, en el commit base
de `develop`. Los comandos propios de cada agente se detallan en su spec; aquí está el canal y lo
común. Las desviaciones de la constitución se listan al final con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configurar el bot y anclarlo a la persona (Priority: P1)

La persona crea un bot con @BotFather, pega su token en Ajustes → Telegram y avisos, le escribe
"hola" desde su Telegram y confirma su nombre en la Mac. Desde ahí, el bot atiende solo a su cuenta.

**Why this priority**: sin el canal, la persona no puede aprobar nada desde el celular.

**Independent Test**: con updates de ejemplo, un mensaje privado posterior a empezar la vinculación
se propone, la confirmación ancla esa cuenta y los mensajes de otras cuentas se ignoran.

**Acceptance Scenarios**:

1. **Given** Ajustes → Telegram y avisos, **When** la persona pega un token y lo comprueba, **Then** la
   app lo valida con Telegram (`getMe`), muestra el nombre del bot y lo guarda en el Llavero; un token
   inválido se explica y no se guarda.
2. **Given** un token válido, **When** empieza la vinculación y la persona le escribe al bot desde su
   chat privado, **Then** la app muestra su nombre y usuario y pide confirmarlo (detalle en la spec
   `012-canal-de-mensajes`).
3. **Given** la confirmación, **When** la persona dice que sí, **Then** el bot queda anclado a su ID de
   usuario y a ese chat, y llega la bienvenida con la lista de comandos.
4. **Given** el bot anclado, **When** escribe otra cuenta, llega un mensaje de un grupo o alguien más
   pulsa un botón, **Then** se ignora sin responder y se anota en el registro sin el contenido.
5. **Given** el bot anclado, **When** la persona elige "Cambiar de cuenta", **Then** se borra el
   anclaje y empieza una vinculación nueva; "Quitar bot" borra además el token del Llavero.
6. **Given** que la persona elige "Enviar aviso de prueba", **When** Telegram está listo, **Then**
   llega al chat un mensaje de prueba con el mismo contenido de `estado`.

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

1. **Given** una nota de voz, un audio o un video circular, **When** llega de la persona anclada,
   **Then** se descarga (si pesa más de 500 bytes) con su extensión (`oga`, la del archivo o `mp4`) y
   pasa al flujo del video narrado.

---

### Edge Cases

- Telegram no responde: el sondeo reintenta cada 15 segundos sin avisar. Si Telegram rechaza el
  token, el panel muestra "El token ya no sirve" y los avisos pasan a notificaciones de macOS.
- El token cambia: el sondeo vuelve a empezar desde el primer mensaje pendiente.
- La app se reinicia: retoma desde el último mensaje procesado, sin repetir comandos.
- Telegram no está configurado o un envío falla: el aviso aparece como notificación de macOS.
- Cada verbo pertenece a un solo comando (`Resources/comandos.json`); la palabra `correos` no cambia
  el comando, solo el destino: `si correos` o `envia correos 1 3` aprueban la última lista de correos y
  `no correos` la descarta. `auto si` sin nombre cambia Empleo y Freelance; Clientes se prende con
  `auto clientes si`.

## Requirements *(mandatory)*

### Functional Requirements

**Canal**

- **FR-001**: El token MUST guardarse solo en el Llavero de macOS, después de validarlo con Telegram.
- **FR-002**: Hirebar MUST recibir mensajes con sondeo largo (`getUpdates`, 50 segundos, solo
  mensajes y botones), recordar el último procesado entre reinicios y reintentar cada 15 segundos si
  falla.
- **FR-003**: Hirebar MUST atender solo mensajes y botones de la cuenta anclada en su chat privado;
  los demás MUST ignorarse.
- **FR-004**: Hirebar MUST poder enviar textos (hasta 4.000 caracteres, con botones), fotos, videos
  (hasta 300 segundos de subida) y documentos (pie de hasta 1.000 caracteres), y quitar los botones de
  un mensaje.
- **FR-005**: Ajustes MUST ofrecer la sección "Telegram y avisos" (vinculación, aviso de prueba,
  "Cambiar de cuenta", "Quitar bot" y permiso de notificaciones), y el menú y el panel MUST mostrar el
  estado del canal y llevar a esa sección.

**Comandos**

- **FR-006**: Los textos MUST normalizarse (minúsculas, sin tildes, sin espacios al borde) antes de
  interpretarse; la primera palabra es el verbo y cada verbo pertenece a un solo comando del
  vocabulario `Resources/comandos.json`, que interpreta un `CommandParser` puro en
  `HirebarApplication`, también para las notas de voz.
- **FR-007**: Los botones MUST traer el identificador de su lista (`si:<lista>`, `no:<lista>`) y
  responderse con "Recibido".
- **FR-008**: Una respuesta que cita un mensaje MUST aplicar a la lista de ese mensaje.
- **FR-009**: Hirebar MUST reconocer los comandos de `ARCHITECTURE.md` §4.2: aprobar y descartar
  listas, `estado`, `agentes`, `agente <nombre> on/off`, `corre <nombre>`, `auto [<nombre>] si/no`,
  `buscar`, `seguimientos`, `informe`, `anota`, `reanudar <nombre>`, los de correos, contenido, video y
  perfil, y los botones "Reanudar <agente>" y "Mantener en pausa".
- **FR-010**: Los nombres de agente MUST aceptar sinónimos (por ejemplo, `trabajo` para Empleo,
  `correos` para Clientes, `hv` para Perfil).
- **FR-011**: Un texto que no es comando MUST responderse con la lista de comandos.
- **FR-012**: Las notas de voz, audios y videos circulares de la persona anclada MUST pasar al flujo
  del video narrado.

### Key Entities

- **Mensaje entrante (TelegramMessage)**: chat, remitente (ID, nombre, usuario, tipo de chat y hora),
  texto, mensaje citado, identificador de botón y, si es audio, el identificador del archivo y su
  extensión.
- **Dueño del canal**: ID de usuario, chat y nombre de la persona anclada, en `config.json`.
- **Token del bot**: en el Llavero, cuenta `telegram-bot`.
- **Último mensaje procesado**: en `UserDefaults` (`telegram.offset`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ningún mensaje ni botón de una cuenta distinta de la anclada produce una acción.
- **SC-002**: Ningún comando se ejecuta dos veces después de un reinicio.
- **SC-003**: Pulsar un botón y escribir el comando equivalente citando el mismo mensaje producen la
  misma acción.
- **SC-004**: Todo texto que no es comando recibe la lista de comandos.

## Assumptions

- La persona crea el bot con @BotFather y usa Telegram en un chat privado con él.
- La API de Telegram permite sondeo largo sin servidor propio.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| Las acciones de los comandos viven en el adaptador, no en casos de uso | VIII | `017-arquitectura-hexagonal` |
| El último mensaje procesado se guarda en `UserDefaults` | IV | `022-version-datos` |
| La lista de comandos y las respuestas están escritas en el código | VI | `024-textos-y-valores-fuera-del-codigo` |
| El cliente usa `Thread`, `DispatchSemaphore` y un singleton | VIII | `017-arquitectura-hexagonal` · `018-macos-26-swift-6` |

## Hallazgos sin principio asociado

- El token se valida solo por su forma: un token mal copiado con la forma correcta se guarda y el
  sondeo falla en silencio cada 15 segundos. Se resuelve en `012-canal-de-mensajes`, que lo verifica
  contra Telegram al guardarlo.
