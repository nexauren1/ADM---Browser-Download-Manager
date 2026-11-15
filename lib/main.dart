import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const native = MethodChannel('adm/app');
const bg = Color(0xFF070B14);
const card = Color(0xFF111827);
const field = Color(0xFF182338);
const cyan = Color(0xFF00E5FF);
const violet = Color(0xFF8B5CF6);
const muted = Color(0xFF91A0B8);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const AdmApp());
}

class AdmApp extends StatelessWidget {
  const AdmApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ADM - Browser & Download Manager',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark)
          .copyWith(primary: cyan, secondary: violet, surface: card),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: field, hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cyan),
        ),
      ),
    ),
    home: const AdmHome(),
  );
}

class AdmHome extends StatefulWidget {
  const AdmHome({super.key});
  @override
  State<AdmHome> createState() => _AdmHomeState();
}
class _AdmHomeState extends State<AdmHome> {
  int page = 0;
  bool searchMode = false;
  final search = TextEditingController();
  int refreshKey = 0;

  @override
  void dispose() { search.dispose(); super.dispose(); }

  void _page(int value) => setState(() { page = value; searchMode = false; search.clear(); });

  Future<void> _newDownload() async {
    final draft = await showDialog<_Draft>(context: context, builder: (_) => const AddDownloadDialog());
    if (draft == null) return;
    try {
      await native.invokeMethod<int>('enqueueDownload', {'url': draft.url, 'name': draft.name});
      if (!mounted) return;
      setState(() { page = 0; refreshKey++; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transferência adicionada à fila')));
    } on PlatformException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Não foi possível iniciar a transferência')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBrowser = page == 2;
    return Scaffold(
      appBar: isBrowser ? null : AppBar(
        leading: Builder(builder: (context) => IconButton(
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: cyan),
        )),
        title: searchMode && page < 2
            ? TextField(controller: search, autofocus: true,
                decoration: const InputDecoration(hintText: 'Pesquisar ficheiros', isDense: true),
                onChanged: (_) => setState(() => refreshKey++))
            : Text(page == 0 ? 'Fila' : page == 1 ? 'Concluídos' : 'Definições',
                style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (page < 2) ...[
            IconButton(onPressed: () => setState(() { searchMode = !searchMode; search.clear(); }),
              icon: Icon(searchMode ? Icons.close_rounded : Icons.search_rounded, color: cyan)),
            IconButton(onPressed: () => showDialog<void>(context: context,
              builder: (_) => const _InfoDialog(title: 'ADM Download Center',
                message: 'As transferências são executadas pelo serviço DownloadManager do Android. O sistema mantém os ficheiros em segundo plano e emite notificações de estado.')),
              icon: const Icon(Icons.help_outline_rounded)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_alt_outlined, color: cyan),
              onSelected: (_) => setState(() => refreshKey++),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'all', child: Text('Todas')),
                PopupMenuItem(value: 'active', child: Text('Em andamento')),
                PopupMenuItem(value: 'failed', child: Text('Com falha')),
              ],
            ),
          ],
        ],
      ),
      drawer: isBrowser ? null : _AdmDrawer(selected: page, onSelect: (value) {
        Navigator.pop(context);
        _page(value);
      }),
      body: switch (page) {
        0 => DownloadList(key: ValueKey('queue-' + refreshKey.toString()), completed: false, search: search.text),
        1 => DownloadList(key: ValueKey('done-' + refreshKey.toString()), completed: true, search: search.text),
        2 => BrowserScreen(onDownloads: () => _page(0)),
        _ => const SettingsHome(),
      },
      bottomNavigationBar: _BottomDock(page: page, onSelect: _page, onAdd: _newDownload),
    );
  }
}

