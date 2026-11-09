# Guía de uso

Cómo se usa Hirebar en el día a día: qué hace cada parte, cómo mantener tu perfil al día y qué hacer si algo falla.

## El panel

Un clic en el maletín de la barra abre el panel. Clic derecho abre el menú clásico con lo mismo en forma de lista.

### Encabezado
- **Claude en espera / trabajando:** qué está haciendo Claude. Punto verde = libre; naranja = trabajando. Claude hace una cosa a la vez porque todos los agentes usan el mismo Chrome; lo demás espera en fila.
- **Avión de papel:** Telegram. Azul = conectado; gris = falta configurarlo (engranaje → Configurar bot de Telegram).

### Cada agente
- **Nombre y descripción:** qué hace.
- **"en 5 min", "en 19 h", "a pedido", "trabajando":** cuándo vuelve a correr solo.
- **Interruptor:** lo prende o lo apaga. Apagar uno no afecta a los demás.
- **Flecha ›:** abre el detalle: estado, números de la semana, casilla **Envío automático**, botón **Correr ahora** y menú **⋯** (portales, horario y ajustes del agente).

### Pie
- **Informes:** análisis de cada semana.
- **Registro:** lo que la app hizo, minuto a minuto. Mira aquí cuando algo no corre.
- **Datos:** tu carpeta (`~/Library/Application Support/Hirebar/`).
- **Ajustes:** ventana para configurar agentes y habilidades sin editar archivos.
- **Engranaje:** bot de Telegram, aviso de prueba, abrir al iniciar sesión y salir.

## Los agentes

| Agente | Qué hace | Cuándo | Qué haces tú |
|---|---|---|---|
| Empleo | Revisa LinkedIn, Get on Board, Computrabajo, elempleo y Magneto; descarta lo que no encaja y postula. También busca vacantes publicadas en redes y te las propone como lista. | Búsqueda cada 30 min; redes cada 2 h de 8 a. m. a 8 p. m. | Con envío automático, nada. Sin él, respondes `si`, `si 1 3` o `no` en Telegram. |
| Freelance | Revisa Workana y Freelancer; analiza la competencia, pone precio, redacta y envía. Propone seguimientos a las 48 h. | Búsqueda cada 20 min; seguimientos 10 a. m. y 4 p. m. | Igual que Empleo, también para los seguimientos. Si un cliente responde, te llega una respuesta propuesta que solo sale con tu `si`, aunque tengas el envío automático. |
| Clientes | Busca empresas y negocios que necesitan software y les escribe por correo desde tu Gmail. | Lunes a viernes, 7 a. m. | Con envío automático, nada. Sin él, `envia correos`, `envia correos 1 3` o `no correos`. Las respuestas con interés siempre las apruebas tú. |
| Contenido | Prepara publicaciones con texto e imágenes (carrusel) para cada cuenta que configures: por ejemplo, la de tu empresa en Instagram y la tuya en LinkedIn. Cada cuenta tiene su nombre, sus colores y sus días. Los temas no salen de tu hoja de vida: consejos de tecnología para negocios, mitos del software, noticias de la semana y buenas prácticas. | 9 a. m. en los días de cada cuenta, o cuando escribas `post` (pasa de primero en la fila). | `publica <cuenta>`, `post <cuenta> cambia <qué>` o `post <cuenta> salta`. Nunca publica sin tu aprobación. |
| Perfil | Mantiene tu perfil y regenera tus hojas de vida. | Cuando se lo pides. | Ver la sección siguiente. |
| Analista | Te manda los números de la semana de cada agente. No cambia nada. | Domingo, 6 p. m. | Leerlo y decidir qué ajustar. |

## Motor de IA

La búsqueda en los portales incluidos no usa IA. La IA hace el trabajo pesado: enviar propuestas, postular, seguimientos, correos, publicaciones y tu perfil. Se elige en **Ajustes → Motor de IA**:

