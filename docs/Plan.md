# Plan de reorganización de Hirebar

> 🟡 **BORRADOR, no ejecutable.** Faltan las fechas y la decisión D3 de la sección 1.1.

## 0. Objetivo

Llevar Hirebar a desarrollo guiado por specs (SDD), cerrar los riesgos de seguridad y después mejorar UX, UI y accesibilidad sin romper lo que ya funciona.

Línea base: commit `96e7a97` ("Narrate shorts with the user's voice note").

## 1. Planeación

### 1.1 Decisiones pendientes

| # | Decisión | Opciones | Estado |
|---|---|---|---|
| D1 | Forma de trabajo con el repo | Push directo a `VictorMMosqueraG/Hirebar` · fork + PR | ✅ Fork + PR hacia `VictorMMosqueraG/Hirebar` |
| D2 | Máquina de build y test | M5 · worker (M1) | ✅ Worker, con `--scratch-path ~/Library/Caches/hirebar-build` para que `.build/` no se sincronice por iCloud |
| D3 | Usuarios además del autor | Sí · no (define la exigencia de migraciones y rollback) | ⬜ |
| D4 | `graphify-out/` en git | Ignorado (propuesto) · versionado | ✅ Ignorado: el grafo vive en el worker |
| D5 | Código de proyecto para los tickets de las ramas (`feature/{TICKET}-{descripción}`) | `HB` (propuesto: ramas `feature/HB-001-nombre`) · otro | ✅ `HB`, configurado en `.conventions` |
| D6 | Archivo de contexto para otros agentes (Codex, Gemini) | Solo `CLAUDE.md` · `CLAUDE.md` + `AGENTS.md` sincronizados | ✅ `AGENTS.md` como fuente única (la extensión `agent-context` mantiene su bloque) y `CLAUDE.md` que lo importa con `@AGENTS.md`; la configuración de cada máquina en `CLAUDE.local.md`, sin versionar |
| D7 | ffmpeg para limpiar la nota de voz | Prerrequisito del sistema · instalarlo en ejecución con versión fija y hash · reemplazarlo por AVFoundation · empaquetarlo con la app | ✅ Prerrequisito del sistema (`brew install ffmpeg`), detectado y pedido en la configuración inicial; se revisa con un ADR en la fase 7 si la app se distribuye a personas que no compilan |
| D8 | Versión mínima de macOS | macOS 13 (actual) · macOS 26 · macOS 27 | ✅ macOS 26 (Liquid Glass, `@Observable`, SwiftUI actual, Swift 6); macOS 27 cuando la imagen `xcode-27` de GitHub Actions deje de ser preview |

### 1.2 Prerrequisitos

| # | Qué | Estado |
|---|---|---|
| P1 | Clon de trabajo en `~/Documents/workspace/projects/personal/hirebar`, rama `docs/reorganization-plan` | ✅ |
| P2 | Xcode completo en la máquina de build (`swift test` necesita XCTest) | ✅ Worker: Xcode, Swift 6.4.2 |
| P3 | Spec Kit (`specify`) con la extensión `agent-context` disponible | ✅ |
| P4 | Graphify (solo en el worker) | ✅ |
| P5 | Features nuevas congeladas durante las fases 0 a 2, acordado con el autor | ⬜ |
| P6 | Permiso de Reconocimiento de voz de macOS concedido en la Mac de pruebas (lo pide el flujo de video narrado) | ⬜ |
| P7 | ffmpeg en la Mac de pruebas (`brew install ffmpeg`), requerido por el video narrado | ⬜ |

### 1.3 Partes interesadas

| Quién | Rol | Se le informa | Se le consulta |
|---|---|---|---|
| cenhawer | Decide, aprueba specs y PR | Siempre | — |
| Víctor Mosquera | Autor, owner del repo, usuario principal | Al cerrar cada fase | Antes de cada rollback, y de cada cambio de formato de datos |
| Usuarios actuales | Reciben versiones | En cada release (CHANGELOG) | — |

### 1.4 Reglas del proyecto

Fuente: `Lineamientos/` (Engineering Standards). La constitution (actividad 1.2) las fija para Hirebar.

