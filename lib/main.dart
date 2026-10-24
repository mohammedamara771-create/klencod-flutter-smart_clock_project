// ساعة ذكية Flutter: 6 نماذج + إشعار عند بداية كل ساعة
//
// pubspec.yaml -> dependencies:
//   flutter_local_notifications: ^19.0.0
//   timezone: ^0.10.0
//   shared_preferences: ^2.2.0
//
// Android: داخل <application> في AndroidManifest.xml أضف:
//   <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
//   <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
//     <intent-filter>
//       <action android:name="android.intent.action.BOOT_COMPLETED"/>
//       <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
//     </intent-filter>
//   </receiver>
// وأضف الصلاحيات: POST_NOTIFICATIONS و RECEIVE_BOOT_COMPLETED
// وفي android/app/build.gradle: compileOptions { coreLibraryDesugaringEnabled true }
// و dependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4' }

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ---------------------------------------------------------------------------
// أدوات
// ---------------------------------------------------------------------------
String two(int n) => n.toString().padLeft(2, '0');

const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];

String dateText(DateTime t) =>
    '${days[t.weekday - 1]}  ${t.day} ${months[t.month - 1]} ${t.year}';

class TP {
  final String h, m, s, suffix;
  TP(DateTime t, bool use24)
      : h = use24 ? two(t.hour) : two(t.hour % 12 == 0 ? 12 : t.hour % 12),
        m = two(t.minute),
        s = two(t.second),
        suffix = use24 ? '' : (t.hour < 12 ? 'ص' : 'م');
}

const faceNames = ['نيون رقمي', 'كلاسيكية', 'حلقات', 'ثنائية', 'قلاب', 'عصرية'];

// ---------------------------------------------------------------------------
// الإعدادات
// ---------------------------------------------------------------------------
class Cfg {
  int model = 0;
  bool hourly = true;
  int from = 7;
  int to = 23;
  bool use24 = true;

  Cfg.load(SharedPreferences sp) {
    model = sp.getInt('model') ?? 0;
    hourly = sp.getBool('hourly') ?? true;
    from = sp.getInt('from') ?? 7;
    to = sp.getInt('to') ?? 23;
    use24 = sp.getBool('use24') ?? true;
  }

  Future<void> save(SharedPreferences sp) async {
    await sp.setInt('model', model);
    await sp.setBool('hourly', hourly);
    await sp.setInt('from', from);
    await sp.setInt('to', to);
    await sp.setBool('use24', use24);
  }
}

// ---------------------------------------------------------------------------
// الإشعارات
// ---------------------------------------------------------------------------
final FlutterLocalNotificationsPlugin notif = FlutterLocalNotificationsPlugin();

const NotificationDetails kDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'hourly_clock',
    'تنبيه كل ساعة',
    channelDescription: 'إشعار عند بداية كل ساعة',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(),
);

Future<void> initNotifications() async {
  try {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await notif.initialize(settings);
    await notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await notif
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } catch (_) {}
}

String hourLabel(int h, bool use24) {
  if (use24) return '${two(h)}:00';
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '${two(hh)}:00 ${h < 12 ? 'ص' : 'م'}';
}

Future<void> scheduleHourly(Cfg c) async {
  try {
    await notif.cancelAll();
    if (!c.hourly) return;
    final now = DateTime.now();
    for (int h = 0; h < 24; h++) {
      if (h < c.from || h > c.to) continue;
      var t = DateTime(now.year, now.month, now.day, h);
      if (!t.isAfter(now)) t = DateTime(now.year, now.month, now.day + 1, h);
      // نجدول بتوقيت UTC مع تكرار يومي لنفس الوقت
      final when = tz.TZDateTime.from(t, tz.UTC);
      await notif.zonedSchedule(
        h,
        '⏰ ${hourLabel(h, c.use24)}',
        'بدأت ساعة جديدة، ${dateText(t)}',
        when,
        kDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  final sp = await SharedPreferences.getInstance();
  runApp(ClockApp(sp: sp));
}

class ClockApp extends StatelessWidget {
  final SharedPreferences sp;
  const ClockApp({super.key, required this.sp});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الساعة الذكية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F1A),
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.cyan, brightness: Brightness.dark),
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: HomePage(sp: sp),
    );
  }
}