| Opción | Qué necesitas |
|---|---|
| **Claude Code** (recomendado) | `curl -fsSL https://claude.ai/install.sh \| bash`, luego `claude` para iniciar sesión, y la extensión Claude in Chrome. Es la que está probada de punta a punta. |
| **Codex (OpenAI)** | `npm i -g @openai/codex` y `codex login`. Para que use el navegador, configura un servidor MCP de Chrome en `~/.codex/config.toml`. Las tareas que leen con el navegador (redes, tus portales, seguimientos, clientes y revisión de rendimiento) no corren con Codex. |
| **Gemini CLI (Google)** | `npm i -g @google/gemini-cli` y abrir `gemini` una vez para iniciar sesión. Para el navegador, un servidor MCP de Chrome en `~/.gemini/settings.json`. Igual que con Codex, las tareas que leen con el navegador no corren. |
| **Otra IA** | Escribes dos comandos: uno de lectura y redacción, y otro de ejecución. Hirebar los corre en la terminal con estas variables: `$HIREBAR_PROMPT` (el pedido), `$HIREBAR_INSTRUCTIONS` (ruta de las reglas de la tarea), `$HIREBAR_FULL_PROMPT` (reglas + pedido juntos), `$HIREBAR_WORKSPACE` (la carpeta de trabajo), `$HIREBAR_PHASE` (`read`, `draft` o `act`) y `$HIREBAR_WRITABLE_PATHS` (dónde puede escribir en `draft`). Lo que imprima es la respuesta que te llega a Telegram. Hirebar no puede verificar qué permisos tienen tus comandos: el de lectura no debería poder enviar ni escribir fuera de la carpeta de trabajo. |

Después de elegir, pulsa **Probar**: le hace una pregunta corta y te dice si respondió, si falta iniciar sesión o qué error dio. Luego **Guardar**.

Ejemplo de comandos propios: lectura `mi-ia run --read-only --system-file "$HIREBAR_INSTRUCTIONS" "$HIREBAR_PROMPT"` y ejecución `mi-ia run --system-file "$HIREBAR_INSTRUCTIONS" "$HIREBAR_PROMPT"`.

### Qué puede hacer la IA en cada tarea

La IA nunca tiene más permisos de los que necesita la tarea:

| Tarea | Puede |
|---|---|
| Redes y tus portales | Leer y buscar. No escribe archivos ni actúa en las páginas: te devuelve una lista para aprobar. |
| Seguimientos, clientes, contenido, perfil y análisis | Leer y escribir solo en su carpeta (por ejemplo, el análisis solo escribe en `informes/`). No envía nada. |
| Postular, enviar propuestas, seguimientos y correos, publicar | Actuar con tu Chrome, solo sobre lo que aprobaste. |

En las tareas que leen páginas, la IA no puede abrir `perfil.json`, `perfil.md` ni tus hojas de vida: lo que necesita (tus habilidades, tus logros) va en el pedido, sin tus datos de contacto.

### Verificación y pausa

Cada vez que la IA envía algo, deja un registro de lo que hizo. Hirebar lo compara con lo que aprobaste: si mandó algo que no estaba en la lista, a otro destino o con otro texto, o si no dejó el registro, ese agente queda **en pausa** y te llega un aviso con lo que no coincidió y dos botones: **Reanudar** y **Mantener en pausa**. Mientras está en pausa no ejecuta nada. También puedes reanudarlo con `reanudar <agente>` o desde el panel.

El cupo diario de cada agente (Ajustes) también se cumple: si apruebas más de lo que queda, se ejecuta lo que cabe y el resto queda en una lista pendiente para el día siguiente.

Si la sesión de la IA se vence, te llega un aviso por Telegram con el comando para volver a entrar, y las listas quedan guardadas para reintentar con `si`.

## Agregar o quitar portales

Empleo y Freelance traen portales incluidos y aceptan los que tú agregues.

**Portales incluidos** (Empleo: LinkedIn, Get on Board, Computrabajo, elempleo y Magneto; Freelance: Workana y Freelancer). Se revisan solos cada pocos minutos sin usar a Claude. No se pueden borrar, pero sí apagar: **Ajustes → Empleo** (o **Freelance**) → **Portales incluidos**, o en el panel → flecha del agente → **⋯**.

