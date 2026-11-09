# Feature Specification: Canal de mensajes

**Feature Branch**: `feature/HB-012-canal-de-mensajes`

**Created**: 2026-11-09

**Status**: Draft

**Input**: Spec `008-telegram-y-comandos`: el chat queda vinculado con el primer mensaje que recibe el
bot, de quien sea; sin Telegram, los avisos van a ntfy.sh, un servicio público donde cualquiera que
adivine el tema los lee. Esta spec ancla el bot a una sola persona por su ID de usuario de Telegram,
con una configuración guiada dentro de la app, y reemplaza ntfy.sh por las notificaciones de macOS.

## Clarifications

### Session 2026-11-09

- Q: ¿Cómo se vincula el chat: con un código que muestra la app o anclando el bot al ID de la
  persona? → A: Como el bot de Hex: la app valida el token, pide escribirle "hola" al bot, muestra el
  nombre de quien escribió para confirmarlo y desde ahí el bot atiende solo a ese ID de usuario.
- Q: ¿La configuración vive en un diálogo o en la app? → A: En Ajustes y en el panel, con el estado
  y las acciones a la vista; nada de editar archivos.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Anclar el bot a la persona (Priority: P1)

La persona crea su bot en @BotFather, pega el token en Ajustes y en menos de un minuto el bot queda
anclado a su cuenta de Telegram, sin buscar su ID ni editar archivos.

**Why this priority**: hoy cualquiera que le escriba primero al bot se queda con el control de los
agentes, que actúan con las sesiones de la persona.

**Independent Test**: con un bot nuevo, pegar el token, escribir "hola" desde el teléfono, confirmar
el nombre en la Mac y recibir el aviso de prueba en ese chat.

**Acceptance Scenarios**:

1. **Given** un token pegado en Ajustes, **When** la persona lo comprueba, **Then** la app lo valida
   con Telegram y muestra el nombre del bot; un token inválido muestra el error sin guardarse.
2. **Given** un token válido, **When** la persona empieza la vinculación y le escribe al bot desde su
   chat privado, **Then** la app muestra su nombre y usuario y pide confirmarlo.
3. **Given** el nombre mostrado, **When** la persona confirma, **Then** el bot queda anclado a su ID de
   usuario y a ese chat, y llega un mensaje de bienvenida con la ayuda.
4. **Given** el nombre mostrado, **When** la persona dice que no es ella, **Then** la app descarta ese
   mensaje y sigue esperando.
5. **Given** que pasan los minutos de espera sin mensajes, **When** vence la vinculación, **Then** la
   app lo dice y ofrece volver a intentarlo; los mensajes anteriores a empezar no cuentan.

---

### User Story 2 - Un bot cerrado a todos los demás (Priority: P1)

Con el bot anclado, solo la persona puede darle órdenes; nadie más, ni en otro chat ni en un grupo.

**Why this priority**: los comandos aprueban envíos, reanudan agentes y cambian configuración.

**Independent Test**: desde otra cuenta de Telegram, escribirle "si" y pulsar un botón reenviado;
nada se aprueba y el registro anota un intento ignorado sin el contenido.

**Acceptance Scenarios**:

1. **Given** el bot anclado, **When** escribe otra cuenta o llega un mensaje de un grupo, **Then** se
   ignora, no se responde y el registro anota el intento sin su contenido.
2. **Given** un botón de un aviso, **When** lo pulsa otra cuenta, **Then** no tiene efecto.
3. **Given** la persona, **When** manda más mensajes por minuto que el límite, **Then** los de más se
   ignoran hasta que pase el minuto.
4. **Given** una instalación que ya tenía un chat privado vinculado, **When** se actualiza la app,
   **Then** el bot queda anclado a ese mismo usuario sin pedir nada; si el chat vinculado era un
   grupo, queda sin anclar y la app pide vincularlo de nuevo.

---

### User Story 3 - Avisos en la Mac cuando no hay Telegram (Priority: P2)

Sin Telegram configurado, o si un mensaje no se puede enviar, el aviso aparece como notificación de
macOS y al tocarla se abre el panel.

**Why this priority**: ningún aviso debe perderse ni pasar por un servicio público.

**Independent Test**: sin bot configurado, correr una búsqueda con resultados; aparece la
notificación y al tocarla se abre el panel.

**Acceptance Scenarios**:

1. **Given** Telegram sin configurar o sin persona anclada, **When** Hirebar tiene un aviso, **Then**
   aparece como notificación de macOS.