| Área | Regla |
|---|---|
| Nombres | En inglés y autoexplicativos: clases, métodos, variables y archivos |
| Comentarios | Cero en el código interno; `///` solo en contratos públicos que consume otro sistema; cero en scripts |
| Textos | Ningún texto de usuario escrito en el código: van por String Catalog |
| Valores | Ningún catálogo, umbral, plazo o lista de dominio escrito en el código: van en configuración o datos; si no se conocen, `[NEEDS CLARIFICATION]` |
| Diseño | Arquitectura hexagonal: dominio y casos de uso al centro, puertos en Application, adaptadores afuera, límites impuestos por los targets de SwiftPM; cada patrón justificado por el problema que resuelve |
| Permisos de macOS | Se piden en la configuración inicial, nunca a mitad del uso |
| Documentación | README = instalación, configuración y uso; `docs/` = decisiones y detalle técnico; describen el estado actual, sin historial |
| Idioma | Texto para el usuario en español; código en inglés; commits y ramas en inglés |
| Commits | Conventional Commits (`tipo(scope): descripción`, imperativo, minúsculas, ≤ 72 caracteres), atómicos, de una línea |
| Ramas | `{tipo}/{TICKET}-{descripción-kebab}` (ticket opcional solo en `docs` y `chore`); GitFlow con `main` y `develop`; prohibido commitear directo a ambas |
| SDD | Nada se implementa sin `spec.md`; trazabilidad `FR-###`/`SC-###` → test; `[NEEDS CLARIFICATION]` sin resolver bloquea el plan; un cambio de contrato se actualiza primero en `ARCHITECTURE.md`; una decisión nueva va antes como ADR |

## 2. Ejecución

### 2.0 Cronograma

| Fase | Qué | Duración est. | Inicio | Depende de |
|---|---|---|---|---|
| 0 | Preparación, higiene y herramientas | 2–3 días | `<fecha>` | — |
| 1 | Base SDD: constitution, `ARCHITECTURE.md`, contexto del agente y specs del sistema actual | 1–1,5 semanas | `<fecha>` | 0 |
| 2 | Seguridad, evals de prompts y modo práctica | 2 semanas | `<fecha>` | 1 |
| 3 | Arquitectura habilitante, fixtures y datos versionados | 2 semanas | `<fecha>` | 2 |
| 4 | UX: asistente de primer uso y editor de perfil | 2 semanas | `<fecha>` | 3 |
| 5 | UX: bandeja de pendientes, actividad y política de datos | 2–3 semanas | `<fecha>` | 3 |
| 6 | UI y accesibilidad | 1 semana | `<fecha>` | 3 (en paralelo con 4 y 5) |
| 7 | Distribución: firma Developer ID, notarización y aviso de versión | 1 semana | `<fecha>` | 5 |

Ruta crítica: 0 → 1 → 2 → 3 → (4 ∥ 5 ∥ 6) → 7.

### 2.1 Fase 0: preparación, higiene y herramientas

| # | Actividad | Responsable | Duración | Verificación |
|---|---|---|---|---|
| 0.1 | Crear `develop` desde `main` y proteger ambas: PR obligatorio y CI en verde | Víctor | 15 min | Un push directo a `main` o a `develop` es rechazado |
| 0.2 | Build y test de línea base sobre `96e7a97`, resultado anotado en `docs/linea-base.md` | cenhawer | 30 min | `swift build` y `swift test` en verde |
| 0.3 | Tag `v<VERSION>-baseline` sobre `96e7a97` con su zip en Releases | Víctor | 10 min | El tag y el zip existen (es el punto de rollback) |
| 0.4 | Quitar datos personales de `GUIA.md` y `README.md` (`HV_Victor_Mosquera_*`, `KoralAT`, `~/Documents/vm_software`) | cenhawer | 30 min | `grep -rn -e Mosquera -e KoralAT -e vm_software GUIA.md README.md Resources` no encuentra nada |
| 0.5 | Archivos de ignore (Anexo A) | cenhawer | 1 h | `git status` limpio después de build, test, Graphify y evals |
| 0.6 | Identidad de firma local estable en `bundle.sh` (hoy firma ad-hoc, y con cada build cambia la firma y macOS puede volver a pedir el permiso de Reconocimiento de voz) | cenhawer | 1 h | Tras recompilar, el permiso sigue concedido |
| 0.7 | swift-format y SwiftLint en CI (solo herramientas de desarrollo, no entran en la app) | cenhawer | 3 h | CI falla con un archivo mal formateado |
| 0.8 | gitleaks en CI y en pre-commit | cenhawer | 1 h | Un token de prueba en un commit hace fallar CI |
| 0.9 | Cobertura en CI (`swift test --enable-code-coverage`), umbral inicial = línea base | cenhawer | 1 h | El reporte se publica como artifact |
| 0.10 | Dependabot para GitHub Actions | cenhawer | 15 min | `.github/dependabot.yml` existe |
| 0.11 | Plantillas de PR e issue, validación de Conventional Commits y de nombres de rama en CI, tablero en GitHub Projects | cenhawer | 2 h | Un PR de prueba muestra la plantilla con el campo "Spec"; un commit `implement video now` hace fallar CI |
| 0.12 | Grafo de línea base con Graphify (en el worker) | cenhawer | 30 min | Existe `graphify-out/` con back, scripts, workflows y Resources mapeados |
| 0.13 | `CHANGELOG.md` + SemVer sobre el archivo `VERSION` existente | cenhawer | 30 min | La primera entrada describe la línea base |