class _AdmDrawer extends StatelessWidget {
  const _AdmDrawer({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: card,
    child: SafeArea(child: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 23),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF14243A), Color(0xFF20183D)])),
        child: const Row(children: [
          _LogoMark(), SizedBox(width: 13),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ADM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
            Text('NEXAUREN DOWNLOAD CORE', style: TextStyle(fontSize: 9, color: muted, letterSpacing: 1)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      _DrawerRow(Icons.downloading_rounded, 'Fila', selected == 0, () => onSelect(0)),
      _DrawerRow(Icons.task_alt_rounded, 'Concluídos', selected == 1, () => onSelect(1)),
      _DrawerRow(Icons.public_rounded, 'Navegador', selected == 2, () => onSelect(2)),
      _DrawerRow(Icons.tune_rounded, 'Definições', selected == 3, () => onSelect(3)),
      const Divider(height: 28),
      const Padding(padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
        child: Align(alignment: Alignment.centerLeft,
          child: Text('FERRAMENTAS', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800)))),
      _DrawerRow(Icons.folder_open_outlined, 'Pasta de downloads', false, () => onSelect(1)),
      const Spacer(),
      const Padding(padding: EdgeInsets.all(18),
        child: Text('NEXAUREN • ADM 1.0', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.2))),
    ])),
  );
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow(this.icon, this.label, this.selected, this.onTap);
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    child: ListTile(
      selected: selected, selectedTileColor: cyan.withValues(alpha: .1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: selected ? cyan : muted),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      onTap: onTap,
    ),
  );
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 45, height: 45,
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [cyan, violet]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: cyan.withValues(alpha: .18), blurRadius: 16)]),
    child: const Icon(Icons.bolt_rounded, color: bg, size: 28),
  );
}

class _BottomDock extends StatelessWidget {
  const _BottomDock({required this.page, required this.onSelect, required this.onAdd});
  final int page;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Container(
    height: 69,
    decoration: BoxDecoration(color: const Color(0xFF0B1220),
      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .07)))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _DockItem(Icons.power_settings_new_rounded, 'Serviço', false, () {
        showDialog<void>(context: context, builder: (_) => const _InfoDialog(
          title: 'Serviço de transferências',
          message: 'O Android mantém as transferências em segundo plano. A gestão de bateria e rede segue as regras do sistema.',
        ));
      }),
      _DockItem(Icons.settings_outlined, 'Definições', page == 3, () => onSelect(3)),
      _DockItem(Icons.language_rounded, 'Browser', page == 2, () => onSelect(2)),
      InkWell(onTap: onAdd, borderRadius: BorderRadius.circular(28),
        child: Container(width: 46, height: 46,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [cyan, violet]),
            boxShadow: [BoxShadow(color: cyan.withValues(alpha: .18), blurRadius: 15)]),
          child: const Icon(Icons.add_rounded, size: 30, color: bg))),
      _DockItem(Icons.play_circle_outline_rounded, 'Fila', page == 0, () => onSelect(0)),
      _DockItem(Icons.check_circle_outline_rounded, 'Concluídos', page == 1, () => onSelect(1)),
      _DockItem(Icons.view_list_rounded, 'Lista', page == 0, () => onSelect(0)),
    ]),
  );
}

class _DockItem extends StatelessWidget {
  const _DockItem(this.icon, this.label, this.selected, this.onTap);
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(12),
    child: SizedBox(width: 48, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 22, color: selected ? cyan : muted),
      const SizedBox(height: 3),
      Text(label, maxLines: 1, overflow: TextOverflow.clip,
        style: TextStyle(fontSize: 8, color: selected ? Colors.white : muted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
    ])),
  );
}

class _Download {
  const _Download(this.id, this.title, this.status, this.bytes, this.total);
  final int id, status, bytes, total;
  final String title;
  factory _Download.map(Map<dynamic, dynamic> data) => _Download(
    (data['id'] as num).toInt(),
    data['title'] as String? ?? 'Ficheiro sem nome',
    (data['status'] as num?)?.toInt() ?? 0,
    (data['downloaded'] as num?)?.toInt() ?? 0,
    (data['total'] as num?)?.toInt() ?? -1,
  );
  bool get complete => status == 8;
  String get state => switch (status) {
    1 => 'Na fila', 2 => 'A transferir', 4 => 'Em pausa pelo sistema',
    8 => 'Concluído', 16 => 'Falhou', _ => 'A verificar',
  };
  String get size => _size(bytes) + (total > 0 ? ' / ' + _size(total) : '');
  double? get progress => total > 0 ? (bytes / total).clamp(0.0, 1.0).toDouble() : null;
}

String _size(int bytes) {
  if (bytes < 0) return '—';
  if (bytes < 1024) return bytes.toString() + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toStringAsFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2) + ' GB';
}