// ---------------------------------------------------------------------------
// الصفحة الرئيسية
// ---------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  final SharedPreferences sp;
  const HomePage({super.key, required this.sp});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Cfg cfg;
  late PageController pc;
  final ValueNotifier<DateTime> now = ValueNotifier(DateTime.now());
  Timer? timer;

  @override
  void initState() {
    super.initState();
    cfg = Cfg.load(widget.sp);
    pc = PageController(initialPage: cfg.model);
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      now.value = DateTime.now();
    });
    scheduleHourly(cfg);
  }

  @override
  void dispose() {
    timer?.cancel();
    pc.dispose();
    now.dispose();
    super.dispose();
  }

  Future<void> apply() async {
    await cfg.save(widget.sp);
    await scheduleHourly(cfg);
    if (mounted) setState(() {});
  }

  Widget face(int i, DateTime t) {
    Widget w;
    switch (i) {
      case 0:
        w = DigitalFace(t: t, use24: cfg.use24);
        break;
      case 1:
        w = AnalogFace(t: t, classic: true, use24: cfg.use24);
        break;
      case 2:
        w = RingsFace(t: t, use24: cfg.use24);
        break;
      case 3:
        w = BinaryFace(t: t);
        break;
      case 4:
        w = FlipFace(t: t, use24: cfg.use24);
        break;
      default:
        w = AnalogFace(t: t, classic: false, use24: cfg.use24);
    }
    return Directionality(textDirection: TextDirection.ltr, child: w);
  }

  void openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void change(VoidCallback f) {
            setSheet(f);
            setState(() {});
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الإعدادات',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SwitchListTile(
                  title: const Text('إشعار عند بداية كل ساعة'),
                  value: cfg.hourly,
                  onChanged: (v) {
                    change(() => cfg.hourly = v);
                    apply();
                  },
                ),
                Text(
                    'وقت التنبيه: من ${hourLabel(cfg.from, true)} إلى ${hourLabel(cfg.to, true)}'),
                RangeSlider(
                  min: 0,
                  max: 23,
                  divisions: 23,
                  values: RangeValues(cfg.from.toDouble(), cfg.to.toDouble()),
                  labels: RangeLabels('${cfg.from}', '${cfg.to}'),
                  onChanged: cfg.hourly
                      ? (v) => change(() {
                            cfg.from = v.start.round();
                            cfg.to = v.end.round();
                          })
                      : null,
                  onChangeEnd: (_) => apply(),
                ),
                SwitchListTile(
                  title: const Text('نظام 24 ساعة'),
                  value: cfg.use24,
                  onChanged: (v) {
                    change(() => cfg.use24 = v);
                    apply();
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('إرسال إشعار تجريبي'),
                    onPressed: () async {
                      try {
                        await notif.show(
                            999,
                            '⏰ ${hourLabel(DateTime.now().hour, cfg.use24)}',
                            'هذا إشعار تجريبي',
                            kDetails);
                      } catch (_) {}
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'تنبيه كل ساعة',
                    icon: Icon(
                        cfg.hourly
                            ? Icons.notifications_active
                            : Icons.notifications_off_outlined,
                        color: cfg.hourly ? Colors.cyanAccent : Colors.grey),
                    onPressed: () {
                      cfg.hourly = !cfg.hourly;
                      apply();
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text(faceNames[cfg.model],
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: openSettings),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pc,
                itemCount: faceNames.length,
                onPageChanged: (i) {
                  cfg.model = i;
                  apply();
                },
                itemBuilder: (_, i) => ValueListenableBuilder<DateTime>(
                  valueListenable: now,
                  builder: (_, t, __) => face(i, t),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < faceNames.length; i++)
                  GestureDetector(
                    onTap: () => pc.animateToPage(i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: cfg.model == i ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cfg.model == i
                            ? Colors.cyanAccent
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1) نيون رقمي
// ---------------------------------------------------------------------------
class DigitalFace extends StatelessWidget {
  final DateTime t;
  final bool use24;
  const DigitalFace({super.key, required this.t, required this.use24});

  @override
  Widget build(BuildContext context) {
    final p = TP(t, use24);
    const neon = Color(0xFF00E5FF);
    final dayProgress =
        (t.hour * 3600 + t.minute * 60 + t.second) / 86400.0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${p.h}:${p.m}',
                    style: const TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w300,
                      color: neon,
                      fontFeatures: [FontFeature.tabularFigures()],
                      shadows: [Shadow(color: neon, blurRadius: 28)],
                    )),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.suffix,
                          style: const TextStyle(fontSize: 20, color: neon)),
                      Text(p.s,
                          style: const TextStyle(
                              fontSize: 34,
                              color: Colors.white70,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(dateText(t),
              style: const TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: dayProgress,
                minHeight: 8,
                color: neon,
                backgroundColor: Colors.white12),
          ),
          const SizedBox(height: 6),
          Text('مضى ${(dayProgress * 100).toStringAsFixed(1)}% من اليوم',
              style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 و 6) ساعة عقارب (كلاسيكية / عصرية)
// ---------------------------------------------------------------------------
class AnalogFace extends StatelessWidget {
  final DateTime t;
  final bool classic;
  final bool use24;
  const AnalogFace(
      {super.key, required this.t, required this.classic, required this.use24});

  @override
  Widget build(BuildContext context) {
    final p = TP(t, use24);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: AnalogPainter(t, classic)),
          ),
        ),
        Text('${p.h}:${p.m}:${p.s} ${p.suffix}',
            style: const TextStyle(
                fontSize: 26,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        Text(dateText(t), style: const TextStyle(color: Colors.white60)),
      ],
    );
  }
}

class AnalogPainter extends CustomPainter {
  final DateTime t;
  final bool classic;
  AnalogPainter(this.t, this.classic);

  Offset dir(double frac) {
    final a = frac * 2 * math.pi - math.pi / 2;
    return Offset(math.cos(a), math.sin(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 4;

    // الوجه
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            classic ? const Color(0xFF1B2540) : const Color(0xFF141A2B),
            const Color(0xFF0B0F1A),
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = classic ? 6 : 2
          ..color = classic ? const Color(0xFFD4AF37) : Colors.cyanAccent);

    // العلامات
    for (int i = 0; i < 60; i++) {
      final isHour = i % 5 == 0;
      if (!classic && !isHour) continue;
      final d = dir(i / 60);
      final p1 = c + d * (r - (isHour ? 18 : 9));
      final p2 = c + d * (r - 4);
      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..strokeWidth = isHour ? 3 : 1
            ..strokeCap = StrokeCap.round
            ..color = isHour ? Colors.white : Colors.white54);
    }

    // الأرقام
    if (classic) {
      for (int n = 1; n <= 12; n++) {
        final tp = TextPainter(
          text: TextSpan(
              text: '$n',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout();
        final pos = c + dir(n / 12) * (r - 40);
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // العقارب
    final sec = t.second + t.millisecond / 1000;
    final min = t.minute + sec / 60;
    final hr = (t.hour % 12) + min / 60;

    void hand(double frac, double len, double w, Color col, {double tail = 0}) {
      final d = dir(frac);
      canvas.drawLine(
          c - d * tail,
          c + d * len,
          Paint()
            ..strokeWidth = w
            ..strokeCap = StrokeCap.round
            ..color = col);
    }

    final handColor = classic ? Colors.white : Colors.white;
    hand(hr / 12, r * 0.5, classic ? 8 : 6, handColor);
    hand(min / 60, r * 0.75, classic ? 5 : 4, handColor);
    hand(sec / 60, r * 0.85, 2, classic ? const Color(0xFFFF5252) : Colors.cyanAccent,
        tail: 18);
    canvas.drawCircle(c, 7, Paint()..color = classic ? const Color(0xFFFF5252) : Colors.cyanAccent);
    canvas.drawCircle(c, 3, Paint()..color = const Color(0xFF0B0F1A));
  }

  @override
  bool shouldRepaint(covariant AnalogPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 3) حلقات
// ---------------------------------------------------------------------------
class RingsFace extends StatelessWidget {
  final DateTime t;
  final bool use24;
  const RingsFace({super.key, required this.t, required this.use24});

  @override
  Widget build(BuildContext context) {
    final p = TP(t, use24);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: RingsPainter(t),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${p.h}:${p.m}',
                        style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w300,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    Text('${p.s} ${p.suffix}',
                        style: const TextStyle(
                            fontSize: 20, color: Colors.white60)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(dateText(t), style: const TextStyle(color: Colors.white60)),
      ],
    );
  }
}

class RingsPainter extends CustomPainter {
  final DateTime t;
  RingsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final sec = t.second + t.millisecond / 1000;
    final min = t.minute + sec / 60;
    final hr = (t.hour % 12) + min / 60;
    final data = [
      [hr / 12, const Color(0xFFFF4081), r - 10],
      [min / 60, const Color(0xFF00E676), r - 36],
      [sec / 60, const Color(0xFF00E5FF), r - 62],
    ];
    for (final d in data) {
      final rad = d[2] as double;
      final rect = Rect.fromCircle(center: c, radius: rad);
      canvas.drawArc(
          rect,
          0,
          2 * math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16
            ..color = Colors.white10);
      canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * (d[0] as double),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16
            ..strokeCap = StrokeCap.round
            ..color = d[1] as Color);
    }
  }

  @override
  bool shouldRepaint(covariant RingsPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 4) ثنائية (BCD)
// ---------------------------------------------------------------------------
class BinaryFace extends StatelessWidget {
  final DateTime t;
  const BinaryFace({super.key, required this.t});

  Widget col(int digit, int bits, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int b = 3; b >= 0; b--)
          Container(
            margin: const EdgeInsets.all(5),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: b >= bits
                  ? Colors.transparent
                  : ((digit >> b) & 1 == 1 ? color : Colors.white10),
              boxShadow: (b < bits && (digit >> b) & 1 == 1)
                  ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 12)]
                  : null,
            ),
          ),
        const SizedBox(height: 6),
        Text('$digit',
            style: const TextStyle(fontSize: 18, color: Colors.white70)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = t.hour, m = t.minute, s = t.second;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            col(h ~/ 10, 2, const Color(0xFFFF4081)),
            col(h % 10, 4, const Color(0xFFFF4081)),
            const SizedBox(width: 16),
            col(m ~/ 10, 3, const Color(0xFF00E676)),
            col(m % 10, 4, const Color(0xFF00E676)),
            const SizedBox(width: 16),
            col(s ~/ 10, 3, const Color(0xFF00E5FF)),
            col(s % 10, 4, const Color(0xFF00E5FF)),
          ],
        ),
        const SizedBox(height: 20),
        Text('${two(h)}:${two(m)}:${two(s)}',
            style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        Text(dateText(t), style: const TextStyle(color: Colors.white60)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5) قلاب
// ---------------------------------------------------------------------------
class FlipFace extends StatelessWidget {
  final DateTime t;
  final bool use24;
  const FlipFace({super.key, required this.t, required this.use24});

  Widget card(String d, {double w = 52, double h = 82, double fs = 54}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (c, a) => ScaleTransition(
          scale: a, child: FadeTransition(opacity: a, child: c)),
      child: Container(
        key: ValueKey(d),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2433),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(d,
                style: TextStyle(
                    fontSize: fs,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Container(height: 2, color: Colors.black87),
          ],
        ),
      ),
    );
  }

  Widget pair(String s, {double w = 52, double h = 82, double fs = 54}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        card(s[0], w: w, h: h, fs: fs),
        card(s[1], w: w, h: h, fs: fs),
      ]);

  @override
  Widget build(BuildContext context) {
    final p = TP(t, use24);
    const dots = Text(':',
        style: TextStyle(fontSize: 40, color: Colors.white54));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                pair(p.h),
                dots,
                pair(p.m),
                dots,
                pair(p.s, w: 34, h: 54, fs: 34),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (p.suffix.isNotEmpty)
          Text(p.suffix,
              style: const TextStyle(fontSize: 22, color: Colors.white70)),
        const SizedBox(height: 8),
        Text(dateText(t), style: const TextStyle(color: Colors.white60)),
      ],
    );
  }
}