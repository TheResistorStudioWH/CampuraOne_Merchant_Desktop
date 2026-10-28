import Cocoa
import FlutterMacOS

private final class VisionMenuRowButton: NSButton {
  private var hoverArea: NSTrackingArea?
  private var hovered = false

  override func updateTrackingAreas() {
    if let hoverArea { removeTrackingArea(hoverArea) }
    super.updateTrackingAreas()
    hoverArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(hoverArea!)
  }

  override func mouseEntered(with event: NSEvent) {
    hovered = true
    updateHoverAppearance()
  }

  override func mouseExited(with event: NSEvent) {
    hovered = false
    updateHoverAppearance()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateHoverAppearance()
  }

  private func updateHoverAppearance() {
    wantsLayer = true
    layer?.cornerRadius = 6
    layer?.backgroundColor = hovered
      ? NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
      : nil
  }
}

class MainFlutterWindow: NSWindow {
  private var visionStatusItem: NSStatusItem?
  private var visionMenu: NSMenu?
  private var visionChannel: FlutterMethodChannel?
  private var peopleInStore = 19
  private var onlineOrders = 6
  private var minutesPerOrder = 0.7
  private var peopleValueLabel: NSTextField?
  private var ordersValueLabel: NSTextField?
  private var minutesValueLabel: NSTextField?
  private var estimateItem: NSMenuItem?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = NSRect(x: 0, y: 0, width: 1280, height: 800)
    contentViewController = flutterViewController
    isReleasedWhenClosed = false
    setFrame(windowFrame, display: true)
    minSize = NSSize(width: 1024, height: 700)
    center()
    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()

