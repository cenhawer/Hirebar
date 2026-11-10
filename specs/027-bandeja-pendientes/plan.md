# Implementation Plan: Bandeja de pendientes

**Branch**: `feature/HB-027-bandeja-pendientes` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- `HirebarApplication`: `PendingInbox` arma `InboxList`/`InboxItem` desde los lotes pendientes,
  `InboxSelection` lleva lo elegido y lo traduce a los números del caso de uso, `InboxDraft` describe
  un borrador. `ControllerInbox` expone `pendingLists`, `pendingDrafts`, `approveList`,
  `discardPendingList`, `publishDraft` y `skipDraft`, que llaman a `approve`, `discardList`,
  `runScheduled(.linkedInPublish)` y al mismo descarte de borrador que Telegram.
- `ContentAccountRepository` suma `slideImages` y `videoPreview`; las rutas del video viven en
  `ContentAccountFolders` (`finalVideo`, `previewVideo`).
- App: `InboxWindowController`, `InboxModel` y `InboxView` (listas con casillas, láminas y video con
  AVKit); botón en el pie del panel con el ícono lleno cuando hay pendientes.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| Paridad de canales | ✅ | Mismos casos de uso que Telegram |
| VIII. Arquitectura hexagonal | ✅ | Lógica en la aplicación, archivos por repositorio |
| VII. Probado sin red ni IA | ✅ | Tests con el arnés del motor |
