import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';

class VisionWindowService with TrayListener {
  VisionWindowService._();

  static final VisionWindowService instance = VisionWindowService._();
  static const windowArgument = 'campura-vision-demo';
  static const _macMenuChannel = MethodChannel('campura/vision_menu');

  Future<void>? _opening;
  bool _trayReady = false;

  Future<void> open() {
    if (Platform.isMacOS) {
      return _showMacMenu();
    }
    return _opening ??= _openWindow().whenComplete(() => _opening = null);
  }

  Future<void> _showMacMenu() async {
    final shown = await _macMenuChannel.invokeMethod<bool>('show');
    if (shown != true) {
      throw StateError('状态栏菜单未能打开');
    }
  }

  Future<void> _openWindow() async {
    final windows = await WindowController.getAll();
    for (final window in windows) {
      if (window.arguments == windowArgument) {
        await window.show();
        return;
      }
    }
    final window = await WindowController.create(
      const WindowConfiguration(arguments: windowArgument),
    );
    await window.show();
  }

  Future<void> initializeTray() async {
    if (!Platform.isWindows || _trayReady) return;
    await trayManager.setIcon('assets/icons/vision_tray.ico');
    await trayManager.setToolTip('域校屿商家 · 视觉分析');
    await trayManager.setContextMenu(
      Menu(
        items: [MenuItem(key: 'open_vision', label: '打开视觉分析')],
      ),
    );
    trayManager.addListener(this);
    _trayReady = true;
  }

  void _openFromTray() {
    unawaited(
      open().catchError((Object error, StackTrace stack) {
        debugPrint('打开视觉分析窗口失败：$error');
      }),
    );
  }

  @override
  void onTrayIconMouseDown() => _openFromTray();

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'open_vision') _openFromTray();
  }
}
