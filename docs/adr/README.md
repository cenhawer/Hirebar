# Decisiones de arquitectura (ADR)

Cada decisión técnica que no encaja en `ARCHITECTURE.md` se registra aquí antes de implementarla
(constitución, principio I). Un ADR aceptado no se edita: si la decisión cambia, se escribe uno nuevo
que lo reemplaza y el anterior pasa a "Reemplazado por ADR-NNNN".

| ADR | Título | Estado |
|---|---|---|
| [ADR-0001](0001-desarrollo-guiado-por-specs.md) | Desarrollo guiado por specs con Spec Kit | Aceptado |
| [ADR-0002](0002-arquitectura-hexagonal.md) | Arquitectura hexagonal con límites por targets de SwiftPM | Aceptado |
| [ADR-0003](0003-ffmpeg-prerrequisito-del-sistema.md) | ffmpeg como prerrequisito del sistema | Aceptado |
| [ADR-0004](0004-macos-26-y-swift-6.md) | macOS 26 y Swift 6 como base | Aceptado |
| [ADR-0005](0005-anclar-el-bot-por-id-de-usuario.md) | Anclar el bot por ID de usuario | Aceptado |

## Plantilla

Archivo `NNNN-titulo-en-kebab-case.md`, con el número siguiente:

```markdown
# ADR-NNNN: Título

## Estado

Propuesto | Aceptado | Deprecado | Reemplazado por ADR-NNNN · AAAA-MM-DD

## Contexto

Qué problema o fuerza obliga a decidir, con los datos concretos.

## Decisión

Qué se decide, en una o dos frases, y sus reglas.

## Consecuencias

Qué se gana, qué se paga y qué cambia en el código, las specs o el CI.

## Alternativas consideradas

| Alternativa | Por qué no |
|---|---|

## Referencias

Specs, secciones de `ARCHITECTURE.md`, de la constitución o de `docs/Plan.md`.
```