class DownloadList extends StatefulWidget {
  const DownloadList({super.key, required this.completed, required this.search});
  final bool completed;
  final String search;
  @override
  State<DownloadList> createState() => _DownloadListState();
}
class _DownloadListState extends State<DownloadList> {
  Timer? timer;
  List<_Download> downloads = [];
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); _refresh(); timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh()); }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  Future<void> _refresh() async {
    try {
      final raw = await native.invokeListMethod<dynamic>('getDownloads') ?? [];
      if (!mounted) return;
      final all = raw.map((row) => _Download.map(Map<dynamic, dynamic>.from(row as Map))).toList();
      setState(() {
        downloads = all.where((d) => widget.completed ? d.complete : !d.complete).toList();
        loading = false; error = null;
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() { loading = false; error = e.message ?? 'Não foi possível consultar os downloads.'; });
    }
  }
  Future<void> _remove(int id) async {
    try { await native.invokeMethod<void>('removeDownload', {'id': id}); await _refresh(); } on PlatformException {}
  }
  Future<void> _open(int id) async {
    try { await native.invokeMethod<void>('openDownload', {'id': id}); }
    on PlatformException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Não foi possível abrir o ficheiro.')));
    }
  }
  @override
  Widget build(BuildContext context) {
    final needle = widget.search.trim().toLowerCase();
    final visible = downloads.where((d) => needle.isEmpty || d.title.toLowerCase().contains(needle)).toList();
    if (loading) return const Center(child: CircularProgressIndicator(color: cyan));
    if (error != null) return _Empty(icon: Icons.cloud_off_outlined, title: 'Downloads indisponíveis', text: error!);
    if (visible.isEmpty) return _Empty(
      icon: widget.completed ? Icons.task_alt_rounded : Icons.download_for_offline_outlined,
      title: widget.completed ? 'Ainda sem transferências concluídas' : 'A fila está vazia',
      text: widget.completed ? 'Os ficheiros concluídos aparecerão aqui.'
          : 'Toca no botão + para adicionar um link ou abre uma página e inicia um download.',
    );
    return RefreshIndicator(color: cyan, onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 18),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final d = visible[index];
          return _DownloadCard(item: d, onRemove: () => _remove(d.id), onOpen: () => _open(d.id));
        },
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.item, required this.onRemove, required this.onOpen});
  final _Download item;
  final VoidCallback onRemove, onOpen;
  @override
  Widget build(BuildContext context) {
    final typeIcon = item.title.toLowerCase().endsWith('.apk') ? Icons.android_rounded
      : item.title.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_outlined
      : Icons.insert_drive_file_outlined;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .055))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 45, height: 45,
            decoration: BoxDecoration(color: cyan.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
            child: Icon(typeIcon, color: cyan, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 5),
            Row(children: [
              Container(width: 6, height: 6,
                decoration: BoxDecoration(color: item.complete ? const Color(0xFF34D399)
                  : item.status == 16 ? const Color(0xFFFF6B6B) : cyan, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(item.state, style: const TextStyle(fontSize: 10, color: muted)),
            ]),
          ])),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: muted),
            onSelected: (v) { if (v == 'remove') onRemove(); if (v == 'open') onOpen(); },
            itemBuilder: (_) => [
              if (item.complete) const PopupMenuItem(value: 'open', child: Text('Abrir ficheiro')),
              const PopupMenuItem(value: 'remove', child: Text('Remover da lista')),
            ],
          ),
        ]),
        const SizedBox(height: 13),
        LinearProgressIndicator(value: item.progress, minHeight: 5, borderRadius: BorderRadius.circular(8),
          backgroundColor: Colors.white.withValues(alpha: .07),
          color: item.complete ? const Color(0xFF34D399) : item.status == 16 ? const Color(0xFFFF6B6B) : cyan),
        const SizedBox(height: 8),
        Row(children: [
          Text(item.size, style: const TextStyle(color: muted, fontSize: 10)),
          const Spacer(),
          if (item.complete) TextButton.icon(onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded, size: 15), label: const Text('Abrir')),
          if (!item.complete) const Text('Em segundo plano', style: TextStyle(color: muted, fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _Draft {
  const _Draft(this.url, this.name);
  final String url, name;
}
class AddDownloadDialog extends StatefulWidget {
  const AddDownloadDialog({super.key});
  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}
class _AddDownloadDialogState extends State<AddDownloadDialog> {
  final url = TextEditingController(), name = TextEditingController();
  @override
  void dispose() { url.dispose(); name.dispose(); super.dispose(); }
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => url.text = data!.text!.trim());
  }
  void _start() {
    final value = url.text.trim();
    final parsed = Uri.tryParse(value);
    if (parsed == null || !['https', 'http'].contains(parsed.scheme) || parsed.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Introduz um link HTTP ou HTTPS válido.')));
      return;
    }
    Navigator.pop(context, _Draft(value, name.text.trim()));
  }
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: card, insetPadding: const EdgeInsets.symmetric(horizontal: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    child: Padding(padding: const EdgeInsets.fromLTRB(21, 20, 21, 17),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Nova transferência', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          IconButton(onPressed: _paste, tooltip: 'Colar link', icon: const Icon(Icons.content_paste_rounded, color: cyan)),
        ]),
        const SizedBox(height: 16),
        TextField(controller: url, keyboardType: TextInputType.url, textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Link', hintText: 'https://exemplo.com/ficheiro.zip')),
        const SizedBox(height: 13),
        TextField(controller: name, textInputAction: TextInputAction.done, onSubmitted: (_) => _start(),
          decoration: const InputDecoration(labelText: 'Nome do ficheiro (opcional)', hintText: 'Detetado automaticamente')),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: _start, icon: const Icon(Icons.download_rounded),
            label: const Text('Iniciar'), style: FilledButton.styleFrom(backgroundColor: cyan, foregroundColor: bg)),
        ]),
      ]),
    ),
  );
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.onDownloads});
  final VoidCallback onDownloads;
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}
class _BrowserScreenState extends State<BrowserScreen> {
  final address = TextEditingController(text: 'https://www.google.com');
  final focus = FocusNode();
  MethodChannel? channel;
  bool loading = true, canBack = false, canForward = false;
  int progress = 0;
  @override
  void dispose() { address.dispose(); focus.dispose(); channel?.setMethodCallHandler(null); super.dispose(); }
  String _resolve(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'https://www.google.com';
    final uri = Uri.tryParse(value);
    if (uri != null && ['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty) return value;
    if (!value.contains(' ') && value.contains('.')) return 'https://' + value;
    return 'https://www.google.com/search?q=' + Uri.encodeQueryComponent(value);
  }
  Future<void> _navigate([String? input]) async {
    final destination = _resolve(input ?? address.text);
    address.text = destination; focus.unfocus();
    setState(() { loading = true; progress = 0; });
    try { await channel?.invokeMethod<void>('loadUrl', {'url': destination}); } on PlatformException {}
  }
  Future<void> _cmd(String method) async {
    try { await channel?.invokeMethod<void>(method); } on PlatformException {}
  }
  void _created(int id) {
    final current = MethodChannel('adm/webview/' + id.toString());
    channel = current;
    current.setMethodCallHandler((call) async {
      if (call.method == 'pageState' && call.arguments is Map) {
        final data = Map<dynamic, dynamic>.from(call.arguments as Map);
        if (!mounted) return;
        setState(() {
          address.text = data['url'] as String? ?? address.text;
          loading = data['loading'] as bool? ?? false;
          progress = (data['progress'] as num?)?.toInt() ?? progress;
          canBack = data['canGoBack'] as bool? ?? false;
          canForward = data['canGoForward'] as bool? ?? false;
        });
      }
    });
  }
  @override
  Widget build(BuildContext context) => SafeArea(bottom: false, child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(14, 9, 12, 8), child: Row(children: [
      const _LogoMark(), const SizedBox(width: 10),
      Expanded(child: TextField(controller: address, focusNode: focus, keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go, autocorrect: false, onSubmitted: _navigate,
        decoration: InputDecoration(hintText: 'Pesquisar ou introduzir endereço', isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, color: cyan),
          suffixIcon: IconButton(onPressed: () => _navigate(), icon: const Icon(Icons.arrow_forward_rounded, color: cyan))))),
      IconButton(onPressed: widget.onDownloads, tooltip: 'Transferências',
        icon: const Icon(Icons.downloading_rounded, color: cyan)),
    ])),
    if (loading) LinearProgressIndicator(value: progress == 0 || progress == 100 ? null : progress / 100,
      minHeight: 2, color: cyan, backgroundColor: card) else const SizedBox(height: 2),
    Expanded(child: AndroidView(viewType: 'adm/webview',
      creationParams: {'initialUrl': 'https://www.google.com'},
      creationParamsCodec: const StandardMessageCodec(), onPlatformViewCreated: _created)),
    Container(height: 54, color: const Color(0xFF0B1220),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        IconButton(onPressed: canBack ? () => _cmd('goBack') : null, icon: const Icon(Icons.arrow_back_ios_new_rounded)),
        IconButton(onPressed: canForward ? () => _cmd('goForward') : null, icon: const Icon(Icons.arrow_forward_ios_rounded)),
        IconButton(onPressed: () => _cmd(loading ? 'stopLoading' : 'reload'),
          icon: Icon(loading ? Icons.close_rounded : Icons.refresh_rounded)),
        IconButton(onPressed: () => _navigate('https://www.google.com'), icon: const Icon(Icons.home_outlined)),
      ])),
  ]));
}

