import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../planner/models.dart';
import '../planner/schedule.dart';
import '../app/theme.dart';

String dateTimeLabel(DateTime value) =>
    '${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(tz.TZDateTime.from(value, jakarta))} WIB';
String dateLabel(DateTime value) => DateFormat(
  'EEEE, d MMMM yyyy',
  'id_ID',
).format(tz.TZDateTime.from(value, jakarta));
String timeLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
const weekdays = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
String windowLabel(TimeWindow w) =>
    '${w.weekday == null ? DateFormat('d MMM yyyy', 'id_ID').format(DateTime.parse(w.date!)) : weekdays[w.weekday! - 1]} • ${timeLabel(w.startMinute)}–${timeLabel(w.endMinute)} WIB';
String statusLabel(SessionStatus s) => switch (s) {
  SessionStatus.planned => 'Direncanakan',
  SessionStatus.completed => 'Selesai',
  SessionStatus.missed => 'Terlewat',
  SessionStatus.cancelled => 'Dibatalkan',
};

class PageContent extends StatelessWidget {
  final List<Widget> children;
  final Widget? actions;
  const PageContent({super.key, required this.children, this.actions});
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final gutter = AppLayout.gutter(context);
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                gutter,
                AppLayout.space16,
                gutter,
                AppLayout.section,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.contentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
          if (actions != null)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: gutter,
                vertical: AppLayout.space12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.contentWidth,
                  ),
                  child: SizedBox(width: double.infinity, child: actions),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FocusPanel extends StatelessWidget {
  final String eyebrow, title;
  final String? description;
  final Widget? footer;
  final String icon;
  const FocusPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.footer,
    this.icon = 'imgClock1',
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = Theme.of(context).textTheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    return Container(
      margin: const EdgeInsets.only(bottom: AppLayout.section),
      padding: const EdgeInsets.all(AppLayout.section),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(AppLayout.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
                child: DesignIcon(icon, size: 20, color: colors.onAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  eyebrow,
                  style: type.labelMedium?.copyWith(color: colors.onPanel),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.section),
          Text(
            title,
            style: (largeText ? type.headlineSmall : type.displaySmall)
                ?.copyWith(color: colors.onPanel),
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description!,
              style: type.bodyMedium?.copyWith(color: colors.onPanel),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppLayout.section),
            footer!,
          ],
        ],
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.inkSecondary),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class ErrorNotice extends StatelessWidget {
  final String? message;
  const ErrorNotice(this.message, {super.key});
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return message == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Notice(
              title: 'Periksa kembali',
              message: message!,
              color: colors.dangerBg,
              live: true,
            ),
          );
  }
}

Future<T?> showAppDialog<T>(BuildContext context, WidgetBuilder builder) {
  final duration = AppMotion.durationOf(context);
  return showDialog<T>(
    context: context,
    animationStyle: duration == Duration.zero
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: duration,
            reverseDuration: duration,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
    builder: builder,
  );
}

Future<bool> confirmDelete(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showAppDialog<bool>(
      context,
      (c) => AlertDialog(
        scrollable: true,
        icon: DesignIcon('imgTrash', color: AppColors.of(c).dangerInk),
        title: Text(title),
        content: Text(message),
        actionsOverflowButtonSpacing: AppLayout.space8,
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          AppButton(
            label: action,
            destructive: true,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    ) ??
    false;

class DesignIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const DesignIcon(this.name, {super.key, this.size = 24, this.color});
  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color;
    return ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/figma/$name.svg',
        width: size,
        height: size,
        colorFilter:
            effectiveColor != null && name != 'imgWaktuTugasIllustrationSparkle'
            ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
            : null,
      ),
    );
  }
}

class PaperCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  const PaperCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(AppLayout.space16),
    this.margin = const EdgeInsets.only(bottom: AppLayout.space12),
  });
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final resolvedBorder = borderColor ?? colors.border;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(AppLayout.radius),
        border: Border.all(color: resolvedBorder, width: 1),
      ),
      child: child,
    );
  }
}

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final String? icon;
  final bool secondary;
  final bool highlighted;
  final bool destructive;
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.highlighted = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final duration = AppMotion.durationOf(context);
    final (fill, pressed, ink) = destructive
        ? (colors.dangerInk, colors.dangerPressed, colors.onDanger)
        : highlighted
        ? (colors.accent, colors.accentPressed, colors.onAccent)
        : secondary
        ? (colors.surface, colors.primarySoft, colors.ink)
        : (colors.primary, colors.primaryPressed, colors.onPrimary);
    return FilledButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.surfaceMuted
              : states.contains(WidgetState.pressed)
              ? pressed
              : fill,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.inkMuted
              : secondary &&
                    !highlighted &&
                    states.contains(WidgetState.pressed)
              ? colors.onPrimarySoft
              : ink,
        ),
        elevation: const WidgetStatePropertyAll(0),
        animationDuration: duration,
        splashFactory: duration == Duration.zero
            ? NoSplash.splashFactory
            : null,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) &&
                  !states.contains(WidgetState.pressed) &&
                  !states.contains(WidgetState.focused)
              ? Colors.transparent
              : null,
        ),
        backgroundBuilder: (context, states, child) => AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          color:
              states.contains(WidgetState.hovered) &&
                  !states.contains(WidgetState.disabled) &&
                  !states.contains(WidgetState.pressed)
              ? ink.withValues(alpha: .10)
              : Colors.transparent,
          child: child,
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(AppLayout.control, AppLayout.fieldHeight),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: colors.border);
          }
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: secondary ? colors.focus : ink, width: 2);
          }
          return secondary
              ? BorderSide(color: colors.outline)
              : BorderSide.none;
        }),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            DesignIcon(icon!, size: 18),
            const SizedBox(width: AppLayout.space8),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class Notice extends StatelessWidget {
  final String title;
  final String? message;
  final Color? color;
  final String? icon;
  final bool live;
  const Notice({
    super.key,
    required this.title,
    this.message,
    this.color,
    this.icon,
    this.live = false,
  });
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tone = switch (color) {
      final value when value == colors.warningBg => StatusTone.warning,
      final value when value == colors.successBg => StatusTone.success,
      final value when value == colors.dangerBg || value == colors.dangerInk =>
        StatusTone.danger,
      _ => StatusTone.info,
    };
    final (fillColor, accentColor) = tone.palette(colors);
    final type = Theme.of(context).textTheme;
    return Semantics(
      container: live,
      liveRegion: live,
      child: PaperCard(
        color: fillColor,
        padding: const EdgeInsets.all(AppLayout.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: DesignIcon(
                icon ?? tone.icon,
                size: 20,
                color: accentColor,
              ),
            ),
            const SizedBox(width: AppLayout.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: type.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppLayout.space4),
                    Text(
                      message!,
                      style: type.bodySmall?.copyWith(color: accentColor),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum StatusTone {
  neutral('imgInfo'),
  info('imgInfo'),
  success('imgCheckCircle'),
  warning('imgAlertCircle'),
  danger('imgAlertCircle');

  const StatusTone(this.icon);
  final String icon;

  (Color, Color) palette(AppColors colors) => switch (this) {
    neutral => (colors.surfaceMuted, colors.inkMuted),
    info => (colors.infoBg, colors.infoInk),
    success => (colors.successBg, colors.successInk),
    warning => (colors.warningBg, colors.warningInk),
    danger => (colors.dangerBg, colors.dangerInk),
  };
}

class StatusBadge extends StatelessWidget {
  final String label;
  final String? icon;
  final StatusTone tone;
  const StatusBadge(
    this.label, {
    super.key,
    this.icon,
    this.tone = StatusTone.neutral,
  });
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (bg, fg) = tone.palette(colors);

    return Container(
      constraints: const BoxConstraints(minHeight: AppLayout.section),
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.space8,
        vertical: AppLayout.space4,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignIcon(icon ?? tone.icon, size: 16, color: fg),
          const SizedBox(width: AppLayout.space4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

String clockLabel(DateTime value) =>
    DateFormat('HH:mm').format(tz.TZDateTime.from(value, jakarta));

StatusTone sessionTone(SessionStatus status) => switch (status) {
  SessionStatus.completed => StatusTone.success,
  SessionStatus.missed => StatusTone.warning,
  SessionStatus.cancelled => StatusTone.neutral,
  SessionStatus.planned => StatusTone.info,
};

class SessionCard extends StatelessWidget {
  final PlannerSession session;
  final String title;
  final VoidCallback onTap;
  final bool invalid;
  const SessionCard({
    super.key,
    required this.session,
    required this.title,
    required this.onTap,
    this.invalid = false,
  });
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '${session.endsAt.difference(session.startsAt).inMinutes} menit \u00b7 WIB',
          style: AppTypography.time.copyWith(color: colors.inkSecondary),
        ),
        const SizedBox(height: 8),
        StatusBadge(
          '${statusLabel(session.status)}${invalid ? ' \u00b7 Perlu disusun ulang' : ''}',
          tone: invalid ? StatusTone.warning : sessionTone(session.status),
          icon: !invalid && session.status == SessionStatus.planned
              ? 'imgClock'
              : null,
        ),
      ],
    );
    final clock = Text(
      '${clockLabel(session.startsAt)}\n${clockLabel(session.endsAt)}',
      style: AppTypography.time.copyWith(color: colors.onPrimarySoft),
    );
    return PaperCard(
      padding: EdgeInsets.zero,
      borderColor: invalid ? colors.warningInk : colors.border,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppLayout.radius),
        clipBehavior: Clip.antiAlias,
        child: KeyboardFocusOutline(
          radius: AppLayout.radius,
          child: InkWell(
            onTap: onTap,
            hoverDuration: AppMotion.durationOf(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${clockLabel(session.startsAt)} \u2013 ${clockLabel(session.endsAt)} WIB',
                          style: AppTypography.time.copyWith(color: colors.ink),
                        ),
                        const SizedBox(height: 12),
                        details,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: clock,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: details),
                        const SizedBox(width: 8),
                        DesignIcon(
                          'imgChevronRight',
                          size: 20,
                          color: colors.inkMuted,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class StudyIllustration extends StatelessWidget {
  const StudyIllustration({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 132,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _layer('imgStudentTorso', .1607, .4040, .5506, .5058, .0108, .0155),
          _layer('imgHeadphonesBack', .2946, .0055, .3244, .2965, .0688, .0992),
          _layer('imgStudentHead', .2941, 0, .3332, .4774, .0179, .0164),
          _layer('imgHeadphoneEarcups', .2684, .21, .3769, .1801, .0046, .0126),
          _layer('imgStudyArms', .1069, .5930, .6383, .3043, .0093, .0258),
          _layer('imgOpenBook', 0, .7078, .7708, .2922, .0077, .0268),
          _layer('imgStudyClock', .7679, .5848, .2321, .3603, .0256, .0245),
          _layer('imgStudyAccents', .0417, .2001, .7857, .2509, .0067, .0274),
        ],
      ),
    ),
  );
  Widget _layer(
    String name,
    double x,
    double y,
    double w,
    double h,
    double bleedX,
    double bleedY,
  ) => Positioned(
    left: (x - w * bleedX) * 132,
    top: (y - h * bleedY) * 100,
    width: w * (1 + bleedX * 2) * 132,
    height: h * (1 + bleedY * 2) * 100,
    child: SvgPicture.asset('assets/figma/$name.svg'),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PaperCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DesignIcon('imgCalendar', size: 22, color: colors.primary),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.inkSecondary),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class FormActions extends StatelessWidget {
  final String label;
  final VoidCallback? onSave, onCancel;
  const FormActions({
    super.key,
    required this.label,
    required this.onSave,
    required this.onCancel,
  });
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppButton(label: label, onPressed: onSave),
      TextButton(onPressed: onCancel, child: const Text('Batal')),
    ],
  );
}

class KeyboardFocusOutline extends StatefulWidget {
  const KeyboardFocusOutline({
    super.key,
    required this.child,
    this.radius = AppLayout.controlRadius,
    this.color,
  });
  final Widget child;
  final double radius;
  final Color? color;

  @override
  State<KeyboardFocusOutline> createState() => _KeyboardFocusOutlineState();
}

class _KeyboardFocusOutlineState extends State<KeyboardFocusOutline> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onFocusChange: (value) => setState(() => focused = value),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        border: focused
            ? Border.all(
                color: widget.color ?? AppColors.of(context).focus,
                width: 2,
              )
            : null,
      ),
      child: widget.child,
    ),
  );
}

class PickerField extends StatelessWidget {
  final String label, value, icon;
  final VoidCallback? onTap;
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$label, $value',
      onTap: onTap,
      excludeSemantics: true,
      child: KeyboardFocusOutline(
        child: InkWell(
          onTap: onTap,
          hoverDuration: AppMotion.durationOf(context),
          borderRadius: BorderRadius.circular(AppLayout.controlRadius),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              enabled: onTap != null,
              suffixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: DesignIcon(
                  icon == 'imgClock'
                      ? 'imgFieldClock'
                      : icon == 'imgCalendar'
                      ? 'imgFieldCalendar'
                      : icon,
                  size: 20,
                  color: onTap == null ? colors.inkMuted : colors.inkSecondary,
                ),
              ),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: onTap == null ? colors.inkMuted : colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResponsiveFields extends StatelessWidget {
  final Widget first, second;
  const ResponsiveFields({
    super.key,
    required this.first,
    required this.second,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 18
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          ),
  );
}
