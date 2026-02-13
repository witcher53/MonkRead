import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monkread/core/constants/app_constants.dart';
import 'package:monkread/domain/entities/pdf_document.dart';
import 'package:monkread/presentation/screens/home_screen.dart';
import 'package:monkread/presentation/screens/reader_screen.dart';

/// GoRouter configuration provider.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppConstants.homeRoute,
    routes: [
      GoRoute(
        path: AppConstants.homeRoute,
        name: 'home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: AppConstants.readerRoute,
        name: 'reader',
        pageBuilder: (context, state) {
          final document = state.extra as PdfDocument;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ReaderScreen(document: document),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                )),
                child: child,
              );
            },
          );
        },
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      child: Scaffold(
        body: Center(
          child: Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    ),
  );
});
