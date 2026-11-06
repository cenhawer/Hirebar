# Implementation Plan: Separar lectura de ejecución

**Branch**: `feature/HB-010-separar-lectura-ejecucion` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/010-separar-lectura-ejecucion/spec.md`

## Summary

Cada ejecución de la IA pasa a tener un perfil: `read` para las tareas que leen contenido externo y
`act` para las que envían. El perfil de lectura de Claude Code corre con `--permission-mode dontAsk
--restricted` y sin herramientas de escritura ni de acción en Chrome; Codex y Gemini leen sin
navegador; el comando propio usa dos comandos. La lectura devuelve propuestas estructuradas por la
salida estándar; la ejecución recibe solo lo aprobado (con el cupo restante) y deja un registro de
acciones que el dominio verifica contra una copia de lo aprobado guardada fuera del workspace. Una
acción no autorizada pausa el agente hasta que la persona lo reanude. Redes y seguimientos pasan a
producir listas para aprobar.

## Technical Context

**Language/Version**: Swift 6.4 en el worker, Swift 6.3 en CI; `swift-tools-version` 5.9 (la subida a
6 es de la spec `018-macos-26-swift-6`).

**Primary Dependencies**: ninguna externa; Claude Code 2.1.318 (verificado), Codex y Gemini CLI como
motores opcionales.

**Storage**: archivos JSON con `schemaVersion` en `~/Library/Application Support/Hirebar/estado/`
(aprobados, verificaciones, pausas) y `workspace/ejecuciones/<lote>.acciones.json`.

**Testing**: XCTest con dobles de `AIRunner` y `Messenger`; fixtures de propuestas y registros en
`Tests/Fixtures/`.

**Target Platform**: macOS 13+ hoy (la base pasa a 26 en la spec `018`).

**Project Type**: app de escritorio de barra de menú.

**Performance Goals**: la verificación de un lote termina en menos de 1 segundo; el aviso de acción
no autorizada sale en menos de 1 minuto después de terminar la ejecución (SC-003).

**Constraints**: la verificación es posterior al envío; la primera barrera es que la lectura no pueda
actuar. Los perfiles de permisos no pueden vivir en un lugar que la IA pueda escribir.

**Scale/Scope**: 6 agentes, 12 tipos de tarea, 4 motores.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Cumple | Cómo |
|---|---|---|
| I. Spec primero | ✅ | Spec aprobada con aclaraciones; `ARCHITECTURE.md` se actualiza antes del código (tarea inicial) |
| II. Nada sale sin aprobación y sin rastro | ✅ | Redes y seguimientos con aprobación; registro y verificación de cada acción |
| III. Contenido externo nunca es instrucción | ✅ | Perfil `read` sin herramientas de acción; propuestas estructuradas; catálogo cerrado |
| IV. Datos locales y recuperables | ✅ | Archivos nuevos con `schemaVersion`; estado de seguridad fuera del workspace |
| V. Sin dependencias ocultas | ✅ | Sin paquetes nuevos; los perfiles viven en el bundle |
| VI. Código que se explica solo | ✅ | Herramientas permitidas y textos en archivos de recursos, no en el código |
| VII. Probado sin red ni IA | ✅ | Verificación pura en el dominio; motor de prueba por fixtures |
| VIII. Arquitectura hexagonal | ⚠️ | El código nuevo va en `HirebarDomain` y `HirebarApplication`; los adaptadores siguen en `HirebarEngine` hasta la spec `017` (ver Complexity Tracking) |

**Re-check post-design**: sin cambios; el diseño de la fase 1 respeta las mismas reglas.

## Project Structure

### Documentation (this feature)

```text
specs/010-separar-lectura-ejecucion/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── propuestas.schema.json
│   ├── registro-acciones.schema.json
│   └── comandos-telegram.md
├── checklists/requirements.md
└── tasks.md                 (lo crea /speckit-tasks)
```

### Source Code (repository root)

```text
Package.swift                         targets nuevos: HirebarDomain, HirebarApplication y sus tests
Sources/
├── HirebarDomain/                    nuevo
│   ├── ActionKind.swift
│   ├── Proposal.swift                Proposal, Target
│   ├── ApprovedItem.swift
│   ├── ActionRecord.swift
│   ├── Verification.swift            verificación pura (R7)
│   └── AgentPause.swift
├── HirebarApplication/               nuevo
│   ├── RunProfile.swift
│   ├── AIRunner.swift                puerto
│   ├── ProposalParser.swift          lee el bloque de propuestas de la salida (R6)
│   ├── ExecutionPlanner.swift        aprobados que caben en el cupo
│   └── VerifyExecution.swift         caso de uso: verificar, registrar, pausar, avisar
├── HirebarEngine/                    adaptadores hasta la spec 017
│   ├── ClaudeCLI.swift               perfiles read/act desde perfiles-ia.json
│   ├── Controller.swift              usa RunProfile, ExecutionPlanner y VerifyExecution
│   ├── AgentPrompts.swift            pedidos de lectura y de ejecución
│   └── Commands.swift                reanudar, botones de pausa
├── HirebarCore/
│   ├── AIEngine.swift                readCommand y actCommand para Otra IA
│   └── Paths.swift                   carpeta estado/
└── Hirebar/
    ├── PanelModel.swift, PanelView.swift   estado "en pausa"
    └── Settings.swift                dos comandos y advertencia en Motor de IA
Resources/
├── perfiles-ia.json                  nuevo, en el bundle (R2)
└── inicial/instrucciones-*.md        lectura devuelve propuestas; ejecución deja el registro
Tests/
├── HirebarDomainTests/               verificación, catálogo, normalización de destinos
├── HirebarApplicationTests/          parser, planificador con cupo, caso de uso con dobles
└── Fixtures/
    ├── proposals/  execution/  injection/
    └── engine/read.sh, act.sh        motor de prueba del quickstart
```

**Structure Decision**: los tipos y reglas nuevos nacen en los targets de destino de
`ARCHITECTURE.md` (`HirebarDomain`, `HirebarApplication`); los cambios a lo existente se hacen en su
lugar actual y los mueve la spec `017-arquitectura-hexagonal`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Los adaptadores (motores, Telegram, panel) siguen en `HirebarEngine` y `HirebarCore`, con singletons | La reorganización completa en targets hexagonales es la spec `017` y mezclarla aquí haría un cambio de seguridad imposible de revisar | Hacer la `017` primero deja el riesgo de seguridad abierto semanas; escribir lo nuevo dentro de `HirebarEngine` crearía más código que mover después |
