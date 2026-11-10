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
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppLayout.page,
              16,
              AppLayout.page,
              24,
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
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppLayout.page,
              12,
              AppLayout.page,
              12,
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.forest,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
              child: DesignIcon(icon, size: 20, color: AppColors.forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                eyebrow,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onForest,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: MediaQuery.textScalerOf(context).scale(14) > 18 ? 22 : 32,
            height: 1.12,
            letterSpacing: -1,
            fontWeight: FontWeight.w700,
            color: AppColors.surface,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 12),
          Text(
            description!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.onForest,
            ),
          ),
        ],
        if (footer != null) ...[const SizedBox(height: 24), footer!],
      ],
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppLayout.section),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.inkSecondary,
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSecondary,
                  ),
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

class ErrorNotice extends StatelessWidget {
  final String? message;
  const ErrorNotice(this.message, {super.key});
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Semantics(
            liveRegion: true,
            child: Notice(
              title: 'Periksa kembali',
              message: message!,
              color: AppColors.errorSoft,
              icon: 'imgAlertCircle',
            ),
          ),
        );
}

Future<bool> confirmDelete(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surface,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
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
  final Color color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  const PaperCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
  });
  @override
  Widget build(BuildContext context) {
    final resolvedBorder =
        borderColor ??
        (color == AppColors.warning
            ? AppColors.warningBorder
            : color == AppColors.errorSoft
            ? AppColors.errorBorder
            : color == AppColors.primarySoft
            ? AppColors.primaryBorder
            : color == AppColors.successSoft
            ? AppColors.successBorder
            : AppColors.border);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
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
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fgColor = !enabled
        ? AppColors.inkMuted
        : secondary || highlighted
        ? AppColors.ink
        : AppColors.surface;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: highlighted
            ? AppColors.lime
            : secondary
            ? AppColors.surface
            : AppColors.primary,
        foregroundColor: fgColor,
        disabledBackgroundColor: AppColors.surfaceMuted,
        disabledForegroundColor: AppColors.inkMuted,
        elevation: 0,
        minimumSize: const Size(AppLayout.control, 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radius),
          side: BorderSide(
            color: !enabled
                ? AppColors.border
                : highlighted
                ? AppColors.lime
                : secondary
                ? AppColors.borderStrong
                : AppColors.primaryDark,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            DesignIcon(icon!, size: 18, color: fgColor),
            const SizedBox(width: 8),
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
  final Color color;
  final String icon;
  const Notice({
    super.key,
    required this.title,
    this.message,
    this.color = AppColors.primarySoft,
    this.icon = 'imgInfo',
  });
  @override
  Widget build(BuildContext context) {
    final isWarning = color == AppColors.warning;
    final isSuccess = color == AppColors.successSoft;
    final isError = color == AppColors.errorSoft || color == AppColors.error;
    final accentColor = isError
        ? AppColors.error
        : isWarning
        ? AppColors.warningInk
        : isSuccess
        ? AppColors.success
        : AppColors.primary;
    final fillColor = isError
        ? AppColors.errorSoft
        : isWarning
        ? AppColors.warning
        : isSuccess
        ? AppColors.successSoft
        : AppColors.primarySoft;
    return PaperCard(
      color: fillColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: DesignIcon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isError ? AppColors.error : AppColors.ink,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label, icon;
  const StatusBadge(this.label, {super.key, this.icon = 'imgClock'});
  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final isSuccess =
        lower.contains('selesai') ||
        lower.contains('terkonfirmasi') ||
        lower.contains('daring');
    final isDanger =
        lower.contains('terlambat') ||
        lower.contains('terlewat') ||
        lower.contains('lewat');
    final isWarning =
        lower.contains('perlu') ||
        lower.contains('kurang') ||
        lower.contains('penuh') ||
        lower.contains('horizon') ||
        lower.contains('belum');
    final isMuted = lower.contains('dibatalkan');

    final Color bg;
    final Color border;
    final Color fg;
    if (isSuccess) {
      bg = AppColors.successSoft;
      border = AppColors.successBorder;
      fg = AppColors.success;
    } else if (isDanger) {
      bg = AppColors.errorSoft;
      border = AppColors.errorBorder;
      fg = AppColors.error;
    } else if (isWarning) {
      bg = AppColors.warning;
      border = AppColors.warningBorder;
      fg = AppColors.warningInk;
    } else if (isMuted) {
      bg = AppColors.surfaceMuted;
      border = AppColors.borderStrong;
      fg = AppColors.inkSecondary;
    } else {
      bg = AppColors.primarySoft;
      border = AppColors.primaryBorder;
      fg = AppColors.primaryDark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignIcon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String clockLabel(DateTime value) =>
    DateFormat('HH:mm').format(tz.TZDateTime.from(value, jakarta));

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
    final accentColor = invalid
        ? AppColors.warningInk
        : switch (session.status) {
            SessionStatus.completed => AppColors.success,
            SessionStatus.missed => AppColors.error,
            SessionStatus.cancelled => AppColors.inkMuted,
            SessionStatus.planned => AppColors.primary,
          };
    final statusIcon = switch (session.status) {
      SessionStatus.completed => 'imgCheckCircle',
      SessionStatus.missed => 'imgAlertCircle',
      SessionStatus.cancelled => 'imgInfo',
      SessionStatus.planned => invalid ? 'imgAlertCircle' : 'imgClock',
    };
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${session.endsAt.difference(session.startsAt).inMinutes} menit \u00b7 WIB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            DesignIcon(statusIcon, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${statusLabel(session.status)}${invalid ? ' \u00b7 Perlu disusun ulang' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    final clock = Text(
      '${clockLabel(session.startsAt)}\n${clockLabel(session.endsAt)}',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: accentColor),
    );
    return PaperCard(
      padding: EdgeInsets.zero,
      borderColor: invalid ? AppColors.warningBorder : AppColors.border,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppLayout.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${clockLabel(session.startsAt)} \u2013 ${clockLabel(session.endsAt)} WIB',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: accentColor),
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
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: clock,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                      const SizedBox(width: 8),
                      const DesignIcon(
                        'imgChevronRight',
                        size: 20,
                        color: AppColors.inkMuted,
                      ),
                    ],
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
  Widget build(BuildContext context) => PaperCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const DesignIcon(
            'imgCalendar',
            size: 22,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.inkSecondary,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: '$label, $value',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppLayout.radius),
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
              color: onTap == null
                  ? AppColors.inkMuted
                  : AppColors.inkSecondary,
            ),
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: onTap == null ? AppColors.inkMuted : AppColors.ink,
          ),
        ),
      ),
    ),
  );
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
        constraints.maxWidth < 280 ||
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
