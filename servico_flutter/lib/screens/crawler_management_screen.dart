// lib/screens/crawler_management_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../utils/theme.dart';
import '../router.dart';

class CrawlerManagementScreen extends StatefulWidget {
  final AdminService adminService;
  const CrawlerManagementScreen({super.key, required this.adminService});

  @override
  State<CrawlerManagementScreen> createState() => _CrawlerManagementScreenState();
}

class _CrawlerManagementScreenState extends State<CrawlerManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.iconColor, size: 20),
          onPressed: () => context.go(AppRoutes.admin),
        ),
        title: const Text('Web Crawler',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: AppTheme.divider),
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.accent,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: AppTheme.accent,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Links'),
                  Tab(text: 'Ações'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SelectionArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: TabBarView(
              controller: _tabController,
              children: [
                _LinksTab(adminService: widget.adminService),
                _ActionsTab(adminService: widget.adminService),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Aba Links ─────────────────────────────────────────────────────────────────

class _LinksTab extends StatefulWidget {
  final AdminService adminService;
  const _LinksTab({required this.adminService});

  @override
  State<_LinksTab> createState() => _LinksTabState();
}

class _LinksTabState extends State<_LinksTab> {
  static const int _pageSize = 20;
  int _skip = 0;
  List<CrawlerLink> _links = [];
  int _total = 0;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  String _statusFilter = '';

  LinksStatus? _status;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _urlFilter = '';

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadLinks(reset: true);
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _applySearch(_searchCtrl.text);
    });
  }

  void _applySearch(String value) {
    _debounce?.cancel();
    setState(() => _urlFilter = value);
    _loadLinks(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final s = await widget.adminService.getLinksStatus();
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  Future<void> _loadLinks({bool reset = false}) async {
    if (reset) {
      _skip = 0;
      _hasMore = true;
      _links = [];
    }
    if (!_hasMore || _loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final page = await widget.adminService.listLinks(
        limit: _pageSize, skip: _skip,
        status: _statusFilter.isEmpty ? null : _statusFilter,
        urlFilter: _urlFilter.isEmpty ? null : _urlFilter,
      );
      setState(() {
        if (reset) _links = page.links;
        else _links = [..._links, ...page.links];
        _total = page.total;
        _skip += page.links.length;
        _hasMore = page.links.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _confirmDelete(CrawlerLink link) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.divider)),
        title: const Text('Remover Link',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text(
          'Remover este link e sua página associada?\n\n${link.url}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.adminService.deleteLinkDirect(link.url);
                _loadLinks(reset: true);
                _loadStatus();
                if (mounted) _showSnack('Link removido');
              } catch (e) {
                if (mounted) _showSnack('Erro: $e', error: true);
              }
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : AppTheme.accent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status chips
        if (_status != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _StatChip('Total', _status!.total, AppTheme.textSecondary),
                const SizedBox(width: 8),
                _StatChip('Pendentes', _status!.pending, Colors.orange),
                const SizedBox(width: 8),
                _StatChip('OK', _status!.success, Colors.green),
                const SizedBox(width: 8),
                _StatChip('Erro', _status!.error, Colors.redAccent),
                const SizedBox(width: 6),
                _StatChip('Bloqueados', _status!.blocked, Colors.orange),
              ],
            ),
          ),

        // Filtro de status
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              const Text('Filtro:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 8),
              ..._buildFilterChips(),
              const Spacer(),
              Text('$_total links', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),

        // ── Campo de busca por URL ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _applySearch(v),
            decoration: InputDecoration(
              hintText: 'Buscar por URL...',
              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.iconColor, size: 18),
              suffixIcon: _urlFilter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.iconColor),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _urlFilter = '');
                        _loadLinks(reset: true);
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.bgCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) _loadLinks();
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _links.length + (_loading ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      if (i == _links.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                          ),
                        );
                      }
                      return _LinkTile(link: _links[i], onDelete: () => _confirmDelete(_links[i]));
                    },
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildFilterChips() {
    final options = [('', 'Todos'), ('pending', 'Pendentes'), ('success', 'OK'), ('error', 'Erro'), ('blocked', 'Bloqueados')];
    return options.map((o) {
      final selected = _statusFilter == o.$1;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () {
            setState(() => _statusFilter = o.$1);
            _loadLinks(reset: true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? AppTheme.accentGlow : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: selected ? AppTheme.accent : AppTheme.divider),
            ),
            child: Text(
              o.$2,
              style: TextStyle(
                color: selected ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$value ', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            TextSpan(text: label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final CrawlerLink link;
  final VoidCallback onDelete;
  const _LinkTile({required this.link, required this.onDelete});

  Color get _statusColor {
    switch (link.status) {
      case 'success': return Colors.green;
      case 'error': return Colors.redAccent;
      case 'blocked': return Colors.orange;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${link.domain}  ·  ${link.status}  ·  profundidade ${link.depth}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                ),
                if (link.errorMessage.isNotEmpty)
                  Text(
                    link.errorMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 9),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 15, color: Colors.redAccent),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }
}

// ── Aba Ações ─────────────────────────────────────────────────────────────────

class _ActionsTab extends StatefulWidget {
  final AdminService adminService;
  const _ActionsTab({required this.adminService});

  @override
  State<_ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<_ActionsTab> {
  final _addUrlCtrl = TextEditingController();
  final _singleUrlCtrl = TextEditingController();
  bool _addingLink = false;
  bool _extracting = false;
  bool _crawling = false;
  bool _crawlingSingle = false;
  bool _rescanning = false;
  String? _lastResult;
  bool _lastResultError = false;

  void _setResult(String msg, {bool error = false}) {
    setState(() { _lastResult = msg; _lastResultError = error; });
  }

  Future<void> _confirmDeleteDomain() async {
    final ctrl = TextEditingController();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.divider)),
        title: const Text('Remover Domínio',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digite uma URL ou domínio. Todos os links e páginas desse domínio serão removidos.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'ex: gameaccessibilitynexus.com',
                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                filled: true,
                fillColor: AppTheme.bgDark,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final input = ctrl.text.trim();
      ctrl.dispose();
      if (input.isEmpty) return;
      // Extrai o domínio da URL se necessário
      String domain = input;
      try {
        final uri = Uri.parse(input.contains('://') ? input : 'https://$input');
        domain = uri.host.isNotEmpty ? uri.host : input;
      } catch (_) {}
      try {
        await widget.adminService.deleteDomain(domain);
        _setResult('Domínio "$domain" removido com sucesso.');
      } catch (e) {
        _setResult('Erro ao remover domínio: $e', error: true);
      }
    } else {
      ctrl.dispose();
    }
  }

  Future<void> _addLinks() async {
    final urls = _addUrlCtrl.text.trim().split('\n').map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty) return;
    setState(() => _addingLink = true);
    try {
      final r = await widget.adminService.addLinks(urls);
      _setResult('Adicionados: ${r['added']}, duplicados: ${r['duplicated']}, erros: ${r['errors']}');
      _addUrlCtrl.clear();
    } catch (e) {
      _setResult('Erro: $e', error: true);
    } finally {
      setState(() => _addingLink = false);
    }
  }

  Future<void> _extractLinks() async {
    setState(() => _extracting = true);
    try {
      final r = await widget.adminService.extractLinks(limit: 100);
      _setResult('Processados: ${r['processed']}, links adicionados: ${r['links_added']}, erros: ${r['errors']}');
    } catch (e) {
      _setResult('Erro: $e', error: true);
    } finally {
      setState(() => _extracting = false);
    }
  }

  Future<void> _triggerCrawl() async {
    setState(() => _crawling = true);
    try {
      final r = await widget.adminService.triggerCrawl(limit: 50);
      _setResult(r['message']?.toString() ?? 'Crawling iniciado');
    } catch (e) {
      _setResult('Erro: $e', error: true);
    } finally {
      setState(() => _crawling = false);
    }
  }

  Future<void> _crawlSingle() async {
    final url = _singleUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _crawlingSingle = true);
    try {
      final r = await widget.adminService.crawlSinglePage(url);
      final success = r['success'] as bool? ?? false;
      final msg = r['message']?.toString() ?? '';
      final title = r['title']?.toString() ?? '';
      _setResult(
        success ? 'Página crawleada: ${title.isNotEmpty ? title : url}\n$msg' : 'Falhou: $msg',
        error: !success,
      );
      if (success) _singleUrlCtrl.clear();
    } catch (e) {
      _setResult('Erro: $e', error: true);
    } finally {
      setState(() => _crawlingSingle = false);
    }
  }


  Future<void> _rescanAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.divider)),
        title: const Text('Reescan Geral',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        content: const Text(
          'Todos os links serão marcados como pendentes e o crawler será reiniciado. Isso pode demorar.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _rescanning = true);
    try {
      final r = await widget.adminService.rescanAll(limit: 500);
      _setResult(r['message']?.toString() ?? 'Reescan iniciado em background.');
    } catch (e) {
      _setResult('Erro: $e', error: true);
    } finally {
      setState(() => _rescanning = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Adicionar links ──────────────────────────────────────────────────
        _SectionHeader(title: 'Adicionar Links', icon: Icons.add_link_rounded),
        const SizedBox(height: 10),
        _MultilineField(
          controller: _addUrlCtrl,
          hint: 'Cole URLs (uma por linha)\nhttps://exemplo.com\nhttps://outro.com',
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Cadastrar Links',
          icon: Icons.add_rounded,
          loading: _addingLink,
          onPressed: _addLinks,
        ),

        const SizedBox(height: 20),
        Divider(color: AppTheme.divider),
        const SizedBox(height: 16),

        // ── Extração de links ────────────────────────────────────────────────
        _SectionHeader(title: 'Extração de Links', icon: Icons.device_hub_rounded),
        const SizedBox(height: 6),
        const Text(
          'Extrai novos links das páginas pendentes registradas.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: 'Extrair Links',
          icon: Icons.sync_rounded,
          loading: _extracting,
          onPressed: _extractLinks,
        ),

        const SizedBox(height: 20),
        Divider(color: AppTheme.divider),
        const SizedBox(height: 16),

        // ── Crawling em massa ────────────────────────────────────────────────
        _SectionHeader(title: 'Crawling em Massa', icon: Icons.travel_explore_rounded),
        const SizedBox(height: 6),
        const Text(
          'Faz crawling das páginas pendentes extraídas (até 50 por vez).',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: 'Iniciar Crawling',
          icon: Icons.play_arrow_rounded,
          loading: _crawling,
          onPressed: _triggerCrawl,
        ),

        const SizedBox(height: 20),
        Divider(color: AppTheme.divider),
        const SizedBox(height: 16),

        // ── Crawling de página única ─────────────────────────────────────────
        _SectionHeader(title: 'Crawl Página Única', icon: Icons.article_rounded),
        const SizedBox(height: 6),
        const Text(
          'Faz crawling de uma única URL sem extrair links adicionais.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        _MultilineField(
          controller: _singleUrlCtrl,
          hint: 'https://exemplo.com/pagina-especifica',
          maxLines: 1,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label: 'Crawlear Página',
          icon: Icons.file_download_rounded,
          loading: _crawlingSingle,
          onPressed: _crawlSingle,
        ),

        const SizedBox(height: 20),
        Divider(color: AppTheme.divider),
        const SizedBox(height: 16),


        const SizedBox(height: 20),
        Divider(color: AppTheme.divider),
        const SizedBox(height: 16),

        // ── Reescan Geral (Fix #5) ───────────────────────────────────────────
        _SectionHeader(title: 'Reescan Geral', icon: Icons.refresh_rounded),
        const SizedBox(height: 6),
        const Text(
          'Reseta todos os links para pendente e reinicia o crawling completo.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: 'Iniciar Reescan Geral',
          icon: Icons.replay_rounded,
          loading: _rescanning,
          onPressed: _rescanAll,
          color: Colors.orangeAccent,
        ),

        // ── Remover Domínio ──────────────────────────────────────────────────
        _SectionHeader(title: 'Remover Domínio', icon: Icons.domain_disabled_rounded),
        const SizedBox(height: 6),
        const Text(
          'Remove todos os links, páginas e embeddings de um domínio.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: 'Remover Domínio',
          icon: Icons.delete_sweep_rounded,
          loading: false,
          onPressed: _confirmDeleteDomain,
          color: Colors.redAccent,
        ),

        // ── Resultado ────────────────────────────────────────────────────────
        if (_lastResult != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _lastResultError ? Colors.redAccent.withOpacity(0.08) : Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _lastResultError ? Colors.redAccent.withOpacity(0.3) : Colors.green.withOpacity(0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _lastResultError ? Icons.error_rounded : Icons.check_circle_rounded,
                  size: 16,
                  color: _lastResultError ? Colors.redAccent : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastResult!,
                    style: TextStyle(
                      color: _lastResultError ? Colors.redAccent : Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MultilineField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _MultilineField({required this.controller, required this.hint, this.maxLines = 3});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.accent),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppTheme.accent;
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg.withOpacity(0.15),
          foregroundColor: bg,
          side: BorderSide(color: bg, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
