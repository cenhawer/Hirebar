# Cambios

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versiones: [SemVer](https://semver.org/lang/es/), tomadas del archivo `VERSION`.

## [Sin publicar]

### Agregado
- Validación en CI de nombres de rama y mensajes de commit (Conventional Commits).
- Lint de formato y estilo en CI sobre las líneas que cambia cada PR.
- Revisión de secretos con gitleaks en CI y en el hook de pre-commit.
- Reporte de cobertura de `Sources` en CI, con mínimo configurable.
- Variables `HIREBAR_BUILD_PATH` y `HIREBAR_SIGN_IDENTITY` en `bundle.sh`.
- Plantillas de PR e issues, y Dependabot para GitHub Actions.

### Cambiado
- CI corre en `macos-26` (`macos-14` se retiró de GitHub Actions el 2 de noviembre de 2026).
- Los ejemplos de la documentación ya no usan datos personales.

## [0.2.0]

Línea base: commit `96e7a97`.

- Agentes Empleo, Freelance, Clientes, Contenido, Perfil y Analista, con horario propio e interruptor.
- Búsqueda en LinkedIn, Get on Board, Computrabajo, elempleo, Magneto, Workana y Freelancer, más portales propios del usuario.
- Motor de IA elegible: Claude Code, Codex, Gemini CLI o un comando propio.
- Aprobación y comandos por Telegram, con envío automático opcional por agente.
- Perfil único en `perfil.json` y hojas de vida en PDF por variante.
- Publicaciones de contenido con carrusel y video corto narrado con una nota de voz del usuario.
