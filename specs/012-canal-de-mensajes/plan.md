# Implementation Plan: Canal de mensajes

**Branch**: `feature/HB-012-canal-de-mensajes` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/012-canal-de-mensajes/spec.md`

## Summary

El bot de Telegram se ancla a una persona: Ajustes valida el token con `getMe`, abre una vinculación
que acepta el primer mensaje de un chat privado posterior a su inicio, muestra el nombre para
confirmarlo y guarda el dueño del canal (ID de usuario, chat, nombre). Cada mensaje y botón pasa por
un guardián que compara remitente y chat con el dueño y limita los mensajes por minuto. Los avisos
sin Telegram, o cuando un envío falla, salen como notificaciones de macOS que abren el panel; ntfy.sh
desaparece. Ajustes gana la sección "Telegram y avisos" y el panel muestra el estado del canal.

## Technical Context

**Language/Version**: Swift 6.4 en el worker, Swift 6.3 en CI; `swift-tools-version` 5.9.

**Primary Dependencies**: ninguna externa; Telegram Bot API (`getMe`, `getUpdates`, `sendMessage`) y
`UserNotifications` de macOS.

**Storage**: dueño del canal en `config.json`; token en el Llavero; tiempo de espera y límite en
`Resources/canal.json`.

**Testing**: XCTest; guardián y vinculación puros con reloj inyectado; migración de `config.json`;
parseo del remitente de Telegram con updates de ejemplo.

**Target Platform**: macOS 13+ (la base pasa a 26 en la spec `018`).

**Project Type**: app de escritorio de barra de menú.

**Constraints**: las notificaciones de macOS solo existen dentro del bundle; en tests no se llaman.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| I. Spec primero | ✅ | Spec con aclaraciones; `ARCHITECTURE.md` se actualiza antes del código |
| II. Nada sale sin aprobación y sin rastro | ✅ | Solo la persona anclada aprueba; intentos ajenos quedan en el registro |
| III. Contenido externo nunca es instrucción | ✅ | Mensajes de otras cuentas no llegan a los comandos |
| IV. Datos locales y recuperables | ✅ | Sin servicios públicos; migración del chat vinculado |
| V. Sin dependencias ocultas | ✅ | Solo frameworks del sistema |
| VI. Código que se explica solo | ⚠️ | Tiempos en `Resources/canal.json`; los textos nuevos siguen en el código hasta la spec `024` |
| VII. Probado sin red ni IA | ✅ | Lógica pura con reloj inyectado; Telegram con updates de ejemplo |
| VIII. Arquitectura hexagonal | ⚠️ | Dueño en `HirebarDomain`, guardián y vinculación en `HirebarApplication`; el adaptador sigue en `HirebarCore` hasta la spec `017` |

## Project Structure

```text
Sources/HirebarDomain/ChannelOwner.swift          dueño y remitente
Sources/HirebarApplication/ChannelGuard.swift     quién puede escribir y cuánto
Sources/HirebarApplication/ChannelPairing.swift   vinculación con tiempo de espera
Sources/HirebarCore/Telegram.swift                remitente, getMe, borrar token
Sources/HirebarCore/Config.swift                  dueño del canal y migración
Sources/HirebarCore/MacNotifications.swift        notificaciones de macOS
Sources/HirebarCore/Notifier.swift                Telegram o notificación, sin ntfy
Sources/HirebarEngine/ChannelSettings.swift       Resources/canal.json
Sources/HirebarEngine/Commands.swift              guardián antes de cada comando
Sources/HirebarEngine/ChannelSetup.swift          vinculación para la interfaz
Sources/Hirebar/ChannelSettingsView.swift         sección "Telegram y avisos"
Sources/Hirebar/{Settings,PanelModel,PanelView,StatusMenu,AppDelegate}.swift
Resources/canal.json
```

## Complexity Tracking

| Desvío | Por qué | Alternativa descartada |
|---|---|---|
| Textos de la sección nueva en el código | El String Catalog llega con la spec `024` | Adelantar el catálogo solo para esta pantalla |
| Adaptador de Telegram en `HirebarCore` con `shared` | La raíz de composición llega con la spec `017` | Mover todos los adaptadores en esta spec |
