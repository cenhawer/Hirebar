# Data Model: Canal de mensajes

## ChannelOwner (HirebarDomain)

| Campo | Tipo | Regla |
|---|---|---|
| `userId` | Int64 | ID de usuario de Telegram anclado |
| `chatId` | Int64 | Chat privado con el bot |
| `name` | String | Nombre visible, para el panel |
| `username` | String? | Usuario de Telegram, si tiene |

Se guarda en `config.json` → `channelOwner`.

## ChannelSender (HirebarDomain)

Remitente de un mensaje o botón: `userId`, `chatId`, `name`, `username`, `isPrivateChat`, `sentAt` y
`viaButton` (los botones nunca cuentan para la vinculación).

## ChannelGuard (HirebarApplication)

`check(sender, owner, now)` → `allowed`, `notOwner` o `tooMany`. Recuerda las horas del último
minuto para el límite `messagesPerMinute`.

## ChannelPairing (HirebarApplication)

`startedAt`, `window`, cola de `PairingCandidate` (dueño propuesto y texto recibido) y cuentas
rechazadas. `receive(sender, text:, at:)` encola un mensaje de texto privado posterior al inicio y
dentro de la ventana; `current` es el primero; `declineCurrent()` lo rechaza y pasa al siguiente.

## Resources/canal.json

`{"schemaVersion": 1, "pairingMinutes": 10, "messagesPerMinute": 30}`