**Tus portales:** cualquier página de empleo o de proyectos (Torre, Indeed, Hireline, Upwork, la página de empleos de una empresa…).

1. En el portal, haz la búsqueda con los filtros que quieras (por ejemplo, "backend", remoto, Colombia) y copia el enlace de la barra del navegador.
2. **Ajustes → Empleo** (o **Freelance**) → **Tus portales** → **Agregar portal**.
3. Escribe un nombre, pega el enlace y, si quieres, unas indicaciones (por ejemplo, "ignora las que piden inglés").
4. **Guardar**.

Claude abre esos enlaces con tu Chrome a las 9 a. m., 1 p. m. y 5 p. m. (tarea **Revisar tus portales**, cambiable en Ajustes). Sirve aunque el portal pida sesión iniciada: solo inicia sesión una vez en tu Chrome. Lo que encuentre te llega a Telegram en la lista de siempre (`si`, `si 1 3`, `no`); con envío automático se procesa solo. Lo que ya te mostró no se repite durante 30 días.

Para quitar uno: el ícono de basura junto al portal y **Guardar**. Para pausarlo sin borrarlo: su interruptor.

Para revisarlos ya: `corre empleo` o `corre freelance` en Telegram.

## Tu perfil

Todo sale de un solo archivo: `workspace/perfil.json`. De ahí se alimentan:
- las búsquedas (tus habilidades deciden qué se avisa y qué se descarta),
- las propuestas y postulaciones (Claude solo usa logros que estén ahí),
- tus hojas de vida (una por tecnología),
- las publicaciones en borrador de cada cuenta de contenido (texto e imágenes), en `workspace/contenido/<cuenta>/`.

`workspace/perfil.md` es la misma información en texto; Claude lo mantiene igual al JSON. No lo edites a mano.

### Agregar un logro
En Telegram:
```
logro bajé el tiempo de despliegue de 30 a 10 minutos en Acme con GitHub Actions
```
- Claude lo agrega al trabajo que nombres (si no nombras ninguno, al actual), con verbo en pasado y con las tecnologías que menciones.
- Si no das un número, no se inventa uno.
- Regenera tus hojas de vida y te manda los PDF.

Consejo: mándalo apenas pase, con número y tecnología. "Bajé X de A a B con Y" es el formato que mejor funciona.

### Cambiar de trabajo
```
trabajo nuevo Backend Senior en Acme desde dic 2026
```
Cierra el trabajo actual con esa fecha, crea el nuevo arriba, actualiza tu titular y las reglas que nombraban el trabajo anterior, y regenera las hojas de vida. Para un proyecto como independiente, dilo: `trabajo consultoría para Tienda X desde ene 2027, API de pagos`.

### Habilidades
```
habilidad Go conozco
habilidad Terraform domino
habilidad PHP evito
habilidades
```
- **Domino:** se busca y cuenta como ENCAJA.
- **Conozco:** se busca, pero cuenta como RETO (se avisa solo si no hay nada de tu fuerte).
- **Evito:** se descarta.
- Aplica desde la búsqueda siguiente, sin pasar por Claude.

También en **Ajustes → Habilidades**: nombre, nivel y "otros nombres" (cómo aparece en los avisos, por ejemplo `node, nodejs`). Pulsa **Guardar**.

### Regenerar las hojas de vida
`hv` en Telegram o **Regenerar HV** en el detalle de Perfil. Los PDF quedan en `workspace/` con estos nombres y se usan al postular según la vacante:
- `HV_Nombre_Apellido_Backend_Node.pdf`
- `HV_Nombre_Apellido_Backend_NET.pdf`
- `HV_Nombre_Apellido_Backend_Java.pdf`

Son formato ATS (una columna, sin tablas ni imágenes, máximo 2 páginas). Hirebar las convierte a PDF con Google Chrome sin abrir ventana.

