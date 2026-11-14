import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A short transition for pushed pages; reduced-motion users get an instant page.
CustomTransitionPage<void> lingoPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          MediaQuery.disableAnimationsOf(context)
          ? child
          : FadeTransition(
              opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
              child: child,
            ),
    );
