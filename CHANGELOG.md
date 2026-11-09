# Cambios

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versiones: [SemVer](https://semver.org/lang/es/), tomadas del archivo `VERSION`.

## [Sin publicar]

### Agregado
- Cada tarea de la IA corre con el perfil que necesita: lectura (sin escribir ni actuar), redacción (escribe solo en su carpeta) o ejecución (actúa solo sobre lo aprobado).
- Registro y verificación de cada envío contra lo aprobado; una acción que no coincide pone al agente en pausa, con aviso y botones para reanudar (`reanudar <agente>`).
- Las vacantes de redes y los seguimientos llegan como listas para aprobar.
- El cupo diario de cada agente se cumple, también el de Clientes.
- "Otra IA" usa dos comandos: lectura y ejecución.
- Un PR que toca `Sources/` o `Package.swift` tiene que nombrar en su descripción una spec existente (`specs/NNN-nombre`).
- Validación en CI de nombres de rama y mensajes de commit (Conventional Commits).
- Lint de formato y estilo en CI sobre las líneas que cambia cada PR.
- Revisión de secretos con gitleaks en CI y en el hook de pre-commit.
- Reporte de cobertura de `Sources` en CI, con mínimo configurable.
- Variables `HIREBAR_BUILD_PATH` y `HIREBAR_SIGN_IDENTITY` en `bundle.sh`.
- Plantillas de PR e issues, y Dependabot para GitHub Actions.

### Cambiado
- La búsqueda en redes ya no postula sola y los seguimientos ya no se envían solos: necesitan tu aprobación o el envío automático del agente.
- Las respuestas a clientes y las publicaciones nunca se aprueban solas.
- Con Codex o Gemini, las tareas que leen con el navegador no corren.
- En las tareas que leen páginas, la IA no tiene acceso a tu perfil ni a tus hojas de vida.
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