### Agregar otra hoja de vida
En `perfil.json`, dentro de `cvVariants`, agrega un elemento y luego escribe `hv`:
```json
{ "id": "cloud", "title": "Cloud / DevOps Engineer", "file": "HV_Nombre_Apellido_Cloud", "focus": ["AWS", "Docker", "Kubernetes", "Terraform"] }
```
- `id`: nombre corto, sin espacios.
- `title`: el titular de esa hoja de vida.
- `file`: nombre del PDF.
- `focus`: tecnologías que van primero; los logros con esas tecnologías suben.

### Cambiar datos, estudios o salario
Por ahora, a mano en `perfil.json`:
- `person`: nombre, titular, ciudad, correo, teléfono, enlaces, idiomas y estudios.
- `preferences`: cargos que buscas, modalidad, salario (`copMonthly`, `copMinimum`, `usdMonthly`) y tarifa freelance.
- `rules`: reglas que Claude debe respetar siempre.

Después de editar, escribe `hv` para que todo quede igual en `perfil.md` y en las hojas de vida. Si el archivo queda con un error de formato, la app lo ignora y lo anota en el **Registro**.

## Ajustes

Panel → **Ajustes**. A la izquierda, los agentes y tus habilidades. Para cada agente:
- nombre y descripción,
- prendido y envío automático,
- "Buscar cada X min" y portales (Empleo y Freelance),
- cupo diario (máximo de envíos al día que se le indica a Claude),
- por tarea: días (L M X J V S D), horas (`10, 16`) y hasta cuántas horas tarde puede correr si el Mac estaba dormido.

### Cuentas de contenido

Con cada publicación llegan a Telegram, aparte y listos para copiar y pegar, el texto del carrusel y la descripción del video, con hashtags mezclados (generales, del tema, de Cali/Colombia y de la marca). Ninguna publicación se repite: cada una cambia de tema, formato y composición. Una vez por semana la IA revisa en tu Chrome las últimas publicaciones de la cuenta (vistas, me gusta, guardados) y lo anota en `contenido/<cuenta>/rendimiento.md`; con eso favorece lo que más funciona y sigue probando cosas nuevas.

Ajustes → **Cuentas de contenido**. Agrega una cuenta por cada perfil donde quieras publicar (por ejemplo, `empresa` en Instagram y `personal` en LinkedIn). Para cada una:
- **Identificador**: el nombre corto que usas en Telegram (`post empresa`, `publica empresa`).
- **Red**: LinkedIn o Instagram.
- **Nombre en las imágenes**, **línea bajo el nombre** y **usuario**: la firma de cada imagen. Si alguien más baja el repo, pone aquí su propio nombre.
- **De qué habla y para quién**: el enfoque de los temas.
- **Días**: cuándo se prepara la publicación sola (a la hora de la tarea del agente Contenido).
- **También un video corto (Reel o Short) narrado con tu voz**: además del carrusel llega a Telegram una vista previa de un Short ANIMADO de 20 a 40 segundos, pensado para ganar audiencia (no es copia del carrusel): titulares que entran palabra por palabra, tarjetas y ventanas de apps, flechas que se dibujan, contadores. Lleva gancho en el primer segundo y cierre con invitación. Hirebar lo graba cuadro por cuadro en tu Mac.
  - Junto a la vista previa (sin voz) llega el **guion para grabar**, escena por escena, con el tono sugerido.
  - **Respondes con una nota de voz** en Telegram leyéndolo de corrido. Hirebar limpia el ruido y nivela el volumen, escucha tu audio con el reconocimiento de voz del Mac (gratis, en tu Mac; la primera vez pide permiso) y cuadra cada escena y cada subtítulo con el momento en que dices cada palabra. Te devuelve el video con tu voz y la descripción lista para copiar. Si quieres repetir, manda otra nota de voz.
  - La primera vez Hirebar instala sola una herramienta de audio (ffmpeg) para leer las notas de voz de Telegram.
  - **Subtítulos palabra por palabra**: se pueden apagar en la cuenta.
  - **Música de fondo (opcional)**: pon un archivo `musica.mp3` (o `.m4a`) en `workspace/contenido/<cuenta>/` y se mezcla bajito debajo de tu voz. Usa música que puedas usar (por ejemplo, de la biblioteca de audio de YouTube). Si no hay archivo, puedes ponerle una canción de moda al subirlo desde la app de Instagram.
  - Con `publica <cuenta>` se sube el carrusel y el video con tu voz aparte.
