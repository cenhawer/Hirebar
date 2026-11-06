# Feature Specification: Motor de IA

**Feature Branch**: `docs/spec-007-motor-ia`

**Created**: 2026-11-05

**Status**: Draft

**Input**: Spec as-is transversal: describe cómo Hirebar elige, lanza, vigila y recupera la IA de
terminal que hace el trabajo de todos los agentes, en el commit base de `develop`. Las desviaciones
de la constitución se listan al final con la spec que las corrige.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Elegir y probar la IA (Priority: P1)

La persona elige qué IA de terminal hace el trabajo (Claude Code, Codex, Gemini CLI o un comando
propio) y la prueba antes de confiarle sus cuentas.

**Why this priority**: sin una IA que responda, ningún agente puede postular, proponer, escribir ni
publicar.

**Independent Test**: con un comando propio de prueba que imprime "OK", el botón Probar responde
"Funciona"; con uno que imprime un mensaje de sesión vencida, responde que falta iniciar sesión.

**Acceptance Scenarios**:

1. **Given** Ajustes → Motor de IA, **When** la persona elige una opción, **Then** ve cómo
   instalarla, cómo darle acceso al navegador y, para Codex y Gemini, el comando que se usará.
2. **Given** la opción "Otra IA", **When** la persona escribe su comando, **Then** ve las variables
   `HIREBAR_PROMPT`, `HIREBAR_INSTRUCTIONS`, `HIREBAR_FULL_PROMPT` y `HIREBAR_WORKSPACE` que recibe.
3. **Given** una IA elegida, **When** la persona pulsa Probar, **Then** Hirebar le pide responder
   "OK" sin navegador y, en máximo 180 segundos, dice si funcionó, si falta iniciar sesión (con el
   comando para entrar) o el error.
4. **Given** que Claude Code no está instalado, **When** se prueba o se lanza una tarea, **Then** se
   responde cómo instalarlo y que se puede elegir otra IA.
5. **Given** "Otra IA" sin comando, **When** se lanza una tarea, **Then** se responde que falta el
   comando.

---

### User Story 2 - Que cada tarea corra con la IA elegida (Priority: P1)

Cada tarea de cada agente se ejecuta con la IA elegida, con sus reglas, en la carpeta de trabajo,
de a una por vez, y su respuesta llega a Telegram.

**Why this priority**: es el mecanismo por el que trabajan todos los agentes.

**Independent Test**: con un comando propio de prueba que escribe sus variables en un archivo, una
tarea lanzada recibe el pedido, la ruta de sus reglas y la carpeta de trabajo, y su salida llega al
doble de `Messenger`.

**Acceptance Scenarios**:

1. **Given** Claude Code elegido, **When** se lanza una tarea, **Then** corre `claude -p` con el
   pedido, las reglas de la tarea como instrucciones de sistema, las herramientas Read, Write, Edit,
   Glob, Grep, WebFetch y WebSearch, y Claude in Chrome salvo en la preparación de contenido sin
   revisión de rendimiento.
2. **Given** Codex, Gemini u otra IA, **When** se lanza una tarea, **Then** corre su comando en una
   terminal con las cuatro variables `HIREBAR_*`, en la carpeta de trabajo.
3. **Given** una tarea en curso, **When** se lanza otra, **Then** la segunda espera en la fila.
4. **Given** una tarea terminada con éxito, **When** su salida no está vacía, **Then** llega a
   Telegram (hasta 3.800 caracteres) y la lista queda "hecho".
5. **Given** una tarea que terminó con error, **When** no es por sesión vencida, **Then** llega a
   Telegram el código, las últimas líneas de la salida y la ruta de su registro, y la lista queda
   "error".
6. **Given** una tarea de seguimientos, redes o portales propios, **When** la IA responde
   `SIN_NOVEDADES`, **Then** no se manda nada a Telegram.
7. **Given** cada ejecución, **When** termina, **Then** su salida y sus errores quedan en
   `workspace/ejecuciones/<lote>.txt` y `.log`.

---

### User Story 3 - Recuperarse de sesiones vencidas, cuelgues y reinicios (Priority: P1)

Si la sesión de la IA se vence, una tarea se cuelga o la Mac se duerme, Hirebar no pierde el trabajo
aprobado y avisa a la persona sin llenarla de mensajes.

**Why this priority**: los agentes corren solos durante horas; un fallo no puede perder una lista
aprobada.

**Independent Test**: con un comando de prueba que imprime "please run /login" y termina con error,
la lista queda pendiente y llega un único aviso por hora.

**Acceptance Scenarios**:

1. **Given** una ejecución que termina con error y un mensaje de sesión vencida, **When** termina,
   **Then** la lista vuelve a pendiente con sus elementos y llega un aviso con el comando para volver
   a entrar.
2. **Given** varias sesiones vencidas seguidas, **When** pasan, **Then** el aviso llega como máximo
   una vez por hora.
3. **Given** una ejecución que lleva más de 1 hora, **When** el vigía la revisa (cada minuto),
   **Then** se detiene y se reporta.
4. **Given** que la app se reinicia con listas en curso de menos de 24 horas, **When** arranca,
   **Then** las listas de postulaciones o propuestas vuelven a pendiente con un aviso para
   reintentar, y las demás quedan "interrumpido".

---

### Edge Cases

- `claude` no está en ninguna de las rutas conocidas (`~/.local/bin`, `~/.claude/local`,
  `/opt/homebrew/bin`, `/usr/local/bin`): se busca con `command -v claude` en una terminal de inicio de
  sesión.
