# ADR-0005: Anclar el bot por ID de usuario

## Estado

Aceptado · 2026-11-09

## Contexto

El bot de Telegram aprueba envíos, reanuda agentes y cambia configuración. Hasta ahora quedaba
vinculado al primer chat que le escribiera. La constitución pedía un código de emparejamiento que
muestra la app; la persona eligió el esquema del bot de Hex, ya probado: validar el token, escribirle
"hola" al bot, confirmar en la Mac quién escribió y anclar ese ID de usuario.

## Decisión

El bot se ancla al ID de usuario de Telegram que la persona confirma en Ajustes, en su chat privado.
Para que un tercero que conozca el bot no pueda hacerse pasar por ella durante la vinculación:

- Solo cuentan mensajes de texto de un chat privado, enviados después de empezar y dentro de su tiempo
  de espera; los botones y los mensajes viejos de la cola no cuentan.
- La confirmación muestra nombre, usuario, ID y el texto recibido, y advierte si la cuenta no tiene
  usuario de Telegram.
- Los mensajes que llegan mientras hay un candidato quedan en cola: "No soy yo" muestra el siguiente.

## Consecuencias

- La persona no busca su ID ni copia códigos.
- La seguridad del anclaje depende de que la persona lea la confirmación; la app le da los datos para
  distinguir a otra cuenta (ID, usuario y el texto que ella misma escribió).

## Alternativas consideradas

| Alternativa | Por qué no |
|---|---|
| Código de emparejamiento que muestra la app | Paso extra que la persona descartó; el anclaje final es el mismo ID |
| Primer mensaje sin confirmación | Cualquiera que escriba primero se queda con el bot |

## Referencias

- Spec `012-canal-de-mensajes`, constitución (restricciones técnicas), `ARCHITECTURE.md` §6.