- **Paleta**: escoge una lista (por ejemplo, "Negro y naranja") o pon tus colores en hexadecimal. **Estilo de las imágenes** describe en palabras cómo se ven (letras, detalles). La vista previa muestra cómo quedan.

Quedan guardadas en `workspace/contenido/cuentas.json`.

**Guardar** (⌘S) aplica desde la próxima búsqueda. **Descartar** deshace lo que no guardaste. **Mostrar archivo** te lleva al JSON de ese agente.

## Comandos de Telegram

| Para | Escribe |
|---|---|
| Ver cómo va todo | `estado` · `agentes` |
| Buscar ya | `buscar` · `buscar empleo` · `buscar freelance` |
| Correr un agente ya | `corre clientes` · `corre contenido` · `corre analista` |
| Prender o apagar un agente | `agente clientes off` · `agente clientes on` |
| Envío automático | `auto si` · `auto no` (Empleo y Freelance) · `auto empleo no` · `auto clientes si` |
| Sacar un agente de la pausa | `reanudar empleo` (o el botón **Reanudar** del aviso) |
| Aprobar o descartar una lista | `si` · `si 1 3` · `no` (o los botones del mensaje) |
| Correos del día | `envia correos` · `envia correos 1 3` · `no correos` |
| Video con tu voz | `video <cuenta>` (vuelve a mandar la vista previa y el guion) · responder con una nota de voz (te devuelvo el video con tu voz) |
| Contenido | `post` · `post <cuenta>` · `post <cuenta> cambia <qué>` · `post <cuenta> salta` · `publica <cuenta>` (con una sola cuenta no hace falta nombrarla) |
| Perfil | `logro …` · `trabajo …` · `habilidad <nombre> <nivel>` · `habilidades` · `hv` |
| Nota para el análisis del domingo | `anota entrevista con Acme el jueves` |

Cualquier otra cosa: el bot responde con la lista completa.

## Si algo falla

| Síntoma | Qué hacer |
|---|---|
| Llega "La sesión de Claude Code se venció" | Abre Terminal, escribe `claude` y luego `/login`. Después `si` para reintentar la última lista: no se pierde. |
| No llegan avisos | Engranaje → Enviar aviso de prueba. Si no llega, Configurar bot de Telegram y envíale `/start` a tu bot. |
| Un agente no corre a su hora | Mira que esté prendido y su horario en Ajustes. Si el Mac estaba dormido, corre al despertar dentro de su tolerancia. Revisa el **Registro**. |
| Claude dice que no pudo enviar algo | Revisa que Chrome esté abierto, con la extensión Claude in Chrome y con sesión en ese portal. Hirebar nunca resuelve CAPTCHAs ni escribe contraseñas. |
| No salen los PDF de la hoja de vida | Hace falta Google Chrome instalado en `/Applications`. El mensaje de Telegram dice cuál falló. |
| Cambié algo y no se nota | Ajustes y habilidades aplican desde la búsqueda siguiente. Para forzarla: `buscar`. |
| Un agente dice "en pausa" | La IA hizo algo que no coincidía con lo que aprobaste, o no dejó el registro. Lee el aviso de Telegram y, si está bien, `reanudar <agente>`. |
| Llega "esta tarea necesita Claude Code" | Elegiste Codex o Gemini: las tareas que leen con el navegador solo corren con Claude Code. |

## Actualizar Hirebar

```sh
cd Hirebar
git pull
scripts/bundle.sh --install
```

Tus datos no se tocan: viven fuera del repo.
