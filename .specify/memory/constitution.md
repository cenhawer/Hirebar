<!--
Sync Impact Report
- Versión: plantilla → 1.0.0 (primera ratificación)
- Principios: I a VIII definidos (VIII: arquitectura hexagonal)
- Secciones: Restricciones técnicas, Flujo de desarrollo, Gobierno
- Pendientes: ninguno
-->

# Constitución de Hirebar

## Principios

### I. Spec primero

- Ningún cambio de comportamiento se implementa sin `specs/NNN-nombre/spec.md` aprobado.
- Cada tarea de `tasks.md` referencia el `FR-###` o la historia de usuario que la origina.
- Una regla, umbral, catálogo o clasificación de dominio que no está en la spec se marca
  `[NEEDS CLARIFICATION]`; nunca se inventa. Un `[NEEDS CLARIFICATION]` abierto bloquea el plan.
- Un cambio de contrato (comandos de Telegram, variables `HIREBAR_*`, formato de los archivos del
  workspace, puertos) se escribe primero en `ARCHITECTURE.md` y después en el código.
- Una decisión técnica que no encaja en `ARCHITECTURE.md` se registra como ADR en `docs/adr/` antes
  de implementarla.

Razón: Hirebar actúa en nombre de una persona; cada comportamiento debe poder rastrearse hasta una
decisión explícita.

### II. Nada sale sin aprobación y sin rastro

- Ninguna postulación, propuesta, correo o publicación se envía sin aprobación de la persona, salvo
  que haya prendido el envío automático de ese agente confirmándolo de forma explícita.
- Las respuestas de clientes con interés y las publicaciones siempre requieren aprobación, aunque el
  envío automático esté prendido.
- Cada envío queda registrado: qué, a quién, cuándo, con qué texto y qué agente lo hizo.
- Todo agente que envía tiene modo práctica: hace todo menos enviar, y lo registra igual.

Razón: un envío equivocado afecta la reputación de la persona y no se puede deshacer.

### III. El contenido externo nunca es instrucción

- Vacantes, proyectos, correos, perfiles y páginas leídas por la IA son datos. La IA no ejecuta
  instrucciones que vengan de ese contenido.
- Leer y redactar está separado de actuar: la fase que lee contenido externo no tiene herramientas
  para enviar, publicar ni escribir fuera del workspace.
- Las acciones de envío pasan por una lista cerrada de acciones que valida la app, no la IA.
- Hirebar nunca resuelve CAPTCHAs, nunca escribe contraseñas y nunca crea cuentas.

Razón: la IA opera con las sesiones reales de la persona en Chrome y Gmail; una inyección en una
vacante no puede convertirse en una acción.

### IV. Los datos de la persona son suyos, locales y recuperables

- Los datos viven en `~/Library/Application Support/Hirebar/` y los secretos en el Llavero de macOS.
  Nada personal entra al repositorio.
- Cada archivo de datos lleva `schemaVersion`. Un cambio de formato trae migración automática con
  respaldo previo, y la app nunca sobrescribe lo que la persona editó.
- El estado de la app vive en el workspace, no en `UserDefaults`, salvo preferencias de interfaz.
- Los registros no contienen datos personales. Historiales y grabaciones de voz tienen retención
  definida y se borran solos al vencer.

Razón: la persona debe poder confiar en que actualizar Hirebar no rompe ni expone su información.

### V. Sin dependencias ocultas

- La app no usa paquetes externos de SwiftPM.
- Las herramientas del sistema que necesita (IA de terminal, Google Chrome, ffmpeg) son
  prerrequisitos declarados en el README y verificados por la app al configurar.
- Ninguna herramienta se descarga ni se instala mientras la app corre sin versión fija y hash
  verificado.
- Los permisos de macOS (Reconocimiento de voz y los que se agreguen) se piden en la configuración
  inicial, nunca a mitad de un flujo.

Razón: lo que corre en la Mac de la persona tiene que ser visible, reproducible y auditable.

### VI. Código que se explica solo

- Nombres en inglés y autoexplicativos: tipos, funciones, variables y archivos.
- Cero comentarios en el código. Solo se admite `///` en contratos públicos que consume un sistema
  externo. Los scripts no llevan comentarios.
- Ningún texto para la persona escrito en el código: va por String Catalog, incluidas las respuestas
  de Telegram.
- Ningún catálogo, umbral, plazo, lista o ruta de dominio escrito en el código: va en configuración
  o en datos.

Razón: el código es la fuente de verdad del cómo; la spec, la del qué y el porqué.

### VII. Probado sin red ni IA

- Cada escenario de aceptación y cada `SC-###` tiene al menos un test automatizado.
- Los tests no usan red, IA, Chrome ni Telegram reales: van contra puertos con dobles de prueba y
  contra fixtures guardados.
