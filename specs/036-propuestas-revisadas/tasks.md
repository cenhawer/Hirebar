---
description: "Task list for Propuestas con segundo agente revisor"
---

# Tasks: Propuestas con segundo agente revisor

**Input**: Design documents from `specs/036-propuestas-revisadas/`

**Prerequisites**: plan.md, spec.md

**Tests**: incluidos.

## Phase 1: Setup

- [ ] T001 Crear `Sources/HirebarDomain/ReviewedDraft.swift` con `ReviewedDraft` y `ReviewOutcome`
  (`approvedAsIs`/`corrected`/`skippedTimeout`).
- [ ] T002 [P] Agregar `reviewEnabled: Bool` por agente a `AgentStore` (default `false` para no
  cambiar el comportamiento de nadie que actualice sin tocar Ajustes).

## Phase 2: Foundational

- [ ] T003 `Sources/HirebarApplication/TaskProfiles.swift`: el modo de revisión resuelve a
  `RunProfile.draft` con las mismas rutas escribibles que el redactor (FR-002).
- [ ] T004 `Sources/HirebarApplication/AgentPrompts.swift`: `reviewPrompt(draft:source:profile:)`
  con instrucción explícita de corregir sin inventar respaldo (FR-003).
- [ ] T005 Definir el tiempo de espera del paso de revisión en `research.md` y aplicarlo donde
  corra el proceso (ver `[NEEDS CLARIFICATION]` del plan).

**Checkpoint**: los tipos y el perfil de ejecución existen; ninguna historia depende de UI todavía.

---

## Phase 3: User Story 1 - Propuesta ya revisada (Priority: P1) 🎯 MVP

**Goal**: la versión que llega a Telegram ya pasó por un segundo proceso de revisión.

**Independent Test**: doble de `AIRunner` con borrador fijo + crítica fija → la versión revisada
(no la original) llega a aprobación, y ambos pasos quedan registrados.

### Tests for User Story 1

- [ ] T006 [P] [US1] `Tests/HirebarUseCaseTests/ControllerRunTests.swift`: el revisor recibe
  borrador + fuente + perfil en un proceso separado del redactor (escenario 1).
- [ ] T007 [P] [US1] `Tests/HirebarUseCaseTests/ControllerRunTests.swift`: afirmación sin respaldo
  se quita de la versión final, nunca se reemplaza por un dato inventado (escenario 2, FR-003).
- [ ] T008 [P] [US1] `Tests/HirebarUseCaseTests/ControllerRunTests.swift`: sin problemas detectados,
  la versión final es idéntica al borrador (escenario 3, FR-004).
- [ ] T009 [P] [US1] `Tests/HirebarUseCaseTests/ControllerRunTests.swift`: el revisor falla o agota
  tiempo → se manda el borrador original con aviso, sin bloquear al agente (escenario 4, FR-005).

### Implementation for User Story 1

- [ ] T010 [US1] `Sources/HirebarApplication/ControllerResults.swift`: orquestar redactor → revisor
  → resultado final, con manejo de timeout/fallo (FR-001, FR-005).
- [ ] T011 [US1] `Resources/Localizable.xcstrings`: aviso de "no se pudo revisar esta vez"; correr
  `scripts/strings.sh`.
- [ ] T012 [US1] Confirmar en `ARCHITECTURE.md` el contrato nuevo del flujo de dos pasos (principio
  I: contrato se documenta antes del código que ya se escribió en T010 — ajustar orden si aplica).

**Checkpoint**: US1 funciona sola y es demostrable con un borrador de prueba.

---

## Phase 4: User Story 2 - Ver qué cambió (Priority: P2)

**Goal**: la persona puede auditar borrador vs. versión final por propuesta.

**Independent Test**: propuesta corregida → el registro de actividad trae las dos versiones y un
resumen de cambios, recuperable por comando/ventana sin leer archivos a mano.

### Tests for User Story 2

- [ ] T013 [P] [US2] `Tests/HirebarStorageTests/ExecutionActivityTests.swift`: `ReviewedDraft` se
  persiste con borrador, versión final y resumen (escenario 1).
- [ ] T014 [P] [US2] `Tests/HirebarStorageTests/ExecutionActivityTests.swift`: propuesta sin cambios
  guarda explícitamente "sin cambios", sin ambigüedad (escenario 2).

### Implementation for User Story 2

- [ ] T015 [US2] `Sources/HirebarStorage/ExecutionActivity.swift`: persistir `ReviewedDraft` junto
  al registro existente de la propuesta (FR-006).
- [ ] T016 [US2] `Sources/Hirebar/ActivityWindow.swift`: mostrar el resumen de cambios en el detalle
  de la actividad.

**Checkpoint**: US1 + US2 funcionan juntas; la revisión ya es auditable.

---

## Phase 5: User Story 3 - Prender/apagar por agente (Priority: P3)

**Goal**: la persona decide en qué agentes vale la pena el costo extra de tokens.

**Independent Test**: revisión apagada en Freelance, prendida en Empleo → solo Empleo dispara el
segundo proceso, contable en el doble de `AIRunner`.

### Tests for User Story 3

- [ ] T017 [P] [US3] `Tests/HirebarUseCaseTests/ControllerRunTests.swift`: con `reviewEnabled =
  false`, una sola invocación de `AIRunner` por propuesta (escenario 1 de US3, FR-008).
- [ ] T018 [P] [US3] `Tests/HirebarUseCaseTests/ControllerRunTests.swift`: con `reviewEnabled =
  true`, dos invocaciones (escenario 2 de US3).

### Implementation for User Story 3

- [ ] T019 [US3] `Sources/Hirebar/SettingsEditors.swift`: toggle "Revisar antes de aprobar" por
  agente en la página de cada agente en Ajustes (FR-007).
- [ ] T020 [US3] `Sources/HirebarApplication/ControllerResults.swift`: leer `reviewEnabled` del
  `AgentStore` antes de lanzar el segundo paso.

**Checkpoint**: las 3 historias funcionan juntas.

---

## Phase 6: Polish

- [ ] T021 [P] `scripts/coverage.sh` en verde.
- [ ] T022 `scripts/lint.sh origin/develop` en verde.
- [ ] T023 Revisión de diff con `swift-code-reviewer` y, por tocar la IA y el flujo de aprobación,
  `/security-review` antes del PR a `develop` (regla de `AGENTS.md`).

## Dependencies & Execution Order

- Setup (T001-T002) sin dependencias.
- Foundational (T003-T005) depende de Setup; bloquea las 3 historias.
- US1 (T006-T012) es el MVP; depende solo de Foundational.
- US2 (T013-T016) depende de que `ReviewedDraft` exista (T001) y de que US1 produzca resultados que
  guardar (T010); no depende de US3.
- US3 (T017-T020) depende de Foundational (T002, T003) y de T010 para poder condicionar el flujo;
  no depende de US2.
- Polish depende de las historias que se decida entregar.