class SettingsHome extends StatelessWidget {
  const SettingsHome({super.key});
  @override
  Widget build(BuildContext context) {
    final rows = [
      _Category(Icons.download_rounded, 'Transferências', 'Pasta de ficheiros • Wi-Fi • Motor', cyan, 'downloads'),
      _Category(Icons.swap_vert_rounded, 'Torrent', 'Suporte BitTorrent ainda não ativo', violet, 'torrent'),
      _Category(Icons.notifications_active_outlined, 'Notificações', 'Avisos do Android', const Color(0xFF60A5FA), 'notifications'),
      _Category(Icons.code_rounded, 'Automatização', 'Retentativas e ações automáticas', const Color(0xFFFB7185), 'automation'),
      _Category(Icons.folder_open_rounded, 'Classificar', 'APK • Vídeo • Música • Imagens • Documentos', const Color(0xFF2DD4BF), 'classify'),
      _Category(Icons.schedule_rounded, 'Agendar', 'Planeamento de transferências', const Color(0xFFF472B6), 'schedule'),
      _Category(Icons.layers_outlined, 'Janela superior', 'Painel flutuante de transferências', const Color(0xFFA78BFA), 'floating'),
      _Category(Icons.palette_outlined, 'Interface', 'Tema • Cores • Aparência', const Color(0xFFFBBF24), 'interface'),
      _Category(Icons.language_rounded, 'Navegador', 'Motor Chromium • Google Search', const Color(0xFF818CF8), 'browser'),
    ];
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(17, 19, 17, 25), children: [
      const Text('Definições', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Configura o ADM e os seus módulos', style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 18),
      for (final row in rows)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(
          color: card, borderRadius: BorderRadius.circular(17),
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingDetail(category: row))),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                Container(width: 43, height: 43,
                  decoration: BoxDecoration(color: row.color.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)),
                  child: Icon(row.icon, color: row.color, size: 22)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(row.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 10, height: 1.25)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: muted),
              ])),
          ),
        )),
      const SizedBox(height: 12),
      const Text('NEXAUREN • ADM BROWSER & DOWNLOAD MANAGER',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: muted, letterSpacing: 1)),
    ]));
  }
}

