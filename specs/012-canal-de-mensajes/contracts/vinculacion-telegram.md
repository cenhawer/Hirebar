# Contrato: vinculación y canal

| Paso en Ajustes → Telegram y avisos | Qué pasa |
|---|---|
| Pegar token → **Comprobar** | `getMe`; muestra `@bot` o el error. El token se guarda en el Llavero solo si es válido |
| **Vincular mi cuenta** | Empieza la vinculación: "Escríbele hola a @bot desde tu Telegram" |
| Llega un mensaje privado | "¿Eres <nombre> (@usuario)?" con **Sí, soy yo** y **No soy yo** |
| **Sí, soy yo** | Guarda el dueño y manda la bienvenida con la ayuda |
| Vence la espera | "No llegó ningún mensaje" y **Volver a intentar** |
| **Enviar aviso de prueba** · **Cambiar de cuenta** · **Quitar bot** | Con el bot anclado |
| **Permitir notificaciones** | Pide el permiso de macOS; muestra si están permitidas |

| Estado en el panel | Botón |
|---|---|
| Telegram sin configurar | Configurar |
| Esperando tu hola | Ver |
| Conectado como <nombre> | Ajustes |
| El token ya no sirve | Arreglar |

Mensajes y botones de otras cuentas: sin respuesta; el registro anota
`Telegram: ignorado un mensaje de otra cuenta`.
