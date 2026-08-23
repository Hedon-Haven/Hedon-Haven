import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

import 'onboarding_disclaimers.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(children: [
                  Expanded(
                      child: FractionallySizedBox(
                          widthFactor: 0.5,
                          heightFactor: 0.5,
                          child: Image.asset(kDebugMode
                              ? "assets/launcher-icon/stock_debug.png"
                              : "assets/launcher-icon/stock.png"))),
                  Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Text(
                          "Welcome to Hedon Haven"
                          "${kDebugMode ? " Debug" : ""}",
                          style: Theme.of(context).textTheme.headlineMedium)),
                  Spacer(),
                  Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary),
                          onPressed: () => Navigator.push(
                              context,
                              PageTransition(
                                  settings: RouteSettings(
                                      name: "/onboarding_disclaimers"),
                                  type: PageTransitionType.rightToLeftJoined,
                                  childCurrent: this,
                                  child: DisclaimersScreen())),
                          child: Text("Next",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary)))),
                ]))));
  }
}
