# Contrato: comandos y avisos nuevos

| Entrada | Efecto |
|---|---|
| `reanudar <agente>` | Levanta la pausa del agente y responde con su estado |
| Botón `Reanudar <agente>` (`resume:<agente>`) | Igual que `reanudar <agente>` |
| Botón `Mantener en pausa` (`keep-paused:<agente>`) | Deja la pausa y lo confirma |

| Aviso | Contenido |
|---|---|
| Acción no autorizada | Agente, lote, por cada acción no autorizada: tipo, destino y motivo; los dos botones |
| Registro no verificado | Agente, lote y motivo (registro ausente o inválido); los dos botones |
| Lista de redes | Igual que las listas de hoy, con la acción propuesta de cada elemento (postular, borrador, anotar) |
| Lista de seguimientos | Cada seguimiento con su proyecto, cliente y el texto que se enviaría |

`agentes` y `estado` muestran "en pausa: <motivo>" para el agente pausado.
