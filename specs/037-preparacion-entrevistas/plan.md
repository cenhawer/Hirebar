# Implementation Plan: Preparación de entrevista

**Branch**: `feature/HB-037-preparacion-entrevistas` | **Date**: 2026-11-18 | **Spec**: `specs/037-preparacion-entrevistas/spec.md`

**Input**: Feature specification from `specs/037-preparacion-entrevistas/spec.md`

## Summary

Dos comandos nuevos del agente Analista: `entrevista <id>` genera un documento de preparación a
partir del historial de postulaciones y el perfil; `simula entrevista <id>` hace una ronda de
preguntas/respuestas por Telegram sobre ese documento. Ninguno envía, postula ni cuenta para cupos.

## Technical Context

**Language/Version**: Swift 6, concurrencia estricta, macOS 26.

**Primary Dependencies**: ninguna nueva. Reutiliza `AIRunner`, `Telegram`, `Repositories`
(historial de postulaciones), `Profile`.

**Storage**: nueva carpeta `entrevistas/` en el workspace (mismo nivel que `informes/`), con
`InterviewPackage` como Markdown + metadatos; `InterviewSimulation` como estado efímero en memoria
del `Controller` mientras dura la conversación (no es dato persistente de la persona, se pierde si
Hirebar se reinicia a mitad de una simulación — documentado como límite aceptado).

**Testing**: XCTest con doble de `AIRunner` y doble de `ChatChannel` para simular el intercambio de
turnos de Telegram.

**Target Platform**: macOS 26, sin cambios de plataforma.

**Performance Goals**: no aplica límite especial; una preparación corre una vez por postulación, no
en bucle.

**Constraints**: el agente Analista nunca envía ni actúa (contrato ya vigente en
`specs/006-agente-analista`); esta spec no cambia eso.

**Scale/Scope**: un documento por postulación con entrevista activa; la simulación es una
conversación a la vez por persona (instalación de un solo usuario).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Spec primero**: el formato exacto del documento (`.md` vs `.json` + render) queda
  `[NEEDS CLARIFICATION: research.md decide Markdown plano, igual que informes/<AAAA-SNN>.md del
  Analista, para no agregar un renderer nuevo]`.
- **II. Nada sale sin aprobación**: no aplica — el comando no envía nada a terceros, solo informa a
  la propia persona.
- **III. El contenido externo nunca es instrucción**: la revisión pública de la empresa, si corre,
  usa el mismo puerto de lectura con navegador ya sujeto a esa regla; sin IA nueva sin restricción.
- **IV. Datos locales y recuperables**: `entrevistas/` vive en el workspace local igual que
  `informes/`; sin dato personal nuevo fuera de lo que ya se guarda (vacante + perfil).
- **V. Sin dependencias ocultas**: cero paquetes o herramientas nuevas.
- **VI. Código que se explica solo**: `InterviewPackage`/`InterviewSimulation` en inglés, sin
  comentarios; textos de Telegram en String Catalog.

Sin violaciones; no se llena Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/037-preparacion-entrevistas/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/HirebarDomain/
└── InterviewPackage.swift     # nuevo: InterviewPackage, InterviewQuestion, InterviewSimulation

Sources/HirebarApplication/
├── AgentPrompts.swift         # interviewPrepPrompt(_:), interviewTurnPrompt(_:)
├── CommandParser.swift        # "entrevista", "simula entrevista"
├── Controller.swift           # estado de simulación en curso (efímero)
└── ControllerInbox.swift      # desambiguar postulación cuando hay varias activas (FR-004)

Sources/HirebarStorage/
└── FileRepositories.swift     # leer historial de postulaciones existente, escribir entrevistas/

Resources/
└── comandos.json              # claves "interviewPrep": ["entrevista"], "interviewSim": ["simula entrevista"]

Tests/HirebarUseCaseTests/
├── CommandFlowTests.swift
└── ControllerRunTests.swift

Tests/HirebarApplicationTests/
└── CommandParserTests.swift
```

**Structure Decision**: todo nuevo vive dentro de los targets existentes del agente Analista; no se
agrega `AgentKind` ni target nuevo. El estado de simulación es efímero en `Controller` porque no es
un dato que la persona necesite recuperar tras un reinicio (se documenta el límite en Assumptions).

## Complexity Tracking

Sin violaciones de la constitución; tabla vacía.