2. **Given** un mensaje que Telegram rechaza o no recibe, **When** falla el envío, **Then** el aviso
   aparece como notificación de macOS.
3. **Given** una notificación, **When** la persona la toca, **Then** se abre el panel.
4. **Given** la configuración, **When** la persona abre la sección de Telegram y avisos, **Then** ve si
   las notificaciones están permitidas y puede pedir el permiso desde ahí.
5. **Given** cualquier instalación, **When** Hirebar avisa, **Then** nada se envía a ntfy.sh.

---

### User Story 4 - Estado y acciones a la vista (Priority: P2)

El panel y Ajustes muestran en qué estado está el canal y qué hacer, sin conceptos internos.

**Acceptance Scenarios**:

1. **Given** cualquier estado, **When** la persona abre el panel, **Then** ve uno de: "Telegram sin
   configurar", "Esperando tu hola", "Conectado como <nombre>" o "El token ya no sirve", y el botón
   lleva a la sección de Telegram y avisos.
2. **Given** el bot anclado, **When** la persona está en Ajustes, **Then** puede mandar un aviso de
   prueba, cambiar de cuenta (vuelve a la vinculación) o quitar el bot (borra el token del Llavero).

### Edge Cases

- Dos personas le escriben al bot durante la vinculación: se muestra la primera; si la persona dice
  que no es ella, se muestra la siguiente.
- El token se revoca en @BotFather con el bot anclado: el panel muestra "El token ya no sirve" y los
  avisos pasan a notificaciones de macOS.
- La persona cambia de token: la vinculación empieza de nuevo y el anclaje anterior se borra.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La app MUST validar el token con Telegram antes de guardarlo y mostrar el nombre del
  bot; el token se guarda solo en el Llavero.
- **FR-002**: La vinculación MUST aceptar solo mensajes de un chat privado enviados después de
  empezarla y dentro de su tiempo de espera, y MUST pedir a la persona que confirme el nombre y el
  usuario de quien escribió.
- **FR-003**: Al confirmar, la app MUST guardar el ID de usuario, el chat y el nombre de la persona,
  y mandar la bienvenida con la ayuda a ese chat.
- **FR-004**: Con el bot anclado, la app MUST atender solo mensajes y botones cuyo remitente sea el ID
  anclado y cuyo chat sea el chat anclado; el resto se ignora sin respuesta y se registra sin
  contenido.
- **FR-005**: La app MUST ignorar los mensajes de la persona que superen el límite por minuto.
- **FR-006**: Una configuración con un chat privado vinculado MUST migrar a ese mismo usuario
  anclado; un chat de grupo MUST quedar sin anclar.
- **FR-007**: Sin Telegram configurado o sin persona anclada, y cuando un envío a Telegram falla, los
  avisos MUST mostrarse como notificaciones de macOS; tocar una MUST abrir el panel.
- **FR-008**: La app MUST NOT enviar avisos a ntfy.sh ni a ningún otro servicio público; el tema de
  ntfy de configuraciones viejas se descarta.
- **FR-009**: Ajustes MUST tener una sección "Telegram y avisos" con la vinculación paso a paso, el
  permiso de notificaciones, el aviso de prueba, "Cambiar de cuenta" y "Quitar bot"; el panel MUST
  mostrar el estado del canal y llevar a esa sección.
- **FR-010**: El tiempo de espera de la vinculación y el límite de mensajes por minuto MUST vivir en
  un archivo de recursos, no en el código.

### Key Entities

- **Dueño del canal**: ID de usuario de Telegram, chat, nombre y usuario de la persona anclada.
- **Vinculación**: inicio, tiempo de espera y candidato propuesto.
- **Remitente**: ID, nombre, usuario, tipo de chat y hora de un mensaje entrante.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Una persona sin experiencia ancla su bot en menos de 2 minutos desde que tiene el token.
- **SC-002**: El 100% de los mensajes y botones de cuentas distintas de la anclada se ignoran.
- **SC-003**: Ningún aviso sale hacia ntfy.sh ni otro servicio público.
- **SC-004**: Sin Telegram, el 100% de los avisos aparece como notificación de macOS.

## Assumptions

- La persona usa Telegram en un chat privado con su bot; los grupos no se soportan.
- En Telegram, el ID de un chat privado es el ID del usuario; eso permite migrar sin pedir nada.
- La bandeja de pendientes del panel es de la spec `027`; hasta entonces la notificación abre el panel.