class _Category {
  const _Category(this.icon, this.title, this.subtitle, this.color, this.id);
  final IconData icon;
  final String title, subtitle, id;
  final Color color;
}

class SettingDetail extends StatefulWidget {
  const SettingDetail({super.key, required this.category});
  final _Category category;
  @override
  State<SettingDetail> createState() => _SettingDetailState();
}
class _SettingDetailState extends State<SettingDetail> {
  Map<String, dynamic> settings = {};
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final values = await native.invokeMapMethod<String, dynamic>('getSettings') ?? {};
      if (mounted) setState(() { settings = values; loading = false; });
    } on PlatformException { if (mounted) setState(() => loading = false); }
  }
  Future<void> _save(String key, bool value) async {
    setState(() => settings[key] = value);
    try { await native.invokeMethod<void>('setSetting', {'key': key, 'value': value}); } on PlatformException {}
  }
  Widget _head(String text) => Padding(padding: const EdgeInsets.fromLTRB(3, 18, 3, 9),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cyan, letterSpacing: 1)));
  Widget _later(String text) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: field, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded, color: violet, size: 20), const SizedBox(width: 10),
      Expanded(child: Text(text + ' depende do motor avançado de transferências. Será ligado numa fase seguinte; não altera os downloads atuais.',
        style: const TextStyle(color: muted, fontSize: 11, height: 1.4))),
    ]));
  @override
  Widget build(BuildContext context) {
    final id = widget.category.id;
    return Scaffold(appBar: AppBar(title: Text(widget.category.title, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: loading ? const Center(child: CircularProgressIndicator(color: cyan))
      : ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 25), children: [
        if (id == 'downloads') ...[
          _head('DESTINO'),
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(15)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pasta para ficheiros', style: TextStyle(color: muted, fontSize: 11)),
              SizedBox(height: 7),
              Text('Download/ADM', style: TextStyle(color: cyan, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Pasta pública de transferências do Android', style: TextStyle(color: muted, fontSize: 10)),
            ])),
          _head('REDE'),
          SwitchListTile(
            value: settings['wifiOnly'] as bool? ?? false,
            onChanged: (value) => _save('wifiOnly', value),
            activeThumbColor: cyan, contentPadding: const EdgeInsets.symmetric(horizontal: 3),
            title: const Text('Apenas através da Wi-Fi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            subtitle: const Text('Os novos downloads só usam Wi-Fi quando ativo.', style: TextStyle(color: muted, fontSize: 10)),
          ),
          _head('MOTOR AVANÇADO'),
          _later('Número simultâneo de transferências, partes por ficheiro, limite de velocidade, transferência inteligente e reinício automático'),
        ],
        if (id == 'torrent') ...[_head('BITTORRENT'), _later('Transferir torrents, transferência sequencial, semear torrents e pasta própria')],
        if (id == 'notifications') ...[
          _head('NOTIFICAÇÕES DO SISTEMA'),
          const Text('As notificações de progresso e conclusão são emitidas pelo DownloadManager do Android. Som, vibração e apresentação podem ser controlados nas definições de notificações do sistema.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
        ],
        if (id == 'automation') ...[_head('AUTOMATIZAÇÃO'), _later('Retentativas automáticas, iniciar/parar transferências, agendamento e encerramento após concluir')],
        if (id == 'classify') ...[
          _head('CATEGORIAS DE FICHEIROS'),
          for (final value in ['Aplicações APK', 'Vídeos', 'Música', 'Imagens', 'Documentos', 'Arquivos ZIP/RAR', 'Outros ficheiros'])
            ListTile(leading: const Icon(Icons.folder_outlined, color: cyan), title: Text(value, style: const TextStyle(fontSize: 13)),
              trailing: const Icon(Icons.chevron_right_rounded, color: muted)),
          _later('Classificação automática em pastas separadas'),
        ],
        if (id == 'schedule') ...[_head('AGENDAMENTO'), _later('Hora de início, hora de fim, dias da semana e agendamento por rede')],
        if (id == 'floating') ...[_head('JANELA SUPERIOR'), _later('Painel flutuante, transparência, cores e controlos sobre outras aplicações')],
        if (id == 'interface') ...[
          _head('APARÊNCIA'),
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(15)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tema Nexauren Cyber', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('Modo escuro • Ciano elétrico • Violeta', style: TextStyle(color: muted, fontSize: 11)),
              SizedBox(height: 14),
              Row(children: [_ColorDot(cyan), SizedBox(width: 8), _ColorDot(violet), SizedBox(width: 8), _ColorDot(bg)]),
            ])),
        ],
        if (id == 'browser') ...[
          _head('NAVEGADOR'),
          const ListTile(leading: Icon(Icons.memory_outlined, color: cyan),
            title: Text('Motor Chromium', style: TextStyle(fontSize: 13)),
            subtitle: Text('Android System WebView', style: TextStyle(color: muted, fontSize: 10))),
          const ListTile(leading: Icon(Icons.search_rounded, color: cyan),
            title: Text('Motor de pesquisa', style: TextStyle(fontSize: 13)),
            subtitle: Text('Google Search', style: TextStyle(color: muted, fontSize: 10))),
          _later('Limpeza de cache e gestão de privacidade por separador'),
        ],
      ]),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 23, height: 23,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white24)));
}
class _InfoDialog extends StatelessWidget {
  const _InfoDialog({required this.title, required this.message});
  final String title, message;
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: card, title: Text(title),
    content: Text(message, style: const TextStyle(color: muted, height: 1.45)),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
  );
}
class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
        decoration: BoxDecoration(color: cyan.withValues(alpha: .09), borderRadius: BorderRadius.circular(25)),
        child: Icon(icon, size: 36, color: cyan)),
      const SizedBox(height: 19),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.5, color: muted)),
    ])));
}
