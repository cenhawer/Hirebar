# Research: Canal de mensajes

## R1. Anclaje por ID de usuario

- **Decision**: el bot atiende solo al ID de usuario confirmado en la vinculación y solo en su chat
  privado. Los botones se comprueban por el remitente del `callback_query`, no por el chat.
- **Rationale**: es el esquema del bot de Hex, ya probado: no hace falta buscar el ID ni copiar un
  código, y un botón reenviado o pulsado por otra cuenta no tiene efecto.
- **Alternatives considered**: código de vinculación que muestra la app (un paso más sin ganar
  seguridad: el anclaje final es el mismo); primer mensaje (cualquiera se queda con el bot).

## R2. Vinculación

- **Decision**: al empezar, la app toma la hora; acepta solo mensajes de chat privado con fecha igual
  o posterior y dentro de `pairingMinutes`. Muestra nombre y usuario y espera la confirmación.
- **Rationale**: los mensajes viejos en la cola de Telegram no pueden anclar a nadie, y la persona ve
  a quién está anclando.

## R3. Respaldo en la Mac

- **Decision**: `UNUserNotificationCenter` con permiso pedido desde la sección de Telegram y avisos;
  el delegado de la app abre el panel al tocar la notificación. Se usa cuando no hay Telegram, no hay
  dueño o un envío falla. ntfy.sh se elimina.
- **Rationale**: los temas de ntfy.sh son públicos; las notificaciones de macOS no salen de la Mac.
- **Alternatives considered**: mantener ntfy con tema aleatorio (sigue siendo un servicio público).

## R4. Migración

- **Decision**: un `chatId` positivo de `config.json` pasa a dueño con ese mismo ID de usuario, porque
  en Telegram el ID de un chat privado es el del usuario; uno negativo (grupo) se descarta.
