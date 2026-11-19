# Implementation Plan: Propuestas con segundo agente revisor

**Branch**: `feature/HB-036-propuestas-revisadas` | **Date**: 2026-11-18 | **Spec**: `specs/036-propuestas-revisadas/spec.md`

**Input**: Feature specification from `specs/036-propuestas-revisadas/spec.md`

## Summary

Insertar un segundo paso de IA, con contexto nuevo y el mismo `RunProfile.draft` restringido, entre
la redacción actual y el envío a Telegram para aprobar. El paso revisa el borrador contra la fuente
original y el perfil, corrige afirmaciones sin respaldo, y si falla o se agota el tiempo, deja pasar
el borrador original con un aviso. Prendible/apagable por agente desde Ajustes.

## Technical Context

**Language/Version**: Swift 6, concurrencia estricta, macOS 26.

**Primary Dependencies**: ninguna nueva; reutiliza el puerto `AIRunner` ya existente, solo con una
invocación adicional.

**Storage**: el registro de actividad existente (`HirebarStorage/ExecutionActivity`) gana el campo
de `ReviewedDraft`; la preferencia por agente vive en `AgentStore` (archivo del agente, ya versionado
con `schemaVersion`).

**Testing**: XCTest con doble de `AIRunner` que simula redactor + revisor por separado
(`Tests/HirebarUseCaseTests/TestAIRunner.swift` ya existe y se extiende).

**Target Platform**: macOS 26, sin cambios de plataforma.

**Performance Goals**: el segundo paso no debe duplicar el tiempo total más allá de una invocación
de IA adicional (mismo orden de magnitud que la redacción actual); no hay paralelismo entre redactor
y revisor porque el revisor necesita el borrador terminado.

**Constraints**: el revisor corre con `RunProfile.draft`, nunca `RunProfile.act`; nunca comparte
proceso ni historial con el redactor (FR-001).

**Scale/Scope**: aplica a los modos `draft` de Empleo, Freelance y Clientes (`followUp`,
`prospecting`, y el borrador de postulación/propuesta). No aplica a Contenido ni Perfil en esta
spec — quedan fuera por alcance, se podrían agregar después con la misma mecánica.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Spec primero**: el tiempo de espera del paso de revisión queda
  `[NEEDS CLARIFICATION: se resuelve en research.md igualándolo a EngineCheck.timeout = 180s salvo
  que la persona pida otro valor]`. Documentado, no inventado en silencio.
- **II. Nada sale sin aprobación**: el revisor no envía ni descarta nada; solo prepara una versión
  que igual pasa por aprobación de la persona. PASA.
- **III. El contenido externo nunca es instrucción**: el revisor recibe la vacante/hilo original
  como dato de comparación, con el mismo perfil restringido que ya impide actuar; sigue sin poder
  ejecutar instrucciones que vengan de ese contenido. PASA.
- **IV. Datos locales y recuperables**: `ReviewedDraft` se guarda junto al registro de actividad
  existente, que ya vive en el workspace local con retención definida. PASA.
- **V. Sin dependencias ocultas**: ninguna herramienta ni paquete nuevo; se reusa el mismo CLI de IA
  ya configurado. PASA.
- **VI. Código que se explica solo**: `ReviewedDraft`/`ReviewOutcome` en inglés, sin comentarios;
  el aviso de "no se pudo revisar" va a String Catalog.

Sin violaciones; no se llena Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/036-propuestas-revisadas/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/HirebarDomain/
└── ReviewedDraft.swift        # nuevo: ReviewedDraft, ReviewOutcome

Sources/HirebarApplication/
├── AgentPrompts.swift         # nuevo reviewPrompt(_:) con borrador + fuente + perfil
├── ControllerResults.swift    # orquesta redactor -> revisor -> resultado final
├── TaskProfiles.swift         # el modo de revisión también resuelve a RunProfile.draft
└── ExecutionActivity.swift (vía HirebarStorage) # guarda ReviewedDraft

Sources/HirebarStorage/
├── AgentStore.swift           # nuevo campo reviewEnabled por agente
└── ExecutionActivity.swift    # persiste borrador + versión final + resumen

Sources/Hirebar/
├── SettingsEditors.swift      # toggle "Revisar antes de aprobar" por agente (US3)
└── ActivityWindow.swift       # muestra el resumen de cambios de US2

Tests/HirebarUseCaseTests/
├── TestAIRunner.swift         # extender para simular redactor + revisor
├── ControllerRunTests.swift   # flujo completo con y sin revisión
└── AIRunnerFlowTests.swift
```

**Structure Decision**: el flujo de dos pasos se orquesta en `HirebarApplication` (donde ya vive la
orquestación de `draft` → `act`); `HirebarDomain` solo define los tipos puros del resultado. No se
crea un target nuevo: el revisor es otra invocación del mismo puerto `AIRunner`, no un adaptador
distinto.

## Complexity Tracking

Sin violaciones de la constitución; tabla vacía.
