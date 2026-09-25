import 'package:flutter/material.dart';
import 'data/turneo_repository.dart';
import 'models/turneo_models.dart';
import 'auth/auth_gate.dart';

const inOffice = {'M', 'M12', 'MC', 'MN', 'N', 'FES', 'T', 'T5', 'TC'};

class TurneoApp extends StatefulWidget {
  const TurneoApp({super.key});
  @override
  State<TurneoApp> createState() => _TurneoAppState();
}

class _TurneoAppState extends State<TurneoApp> {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TURNEO',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFF080D14),
            cardColor: const Color(0xFF101823)),
        home: const AuthGate(),
      );
}

class CalendarScreen extends StatefulWidget {
  final TurneoRepository repository;
  final Future<void> Function() onLogout;
  const CalendarScreen(
      {super.key, required this.repository, required this.onLogout});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final repo = widget.repository;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<MonthData> data;
  int view = 0;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    data = repo.loadMonth(month);
  }

  void move(int n) {
    setState(() {
      month = DateTime(month.year, month.month + n);
      data = repo.loadMonth(month);
    });
  }

  Future<void> _editService(MonthData d, AppUser user, DateTime date) async {
    if (saving || !repo.canEdit(user.id)) return;
    try {
      final services = await repo.loadServices();
      if (!mounted) return;
      final picked = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .75,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${date.day}/${date.month} · ${user.name}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Flexible(
                        child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.8,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6),
                      itemCount: services.length,
                      itemBuilder: (context, i) {
                        final s = services[i];
                        return FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: d.serviceColor(s.code),
                              foregroundColor: d.serviceTextColor(s.code),
                              padding: const EdgeInsets.all(6)),
                          onPressed: () => Navigator.pop(context, s.code),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(s.code,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900)),
                                Text(s.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10))
                              ]),
                        );
                      },
                    )),
                    TextButton(
                        onPressed: () => Navigator.pop(context, '__CLEAR__'),
                        child: const Text('BORRAR SERVICIO')),
                  ]),
                ))),
      );
      if (picked == null) return;
      setState(() => saving = true);
      final saved = await repo.saveService(
          user.id, date, picked == '__CLEAR__' ? null : picked);
      if (mounted &&
          month.year == d.month.year &&
          month.month == d.month.month) {
        setState(
            () => data = Future.value(d.withAssignment(user.id, date, saved)));
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No se ha podido guardar o cargar el servicio. Comprueba la conexión y tus permisos.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('TURNEO',
                style:
                    TextStyle(fontWeight: FontWeight.w900, letterSpacing: .6)),
            centerTitle: true,
            actions: [
              IconButton(
                  tooltip: 'Actualizar mes',
                  onPressed: saving
                      ? null
                      : () => setState(() => data = repo.loadMonth(month)),
                  icon: const Icon(Icons.refresh)),
              IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: saving ? null : widget.onLogout,
                  icon: const Icon(Icons.logout))
            ]),
        body: FutureBuilder<MonthData>(
            future: data,
            builder: (context, s) {
              if (s.hasError)
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('No se ha podido cargar el mes.'),
                  TextButton(
                      onPressed: () =>
                          setState(() => data = repo.loadMonth(month)),
                      child: const Text('REINTENTAR'))
                ]));
              if (s.connectionState != ConnectionState.done || !s.hasData)
                return const Center(child: CircularProgressIndicator());
              final d = s.data!,
                  selected = view == 0
                      ? null
                      : (view - 1 < d.users.length ? d.users[view - 1] : null);
              return Column(children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(children: [
                      IconButton(
                          onPressed: saving ? null : () => move(-1),
                          icon: const Icon(Icons.chevron_left)),
                      Expanded(
                          child: Center(
                              child: Text(d.title,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)))),
                      IconButton(
                          onPressed: saving ? null : () => move(1),
                          icon: const Icon(Icons.chevron_right))
                    ])),
                SummaryCards(data: d, user: selected),
                Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 3),
                    child: Row(
                        children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                            .map((x) => Expanded(
                                child: Center(
                                    child: Text(x,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF9AA9BA))))))
                            .toList())),
                Expanded(
                    child: MonthGrid(
                        data: d,
                        user: selected,
                        onEdit: selected != null &&
                                repo.canEdit(selected.id) &&
                                !saving
                            ? (date) => _editService(d, selected, date)
                            : null)),
              ]);
            }),
        bottomNavigationBar: FutureBuilder<MonthData>(
            future: data,
            builder: (context, s) {
              final users = s.data?.users ?? [];
              if (users.isEmpty) return const SizedBox.shrink();
              final labels = [
                'GENERAL',
                ...users.map((u) => u.name.toUpperCase())
              ];
              return NavigationBar(
                  height: 66,
                  selectedIndex: view < labels.length ? view : 0,
                  onDestinationSelected:
                      saving ? null : (i) => setState(() => view = i),
                  destinations: [
                    for (int i = 0; i < labels.length; i++)
                      NavigationDestination(
                          icon: Icon(
                              i == 0
                                  ? Icons.grid_view_rounded
                                  : Icons.person_outline,
                              size: 20),
                          selectedIcon: Icon(
                              i == 0 ? Icons.grid_view_rounded : Icons.person,
                              size: 20),
                          label: labels[i])
                  ]);
            }),
      );
}

