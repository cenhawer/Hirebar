---

description: "Tareas de implementación: separar lectura de ejecución"
---

# Tasks: Separar lectura de ejecución

**Input**: Design documents from `/specs/010-separar-lectura-ejecucion/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: obligatorios (constitución, principio VII): cada escenario y `SC-###` tiene al menos un test.

**Organization**: tareas agrupadas por historia de usuario; cada una cita el `FR-###` que la origina.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias)
- **[Story]**: historia a la que pertenece (US1, US2, US3)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: contratos primero y estructura de targets

- [x] T001 Actualizar `ARCHITECTURE.md` antes del código (constitución, principio I): puerto `AIRunner` con `RunProfile`, carpeta `estado/`, archivo `Resources/perfiles-ia.json`, variable `HIREBAR_PHASE`, comandos y avisos de `contracts/comandos-telegram.md`, y estado actual de §6 (FR-001, FR-004, FR-010)
- [x] T002 Agregar los targets `HirebarDomain`, `HirebarApplication`, `HirebarDomainTests`, `HirebarApplicationTests` y `HirebarEngineTests` en `Package.swift`, con `HirebarApplication` dependiendo solo de `HirebarDomain`
- [x] T003 [P] Crear `Tests/Fixtures/proposals/`, `Tests/Fixtures/execution/` y `Tests/Fixtures/injection/` con los casos de `quickstart.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: dominio, puertos y almacenamiento que usan las tres historias

- [x] T004 [P] `ActionKind` con `requiresText` y `alwaysNeedsApproval` en `Sources/HirebarDomain/ActionKind.swift` (FR-005, FR-015)
- [x] T005 [P] `Target` con normalización de enlaces (sin parámetros de seguimiento) y correos (minúsculas), y `Proposal`, en `Sources/HirebarDomain/Proposal.swift` (FR-003, FR-006)
- [x] T006 [P] `ApprovedItem`, `ActionRecord` y `AgentPause` en `Sources/HirebarDomain/` (FR-006, FR-008, FR-010)
- [x] T007 Verificación pura (autorizada, no autorizada, no verificada, pendiente sin registro) en `Sources/HirebarDomain/Verification.swift` (FR-009, FR-011)
- [x] T008 [P] Tests de catálogo, normalización de destinos y verificación en `Tests/HirebarDomainTests/` (FR-005, FR-009, FR-011)
- [x] T009 [P] `RunProfile` (`read`, `draft(paths)`, `act`), el puerto `AIRunner` y la tabla de perfil por tarea en `Sources/HirebarApplication/` (FR-001, FR-002, FR-004)
- [x] T010 `ProposalParser`: lee el bloque `HIREBAR_PROPOSALS_BEGIN`/`END` de la salida y lo valida contra `contracts/propuestas.schema.json` en `Sources/HirebarApplication/ProposalParser.swift` (FR-003)
- [x] T011 [P] Tests del parser con propuestas válidas, inválidas y texto alrededor en `Tests/HirebarApplicationTests/ProposalParserTests.swift` (FR-003)
- [x] T012 Carpeta `estado/` fuera del workspace en `Sources/HirebarCore/Paths.swift`, y almacenes con `schemaVersion` para aprobados, verificaciones y pausas en `Sources/HirebarCore/SecurityState.swift` (FR-006, FR-010, FR-012)
- [x] T013 [P] `Resources/perfiles-ia.json` con las herramientas de lectura y de ejecución de cada motor, copiado al bundle por `scripts/bundle.sh` y no al workspace (FR-004)

**Checkpoint**: dominio, puertos y almacenamiento listos.

---

## Phase 3: User Story 1 - Que lo que lee la IA no pueda convertirse en una acción (Priority: P1) 🎯 MVP

**Goal**: toda tarea que lee contenido externo corre con el perfil `read` y devuelve propuestas.

**Independent Test**: con el fixture `injection`, la lectura termina con una lista para aprobar y
ningún archivo `.acciones.json`; el perfil `read` de cada motor no incluye herramientas de acción.

### Tests for User Story 1

- [x] T014 [P] [US1] Tests de argumentos del perfil `read` de Claude Code (`dontAsk`, `--restricted`, sin `Write`, `Edit`, `bypassPermissions` ni herramientas de acción de Chrome) en `Tests/HirebarEngineTests/ClaudeProfileTests.swift`, incluido que `draft` solo escribe en sus rutas (FR-001, FR-004)
- [x] T015 [P] [US1] Tests del perfil `read` de Codex (`--sandbox read-only`), Gemini (`--approval-mode default`) y Otra IA (`HIREBAR_PHASE=read`, comando de lectura) en `Tests/HirebarEngineTests/EngineProfileTests.swift` (FR-004, FR-004a)
- [x] T016 [P] [US1] Test de que las tareas que leen con navegador no corren con Codex ni Gemini y avisan en `Tests/HirebarEngineTests/EngineProfileTests.swift` (FR-004)

### Implementation for User Story 1

- [x] T017 [US1] Perfiles `read`, `draft` y `act` de Claude Code leídos de `perfiles-ia.json` en `Sources/HirebarEngine/ClaudeCLI.swift` (FR-001, FR-004)
- [x] T018 [US1] Perfiles de Codex, Gemini y Otra IA, con `readCommand` y `actCommand` en `Sources/HirebarCore/AIEngine.swift` (FR-004, FR-004a)
- [x] T019 [US1] Ajustes → Motor de IA con los dos comandos de Otra IA y la advertencia en `Sources/Hirebar/Settings.swift` (FR-004a)
- [x] T020 [US1] El controlador lanza cada tarea con su perfil (`read` o `draft`) y convierte las propuestas de las de lectura en una lista pendiente en `Sources/HirebarEngine/Controller.swift` (FR-001, FR-003)
- [x] T021 [US1] Pedidos de lectura que piden el bloque de propuestas en `Sources/HirebarEngine/AgentPrompts.swift` (FR-003)
- [x] T022 [P] [US1] Reglas de lectura que devuelven propuestas en lugar de escribir archivos: `Resources/inicial/instrucciones-portales-empleo.md`, `instrucciones-portales-freelance.md`, `instrucciones-prospeccion.md` e `instrucciones-contenido.md` §0 (FR-001, FR-003)

**Checkpoint**: la lectura ya no puede actuar.

---

## Phase 4: User Story 2 - Que la IA solo actúe sobre lo que la persona aprobó (Priority: P1)

**Goal**: la ejecución recibe solo lo aprobado dentro del cupo, deja su registro y la app lo verifica.

**Independent Test**: con el fixture `unauthorized`, la app marca la acción como no autorizada, avisa,
pausa el agente y no ejecuta la siguiente lista hasta `reanudar`.

### Tests for User Story 2

- [x] T023 [P] [US2] Tests del planificador con cupo restante en `Tests/HirebarApplicationTests/ExecutionPlannerTests.swift` (FR-007)
- [x] T024 [P] [US2] Tests del caso de uso de verificación con dobles de `AIRunner` y `Messenger`: autorizada, no autorizada, registro ausente, registro inválido, pausa y reanudación, en `Tests/HirebarApplicationTests/VerifyExecutionTests.swift` (FR-008 a FR-011a)
- [x] T025 [P] [US2] Tests de `reanudar <agente>` y de los botones `resume:` y `keep-paused:` en `Tests/HirebarEngineTests/PauseCommandTests.swift` (FR-011a)

### Implementation for User Story 2

- [x] T026 [US2] `ExecutionPlanner` en `Sources/HirebarApplication/ExecutionPlanner.swift` (FR-007)
- [x] T027 [US2] Copia de lo aprobado en `estado/aprobados/<lote>.json` al aprobar, a mano o por envío automático, en `Sources/HirebarEngine/Controller.swift` (FR-006)
- [x] T028 [US2] Pedido de ejecución con elementos, acción, destino, texto aprobado y la orden de dejar `ejecuciones/<lote>.acciones.json` en `Sources/HirebarEngine/AgentPrompts.swift` (FR-006, FR-008)
- [x] T029 [P] [US2] Reglas de ejecución que piden el registro de acciones: `instrucciones-empleo.md`, `instrucciones-freelance.md`, `instrucciones-prospeccion-envio.md` e `instrucciones-contenido-publicar.md` (FR-008)
- [x] T030 [US2] `VerifyExecution`: verificar, guardar en `estado/verificaciones/`, pausar y avisar, en `Sources/HirebarApplication/VerifyExecution.swift` (FR-009 a FR-012)
- [x] T031 [US2] El controlador lanza ejecuciones con `RunProfile.act`, no ejecuta agentes en pausa y llama a `VerifyExecution` al terminar en `Sources/HirebarEngine/Controller.swift` (FR-002, FR-010)
- [x] T032 [US2] Aviso de acción no autorizada con los botones, `reanudar <agente>` y "en pausa" en `agentes` y `estado` en `Sources/HirebarEngine/Commands.swift` (FR-010, FR-011a)
- [x] T033 [US2] Agente "en pausa" con motivo y botón "Reanudar" en `Sources/Hirebar/PanelModel.swift` y `Sources/Hirebar/PanelView.swift` (FR-011a)

**Checkpoint**: toda acción queda verificada y una desviación pausa al agente.

---

## Phase 5: User Story 3 - Redes y seguimientos pasan por aprobación (Priority: P1)

**Goal**: las dos tareas que hoy envían solas producen listas para aprobar.

**Independent Test**: con el envío automático apagado y los fixtures `social` y `followups`, las dos
tareas terminan con una lista pendiente y ningún envío.

### Tests for User Story 3

- [x] T034 [P] [US3] Tests de que redes y seguimientos producen listas pendientes y de que con envío automático se aprueban solas, en `Tests/HirebarApplicationTests/ApprovalFlowTests.swift` (FR-013, FR-014, FR-016)
- [x] T035 [P] [US3] Test de que `replyToClient` y `publish` nunca se aprueban solos en `Tests/HirebarApplicationTests/ApprovalFlowTests.swift` (FR-015)

### Implementation for User Story 3

- [x] T036 [US3] La tarea de redes corre como lectura y produce una lista con la acción propuesta de cada elemento en `Sources/HirebarEngine/Controller.swift` y `Resources/inicial/instrucciones-redes.md` (FR-013)
- [x] T037 [US3] La revisión de seguimientos corre como lectura y produce una lista de seguimientos con su texto en `Sources/HirebarEngine/Controller.swift` y `Resources/inicial/instrucciones-seguimiento.md` (FR-014)
- [x] T038 [US3] El envío automático deja fuera `replyToClient` y `publish` en `Sources/HirebarEngine/Controller.swift` (FR-015, FR-016)

**Checkpoint**: ningún envío ocurre sin aprobación con el envío automático apagado.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T039 [P] Agregar a `Paths.previousVersions` las huellas de las reglas modificadas, para que las copias no editadas se actualicen solas en `Sources/HirebarCore/Paths.swift`
- [x] T040 [P] Scripts del motor de prueba `Tests/Fixtures/engine/read.sh` y `act.sh` que leen `$HIREBAR_WORKSPACE/.fixture`
- [x] T041 [P] README (Otra IA con dos comandos), `GUIA.md` (redes y seguimientos con aprobación, pausa y `reanudar`) y `CHANGELOG.md`
- [x] T042 Actualizar el "Estado actual" de `ARCHITECTURE.md` §6 y las divergencias que cierra esta spec en `specs/001`, `002`, `003`, `004`, `006` (el análisis solo escribe en `informes/`) y `007`
- [ ] T043 Correr `quickstart.md` de punta a punta en el worker y anotar el resultado en el PR
- [x] T044 Subir `.coverage-minimum` a la cobertura nueva medida en CI
- [x] T045 `swift-code-reviewer` y `/security-review` sobre el diff; resolver o responder cada hallazgo

---

## Dependencies & Execution Order

- **Setup (fase 1)**: T001 primero (contrato antes del código); T002 y T003 después.
- **Foundational (fase 2)**: depende de T002; bloquea las tres historias.
- **US1 (fase 3)**: depende de la fase 2. Es el MVP: cierra el riesgo de inyección.
- **US2 (fase 4)**: depende de la fase 2; usa los perfiles de US1 (T017, T018) para lanzar la
  ejecución con `act`.
- **US3 (fase 5)**: depende de US1 (corre como lectura) y de US2 (las listas se ejecutan verificadas).
- **Polish (fase 6)**: al final; T042 y T043 después de las tres historias.

### Parallel Opportunities

- T004, T005, T006, T009 y T013 en paralelo; T008 y T011 junto a su código.
- En US1, T014, T015 y T016 en paralelo antes de T017 a T021; T022 en paralelo con el código.
- En US2, T023, T024 y T025 en paralelo; T029 en paralelo con el código.

## Implementation Strategy

1. Fases 1 y 2.
2. US1 completa y verificada con el fixture `injection`: el riesgo principal queda cerrado.
3. US2: verificación y pausa.
4. US3: redes y seguimientos con aprobación.
5. Polish, quickstart en el worker y revisión con agentes; el PR #19 sale de borrador.

Cada fase termina con `swift build`, `scripts/coverage.sh` y `scripts/lint.sh origin/develop` en
verde, y un commit atómico por tarea o grupo de tareas del mismo cambio.