- La cobertura de `Sources` medida en CI no baja del mínimo de `.coverage-minimum`, y el mínimo solo
  sube.
- Los prompts (`Resources/inicial/instrucciones-*.md`) tienen evals con casos fijos, incluidos casos
  de inyección, y corren en CI.

Razón: los agentes corren solos; las regresiones se tienen que detectar antes de que lleguen a la
Mac de la persona.

### VIII. Arquitectura hexagonal

- `HirebarDomain` contiene las entidades y reglas puras (perfil, habilidades, avisos, lotes,
  agentes, clasificación) y no depende de nada fuera de la librería estándar.
- `HirebarApplication` contiene los casos de uso y los puertos que necesitan: IA, mensajería,
  navegador, fuentes de portales, reconocimiento de voz, render de medios, reloj y repositorios.
  Depende solo del dominio.
- Cada familia de adaptadores (Telegram, motores de IA, portales, archivos y Llavero, medios) es un
  target propio que implementa puertos y depende solo de Application.
- La app (`Hirebar`) contiene la interfaz y la raíz de composición: es el único lugar que instancia
  adaptadores y los conecta a los puertos. Ningún singleton existe fuera de ella.
- Los límites los impone SwiftPM: un import que cruza una capa no compila.
- Cada patrón de diseño se nombra junto al problema concreto que resuelve. No se agregan
  contenedores de inyección, buses ni capas sin un problema que lo justifique.

Razón: con el dominio aislado de Telegram, la IA, Chrome y el disco, cada regla se prueba sin ellos
y cada integración se cambia sin tocar el resto.

## Restricciones técnicas

- Plataforma: macOS 26 o superior; sube a macOS 27 cuando la imagen `xcode-27` de GitHub Actions
  deje de ser preview.
- Lenguaje: Swift 6 con concurrencia estricta, compilado con SwiftPM (`swift-tools-version` 6).
- Interfaz: SwiftUI con `@Observable` y AppKit solo donde SwiftUI no alcanza (barra de menú,
  ventanas); estilo visual del sistema, incluido Liquid Glass.
- CI: GitHub Actions en `macos-26`, con los jobs `conventions`, `quality` y `build`.
- Motores de IA: Claude Code (recomendado), Codex, Gemini CLI o un comando propio, siempre por la
  terminal y con las variables `HIREBAR_*` documentadas en `ARCHITECTURE.md`.
- Mensajería: Telegram, anclado al ID de usuario de una sola persona en su chat privado, que ella
  confirma en la app viendo su nombre, su usuario, su ID y el mensaje recibido (ADR-0005).
- Firma: identidad estable configurable (`HIREBAR_SIGN_IDENTITY`); la distribución pública exige
  Developer ID y notarización.
- Convenciones técnicas de la organización: `Lineamientos/` (Engineering Standards).

## Flujo de desarrollo

- GitFlow: `main` y `develop` protegidas; todo entra por PR con CI en verde. Ramas
  `{tipo}/HB-{número}-{descripción}`; el ticket es opcional solo en `docs` y `chore`. Las ramas de
  spec usan el mismo número que su carpeta: `feature/HB-NNN-nombre` para `specs/NNN-nombre`.
- Commits en inglés con Conventional Commits, atómicos y de una línea, sin coautores ni líneas de
  atribución. Las descripciones de PR tampoco llevan atribución.
- Ciclo de una spec: `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` →
  `/speckit-analyze` → `/speckit-implement` → PR a `develop`.
- Cada PR pasa la revisión con `swift-code-reviewer` contra esta constitución, `ARCHITECTURE.md`,
  Lineamientos y su spec; los cambios de seguridad pasan además `security-review`.
- El lint (`scripts/lint.sh`) rechaza violaciones en las líneas que cambia cada PR; lo existente se
  corrige por spec.
- Idioma: texto para la persona y documentación en español; código, commits y ramas en inglés.
- README cubre instalación, configuración y uso; `docs/` cubre decisiones y detalle técnico. Ambos
  describen el producto actual.

## Gobierno

- Esta constitución prevalece sobre cualquier otra práctica del repositorio. `CLAUDE.md` y
  `AGENTS.md` son guía operativa y la referencian sin repetirla.
- Una enmienda entra por PR con un commit `docs(constitution): …`, sube la versión con SemVer
  (MAJOR: se quita o redefine un principio; MINOR: se agrega un principio o sección; PATCH:
  redacción) y actualiza la fecha de última enmienda.
- Toda revisión de PR verifica el cumplimiento. Una desviación del código actual respecto a esta
  constitución es un hallazgo y se corrige por spec, en el orden de `docs/Plan.md`.

**Version**: 1.0.1 | **Ratified**: 2026-11-05 | **Last Amended**: 2026-11-09