- La IA no se puede abrir: la lista queda "error", se avisa y sigue la siguiente.
- La salida está vacía con código 0: se trata como error.
- Codex o Gemini necesitan un servidor MCP de Chrome para usar el navegador: Hirebar no verifica que
  esté configurado, y qué pasa sin él depende de cada IA.

## Requirements *(mandatory)*

### Functional Requirements

**Elección y prueba**

- **FR-001**: La persona MUST poder elegir Claude Code (por defecto), Codex, Gemini CLI u Otra IA, y
  guardar la elección en `config.json`.
- **FR-002**: Para Codex y Gemini, Hirebar MUST usar un comando fijo (`codex exec --sandbox
  workspace-write …`, `gemini --approval-mode yolo …`) que se muestra en Ajustes; Otra IA usa el
  comando de la persona.
- **FR-003**: Probar MUST lanzar la IA sin navegador con la pregunta "Responde solo: OK", esperar
  hasta 180 segundos y clasificar el resultado en funciona, falta iniciar sesión o error.

**Ejecución**

- **FR-004**: Claude Code MUST lanzarse con `-p <pedido>`, `--permission-mode bypassPermissions`,
  las herramientas Read, Write, Edit, Glob, Grep, WebFetch y WebSearch, `--append-system-prompt-file`
  con las reglas de la tarea y, con navegador, `--chrome` y las herramientas de Claude in Chrome.
- **FR-005**: Las demás IA MUST lanzarse con `zsh -lc <comando>` y las variables `HIREBAR_PROMPT`,
  `HIREBAR_INSTRUCTIONS`, `HIREBAR_FULL_PROMPT` (reglas y pedido juntos) y `HIREBAR_WORKSPACE`.
- **FR-006**: Toda ejecución MUST correr en la carpeta de trabajo, sin entrada estándar, con su
  salida y sus errores en `workspace/ejecuciones/<lote>.txt` y `.log`.
- **FR-007**: Las ejecuciones MUST ser de a una; una misma tarea MUST NOT encolarse dos veces para la
  misma cuenta.
- **FR-008**: El pedido de cada tarea MUST incluir su identificador de lote, la fecha y, según la
  tarea, la lista de elementos, el cupo diario del agente (Empleo y Freelance), la ficha de la cuenta
  (Contenido) y la indicación de cómo usar el navegador según la IA.
- **FR-009**: La salida MUST llegar a Telegram salvo `SIN_NOVEDADES` en las tareas que lo admiten; al
  terminar, la app MUST seguir con el paso propio de la tarea (correos, PDF o láminas).

**Recuperación**

- **FR-010**: Una ejecución que pasa de 1 hora MUST detenerse.
- **FR-011**: Una sesión vencida, detectada por los mensajes conocidos de cada IA, MUST devolver la
  lista a pendiente y avisar como máximo una vez por hora con el comando para volver a entrar.
- **FR-012**: Al arrancar, las listas en curso de menos de 24 horas con elementos MUST volver a
  pendiente con un aviso; las demás MUST quedar "interrumpido".
- **FR-013**: El panel MUST mostrar si la IA está libre o trabajando y en qué ("haciendo 3
  postulaciones (desde 10:15)").

### Key Entities

- **Motor de IA (AIEngineSettings)**: tipo (claude, codex, gemini, custom) y comando propio.
- **Ejecución**: lote, tarea, cuenta, inicio, proceso, salida y errores.
- **Lista (Batch)**: como en la spec `001-agente-empleo`; su estado refleja la ejecución.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nunca corren dos ejecuciones de IA a la vez.
- **SC-002**: Ninguna lista aprobada se pierde por una sesión vencida o un reinicio de menos de 24
  horas.
- **SC-003**: Ninguna ejecución sigue corriendo más de 1 hora y un minuto.
- **SC-004**: Una racha de sesiones vencidas produce como máximo un aviso por hora.
- **SC-005**: Probar da un resultado en máximo 180 segundos.

## Assumptions

- La IA elegida está instalada y con sesión iniciada por la persona.
- Claude in Chrome (o el servidor MCP de Chrome de Codex y Gemini) está instalado en el Chrome de la
  persona.
- Los mensajes que indican sesión vencida son los que hoy imprime cada IA; si cambian, la detección
  deja de funcionar hasta actualizarlos.

## Divergencias con la constitución

| Comportamiento actual | Principio | Se corrige en |
|---|---|---|
| Los tres motores corren sin pedir permisos (`bypassPermissions`, `--sandbox workspace-write`, `--approval-mode yolo`) en todas las tareas, incluidas las que leen contenido externo | III | `010-separar-lectura-ejecucion` |
| Las acciones que hace la IA no pasan por una lista cerrada que valide la app | III | `010-separar-lectura-ejecucion` |
| Los registros de cada ejecución en `workspace/ejecuciones/` pueden contener datos personales y no tienen retención definida | IV | `023-logs-oslog` · `029-politica-datos` |
| Rutas de instalación, mensajes de sesión vencida, plazos (1 hora, 24 horas, 180 segundos) y comandos de cada motor escritos en el código | VI | `024-textos-y-valores-fuera-del-codigo` |
| El lanzamiento usa `Process` desde el motor, sin puerto | VIII | `017-arquitectura-hexagonal` (`AIRunner`) |
| La ejecución y la recuperación no tienen tests | VII | `019-tests-engine` |

## Hallazgos sin principio asociado

- El vigía detiene una ejecución colgada por dos caminos a la vez (un temporizador cada minuto y una
  espera de 1 hora por ejecución). Se unifica en `017-arquitectura-hexagonal`, con el reloj como
  puerto.
