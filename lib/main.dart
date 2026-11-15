import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const appChannel = MethodChannel('adm/app');
const bg = Color(0xFF070B14);
const panel = Color(0xFF111827);
const panel2 = Color(0xFF182338);
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
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark)
        .copyWith(primary: cyan, secondary: violet, surface: panel);
    return MaterialApp(
      title: 'ADM - Browser & Download Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: bg,
        cardColor: panel,
        dividerColor: Colors.white.withValues(alpha: 0.08),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel2,
          hintStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: cyan, width: 1.2),
          ),
        ),
      ),
      home: const AdmShell(),
    );
  }
}

class AdmShell extends StatefulWidget {
  const AdmShell({super.key});
  @override
  State<AdmShell> createState() => _AdmShellState();
}

class _AdmShellState extends State<AdmShell> {
  final browserKey = GlobalKey<BrowserScreenState>();
  int section = 0;

  void openUrl(String url) {
    setState(() => section = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => browserKey.currentState?.openUrl(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: section,
        children: [
          BrowserScreen(key: browserKey, onOpenDownloads: () => setState(() => section = 1)),
          const DownloadsScreen(),
          LibraryScreen(onOpenUrl: openUrl),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: const Color(0xFF0B1220),
        indicatorColor: cyan.withValues(alpha: 0.13),
        selectedIndex: section,
        onDestinationSelected: (value) => setState(() => section = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.public_outlined), selectedIcon: Icon(Icons.public, color: cyan), label: 'Navegador'),
          NavigationDestination(icon: Icon(Icons.downloading_outlined), selectedIcon: Icon(Icons.downloading, color: cyan), label: 'Downloads'),
          NavigationDestination(icon: Icon(Icons.bookmarks_outlined), selectedIcon: Icon(Icons.bookmarks, color: cyan), label: 'Biblioteca'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune, color: cyan), label: 'Definições'),
        ],
      ),
    );
  }
}

class BrowserTab {
  BrowserTab(this.id);
  final int id;
  String url = 'https://www.google.com';
  String title = 'Novo separador';
  int progress = 0;
  bool loading = true;
  bool canGoBack = false;
  bool canGoForward = false;
  String savedHistoryUrl = '';
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.onOpenDownloads});
  final VoidCallback onOpenDownloads;
  @override
  State<BrowserScreen> createState() => BrowserScreenState();
}

class BrowserScreenState extends State<BrowserScreen> {
  final address = TextEditingController();
  final addressFocus = FocusNode();
  final channels = <int, MethodChannel>{};
  final tabs = <BrowserTab>[];
  int nextId = 1;
  int activeId = 0;

  BrowserTab get active => tabs.firstWhere((tab) => tab.id == activeId);

  @override
  void initState() {
    super.initState();
    _addTab();
  }