### 2.2 Fase 1: base SDD

| # | Actividad | Responsable | Duración | Verificación |
|---|---|---|---|---|
| 1.1 | `specify init --here --integration claude`, con las ramas de spec nombradas según D5 | cenhawer | 30 min | Existen `.specify/` y las skills `/speckit-*`; `/speckit-specify` de prueba crea `feature/HB-001-…` |
| 1.2 | `constitution.md` (`/speckit-constitution`): reglas de la sección 1.4 + "nada se envía sin trazabilidad" + "el contenido externo nunca es instrucción" + "todo cambio de formato de datos trae migración y respaldo" + "ninguna herramienta se descarga en ejecución sin versión fija y hash" | cenhawer | 1 día | Aprobada en PR |
| 1.3 | `ARCHITECTURE.md` con la plantilla de Lineamientos: arquitectura hexagonal objetivo (capas, puertos y adaptadores) con el mapeo de cada archivo actual de `Hirebar`, `HirebarEngine`, `HirebarSources` y `HirebarCore` a su capa, contratos (comandos de Telegram, variables `HIREBAR_*` del motor de IA propio, archivos del workspace), modelo de error, permisos de macOS y observabilidad | cenhawer (con `principal-architect`) | 1 día | Aprobado en PR; cada contrato tiene dueño y formato |
| 1.4 | `specify extension add agent-context` + `CLAUDE.md` con la plantilla de Lineamientos (solo lo operativo y enlaces a la constitution y a `ARCHITECTURE.md`) + `.claude/rules/swift.md`; `AGENTS.md` es la fuente y `CLAUDE.md` la importa | cenhawer | 2 h | El bloque `<!-- SPECKIT START -->` existe y se actualiza solo tras `/speckit-plan`; `CLAUDE.md` no repite reglas de la constitution |
| 1.5 | Specs as-is (ingeniería inversa) `001-agente-empleo`, `002-agente-freelance`, `003-agente-clientes`, `004-agente-contenido` (carrusel, video narrado con nota de voz, revisión semanal de rendimiento), `005-agente-perfil` y `006-agente-analista` | cenhawer | 3 días | Una spec por agente con `FR-###`, `SC-###` y escenarios Dado/Cuando/Entonces |
| 1.6 | Specs as-is transversales `007-motor-ia`, `008-telegram-y-comandos` (texto, botones y audio) y `009-panel-y-ajustes` | cenhawer | 1 día | Ídem |
| 1.7 | Carpeta `docs/adr/` con plantilla y los ADR de las decisiones ya tomadas: 0001 SDD con Spec Kit, 0002 arquitectura hexagonal, 0003 ffmpeg como prerrequisito, 0004 macOS 26 y Swift 6 | cenhawer | 2 h | Los cuatro ADR aprobados y enlazados desde `ARCHITECTURE.md` §10 |
| 1.8 | Paso en CI: un PR que toca `Sources/` debe referenciar una spec | cenhawer | 2 h | Un PR de prueba sin spec falla |
| 1.9 | Revisión con agentes en cada PR: `swift-code-reviewer` contra constitution, `ARCHITECTURE.md`, Lineamientos y spec; `security-review` desde la fase 2 | cenhawer | — | Hay comentarios del reviewer en el PR |

### 2.3 Fases 2 a 7: specs que se abren

Las specs as-is de la fase 1 ocupan `001` a `009`; las specs de cambio empiezan en `010`, en este orden.

Cada spec sigue el ciclo `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-analyze` → `/speckit-implement` → PR a `develop`. El detalle de actividades vive en el `tasks.md` de cada spec.