class SummaryCards extends StatelessWidget {
  final MonthData data;
  final AppUser? user;
  const SummaryCards({super.key, required this.data, this.user});
  @override
  Widget build(BuildContext context) {
    if (user == null) {
      final days = DateTime(data.month.year, data.month.month + 1, 0).day;
      final covered = <int>{};
      var assigned = 0;
      for (final e in data.assignments.entries) {
        if (e.value.isEmpty) continue;
        assigned++;
        if (inOffice.contains(e.value)) {
          final date = e.key.split('|').last;
          covered.add(int.parse(date.substring(8, 10)));
        }
      }
      final uncovered = [
        for (int d = 1; d <= days; d++)
          if (!covered.contains(d)) d
      ];
      return _cards([
        (
          'Festivos mensuales',
          '${data.holidays.length}',
          data.holidays.isEmpty
              ? 'Sin festivos'
              : data.holidays.entries
                  .map((e) =>
                      '${int.parse(e.key.substring(8, 10))} · ${e.value}')
                  .join(' · ')
        ),
        (
          'Días sin cubrir',
          '${uncovered.length}',
          uncovered.isEmpty
              ? 'Todos cubiertos'
              : 'Días: ${uncovered.join(', ')}'
        ),
        ('Servicios asignados', '$assigned', 'Total de asignaciones del mes'),
      ]);
    }
    final counts = <String, int>{};
    var work = 0, rest = 0;
    for (final e in data.assignments.entries) {
      if (!e.key.startsWith('${user!.id}|') || e.value.isEmpty) continue;
      counts[e.value] = (counts[e.value] ?? 0) + 1;
      if (inOffice.contains(e.value)) {
        work++;
      } else {
        rest++;
      }
    }
    String detail(bool office) => counts.entries
        .where((e) => inOffice.contains(e.key) == office)
        .map((e) => '${e.key} ${e.value}')
        .join(' · ');
    return _cards([
      (
        'Servicios',
        '$work',
        detail(true).isEmpty ? 'Sin servicios presenciales' : detail(true)
      ),
      (
        'Horas',
        counts.entries
            .fold<double>(
                0, (sum, e) => sum + (data.hours[e.key] ?? 0) * e.value)
            .toStringAsFixed(1),
        '${counts.values.fold<int>(0, (a, b) => a + b)} servicios · horas del catálogo'
      ),
      (
        'Descansos',
        '$rest',
        detail(false).isEmpty ? 'Sin descansos' : detail(false)
      )
    ]);
  }

  Widget _cards(List<(String, String, String)> values) => SizedBox(
      height: 104,
      child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          scrollDirection: Axis.horizontal,
          itemCount: values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final x = values[i];
            return InkWell(
                onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                            title: Text(x.$1),
                            content: SingleChildScrollView(
                                child: Text('${x.$2}\n\n${x.$3}')),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('CERRAR'))
                            ])),
                child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFF101823),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1D2A3A))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(x.$1,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9AA9BA),
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(x.$2,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w900)),
                          Text(x.$3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 9, color: Color(0xFF9AA9BA)))
                        ])));
          }));
}

class MonthGrid extends StatelessWidget {
  final MonthData data;
  final AppUser? user;
  final ValueChanged<DateTime>? onEdit;
  const MonthGrid({super.key, required this.data, this.user, this.onEdit});
  String initial(String uid) {
    final u = data.users.where((x) => x.id == uid);
    return u.isEmpty ? '?' : u.first.name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(data.month.year, data.month.month, 1),
        offset = first.weekday - 1,
        days = DateTime(data.month.year, data.month.month + 1, 0).day;
    final order =
        user == null ? data.users.map((u) => u.id).toList() : [user!.id];
    return GridView.builder(
        padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: user == null ? .57 : .82,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3),
        itemCount: offset + days,
        itemBuilder: (context, i) {
          if (i < offset) return const SizedBox.shrink();
          final day = i - offset + 1,
              date = DateTime(data.month.year, data.month.month, day),
              key =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
              holiday = data.holidays[key],
              today = DateUtils.isSameDay(date, DateTime.now());
          return InkWell(
              onTap: onEdit == null ? null : () => onEdit!(date),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: holiday != null
                          ? const Color(0xFF25151B)
                          : const Color(0xFF101823),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: today
                              ? const Color(0xFF4DA3FF)
                              : (holiday != null
                                  ? const Color(0xFF8B3349)
                                  : const Color(0xFF172334)),
                          width: today ? 1.8 : 1)),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('$day',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      if (today)
                        const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Text('HOY',
                                style: TextStyle(
                                    fontSize: 5,
                                    color: Color(0xFF4DA3FF),
                                    fontWeight: FontWeight.w900))),
                      if (holiday != null)
                        const Text(' •',
                            style: TextStyle(color: Colors.redAccent))
                    ]),
                    const SizedBox(height: 2),
                    for (final uid in order)
                      Expanded(
                          child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 1),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                  color: data.serviceColor(
                                      data.assignments['$uid|$key']),
                                  borderRadius: BorderRadius.circular(4)),
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text.rich(
                                      TextSpan(children: [
                                        if (user == null)
                                          TextSpan(
                                              text: '${initial(uid)} ',
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w500)),
                                        TextSpan(
                                            text:
                                                data.assignments['$uid|$key'] ??
                                                    '—',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900))
                                      ]),
                                      style: TextStyle(
                                          color: data.serviceTextColor(data
                                              .assignments['$uid|$key'])))))),
                  ])));
        });
  }
}
