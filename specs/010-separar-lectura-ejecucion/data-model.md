# Data Model: Separar lectura de ejecución

Todas las entidades son tipos de valor de `HirebarDomain`, salvo que se indique otra capa.

## ActionKind

Catálogo cerrado (FR-005): `apply` (postular), `sendProposal`, `sendFollowUp`, `sendEmail`,
`draftEmail`, `publish`, `replyToClient`.

- `requiresText`: verdadero para `sendProposal`, `sendFollowUp`, `sendEmail`, `draftEmail`,
  `replyToClient` y `publish`.
- `alwaysNeedsApproval`: verdadero para `replyToClient` y `publish` (FR-015).

## Proposal

Resultado de una fase de lectura.

| Campo | Tipo | Regla |
|---|---|---|
| `id` | String | Único dentro de la lista; estable para el mismo elemento |
| `agent` | AgentKind | Agente que la produjo |
| `action` | ActionKind | Del catálogo |
| `target` | Target | Enlace, plataforma o destinatario |
| `title` | String | Para mostrar en la lista |
| `source` | String | De dónde salió (portal, publicación, correo) |
| `text` | String? | Obligatorio si `action.requiresText` |
| `fit` | Fit? | ENCAJA o RETO, cuando aplica |

## Target

`url(String)` normalizado sin parámetros de seguimiento, `email(String)` en minúsculas, o
`account(network, handle)`.

## ApprovedItem

`Proposal` aprobada, con `approvedAt`, `approvedBy` (`person` o `autoSend`) y el lote al que
pertenece. Se guarda en `estado/aprobados/<lote>.json`, fuera del workspace.

## ActionRecord

Una línea del registro de la fase de ejecución (`ejecuciones/<lote>.acciones.json`).

| Campo | Tipo |
|---|---|
| `itemId` | String |
| `action` | ActionKind |
| `target` | Target |
| `sentText` | String? |
| `outcome` | `done` · `pending(reason)` · `discarded(reason)` |
| `at` | Date |

## Verification

Por cada `ActionRecord`: `authorized`, `unauthorized(reason)` o `unverified(reason)`.

- `unauthorized`: el `itemId` no está aprobado en ese lote, o la acción, el destino o el texto no
  coinciden.
- `unverified`: el registro falta, no se puede leer o no cumple el esquema.
- Un `ApprovedItem` sin `ActionRecord` queda como `pending("sin registro")`.

## AgentPause

| Campo | Tipo |
|---|---|
| `agent` | AgentKind |
| `batch` | String |
| `reason` | String |
| `since` | Date |

Se guarda en `estado/pausas.json`. Mientras existe, el agente no lanza ejecuciones (FR-010). Solo la
persona la levanta (FR-011a).

## RunProfile (HirebarApplication)

`read`, `draft(paths)` o `act`. `draft` lleva la lista de carpetas o archivos donde la tarea puede
escribir. El puerto `AIRunner` recibe el perfil junto con el pedido; cada adaptador lo traduce a los
argumentos de su motor según `Resources/perfiles-ia.json`.

| Tarea | Perfil |
|---|---|
| Redes, portales propios | `read` |
| Búsqueda de clientes | `draft(prospeccion/)`, más el bloque de propuestas |
| Seguimientos | `draft(seguimiento.json)`, más el bloque de propuestas |
| Preparar contenido (con o sin revisión de rendimiento) | `draft(contenido/<cuenta>/)` |
| Actualizar perfil y hojas de vida | `draft(perfil.json, perfil.md, hv/)` |
| Análisis semanal | `draft(informes/)` |
| Postular, enviar propuestas, enviar correos, publicar | `act` |

## Transiciones de una lista

```text
lectura ──propuestas──▶ pendiente ──si / envío automático──▶ aprobada ──ejecución──▶ verificada
                          │                                                         │
                          └──no──▶ descartada            no autorizada ◀────────────┘──▶ agente en pausa
```
