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

Remitente de un mensaje o botón: `userId`, `chatId`, `name`, `username`, `isPrivateChat`, `sentAt`.

## ChannelGuard (HirebarApplication)

`check(sender, owner, now)` → `allowed`, `notOwner` o `tooMany`. Recuerda las horas del último
minuto para el límite `messagesPerMinute`.

## ChannelPairing (HirebarApplication)

`startedAt` y `window`. `candidate(from: sender)` devuelve el dueño propuesto si el chat es privado,
el mensaje es posterior al inicio y la vinculación no venció; `isExpired(at:)`.

## Resources/canal.json

`{"schemaVersion": 1, "pairingMinutes": 10, "messagesPerMinute": 30}`