    visionChannel = FlutterMethodChannel(
      name: "campura/vision_menu",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    visionChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "show" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let button = self?.visionStatusItem?.button
      result(button != nil)
      DispatchQueue.main.async { button?.performClick(nil) }
    }

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem.button {
      if #available(macOS 11.0, *) {
        button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "视觉分析")
      }
      button.image?.isTemplate = true
      if button.image == nil { button.title = "◉" }
      button.toolTip = "域校屿商家 · 视觉分析"
    }
    let menu = makeVisionMenu()
    statusItem.menu = menu
    visionMenu = menu
    visionStatusItem = statusItem
  }

  private func makeVisionMenu() -> NSMenu {
    let menu = NSMenu(title: "视觉分析")
    menu.autoenablesItems = false

    let heading = NSMenuItem(title: "视觉分析", action: nil, keyEquivalent: "")
    heading.isEnabled = false
    heading.attributedTitle = NSAttributedString(
      string: "视觉分析",
      attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]
    )
    menu.addItem(heading)
    menu.addItem(NSMenuItem.separator())

    let status = NSMenuItem(title: "当前正在监控 · 画面待接入", action: nil, keyEquivalent: "")
    status.isEnabled = false
    menu.addItem(status)

    let cameraItem = NSMenuItem()
    cameraItem.view = makeCameraPlaceholder()
    menu.addItem(cameraItem)
    menu.addItem(NSMenuItem.separator())

    let peopleRow = makeMetricRow(title: "店内人数", action: #selector(adjustPeople(_:)))
    peopleValueLabel = peopleRow.valueLabel
    menu.addItem(peopleRow.item)
    let ordersRow = makeMetricRow(title: "线上单数", action: #selector(adjustOrders(_:)))
    ordersValueLabel = ordersRow.valueLabel
    menu.addItem(ordersRow.item)
    let minutesRow = makeMetricRow(title: "每单时间", action: #selector(adjustMinutes(_:)))
    minutesValueLabel = minutesRow.valueLabel
    menu.addItem(minutesRow.item)
    menu.addItem(NSMenuItem.separator())

    estimateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    estimateItem?.isEnabled = false
    menu.addItem(estimateItem!)
    let note = NSMenuItem(title: "仅按线上待处理单及单工位估算；人数不计为订单", action: nil, keyEquivalent: "")
    note.isEnabled = false
    menu.addItem(note)
    menu.addItem(NSMenuItem.separator())

    let reset = NSMenuItem(title: "恢复初始数值", action: #selector(resetVisionValues(_:)), keyEquivalent: "")
    reset.target = self
    menu.addItem(reset)
    let showMerchant = NSMenuItem(title: "显示商家端", action: #selector(showMerchantWindow(_:)), keyEquivalent: "")
    showMerchant.target = self
    menu.addItem(showMerchant)
    menu.addItem(NSMenuItem.separator())
    let quit = NSMenuItem(title: "退出域校屿商家", action: #selector(quitApplication(_:)), keyEquivalent: "")
    quit.target = self
    menu.addItem(quit)

    refreshVisionMenu()
    return menu
  }

  private func makeCameraPlaceholder() -> NSView {
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 176))
    view.wantsLayer = true
    view.layer?.cornerRadius = 10
    view.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.38).cgColor

    func addLabel(_ title: String, frame: NSRect, size: CGFloat, color: NSColor) {
      let label = NSTextField(labelWithString: title)
      label.frame = frame
      label.font = NSFont.systemFont(ofSize: size)
      label.textColor = color
      label.alignment = .center
      view.addSubview(label)
    }
    addLabel("CAM 01 · 未接入", frame: NSRect(x: 12, y: 145, width: 436, height: 20), size: 11, color: .secondaryLabelColor)
    addLabel("▧", frame: NSRect(x: 195, y: 80, width: 70, height: 48), size: 32, color: .secondaryLabelColor)
    addLabel("监控画面预留区", frame: NSRect(x: 60, y: 53, width: 340, height: 24), size: 14, color: .labelColor)
    addLabel("画面接入后将在此显示", frame: NSRect(x: 60, y: 29, width: 340, height: 20), size: 11, color: .secondaryLabelColor)
    return view
  }

  private func makeMetricRow(title: String, action: Selector) -> (item: NSMenuItem, valueLabel: NSTextField) {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 40))
    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = NSFont.systemFont(ofSize: 13)
    let valueLabel = NSTextField(labelWithString: "")
    valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    let actionLabel = NSTextField(labelWithString: "手动调整…")
    actionLabel.font = NSFont.systemFont(ofSize: 13)
    actionLabel.textColor = .secondaryLabelColor
    actionLabel.setContentHuggingPriority(.required, for: .horizontal)

    let content = NSStackView(views: [titleLabel, valueLabel, spacer, actionLabel])
    content.orientation = .horizontal
    content.alignment = .centerY
    content.spacing = 8
    content.translatesAutoresizingMaskIntoConstraints = false
    row.addSubview(content)
    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
      content.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
      content.topAnchor.constraint(equalTo: row.topAnchor),
      content.bottomAnchor.constraint(equalTo: row.bottomAnchor),
    ])

    // One transparent button covers the entire row; the text is only its layout.
    let button = VisionMenuRowButton(title: "", target: self, action: action)
    button.isBordered = false
    button.toolTip = "手动调整\(title)"
    button.setAccessibilityLabel("\(title)，手动调整")
    button.translatesAutoresizingMaskIntoConstraints = false
    row.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: row.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: row.trailingAnchor),
      button.topAnchor.constraint(equalTo: row.topAnchor),
      button.bottomAnchor.constraint(equalTo: row.bottomAnchor),
    ])

    let item = NSMenuItem()
    item.view = row
    return (item, valueLabel)
  }

  private func refreshVisionMenu() {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0
    let minutes = formatter.string(from: NSNumber(value: minutesPerOrder)) ?? "0.7"
    peopleValueLabel?.stringValue = "\(peopleInStore) 人"
    ordersValueLabel?.stringValue = "\(onlineOrders) 单"
    minutesValueLabel?.stringValue = "\(minutes) min"
    let estimate = max(1, Int((Double(onlineOrders + 1) * minutesPerOrder).rounded()))
    estimateItem?.title = "预计等待：约 \(estimate) 分钟"
  }

  private func askForValue(title: String, current: String, decimal: Bool) -> String? {
    while true {
      let alert = NSAlert()
      alert.messageText = "手动调整\(title)"
      alert.informativeText = decimal ? "请输入 0.1–60 分钟，最多两位小数。" : "请输入 0–999 的整数。"
      alert.addButton(withTitle: "应用")
      alert.addButton(withTitle: "取消")
      let field = NSTextField(string: current)
      field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
      alert.accessoryView = field
      guard alert.runModal() == .alertFirstButtonReturn else { return nil }
      let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      if decimal {
        if value.range(of: "^[0-9]+(\\.[0-9]{1,2})?$", options: .regularExpression) != nil,
           let parsed = Double(value), parsed >= 0.1, parsed <= 60 {
          return value
        }
      } else if let parsed = Int(value), parsed >= 0, parsed <= 999 {
        return value
      }
      NSSound.beep()
    }
  }

  @objc private func adjustPeople(_ sender: Any?) {
    visionMenu?.cancelTracking()
    DispatchQueue.main.async {
      guard let value = self.askForValue(title: "店内人数", current: String(self.peopleInStore), decimal: false),
            let parsed = Int(value) else { return }
      self.peopleInStore = parsed
      self.refreshVisionMenu()
    }
  }

  @objc private func adjustOrders(_ sender: Any?) {
    visionMenu?.cancelTracking()
    DispatchQueue.main.async {
      guard let value = self.askForValue(title: "线上单数", current: String(self.onlineOrders), decimal: false),
            let parsed = Int(value) else { return }
      self.onlineOrders = parsed
      self.refreshVisionMenu()
    }
  }

  @objc private func adjustMinutes(_ sender: Any?) {
    visionMenu?.cancelTracking()
    DispatchQueue.main.async {
      guard let value = self.askForValue(title: "每单时间", current: String(self.minutesPerOrder), decimal: true),
            let parsed = Double(value) else { return }
      self.minutesPerOrder = parsed
      self.refreshVisionMenu()
    }
  }

  @objc private func resetVisionValues(_ sender: Any?) {
    peopleInStore = 19
    onlineOrders = 6
    minutesPerOrder = 0.7
    refreshVisionMenu()
  }

  @objc private func showMerchantWindow(_ sender: Any?) {
    makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func quitApplication(_ sender: Any?) {
    NSApp.terminate(nil)
  }
}