| Fase | Spec (`specs/NNN-nombre`, rama `feature/HB-NNN-nombre`) | Criterio de salida |
|---|---|---|
| 2 | `010-separar-lectura-ejecucion` | La IA lee y redacta sin poder actuar; el envío usa una lista cerrada de acciones; sin `bypassPermissions` con contenido externo. Incluye la revisión semanal de rendimiento del agente Contenido, que ahora abre Chrome en las redes |
| 2 | `011-confirmar-envio-automatico` | Prender el envío automático pide confirmación explícita |
| 2 | `012-canal-de-mensajes` | El chat de Telegram se vincula con un código que muestra la app, no con el primer mensaje; sin Telegram, el respaldo son las notificaciones de macOS (permiso pedido en la configuración inicial) que llevan a la bandeja del panel; se elimina ntfy.sh |
| 2 | `013-parser-comandos` | `CommandParser` puro con tests de tabla; ningún verbo se usa en dos comandos; los audios entran por el mismo parser |
| 2 | `014-modo-practica` | Un agente en modo práctica hace todo menos enviar, y lo registra |
| 2 | `015-evals-prompts` | Casos fijos para cada `instrucciones-*.md`: clasificación, "no inventa logros", inyección en vacante falsa → ninguna acción; corren en CI |
| 2 | `016-herramientas-en-ejecucion` | ffmpeg se toma del sistema y se valida al configurar (sin `pip` ni descargas en ejecución); requisito listado en el README; tamaño máximo para los audios que llegan por Telegram |
| 3 | `017-arquitectura-hexagonal` | Targets `HirebarDomain`, `HirebarApplication`, un target por familia de adaptadores y la app como raíz de composición; puertos `AIRunner`, `Messenger`, `Browser`, `PortalSource`, `SpeechRecognizer`, `MediaRenderer`, `Clock` y repositorios; ningún `.shared` fuera de la raíz de composición; un import que cruce un límite no compila |
| 3 | `018-macos-26-swift-6` | `platforms: [.macOS(.v26)]`, `swift-tools-version` 6 con concurrencia estricta, `@Observable` en lugar de `ObservableObject`; sin código de compatibilidad con versiones anteriores |
| 3 | `019-tests-engine` | Scheduler, Commands y Controller con tests sin red ni IA, incluido el flujo de nota de voz |
| 3 | `020-partir-archivos` | Ningún archivo de más de 300 líneas (`Settings`, `ContentSettings`, `ReelRenderer`, `Controller`, `Commands`); ningún `///` en código interno |
| 3 | `021-fixtures-portales` | Un HTML guardado por portal; cada scraper se testea contra su fixture |
| 3 | `022-version-datos` | `schemaVersion` en config, perfil, agentes y cuentas; el estado que hoy vive en `UserDefaults` (`video.esperandoVoz`, `portals.seen`) pasa al workspace versionado; migración con respaldo previo; borrado de las claves huérfanas del Llavero (`elevenlabs`, `azure-speech`, `azure-speech-region`) y "Desinstalar" del README completo |
| 3 | `023-logs-oslog` | `OSLog` con categoría por agente; sin datos personales en los registros |
| 3 | `024-textos-y-valores-fuera-del-codigo` | Ningún texto de usuario en el código, incluida la ayuda y las respuestas de Telegram (String Catalog); palabras de búsqueda, plazos y timeouts en configuración |
| 4 | `025-asistente-primer-uso` | Instalar y configurar sin editar JSON; checklist visible en el panel, con los permisos de macOS (Reconocimiento de voz) pedidos en el asistente y no a mitad de un flujo |
| 4 | `026-editor-perfil` | Datos, experiencia, preferencias y `cvVariants` editables en Ajustes |
| 5 | `027-bandeja-pendientes` | Aprobar desde el panel con vista previa de cada envío, incluido el video narrado |
| 5 | `028-vista-actividad` | Cada envío queda trazado: qué, a quién, cuándo y con qué texto |
| 5 | `029-politica-datos` | Retención definida para historiales, postulaciones y grabaciones de voz (`grabacion.*`), con borrado automático |
| 6 | `030-accesibilidad` | VoiceOver lee todos los controles; el estado nunca depende solo del color; fuentes semánticas |
| 6 | `031-panel-uso` | Zonas de clic separadas en la fila del agente; scroll con altura máxima; copy sin jerga |
| 7 | `032-firma-notarizacion` | App firmada con Developer ID y notarizada; Gatekeeper no la bloquea |
| 7 | `033-aviso-version` | La app avisa de releases nuevos en GitHub sin dependencias externas |

## 3. Cierre (por fase)

