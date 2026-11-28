import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '/utils/global_vars.dart';

/// Actions triggered by desktop keyboard shortcuts
enum DesktopShortcut { refresh }

/// Returns true if the event was handled
bool handleDesktopEvents(
    KeyEvent event, GlobalKey<NavigatorState> navigatorKey) {
  if (event is! KeyDownEvent) return false;

  switch (event.logicalKey) {
    case LogicalKeyboardKey.escape:
      navigatorKey.currentState?.maybePop();
      return true;

    // Ctrl + R
    case LogicalKeyboardKey.keyR
        when HardwareKeyboard.instance.isControlPressed:
      desktopShortcutEvent.add(DesktopShortcut.refresh);
      return true;

    default:
      return false;
  }
}
