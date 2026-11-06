# Hirebar

## Overview

App de barra de menú para macOS que busca empleo remoto, proyectos freelance y clientes por una
persona. Revisa portales, filtra con su perfil, le avisa por Telegram y, con su aprobación, usa una
IA de terminal que maneja su Chrome para postular, proponer, escribir correos y preparar
publicaciones. La usa una persona por instalación.

## Stack

- Swift 6 con concurrencia estricta, SwiftPM sin paquetes externos, macOS 26 o superior.
- SwiftUI con `@Observable`; AppKit solo para la barra de menú y las ventanas.
- Integraciones: Telegram Bot API, Claude Code / Codex / Gemini CLI / comando propio, Google Chrome,
  reconocimiento de voz de macOS, ffmpeg del sistema.
- Datos en archivos JSON y Markdown en `~/Library/Application Support/Hirebar/`; secretos en el
  Llavero.

## Arquitectura

- Hexagonal con límites impuestos por targets de SwiftPM. Detalle, puertos, contratos y el destino
  de cada archivo actual en `ARCHITECTURE.md`.
- Principios no negociables en `.specify/memory/constitution.md`.
- El código actual todavía tiene cuatro targets en cadena (`Hirebar` → `HirebarEngine` →
  `HirebarSources` → `HirebarCore`); lo nuevo se escribe ya en la capa de destino que indica
  `ARCHITECTURE.md` §3.3.

## Convenciones

- Código en inglés y autoexplicativo; textos para la persona y documentación en español.
- Reglas de Swift de este repo: `.claude/rules/swift.md`.
- Git, ramas y commits: `Lineamientos/git/` y la sección "Flujo de desarrollo" de la constitución.
  Validados por `scripts/check-conventions.sh`.

## Testing

- XCTest en `Tests/`, sin red, IA, Chrome ni Telegram reales: dobles de los puertos y fixtures.
- Cada escenario de aceptación y cada `SC-###` de una spec tiene al menos un test.
- La cobertura de `Sources` no baja de `.coverage-minimum`; la medida de referencia es la del CI.

## Comandos

```sh
swift build
scripts/coverage.sh
scripts/lint.sh origin/develop
scripts/check-conventions.sh origin/develop
scripts/bundle.sh --install
graphify update .
```

## SDD

- Motor: GitHub Spec Kit. `specs/NNN-nombre/{spec,plan,tasks}.md` y
  `.specify/memory/constitution.md`.
- Flujo: `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` →
  `/speckit-analyze` → `/speckit-implement` → PR a `develop`.
- La rama de cada spec se crea a mano con el número de su carpeta: `feature/HB-NNN-nombre`.
- Orden de las specs y fases: `docs/Plan.md`.
- Antes de abrir un PR: revisión del diff con `swift-code-reviewer` contra la constitución,
  `ARCHITECTURE.md`, Lineamientos y la spec; si toca envíos, la IA, Telegram, secretos o contenido
  externo, también `/security-review`. La revisión se corre en local y se marca en la plantilla del
  PR.
- El bloque entre `SPECKIT START` y `SPECKIT END` lo mantiene la extensión `agent-context` después
  de `/speckit-specify` y `/speckit-plan`; no se edita a mano. Su script necesita PyYAML; sin
  instalarlo: `uv run --no-project --with pyyaml bash
  .specify/extensions/agent-context/scripts/bash/update-agent-context.sh`.

## Anti-patrones (rechazar en review)

- Features sin spec ni tests: una integración entró y salió el mismo día sin dejar un solo test.
- Singletons (`.shared`) y estado global en el motor; nada fuera de la raíz de composición.
- Estado de la app en `UserDefaults` en lugar del workspace versionado.
- Textos para la persona, listas de palabras, plazos o rutas escritos en el código.
- Comentarios `///` o `//` en código interno.
- La IA con `bypassPermissions` mientras lee contenido externo; acciones que la app no valida.
- Instalar herramientas con `pip` o descargas en ejecución.
- Leer disco en cada refresco de la interfaz (`Config.load()` por fila del panel).
- `DispatchSemaphore` y callbacks donde alcanza `async`/`await`.
- Un mismo verbo de Telegram para dos comandos (`si`, `envia`).
- Fijar el CI a una imagen de runner sin revisar su retiro.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->
