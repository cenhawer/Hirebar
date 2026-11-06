# Quickstart: probar la separación de lectura y ejecución

En el worker, con `HIREBAR_HOME` apuntando a una carpeta de datos de prueba para no tocar la real, y
"Otra IA" configurada con los comandos de prueba de `Tests/Fixtures/engine/`, que imprimen fixtures
en lugar de llamar a una IA.

```sh
scripts/bundle.sh
HIREBAR_HOME="$HOME/Library/Caches/hirebar-e2e" dist/Hirebar.app/Contents/MacOS/Hirebar &
```

La app se lanza directamente y no con `open`, para que herede `HIREBAR_HOME`.

Ajustes → Motor de IA → Otra IA:

- Comando de lectura: `Tests/Fixtures/engine/read.sh`
- Comando de ejecución: `Tests/Fixtures/engine/act.sh`

Los dos scripts eligen su fixture leyendo `$HIREBAR_WORKSPACE/.fixture`; para cambiarlo:
`echo <nombre> > "$HOME/Library/Caches/hirebar-e2e/workspace/.fixture"`.

## 1. Lectura sin acciones (US1)

1. Fixture `injection` y en Telegram `corre empleo`.
2. Esperado: el comando de lectura recibe `HIREBAR_PHASE=read`; llega una lista para aprobar con la
   vacante que trae instrucciones escondidas, como cualquier otra; no hay archivos `.acciones.json`
   en `ejecuciones/`.
3. Con Claude Code elegido, el registro de la app muestra los argumentos del perfil `read`
   (`--permission-mode dontAsk --restricted`, sin herramientas de escritura).

## 2. Ejecución verificada (US2)

1. Fixture `authorized` y responde `si 1`.
2. Esperado: el comando de ejecución recibe `HIREBAR_PHASE=act` y solo el elemento 1;
   `estado/verificaciones/<lote>.json` tiene una acción `authorized`.
3. Fixture `unauthorized` y aprueba otra lista.
4. Esperado: llega el aviso de acción no autorizada con "Reanudar Empleo" y "Mantener en pausa"; el
   panel muestra Empleo "en pausa" con el motivo; una nueva lista aprobada de Empleo no se ejecuta.
5. Pulsa "Reanudar Empleo": el agente vuelve a ejecutar.

## 3. Redes y seguimientos con aprobación (US3)

1. Envío automático de Empleo y Freelance apagado; fixture `social` y `corre empleo`; fixture
   `followups` y `seguimientos`.
2. Esperado: dos listas para aprobar, la de seguimientos con el texto de cada uno, y ningún envío.