  @override
  void dispose() {
    address.dispose();
    addressFocus.dispose();
    for (final channel in channels.values) {
      channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  void _addTab() {
    final tab = BrowserTab(nextId++);
    setState(() {
      tabs.add(tab);
      activeId = tab.id;
      address.text = tab.url;
    });
  }

  void _selectTab(int id) {
    setState(() {
      activeId = id;
      address.text = active.url;
    });
  }

  void _closeTab(int id) {
    if (tabs.length == 1) {
      final tab = active;
      setState(() {
        tab.url = 'https://www.google.com';
        tab.title = 'Novo separador';
        tab.loading = true;
        tab.progress = 0;
        address.text = tab.url;
      });
      channels[id]?.invokeMethod<void>('loadUrl', {'url': tab.url});
      return;
    }
    channels.remove(id)?.setMethodCallHandler(null);
    setState(() {
      final index = tabs.indexWhere((tab) => tab.id == id);
      tabs.removeWhere((tab) => tab.id == id);
      if (activeId == id) {
        activeId = tabs[(index - 1).clamp(0, tabs.length - 1)].id;
        address.text = active.url;
      }
    });
  }

  String _normalise(String input) {
    final value = input.trim();
    if (value.isEmpty) return 'https://www.google.com';
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
      return value;
    }
    if (!value.contains(' ') && value.contains('.') && !value.startsWith('.')) {
      return 'https://' + value;
    }
    return 'https://www.google.com/search?q=' + Uri.encodeQueryComponent(value);
  }

  Future<void> _navigate(String input) async {
    final url = _normalise(input);
    addressFocus.unfocus();
    setState(() {
      active.url = url;
      active.loading = true;
      active.progress = 0;
      address.text = url;
    });
    try {
      await channels[activeId]?.invokeMethod<void>('loadUrl', {'url': url});
    } on PlatformException {
      // The native view may still be initialising.
    }
  }

  void openUrl(String url) => _navigate(url);

  Future<void> _command(String method) async {
    try {
      await channels[activeId]?.invokeMethod<void>(method);
    } on PlatformException {
      // Ignore actions while a native view is being recreated.
    }
  }

  void _onNativeReady(int tabId, MethodChannel channel) {
    channels[tabId] = channel;
  }

  void _onPageState(int tabId, Map<String, dynamic> state) {
    if (!mounted) return;
    final index = tabs.indexWhere((tab) => tab.id == tabId);
    if (index < 0) return;
    final tab = tabs[index];
    final url = state['url'] as String? ?? tab.url;
    final title = state['title'] as String? ?? tab.title;
    final loading = state['loading'] as bool? ?? false;

    setState(() {
      tab.url = url;
      tab.title = title.isEmpty ? 'Página sem título' : title;
      tab.progress = (state['progress'] as num?)?.toInt() ?? tab.progress;
      tab.loading = loading;
      tab.canGoBack = state['canGoBack'] as bool? ?? false;
      tab.canGoForward = state['canGoForward'] as bool? ?? false;
      if (tabId == activeId && !addressFocus.hasFocus) address.text = url;
    });

    if (!loading && url.startsWith('http') && url.isNotEmpty && url != tab.savedHistoryUrl) {
      tab.savedHistoryUrl = url;
      appChannel.invokeMethod<void>('saveHistory', {'url': url, 'title': tab.title}).catchError((_) {});
    }
  }

  Future<void> _bookmark() async {
    final tab = active;
    if (!tab.url.startsWith('http')) return;
    try {
      await appChannel.invokeMethod<void>('addBookmark', {'url': tab.url, 'title': tab.title});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Página guardada nos favoritos')));
      }
    } on PlatformException {
      // Native persistence is provided by the Android host.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = active;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [cyan, violet], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [BoxShadow(color: cyan.withValues(alpha: 0.16), blurRadius: 18)],
                  ),
                  child: const Icon(Icons.bolt_rounded, color: bg, size: 25),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ADM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
                      Text('BROWSER  •  DOWNLOAD CORE',
                          style: TextStyle(fontSize: 9, color: muted, letterSpacing: 1.15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Downloads', onPressed: widget.onOpenDownloads, icon: const Icon(Icons.downloading_rounded)),
                IconButton(tooltip: 'Novo separador', onPressed: _addTab, icon: const Icon(Icons.add_box_outlined)),
                Text(tabs.length.toString(), style: const TextStyle(color: muted, fontWeight: FontWeight.w700)),
                const SizedBox(width: 5),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: address,
                    focusNode: addressFocus,
                    textInputAction: TextInputAction.go,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onSubmitted: _navigate,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar ou introduzir endereço',
                      prefixIcon: const Icon(Icons.search_rounded, color: cyan),
                      suffixIcon: IconButton(
                        tooltip: 'Abrir endereço',
                        onPressed: () => _navigate(address.text),
                        icon: const Icon(Icons.arrow_forward_rounded, color: cyan),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: panel2,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _closeTab(activeId),
                    child: const SizedBox(width: 47, height: 49, child: Icon(Icons.close_rounded, color: muted)),
                  ),
                ),
              ],
            ),
          ),
          if (tabs.length > 1)
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final item = tabs[index];
                  final selected = item.id == activeId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectTab(item.id),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: selected ? cyan.withValues(alpha: 0.12) : panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? cyan.withValues(alpha: 0.55) : Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, size: 14, color: selected ? cyan : muted),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: selected ? Colors.white : muted,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (tab.loading)
            LinearProgressIndicator(
              value: tab.progress >= 100 ? null : tab.progress / 100,
              minHeight: 2,
              backgroundColor: panel,
              color: cyan,
            )
          else
            const SizedBox(height: 2),
          Expanded(
            child: IndexedStack(
              index: tabs.indexWhere((item) => item.id == activeId),
              children: tabs.map((item) => BrowserPane(
                key: ValueKey(item.id),
                tab: item,
                onChannelReady: (channel) => _onNativeReady(item.id, channel),
                onPageState: (state) => _onPageState(item.id, state),
              )).toList(),
            ),
          ),
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BrowserAction(icon: Icons.arrow_back_ios_new_rounded, enabled: tab.canGoBack, onTap: () => _command('goBack')),
                _BrowserAction(icon: Icons.arrow_forward_ios_rounded, enabled: tab.canGoForward, onTap: () => _command('goForward')),
                _BrowserAction(icon: tab.loading ? Icons.close_rounded : Icons.refresh_rounded,
                    enabled: true, onTap: () => _command(tab.loading ? 'stopLoading' : 'reload')),
                _BrowserAction(icon: Icons.bookmark_add_outlined, enabled: true, onTap: _bookmark, accent: true),
                _BrowserAction(icon: Icons.home_outlined, enabled: true, onTap: () => _navigate('https://www.google.com')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BrowserPane extends StatefulWidget {
  const BrowserPane({
    super.key,
    required this.tab,
    required this.onChannelReady,
    required this.onPageState,
  });
  final BrowserTab tab;
  final ValueChanged<MethodChannel> onChannelReady;
  final ValueChanged<Map<String, dynamic>> onPageState;

  @override
  State<BrowserPane> createState() => _BrowserPaneState();
}

class _BrowserPaneState extends State<BrowserPane> {
  MethodChannel? channel;

  void _onPlatformViewCreated(int viewId) {
    final nativeChannel = MethodChannel('adm/webview/' + viewId.toString());
    channel = nativeChannel;
    nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'pageState' && call.arguments is Map) {
        widget.onPageState(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
    widget.onChannelReady(nativeChannel);
    nativeChannel.invokeMethod<Map<dynamic, dynamic>>('getState').then((state) {
      if (state != null && mounted) widget.onPageState(Map<String, dynamic>.from(state));
    }).catchError((_) {});
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'adm/webview',
      creationParams: {'initialUrl': widget.tab.url},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}

class _BrowserAction extends StatelessWidget {
  const _BrowserAction({required this.icon, required this.enabled, required this.onTap, this.accent = false});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      tooltip: 'Ação do navegador',
      icon: Icon(icon, size: 21,
          color: enabled ? (accent ? cyan : Colors.white) : muted.withValues(alpha: 0.35)),
    );
  }
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  Timer? timer;
  List<Map<String, dynamic>> downloads = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final raw = await appChannel.invokeListMethod<dynamic>('getDownloads') ?? [];
      if (!mounted) return;
      setState(() {
        downloads = raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        loading = false;
        error = null;
      });
    } on PlatformException catch (exception) {
      if (mounted) setState(() { loading = false; error = exception.message ?? 'Não foi possível ler as transferências.'; });
    }
  }

  Future<void> _remove(int id) async {
    try {
      await appChannel.invokeMethod<void>('removeDownload', {'id': id});
      await _refresh();
    } on PlatformException {}
  }

  Future<void> _openSystemDownloads() async {
    try {
      await appChannel.invokeMethod<void>('openSystemDownloads');
    } on PlatformException {}
  }

  String _status(int value) {
    switch (value) {
      case 1: return 'Na fila';
      case 2: return 'A transferir';
      case 4: return 'Em pausa pelo sistema';
      case 8: return 'Concluído';
      case 16: return 'Falhou';
      default: return 'A verificar';
    }
  }

  String _size(num bytes) {
    if (bytes < 0) return 'Tamanho desconhecido';
    if (bytes < 1024) return bytes.toStringAsFixed(0) + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toStringAsFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';
    return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2) + ' GB';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: cyan,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Row(
                  children: [
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Centro de transferências', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                      SizedBox(height: 5),
                      Text('Acompanha os ficheiros recebidos pelo Android', style: TextStyle(fontSize: 12, color: muted)),
                    ])),
                    IconButton(tooltip: 'Gestor de downloads do Android', onPressed: _openSystemDownloads,
                        icon: const Icon(Icons.open_in_new_rounded, color: cyan)),
                  ],
                ),
              ),
            ),
            if (loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: cyan)))
            else if (error != null)
              SliverFillRemaining(hasScrollBody: false,
                  child: _EmptyState(icon: Icons.cloud_off_outlined, title: 'Downloads indisponíveis', subtitle: error!))
            else if (downloads.isEmpty)
              const SliverFillRemaining(hasScrollBody: false,
                  child: _EmptyState(icon: Icons.download_for_offline_outlined, title: 'Ainda sem transferências',
                      subtitle: 'Quando descarregares um ficheiro no navegador, ele aparecerá aqui.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: downloads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = downloads[index];
                    final id = (item['id'] as num).toInt();
                    final status = (item['status'] as num?)?.toInt() ?? 0;
                    final downloaded = (item['downloaded'] as num?) ?? 0;
                    final total = (item['total'] as num?) ?? -1;
                    final progress = total > 0 ? (downloaded / total).clamp(0.0, 1.0) : null;
                    final completed = status == 8;
                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 42, height: 42,
                              decoration: BoxDecoration(color: cyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
                              child: const Icon(Icons.insert_drive_file_outlined, color: cyan)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item['title'] as String? ?? 'Ficheiro sem nome', maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_status(status), style: TextStyle(color: completed ? cyan : muted, fontSize: 11)),
                          ])),
                          IconButton(onPressed: () => _remove(id), tooltip: 'Remover registo',
                              icon: const Icon(Icons.delete_outline, color: muted)),
                        ]),
                        const SizedBox(height: 13),
                        LinearProgressIndicator(value: progress, minHeight: 5,
                            borderRadius: BorderRadius.circular(10),
                            backgroundColor: Colors.white.withValues(alpha: 0.07),
                            color: completed ? const Color(0xFF34D399) : cyan),
                        const SizedBox(height: 8),
                        Row(children: [
                          Text(_size(downloaded), style: const TextStyle(color: muted, fontSize: 11)),
                          const Spacer(),
                          Text(total > 0 ? _size(total) : '—', style: const TextStyle(color: muted, fontSize: 11)),
                        ]),
                      ]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.onOpenUrl});
  final ValueChanged<String> onOpenUrl;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool showBookmarks = true;
  bool loading = true;
  List<Map<String, dynamic>> bookmarks = [];
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rawBookmarks = await appChannel.invokeListMethod<dynamic>('getBookmarks') ?? [];
      final rawHistory = await appChannel.invokeListMethod<dynamic>('getHistory') ?? [];
      if (!mounted) return;
      setState(() {
        bookmarks = rawBookmarks.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        history = rawHistory.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        loading = false;
      });
    } on PlatformException {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _removeBookmark(String url) async {
    await appChannel.invokeMethod<void>('removeBookmark', {'url': url});
    await _load();
  }

  Future<void> _clearHistory() async {
    await appChannel.invokeMethod<void>('clearHistory');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final entries = showBookmarks ? bookmarks : history;
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Row(children: [
            const Expanded(child: Text('Biblioteca', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
            if (!showBookmarks && history.isNotEmpty)
              TextButton.icon(onPressed: _clearHistory, icon: const Icon(Icons.delete_sweep_outlined, size: 18), label: const Text('Limpar')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Favoritos'), icon: Icon(Icons.bookmark_outline)),
              ButtonSegment(value: false, label: Text('Histórico'), icon: Icon(Icons.history)),
            ],
            selected: {showBookmarks},
            onSelectionChanged: (selection) { setState(() => showBookmarks = selection.first); _load(); },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: cyan))
              : entries.isEmpty
                  ? _EmptyState(
                      icon: showBookmarks ? Icons.bookmark_border : Icons.history,
                      title: showBookmarks ? 'Sem favoritos guardados' : 'Histórico vazio',
                      subtitle: showBookmarks ? 'Guarda páginas através do botão de favorito no navegador.' : 'As páginas visitadas aparecerão aqui.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = entries[index];
                        final url = item['url'] as String? ?? '';
                        return ListTile(
                          tileColor: panel,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          leading: const CircleAvatar(backgroundColor: Color(0xFF1B2940),
                              child: Icon(Icons.language, color: cyan)),
                          title: Text(item['title'] as String? ?? url, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => widget.onOpenUrl(url),
                          trailing: showBookmarks
                              ? IconButton(onPressed: () => _removeBookmark(url),
                                  icon: const Icon(Icons.close_rounded, color: muted))
                              : const Icon(Icons.chevron_right_rounded, color: muted),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
        children: const [
          Text('Definições', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          SizedBox(height: 5),
          Text('Configuração do navegador e do gestor de transferências', style: TextStyle(color: muted, fontSize: 12)),
          SizedBox(height: 20),
          SettingsTile(icon: Icons.search_rounded, title: 'Motor de pesquisa', subtitle: 'Google Search',
              trailing: Icon(Icons.check_circle, color: cyan, size: 19)),
          SettingsTile(icon: Icons.memory_rounded, title: 'Motor do navegador', subtitle: 'Android System WebView (baseado em Chromium)',
              trailing: Icon(Icons.verified_outlined, color: cyan, size: 19)),
          SettingsTile(icon: Icons.download_rounded, title: 'Destino das transferências', subtitle: 'Pasta pública Downloads do Android',
              trailing: Icon(Icons.folder_outlined, color: muted)),
          SettingsTile(icon: Icons.security_rounded, title: 'Segurança', subtitle: 'HTTPS, navegação segura e acesso local bloqueado',
              trailing: Icon(Icons.shield_outlined, color: cyan)),
          SizedBox(height: 18),
          _AboutCard(),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({super.key, required this.icon, required this.title, required this.subtitle, required this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
    child: ListTile(
      leading: Icon(icon, color: cyan),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
      trailing: trailing,
    ),
  );
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF14243A), Color(0xFF18152F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: cyan.withValues(alpha: 0.16)),
    ),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ADM', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 2)),
      SizedBox(height: 5),
      Text('Browser & Download Manager', style: TextStyle(color: muted)),
      SizedBox(height: 13),
      Text('Versão 1.0.0 • Núcleo Android + Flutter', style: TextStyle(color: muted, fontSize: 11)),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(34),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 74, height: 74,
          decoration: BoxDecoration(color: cyan.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(24)),
          child: Icon(icon, size: 34, color: cyan)),
        const SizedBox(height: 18),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.5, color: muted)),
      ]),
    ),
  );
}
