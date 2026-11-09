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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
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
              border: Border(top: BorderSide(color: Color(0xffd4d9d0))),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SizedBox(width: double.infinity, child: actions),
              ),
            ),
          ),
      ],
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Notice(
              title: 'Periksa kembali',
              message: message!,
              color: AppColors.warning,
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
  const DesignIcon(this.name, {super.key, this.size = 24});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      'assets/figma/$name.svg',
      width: size,
      height: size,
    ),
  );
}

class PaperCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  const PaperCard({
    super.key,
    required this.child,
    this.color = AppColors.canvas,
    this.padding = const EdgeInsets.all(14),
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14, right: 4),
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.ink, width: 2),
      boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
    ),
    child: child,
  );
}

class AppButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final String? icon;
  final bool secondary;
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
  });
  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  final states = WidgetStatesController();
  @override
  void initState() {
    super.initState();
    states.addListener(_changed);
  }

  void _changed() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() {});
  });
  @override
  void dispose() {
    states.removeListener(_changed);
    states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pressed = states.value.contains(WidgetState.pressed);
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          pressed ? 2 : 0,
          pressed ? 2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: widget.onPressed == null
              ? []
              : [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(pressed ? 2 : 4, pressed ? 2 : 4),
                  ),
                ],
        ),
        child: FilledButton(
          statesController: states,
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: widget.secondary
                ? AppColors.canvas
                : AppColors.lime,
            foregroundColor: AppColors.ink,
            disabledBackgroundColor: const Color(0xffe3e3db),
            disabledForegroundColor: const Color(0xff55554e),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            textStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.ink, width: 2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                DesignIcon(widget.icon!, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(widget.label, textAlign: TextAlign.center)),
            ],
          ),
        ),
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
    this.color = AppColors.cyan,
    this.icon = 'imgInfo',
  });
  @override
  Widget build(BuildContext context) => PaperCard(
    color: color,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignIcon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (message != null) ...[
                const SizedBox(height: 4),
                Text(message!, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  final String label, icon;
  const StatusBadge(this.label, {super.key, this.icon = 'imgClock'});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.ink, width: 2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignIcon(icon, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => PaperCard(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    Text(
                      '${clockLabel(session.startsAt)}–${clockLabel(session.endsAt)} WIB · ${session.endsAt.difference(session.startsAt).inMinutes} menit',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '${statusLabel(session.status)}${invalid ? ' · Perlu disusun ulang' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const DesignIcon('imgChevronRight', size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

class StudyIllustration extends StatelessWidget {
  const StudyIllustration({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 152.828,
      height: 116,
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
    left: (x - w * bleedX) * 152.828,
    top: (y - h * bleedY) * 116,
    width: w * (1 + bleedX * 2) * 152.828,
    height: h * (1 + bleedY * 2) * 116,
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: StudyIllustration()),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message),
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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: AppButton(label: 'Batal', onPressed: onCancel, secondary: true),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: AppButton(label: label, onPressed: onSave),
      ),
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
      borderRadius: BorderRadius.circular(12),
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
              size: 22,
            ),
          ),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
        constraints.maxWidth < 340 ||
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
