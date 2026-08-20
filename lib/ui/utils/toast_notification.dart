import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '/utils/global_vars.dart';


// TODO: Look into replacing with ScaffoldMessenger.showSnackBar
void showToast(String message, BuildContext context, [int showDuration = 2]) {
  logger.i("Showing toast with message: $message");

  // TODO: Get rid of white border color
  toastification.show(
    context: context,
    type: ToastificationType.info,
    style: ToastificationStyle.simple,
    title: Text(message, maxLines: 3),
    alignment: Alignment.bottomCenter,
    autoCloseDuration: Duration(seconds: showDuration),
    animationDuration: const Duration(milliseconds: 500),
    borderRadius: BorderRadius.circular(100.0),
    closeButtonShowType: CloseButtonShowType.none,
    backgroundColor: Theme.of(context).colorScheme.surface,
    // background
    foregroundColor: Theme.of(context).colorScheme.primary, // text
  );
}

/// This does the same as [showToast] but uses [OverlayState] instead of [BuildContext]
void showToastViaOverlay(String message, OverlayState overlay,
    [int showDuration = 2]) {
  logger.i("Showing overlay toast with message: $message");

  // TODO: Get rid of white border color
  toastification.show(
    overlayState: overlay,
    type: ToastificationType.info,
    style: ToastificationStyle.simple,
    title: Text(message, maxLines: 3),
    alignment: Alignment.bottomCenter,
    autoCloseDuration: Duration(seconds: showDuration),
    animationDuration: const Duration(milliseconds: 500),
    borderRadius: BorderRadius.circular(100.0),
    closeButtonShowType: CloseButtonShowType.none,
    backgroundColor: Theme.of(overlay.context).colorScheme.surface,
    // background
    foregroundColor: Theme.of(overlay.context).colorScheme.primary, // text
  );
}