| # | Actividad | Responsable | Verificación |
|---|---|---|---|
| C1 | E2E en una Mac limpia: instalar, configurar y correr un agente en modo práctica (desde la fase 2) | cenhawer | Checklist E2E completo |
| C2 | Release con tag, zip y entrada en CHANGELOG | cenhawer | Release publicado |
| C3 | Grafo de Graphify actualizado y comparado con el anterior | cenhawer | Sin dependencias nuevas no explicadas |
| C4 | Balance corto con el autor: qué salió y qué pasa a la siguiente fase | cenhawer convoca | Notas en el issue de la fase |

## 4. Rollback

| Disparador (objetivo) | Acción | Consulta previa |
|---|---|---|
| Un envío sale sin aprobación con el envío automático apagado | Revertir al tag anterior y apagar todos los agentes | No: se revierte y se avisa después |
| La app no abre o se cae al iniciar | Revertir al tag anterior | Autor |
| Un agente deja de correr más de 24 h por un cambio nuevo | Revertir el PR causante | Autor |
| Un cambio de formato daña archivos en `~/Library/Application Support/Hirebar/` | Restaurar el respaldo de la migración y revertir la versión | Autor |
| Los evals de prompts bajan del umbral acordado tras un cambio de instrucciones | Revertir el cambio de `instrucciones-*.md` | No |
| El video narrado deja de salir en la Mac de pruebas tras un cambio (permiso, ffmpeg o render) | Revertir el PR causante | Autor |

## 5. Riesgos

| Riesgo | Mitigación |
|---|---|
| El autor sigue sacando features sin spec ni tests: 8 commits el 4 nov; `3c7c07e` agregó Azure (952 líneas) y `96e7a97` lo quitó el mismo día, sin un solo test | Congelamiento (P5) desde ya; después, toda feature entra por spec → PR |
| El código está lejos de las reglas de la sección 1.4: 76 `///` internos, unos 200 textos y unos 24 plazos escritos en el código, commits sin Conventional Commits | Se corrige por spec (`020`, `024`) y no en un solo commit masivo; CI impide que entren casos nuevos desde la fase 0 |
| El Engine no tiene tests y el refactor rompe algo | Las specs as-is (fase 1) y los tests (fase 3) van antes de mover código |
| La app descarga e instala ffmpeg con pip en la Mac del usuario, sin versión fija | D7: pasa a prerrequisito del sistema (spec `016`) y regla en la constitution |
| La firma ad-hoc cambia en cada build y macOS vuelve a pedir permisos | Actividad 0.6 (firma local estable) y fase 7 (Developer ID) |
| Los portales cambian su HTML | Fixtures (`021`) y alerta en CI |
| Claude CLI cambia sus flags | El adaptador del puerto `AIRunner` (`017`) aísla el cambio |
| Graphify solo está en el worker | El grafo se genera allí; el clon debe existir en el worker o sincronizarse antes de C3 |
| Firma y notarización requieren cuenta de Apple Developer (pago anual) | La fase 7 va al final y no bloquea las anteriores |

## Anexo A: archivos de ignore

| Archivo | Para qué | Contenido propuesto |
|---|---|---|
| `.gitignore` (ampliar) | Que nada generado ni personal entre al repo | Mantener lo actual y agregar: `graphify-out/` (si D4 = ignorado), `*.xcresult`, `/coverage/`, `/evals/out/`, `.env`, `.env.*`, `*.p12`, `*.cer`, `*.mobileprovision`, `.claude/settings.local.json`, `*.mp3`, `*.m4a`, `*.oga`, `*.mp4` |
| `.graphifyignore` | Mapear todo excepto lo generado, lo sensible y `.claude/` | `.build/`, `.swiftpm/`, `dist/`, `DerivedData/`, `graphify-out/`, `coverage/`, `evals/out/`, `.claude/`, `Tests/Fixtures/portals/` (HTML de terceros, no es código del proyecto) |
| `.gitleaks.toml` | Reglas de gitleaks + allowlist | Allowlist solo para los placeholders de `Resources/inicial/` y los fixtures de tests |
| `.gitleaksignore` | Falsos positivos puntuales | Vacío al inicio; cada entrada por fingerprint y con justificación en el PR |
| `.swiftlint.yml` (`excluded:`) | Que el lint no revise lo generado | `.build`, `.swiftpm`, `DerivedData`, `Tests/Fixtures` |
| `.gitattributes` | Que los fixtures no ensucien diffs ni estadísticas | `Tests/Fixtures/** linguist-generated=true -diff` |
| `.claude/settings.json` (`permissions.deny`) | Claude Code no tiene archivo `.claudeignore`; los archivos que no debe leer se bloquean con permisos | `Read` denegado a `.env*`, `*.p12` y `~/Library/Application Support/Hirebar/**` |
