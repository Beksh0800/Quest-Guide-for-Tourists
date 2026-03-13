import 'dart:io';

import 'package:flutter/material.dart';

class FullscreenImageViewer extends StatefulWidget {
  final File? file;
  final String? imageUrl;

  const FullscreenImageViewer({
    super.key,
    this.file,
    this.imageUrl,
  });

  static Future<void> show(
    BuildContext context, {
    File? file,
    String? imageUrl,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, __, ___) => FullscreenImageViewer(
          file: file,
          imageUrl: imageUrl,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();

  TapDownDetails? _doubleTapDetails;
  double _verticalDragOffset = 0;

  bool get _isZoomed {
    final matrix = _transformationController.value;
    return matrix.getMaxScaleOnAxis() > 1.01;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (details == null) return;

    final currentlyZoomed = _isZoomed;
    if (currentlyZoomed) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    final position = details.localPosition;
    const targetScale = 2.5;
    final dx = -position.dx * (targetScale - 1);
    final dy = -position.dy * (targetScale - 1);

    // Build transform without deprecated Matrix4 translate/scale helpers.
    _transformationController.value = Matrix4.identity()
      ..setEntry(0, 0, targetScale)
      ..setEntry(1, 1, targetScale)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;

    setState(() {
      final next = _verticalDragOffset + (details.primaryDelta ?? 0);
      _verticalDragOffset = next.clamp(-260.0, 260.0);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) {
      if (_verticalDragOffset != 0) {
        setState(() {
          _verticalDragOffset = 0;
        });
      }
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    final shouldClose = _verticalDragOffset.abs() > 140 || velocity.abs() > 900;

    if (shouldClose) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _verticalDragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = (_verticalDragOffset.abs() / 220).clamp(0.0, 1.0);
    final opacity = (1.0 - dragProgress * 0.45).clamp(0.0, 1.0);

    final hasImageSource = widget.file != null ||
        ((widget.imageUrl ?? '').trim().isNotEmpty);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              onVerticalDragUpdate: _handleVerticalDragUpdate,
              onVerticalDragEnd: _handleVerticalDragEnd,
              onVerticalDragCancel: () {
                if (_verticalDragOffset == 0) return;
                setState(() {
                  _verticalDragOffset = 0;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                transform: Matrix4.translationValues(0, _verticalDragOffset, 0),
                child: Center(
                  child: hasImageSource
                      ? InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1,
                          maxScale: 5,
                          child: widget.file != null
                              ? Image.file(widget.file!, fit: BoxFit.contain)
                              : Image.network(
                                  widget.imageUrl ?? '',
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Не удалось загрузить изображение',
                                      style: TextStyle(color: Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                        )
                      : const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Изображение недоступно',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


