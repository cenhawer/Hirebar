import AppKit
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import ServiceManagement
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let loginItem = NSMenuItem(
        title: String(localized: "Abrir al iniciar sesión"), action: #selector(toggleLogin), keyEquivalent: "")
    private let popover = NSPopover()
    private let engine: Engine
    private lazy var statusMenu = StatusMenu(engine: engine)
    private lazy var panel = PanelModel(engine: engine)
    private var activity: NSObjectProtocol?
    private var panelTimer: Timer?
    private lazy var settings = SettingsWindowController(engine: engine)
    private let notificationRouter = NotificationRouter()

    init(engine: Engine) {
        self.engine = engine
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: String(localized: "Hirebar busca proyectos y vacantes durante el día"))
        engine.start(resources: Bundle.main.resourceURL)
        statusMenu.install(in: menu)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        let quit = NSMenuItem(title: String(localized: "Salir de Hirebar"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        if MacNotifications.isAvailable {
            notificationRouter.onOpen = { [weak self] in self?.showPanel() }
            UNUserNotificationCenter.current().delegate = notificationRouter
            Task { await MacNotifications.requestPermissionIfUndecided() }
        }
        statusMenu.onOpenChannel = { [weak self] in self?.settings.show(.channel) }
        settings.channel.onStateChange = { [weak self] in
            self?.panel.refresh()
            self?.statusMenu.refresh()
        }
        panel.onQuit = { NSApp.terminate(nil) }
        panel.onOpenSettings = { [weak self] page in self?.closePanel { self?.settings.show(page) } }
        statusMenu.onOpenSettings = { [weak self] kind in self?.settings.show(.agent(kind)) }
        settings.onSaved = { [weak self] in
            self?.panel.refresh()
            self?.statusMenu.refresh()
        }
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = true
        let host = NSHostingController(rootView: PanelView(model: panel))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host

        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusMenu.onRefresh = { [weak self] busy in
            self?.render(busy: busy)
            if self?.popover.isShown == true { self?.panel.refresh() }
        }
        render(busy: false)
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func showMenu() {
        closePanel()
        statusMenu.refresh()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePanel() {
        if popover.isShown {
            closePanel()
            return
        }
        showPanel()
    }

    private func showPanel() {
        guard !popover.isShown, let button = statusItem.button else { return }
        panel.refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.panel.refresh() } }
        RunLoop.main.add(timer, forMode: .common)
        panelTimer = timer
    }

    private func closePanel(then action: (() -> Void)? = nil) {
        panelTimer?.invalidate()
        panelTimer = nil
        if popover.isShown { popover.performClose(nil) }
        if let action { Task { @MainActor in action() } }
    }

    func popoverDidClose(_ notification: Notification) {
        panelTimer?.invalidate()
        panelTimer = nil
    }

    private func render(busy: Bool) {
        statusItem.button?.image = StatusIcon.make(dot: busy ? .systemOrange : .systemGreen)
        let state = "\(engine.controller.ai.capitalizedName): \(engine.controller.status)"
        statusItem.button?.toolTip = String(localized: "Hirebar · \(state)\nClic: panel · Clic derecho: menú")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            StatusMenu.info(String(localized: "No pude cambiar el inicio automático: \(error.localizedDescription)"))
        }
        render(busy: !engine.controller.isIdle)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    var onOpen: (() -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async { [weak self] in self?.onOpen?() }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
