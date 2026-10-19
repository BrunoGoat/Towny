import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'style.dart';

/// El vidrio ahumado de las hojas nuevas (ver [SheetInk]): flotando con las
/// cuatro esquinas redondas, o apoyado abajo con las dos de arriba.
class SheetGlass extends StatelessWidget {
  const SheetGlass({
    super.key,
    required this.velo,
    required this.child,
    required this.padding,
    this.radius = 26,
    this.bottom = true,
  });

  final SheetInk velo;
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// Si redondea también las esquinas de abajo.
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    final borde = bottom
        ? BorderRadius.circular(radius)
        : BorderRadius.vertical(top: Radius.circular(radius));
    return ClipRRect(
      borderRadius: borde,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: velo.bruma, sigmaY: velo.bruma),
        // Material transparente: un diálogo vive fuera del `Scaffold` y sin
        // esto escribe con la letra de emergencia de Flutter, subrayada.
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: velo.tinte.withValues(alpha: velo.tapa),
              borderRadius: borde,
              border: bottom
                  ? Border.all(color: velo.canto)
                  : Border(top: BorderSide(color: velo.canto)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// El botón de seguir: del color del pueblo, lleno.
class SheetAccent extends StatelessWidget {
  const SheetAccent({
    super.key,
    required this.theme,
    required this.text,
    required this.onTap,
  });

  final UiTheme theme;
  final String text;

  /// Nulo, apagado: todavía no hay nada elegido.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        disabledBackgroundColor: velo.cuerpo.withValues(alpha: 0.08),
        disabledForegroundColor: velo.tenue,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Un renglón: el punto de elegir, el nombre de la manera y una línea de qué
/// quiere decir. Sin cápsula alrededor: el renglón elegido se nota porque el
/// vidrio se espesa debajo y el punto se enciende.
class SheetChoice extends StatelessWidget {
  const SheetChoice({
    super.key,
    required this.theme,
    required this.velo,
    required this.on,
    required this.title,
    required this.hint,
    required this.onTap,
    this.trailing,
  });

  final UiTheme theme;
  final SheetInk velo;
  final bool on;
  final String title;
  final String hint;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: on ? velo.cuerpo.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? t.accent : velo.cuerpo.withValues(alpha: 0.38),
                  width: on ? 5.5 : 1.4,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.body.copyWith(
                      fontSize: 14.5,
                      color: velo.cuerpo,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: t.bodySoft.copyWith(
                      fontSize: 11.5,
                      height: 1.3,
                      color: velo.tenue,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
