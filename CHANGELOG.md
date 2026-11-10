# Cambios

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versiones: [SemVer](https://semver.org/lang/es/), tomadas del archivo `VERSION`.

## [Sin publicar]

### Agregado
- **Actividad** (panel y menú): cada envío con qué se hizo, a quién, cuándo, qué agente y con qué texto; también lo que no coincidió con lo aprobado y lo que se habría enviado en práctica. Filtros por agente y período.
- Ajustes → Datos y experiencia: datos personales, preferencias, empleos con logros y hojas de vida se editan sin tocar JSON; se conservan los demás campos de `perfil.json`.
- La limpieza del domingo borra también las grabaciones de voz (14 días), los videos armados (30 días) y los borradores y listas descartadas (90 días); todos los plazos viven en `Resources/retencion.json` y la guía los lista.
- Asistente de primer uso: nombre, IA con prueba, Telegram, agentes y permisos de macOS sin editar archivos; el panel muestra lo que falta configurar.
- Los textos de Hirebar están en un String Catalog (`Resources/Localizable.xcstrings`), listo para traducirse.
- Cada tarea de la IA corre con el perfil que necesita: lectura (sin escribir ni actuar), redacción (escribe solo en su carpeta) o ejecución (actúa solo sobre lo aprobado).
- Registro y verificación de cada envío contra lo aprobado; una acción que no coincide pone al agente en pausa, con aviso y botones para reanudar (`reanudar <agente>`).
- Las vacantes de redes y los seguimientos llegan como listas para aprobar.
- El cupo diario de cada agente se cumple, también el de Clientes.
- "Otra IA" usa dos comandos: lectura y ejecución.
- Los correos de prospección llegan a Telegram con destinatario, asunto y texto completos, y `envia correos` aprueba esa lista.
- Las listas largas llegan en varios mensajes; si una no llega completa, se descarta.
- Ajustes → Telegram y avisos: el token se valida con Telegram, le escribes "hola" a tu bot, confirmas tu nombre y el bot queda anclado a tu cuenta; mensajes y botones de otras cuentas se ignoran.
- Sin Telegram, o si un mensaje no llega, el aviso aparece como notificación de macOS y al tocarla se abre el panel.
- Un PR que toca `Sources/` o `Package.swift` tiene que nombrar en su descripción una spec existente (`specs/NNN-nombre`).
- Validación en CI de nombres de rama y mensajes de commit (Conventional Commits).
- Lint de formato y estilo en CI sobre las líneas que cambia cada PR.
- Revisión de secretos con gitleaks en CI y en el hook de pre-commit.
- Reporte de cobertura de `Sources` en CI, con mínimo configurable.
- Variables `HIREBAR_BUILD_PATH` y `HIREBAR_SIGN_IDENTITY` en `bundle.sh`.
- Plantillas de PR e issues, y Dependabot para GitHub Actions.

### Cambiado
- Las palabras de búsqueda, los descartes y las palabras del filtro de vacantes por defecto viven en `Resources/perfil-busqueda.json`.
- Los plazos, intervalos y límites del motor, los radares y el programador viven en `Resources/motor.json`.
- Los archivos de configuración, perfil, agentes y cuentas llevan versión; al actualizar, Hirebar los respalda en `respaldos/` antes de migrarlos. El estado de corrida ya no se guarda en las preferencias del sistema.
- Computrabajo vuelve a reconocer las ofertas con su HTML actual.
- Hirebar requiere macOS 26 y se compila con Swift 6 en modo estricto; la interfaz usa Observation y el armado del video usa las APIs actuales de AVFoundation.
- Se quitó el envío de avisos a ntfy.sh.
- El video narrado usa el ffmpeg del sistema (`brew install ffmpeg`): Hirebar ya no instala Python ni ffmpeg por su cuenta y borra la copia vieja. Las notas de voz tienen un máximo de 5 minutos o 20 MB.
- El registro usa el del sistema (OSLog) con una categoría por agente y por área; el botón **Registro** exporta los últimos 3 días.
- Evals de las reglas de la IA: casos fijos de inyección y de cifras inventadas que el CI corre sobre respuestas grabadas y que se pueden correr contra la IA real (`HIREBAR_LIVE_EVALS=1`).
- Las reglas de contenido y de envío de seguimientos tratan como contenido lo que leen; la de prospección prohíbe inventar resultados.
- Modo práctica por agente: hace todo menos enviar y te cuenta lo que habría hecho (`practica empleo si`, casilla **Práctica** del panel, menú o Ajustes).
- Prender el envío automático muestra qué hará cada agente sin esperarte y pide confirmar, en la Mac y en Telegram; apagarlo es inmediato.
- Una instalación con el chat ya vinculado queda anclada a esa misma cuenta sin pedir nada.
- La búsqueda en redes ya no postula sola y los seguimientos ya no se envían solos: necesitan tu aprobación o el envío automático del agente.
- Las respuestas a clientes y las publicaciones nunca se aprueban solas.
- Con Codex o Gemini, las tareas que leen con el navegador no corren.
- En las tareas que leen páginas, la IA no tiene acceso a tu perfil ni a tus hojas de vida, ni descarga direcciones con `WebFetch`.
- El cupo diario cuenta también lo aprobado que todavía no terminó y todo lo que se envió.
- Con envío automático, un correo en frío o un seguimiento a un destino nuevo espera tu aprobación.
- Mientras ejecuta, la IA no puede cambiar sus reglas ni tu perfil; si algo cambia, Hirebar lo restaura y te avisa.
- Con Gemini, la lectura corre en su modo de solo lectura (`--approval-mode plan`).
- Los enlaces se comparan conservando los parámetros que identifican la vacante o el proyecto.
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
