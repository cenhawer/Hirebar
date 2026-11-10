# Hirebar

App para la barra de menú de macOS que busca empleo remoto, proyectos freelance y clientes por ti. Revisa los portales cada pocos minutos, filtra con tu perfil y te avisa por Telegram. Cuando apruebas (o si activas el envío automático), una IA de terminal abre tu Chrome, redacta y envía las propuestas o postulaciones, y te cuenta qué hizo. La IA solo actúa sobre lo que aprobaste, y Hirebar verifica cada envío: si algo no coincide, el agente queda en pausa hasta que lo revises. Puedes usar [Claude Code](https://claude.com/claude-code) (recomendado), Codex de OpenAI, Gemini CLI de Google u otra que se pueda ejecutar desde la terminal.

Está dividida en agentes independientes, cada uno con su horario: **Empleo, Freelance, Clientes, Contenido, Perfil y Analista**. Cómo se usa cada uno está en la [guía de uso](GUIA.md).

## Requisitos

- macOS 26 o superior.
- Xcode 26, o las herramientas de línea de comandos con Swift 6.2 o superior, para compilar.
- Una IA de terminal con sesión iniciada. Por defecto, [Claude Code](https://claude.com/claude-code) (`claude` en la terminal) con la extensión Claude in Chrome. Para usar otra, mira "Motor de IA" en la [guía de uso](GUIA.md).
- Google Chrome con tu sesión iniciada en los portales donde quieres que postule.
- Un bot de Telegram (se crea con @BotFather en un minuto).
- ffmpeg, solo si vas a usar el video narrado con tu voz: `brew install ffmpeg`. Hirebar no instala herramientas por su cuenta.

## Instalación

```sh
git clone https://github.com/VictorMMosqueraG/Hirebar.git
cd Hirebar
scripts/bundle.sh --install
```

Compila, copia la app a `~/Applications/Hirebar.app` y la abre. Aparece un maletín en la barra de menú.

| Comando | Qué hace |
|---|---|
| `scripts/bundle.sh` | Solo arma `dist/Hirebar.app`. |
| `scripts/bundle.sh --install` | Además la instala en `~/Applications` y la abre. |
| `scripts/bundle.sh --zip` | Además crea `dist/Hirebar-<versión>.zip`. |

## Primera configuración

1. **Telegram:** clic en el maletín → engranaje → **Telegram y avisos…**. Pega el token de @BotFather y pulsa **Comprobar**; después escríbele "hola" a tu bot desde tu Telegram y confirma tu nombre en la Mac. Desde ahí el bot solo atiende tu cuenta. En la misma sección permite las notificaciones de macOS: son el respaldo cuando Telegram no está disponible.
2. **Tu perfil:** pie del panel → **Datos** → abre `workspace/perfil.json` y llénalo con tu información real: datos, experiencia con logros, habilidades con nivel y las versiones de hoja de vida que quieres (`cvVariants`). Viene con un ejemplo para guiarte.
3. **Hojas de vida:** escribe `hv` a tu bot. Claude genera `perfil.md` y una hoja de vida en PDF por cada versión.
4. **IA:** pie del panel → **Ajustes → Motor de IA**. Elige cuál usar y pulsa **Probar**.
5. **Agentes:** en la misma ventana de **Ajustes**. Prende los que quieras, ajusta horarios y portales, y decide cuáles envían solos.
6. **Inicio automático:** engranaje → **Abrir al iniciar sesión**.

## Dónde quedan tus datos

Todo vive en `~/Library/Application Support/Hirebar/`, fuera del repositorio. Actualizar o borrar el código no los toca.

| Archivo | Para qué |
|---|---|
| `config.json` | Portales activos, la IA elegida, tu nombre y el chat de Telegram. |
| `workspace/perfil.json` | Tu perfil: la única fuente de tu experiencia. Claude no inventa nada que no esté aquí. |
| `workspace/agentes/<agente>.json` | Horario, envío automático, frecuencia y cupo de cada agente. Se edita desde Ajustes. |
| `workspace/search-profile.json` | Palabras de búsqueda y descartes de los portales incluidos. |
| `workspace/portales.json` | Los portales que agregaste tú. Se editan desde Ajustes. |
| `workspace/instrucciones-*.md` | Las reglas que sigue Claude en cada tarea. Puedes ajustarlas a tu gusto. |
| `workspace/HV_*.pdf` | Tus hojas de vida generadas. |
| `workspace/postulaciones.md`, `historial-propuestas.md`, `informes/` | Registro de lo enviado y los análisis semanales. |

El token de Telegram se guarda en el Llavero de macOS. Los registros de la app están en `~/Library/Logs/Hirebar/`.

La primera vez que se abre, Hirebar copia a esa carpeta los archivos de `Resources/inicial/` (perfil de ejemplo, reglas de Claude, plantilla de hoja de vida y palabras de búsqueda). Nunca sobrescribe los que ya tienes.

## Actualizar

```sh
cd Hirebar
git pull
scripts/bundle.sh --install
```

## Desarrollo

```sh
brew install swiftlint gitleaks shellcheck
git config core.hooksPath scripts/hooks
swift build
scripts/coverage.sh
scripts/lint.sh origin/develop
```

Los tests necesitan Xcode completo, porque XCTest no viene en las herramientas de línea de comandos. El hook de `scripts/hooks` revisa con gitleaks que ningún commit lleve secretos.

| Comando | Qué hace |
|---|---|
| `scripts/coverage.sh` | Corre los tests y mide la cobertura de `Sources`. Falla si baja del mínimo de `.coverage-minimum` y lista los archivos que no tienen ningún test. |
| `scripts/lint.sh <rama base>` | Revisa formato (swift-format) y estilo (SwiftLint) solo en las líneas que cambiaste respecto a esa rama. Sin rama base, revisa todo el código. |
| `scripts/check-conventions.sh <rama base>` | Valida el nombre de la rama y los mensajes de commit con las reglas de `.conventions`. |
| `scripts/check-spec-reference.sh <rama base> <descripción>` | Si el PR toca `Sources/` o `Package.swift`, exige que su descripción nombre una carpeta `specs/NNN-nombre` que exista en la rama. El CI lo corre también al editar la descripción. |

| Variable | Para qué |
|---|---|
| `HIREBAR_BUILD_PATH` | Carpeta de compilación de `bundle.sh` y `coverage.sh` (por defecto `.build`). Si el repositorio está en una carpeta sincronizada con iCloud, apúntala fuera, por ejemplo a `~/Library/Caches/hirebar-build`. |
| `HIREBAR_SIGN_IDENTITY` | Identidad con la que `bundle.sh` firma la app (por defecto `-`, firma ad-hoc). Con una identidad fija, macOS conserva entre compilaciones el permiso de Reconocimiento de voz. Sirve un certificado Apple Development: lista los tuyos con `security find-identity -v -p codesigning` y usa el hash de 40 caracteres. |

Para no pasarlas en cada comando, ponlas en `~/.zshenv` (zsh lo lee también en los comandos por SSH):

```sh
export HIREBAR_BUILD_PATH="$HOME/Library/Caches/hirebar-build"
export HIREBAR_SIGN_IDENTITY="<hash de tu identidad>"
```

| Carpeta | Qué tiene |
|---|---|
| `Sources/Hirebar` | La app: panel, menú, Ajustes y la creación de todas las piezas al arrancar. |
| `Sources/HirebarDomain` | Reglas y entidades sin E/S: agentes, perfil, avisos, cuentas, encaje. |
| `Sources/HirebarApplication` | Casos de uso y puertos: agentes, horarios, comandos, radares, verificación de acciones y canal. |
| `Sources/HirebarStorage` | Configuración, datos del workspace y Llavero. |
| `Sources/HirebarTelegram` · `HirebarNotifications` · `HirebarPortals` | Telegram, notificaciones de macOS y un archivo por portal. |
| `Sources/HirebarAI` · `HirebarMedia` | Lanzador de la IA con sus perfiles; carrusel, video, voz y hojas de vida. |
| `Resources/inicial` | Archivos con los que arranca una instalación nueva. |
| `scripts/` | Compilar y empaquetar, tests con cobertura, lint, convenciones y hooks de git. |

Reglas: código en inglés y sin comentarios; documentación en español; sin dependencias externas; nada personal en el repositorio; commits en inglés con [Conventional Commits](https://www.conventionalcommits.org/); ramas `{tipo}/HB-{número}-{descripción}` hacia `develop`.

## Desinstalar

```sh
pkill -x Hirebar
rm -rf ~/Applications/Hirebar.app ~/Library/Logs/Hirebar
rm -rf ~/Library/Application\ Support/Hirebar      # tus datos: haz una copia antes si los quieres
security delete-generic-password -s Hirebar -a telegram-bot
defaults delete com.vmsoftware.hirebar
```

## Uso responsable

Hirebar actúa con tus cuentas y en tu nombre. Mantén tu perfil honesto, revisa los términos de cada portal y empieza con el envío automático apagado hasta que confíes en los filtros. Nunca resuelve CAPTCHAs ni crea cuentas.

## Licencia

MIT.
