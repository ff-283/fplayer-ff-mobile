import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

enum LogLevel { info, warn, error }

enum UrlInputMode { service, direct }

enum ServicePlayProtocol { hls, httpFlv, rtmp }

const _kInputMode = 'input_mode';
const _kGatewayUrl = 'gateway_url';
const _kApp = 'app';
const _kStream = 'stream';
const _kProtocol = 'protocol';
const _kDirectUrl = 'direct_url';

Widget _liveControls(VideoState state) {
  return MaterialDesktopVideoControlsTheme(
    normal: const MaterialDesktopVideoControlsThemeData(
      displaySeekBar: false,
      bottomButtonBar: [
        MaterialDesktopPlayOrPauseButton(),
        MaterialDesktopVolumeButton(),
        Spacer(),
        MaterialDesktopFullscreenButton(),
      ],
    ),
    fullscreen: const MaterialDesktopVideoControlsThemeData(
      displaySeekBar: false,
      bottomButtonBar: [
        MaterialDesktopPlayOrPauseButton(),
        MaterialDesktopVolumeButton(),
        Spacer(),
        MaterialDesktopFullscreenButton(),
      ],
    ),
    child: MaterialVideoControlsTheme(
      normal: const MaterialVideoControlsThemeData(
        displaySeekBar: false,
        seekGesture: false,
        seekOnDoubleTap: false,
        bottomButtonBar: [
          Spacer(),
          MaterialFullscreenButton(),
        ],
      ),
      fullscreen: const MaterialVideoControlsThemeData(
        displaySeekBar: false,
        seekGesture: false,
        seekOnDoubleTap: false,
        bottomButtonBar: [
          Spacer(),
          MaterialFullscreenButton(),
        ],
      ),
      child: AdaptiveVideoControls(state),
    ),
  );
}

class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
  });

  final String time;
  final LogLevel level;
  final String message;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Service Stream Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF),
          onPrimary: Color(0xFF0D1117),
          primaryContainer: Color(0xFF1A3A5C),
          secondary: Color(0xFF3FB950),
          onSecondary: Color(0xFF0D1117),
          tertiary: Color(0xFF8B949E),
          surface: Color(0xFF161B22),
          surfaceContainerHighest: Color(0xFF21262D),
          error: Color(0xFFF85149),
          onError: Color(0xFFFFFFFF),
          onSurface: Color(0xFFC9D1D9),
          outline: Color(0xFF30363D),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: const Color(0xFF161B22),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D), width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D1117),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF58A6FF), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: Color(0xFF8B949E)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF85149),
            side: const BorderSide(color: Color(0xFFF85149)),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF388BFD);
              }
              return const Color(0xFF21262D);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return const Color(0xFF8B949E);
            }),
            side: WidgetStateProperty.resolveWith((states) {
              return BorderSide(
                color: states.contains(WidgetState.selected)
                    ? const Color(0xFF388BFD)
                    : const Color(0xFF30363D),
              );
            }),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            )),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF21262D),
          contentTextStyle: const TextStyle(color: Color(0xFFC9D1D9)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const HttpFlvPlayerPage(),
    );
  }
}

class HttpFlvPlayerPage extends StatefulWidget {
  const HttpFlvPlayerPage({super.key});

  @override
  State<HttpFlvPlayerPage> createState() => _HttpFlvPlayerPageState();
}

class _HttpFlvPlayerPageState extends State<HttpFlvPlayerPage>
    with TickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoController;
  final ScrollController _logScrollController = ScrollController();
  final List<LogEntry> _logs = <LogEntry>[];

  final TextEditingController _urlController = TextEditingController(text: '');
  final TextEditingController _gatewayController = TextEditingController(
    text: 'http://192.168.1.100:9000',
  );
  final TextEditingController _appController = TextEditingController(
    text: 'live',
  );
  final TextEditingController _streamController = TextEditingController(
    text: 'stream001',
  );

  String? _error;
  bool _loading = false;
  bool _isStreaming = false;
  UrlInputMode _inputMode = UrlInputMode.service;
  ServicePlayProtocol? _servicePlayProtocol;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool get _isAndroidRuntime =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _canPull => !_loading && !_isStreaming;
  bool get _canStop => _loading || _isStreaming;

  @override
  void initState() {
    super.initState();
    _servicePlayProtocol = (kIsWeb || _isAndroidRuntime)
        ? ServicePlayProtocol.hls
        : ServicePlayProtocol.httpFlv;
    _player = Player();
    _videoController = VideoController(_player);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _addLog('播放器初始化完成');
    _bindPlayerLogs();
    _loadSettings();
  }

  Future<void> _play() async {
    if (_isStreaming || _loading) return;

    String url = _urlController.text.trim();
    if (_inputMode == UrlInputMode.service) {
      try {
        url = await _resolvePlayUrlFromGateway();
        _urlController.text = url;
      } catch (e) {
        setState(() => _error = '解析播放地址失败: $e');
        _addLog('解析播放地址失败: $e', level: LogLevel.error);
        return;
      }
    }

    _addLog('点击拉流: $url');
    if (url.isEmpty) {
      setState(() => _error = '请输入播放地址');
      _addLog('播放被拒绝: URL 为空', level: LogLevel.warn);
      return;
    }

    if (kIsWeb && _looksLikeFlvOrRtmp(url)) {
      const String msg =
          '当前为 Web 运行环境，HTTP-FLV/RTMP 可能无法渲染画面。请在服务模式切换到 HLS，或使用 Android 真机播放。';
      setState(() => _error = msg);
      _addLog(msg, level: LogLevel.warn);
      return;
    }

    if (_isAndroidRuntime && _looksLikeFlvOrRtmp(url)) {
      const String msg =
          '当前为 Android 端，HTTP-FLV/RTMP 在部分机型/模拟器可能黑屏。建议优先使用 HLS。';
      _addLog(msg, level: LogLevel.warn);
    }

    setState(() {
      _error = null;
      _loading = true;
      _isStreaming = true;
    });
    _pulseController.repeat(reverse: true);

    try {
      await _player.open(Media(url), play: true);
      _addLog('open 调用成功，等待流数据');
    } catch (e) {
      setState(() {
        _error = '播放失败: $e';
        _isStreaming = false;
      });
      _pulseController.stop();
      _pulseController.reset();
      _addLog('播放异常: $e', level: LogLevel.error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _looksLikeFlvOrRtmp(String url) {
    final String v = url.toLowerCase();
    return v.startsWith('rtmp://') || v.contains('.flv');
  }

  Future<String> _resolvePlayUrlFromGateway() async {
    final String gateway =
        _gatewayController.text.trim().replaceAll(RegExp(r'/+$'), '');
    final String app = _appController.text.trim();
    final String stream = _streamController.text.trim();

    if (gateway.isEmpty || app.isEmpty || stream.isEmpty) {
      throw Exception('请填写服务地址、App、Stream');
    }

    final Uri uri = Uri.parse(
      '$gateway/api/v1/streams/resolve',
    ).replace(queryParameters: <String, String>{
      'app': app,
      'stream': stream,
    });

    _addLog('解析拉流地址: $uri');
    final http.Response resp = await http.get(
      uri,
      headers: <String, String>{'Accept': 'application/json'},
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('gateway 响应 ${resp.statusCode}: ${resp.body}');
    }
    final dynamic decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('响应格式无效');
    }
    final String hls = (decoded['playHls'] ?? '').toString().trim();
    final String flv = (decoded['playHttpFlv'] ?? '').toString().trim();
    final Map<String, dynamic> playUrls = (decoded['playUrls']
            is Map<String, dynamic>)
        ? (decoded['playUrls'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final String rtmp = (playUrls['rtmp'] ?? '').toString().trim();
    final String hlsFromPlayUrls = (playUrls['hls'] ?? '').toString().trim();

    final ServicePlayProtocol protocol =
        _servicePlayProtocol ?? ServicePlayProtocol.httpFlv;
    final bool useRtmp = protocol == ServicePlayProtocol.rtmp;
    final bool useHls = protocol == ServicePlayProtocol.hls;
    final String selected = useRtmp
        ? rtmp
        : (useHls ? (hls.isNotEmpty ? hls : hlsFromPlayUrls) : flv);
    if (selected.isEmpty) {
      final String need = useRtmp
          ? 'playUrls.rtmp'
          : (useHls ? 'playHls/playUrls.hls' : 'playHttpFlv');
      throw Exception('响应中缺少 $need');
    }
    _addLog('解析成功(${useRtmp ? "RTMP" : (useHls ? "HLS" : "HTTP-FLV")}): $selected');
    return selected;
  }

  Future<void> _stop() async {
    if (!_isStreaming && !_loading) return;
    _addLog('点击停止拉流');
    _pulseController.stop();
    _pulseController.reset();
    try {
      await _player.stop();
      await _player.pause();
      _addLog('已终止拉流并暂停播放器');
    } catch (e) {
      _addLog('停止异常: $e', level: LogLevel.error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _isStreaming = false;
        });
      }
    }
  }

  void _bindPlayerLogs() {
    _player.stream.playing.listen((bool playing) {
      _addLog('状态 playing=$playing');
    });
    _player.stream.buffering.listen((bool buffering) {
      _addLog('状态 buffering=$buffering');
    });
    _player.stream.completed.listen((bool completed) {
      if (completed) _addLog('流播放完成');
    });
  }

  void _addLog(String message, {LogLevel level = LogLevel.info}) {
    final DateTime now = DateTime.now();
    final String time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    if (!mounted) return;

    setState(() {
      _logs.add(LogEntry(time: time, level: level, message: message));
      if (_logs.length > 200) {
        _logs.removeRange(0, _logs.length - 200);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScrollController.hasClients) return;
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearLogs() {
    setState(() => _logs.clear());
    _addLog('日志已清空');
  }

  Future<void> _copyAllLogs() async {
    if (_logs.isEmpty) return;
    final String content = _logs
        .map((LogEntry e) => '[${e.time}] [${_levelTag(e.level)}] ${e.message}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已复制到剪贴板')),
    );
  }

  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final String? modeStr = prefs.getString(_kInputMode);
    final String? gateway = prefs.getString(_kGatewayUrl);
    final String? app = prefs.getString(_kApp);
    final String? stream = prefs.getString(_kStream);
    final String? protocolStr = prefs.getString(_kProtocol);
    final String? directUrl = prefs.getString(_kDirectUrl);

    setState(() {
      if (modeStr == 'direct') {
        _inputMode = UrlInputMode.direct;
      }
      if (gateway != null && gateway.isNotEmpty) {
        _gatewayController.text = gateway;
      }
      if (app != null && app.isNotEmpty) {
        _appController.text = app;
      }
      if (stream != null && stream.isNotEmpty) {
        _streamController.text = stream;
      }
      if (protocolStr != null) {
        _servicePlayProtocol = ServicePlayProtocol.values.firstWhere(
          (ServicePlayProtocol p) => p.name == protocolStr,
          orElse: () => ServicePlayProtocol.httpFlv,
        );
      }
      if (_inputMode == UrlInputMode.direct &&
          directUrl != null &&
          directUrl.isNotEmpty) {
        _urlController.text = directUrl;
      }
    });

    _addControllerListeners();
  }

  void _addControllerListeners() {
    void onChanged() => _saveSettings();
    _gatewayController.addListener(onChanged);
    _appController.addListener(onChanged);
    _streamController.addListener(onChanged);
    _urlController.addListener(onChanged);
  }

  Future<void> _saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kInputMode,
      _inputMode == UrlInputMode.direct ? 'direct' : 'service',
    );
    await prefs.setString(_kGatewayUrl, _gatewayController.text);
    await prefs.setString(_kApp, _appController.text);
    await prefs.setString(_kStream, _streamController.text);
    if (_servicePlayProtocol != null) {
      await prefs.setString(_kProtocol, _servicePlayProtocol!.name);
    }
    if (_inputMode == UrlInputMode.direct) {
      await prefs.setString(_kDirectUrl, _urlController.text);
    }
  }

  String _levelTag(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return const Color(0xFF58A6FF);
      case LogLevel.warn:
        return const Color(0xFFD29922);
      case LogLevel.error:
        return const Color(0xFFF85149);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _gatewayController.dispose();
    _appController.dispose();
    _streamController.dispose();
    _logScrollController.dispose();
    _pulseController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: _buildAppBar(colors),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1117), Color(0xFF010409)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              _buildVideoSection(colors),
              _buildModeSwitch(colors),
              if (_inputMode == UrlInputMode.service)
                _buildServiceConfig(colors, textTheme),
              _buildUrlInput(colors),
              _buildActionButtons(colors),
              if (_error != null) _buildErrorCard(colors),
              const SizedBox(height: 16),
              _buildLogPanel(colors, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colors) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF161B22), Color(0xFF0D1117)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [Color(0xFF58A6FF), Color(0xFF3FB950)],
              ),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            '局域网流播放器',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ],
      ),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: colors.outline,
      actions: <Widget>[
        if (_isStreaming)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _StreamingBadge(pulseController: _pulseController),
          ),
      ],
    );
  }

  Widget _buildVideoSection(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (BuildContext context, Widget? child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isStreaming
                        ? const Color(0xFF388BFD).withValues(alpha: 0.6)
                        : const Color(0xFF30363D),
                    width: _isStreaming ? 2 : 1,
                  ),
                  boxShadow: _isStreaming
                      ? <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFF388BFD).withValues(alpha: 0.15),
                            blurRadius: 12 + _pulseAnimation.value * 4,
                            spreadRadius: _pulseAnimation.value * 2,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(
                      color: Colors.black,
                      child: Stack(
                        children: <Widget>[
                          Video(
                            controller: _videoController,
                            controls: _liveControls,
                          ),
                          if (!_isStreaming)
                            Positioned.fill(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.live_tv_rounded,
                                      size: 56,
                                      color: colors.onSurface.withValues(alpha: 0.2),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '等待播放',
                                      style: TextStyle(
                                        color: colors.onSurface.withValues(alpha: 0.3),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_loading)
                            const Positioned.fill(
                              child: Center(
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF58A6FF),
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitch(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<UrlInputMode>(
        segments: const <ButtonSegment<UrlInputMode>>[
          ButtonSegment<UrlInputMode>(
            value: UrlInputMode.service,
            label: Text('服务模式'),
            icon: Icon(Icons.dns_rounded, size: 18),
          ),
          ButtonSegment<UrlInputMode>(
            value: UrlInputMode.direct,
            label: Text('直接链接'),
            icon: Icon(Icons.link_rounded, size: 18),
          ),
        ],
        selected: <UrlInputMode>{_inputMode},
        onSelectionChanged: (Set<UrlInputMode> selected) {
          if (selected.isEmpty) return;
          setState(() => _inputMode = selected.first);
          _saveSettings();
        },
      ),
    );
  }

  Widget _buildServiceConfig(ColorScheme colors, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.cloud_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '服务配置',
                          style: textTheme.titleSmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _gatewayController,
                      decoration: const InputDecoration(
                        labelText: 'Service Gateway URL',
                        hintText: 'http://192.168.x.x:9000',
                        prefixIcon: Icon(Icons.language_rounded, size: 20),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _appController,
                            decoration: const InputDecoration(
                              labelText: 'App',
                              prefixIcon: Icon(Icons.apps_rounded, size: 20),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _streamController,
                            decoration: const InputDecoration(
                              labelText: 'Stream',
                              prefixIcon: Icon(Icons.stream_rounded, size: 20),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Icon(Icons.settings_ethernet_rounded, size: 18, color: colors.tertiary),
                        const SizedBox(width: 8),
                        Text(
                          '播放协议',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.tertiary,
                          ),
                        ),
                        const Spacer(),
                        _buildProtocolChips(colors),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolChips(ColorScheme colors) {
    return SegmentedButton<ServicePlayProtocol>(
      segments: const <ButtonSegment<ServicePlayProtocol>>[
        ButtonSegment<ServicePlayProtocol>(
          value: ServicePlayProtocol.hls,
          label: Text('HLS'),
        ),
        ButtonSegment<ServicePlayProtocol>(
          value: ServicePlayProtocol.httpFlv,
          label: Text('FLV'),
        ),
        ButtonSegment<ServicePlayProtocol>(
          value: ServicePlayProtocol.rtmp,
          label: Text('RTMP'),
        ),
      ],
      selected: <ServicePlayProtocol>{
        _servicePlayProtocol ?? ServicePlayProtocol.httpFlv,
      },
      onSelectionChanged: (Set<ServicePlayProtocol> selected) {
        if (selected.isEmpty) return;
        setState(() => _servicePlayProtocol = selected.first);
        _saveSettings();
      },
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildUrlInput(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: TextField(
            controller: _urlController,
            readOnly: _inputMode == UrlInputMode.service,
            decoration: InputDecoration(
              labelText: _inputMode == UrlInputMode.service
                  ? '播放 URL（自动解析）'
                  : '播放 URL',
              hintText: 'http://192.168.x.x:7001/live/test.flv',
              prefixIcon: Icon(
                _inputMode == UrlInputMode.service
                    ? Icons.auto_fix_high_rounded
                    : Icons.edit_rounded,
                size: 20,
              ),
              suffixIcon: _urlController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _urlController.clear();
                        setState(() => _error = null);
                        _saveSettings();
                      },
                    )
                  : null,
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: TextStyle(
              fontSize: 14,
              color: _inputMode == UrlInputMode.service
                  ? colors.tertiary
                  : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: IntrinsicHeight(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: FilledButton.icon(
                    key: ValueKey<String>(_loading ? 'loading' : 'play'),
                    onPressed: _canPull ? _play : null,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(_loading ? '连接中...' : '拉 流'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canStop ? _stop : null,
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  label: const Text('停 止'),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            color: colors.error.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.error_outline, color: colors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: colors.error, fontSize: 13),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _error = null),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colors.error.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogPanel(ColorScheme colors, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF010409),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildLogHeader(colors, textTheme),
                _buildLogList(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogHeader(ColorScheme colors, TextTheme textTheme) {
    final int infoCount = _logs.where((e) => e.level == LogLevel.info).length;
    final int warnCount = _logs.where((e) => e.level == LogLevel.warn).length;
    final int errorCount = _logs.where((e) => e.level == LogLevel.error).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.terminal_rounded, size: 18, color: Color(0xFF8B949E)),
          const SizedBox(width: 8),
          Text(
            '日志',
            style: textTheme.titleSmall?.copyWith(
              color: const Color(0xFFC9D1D9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          _LogCountBadge(label: '$infoCount', color: const Color(0xFF58A6FF)),
          const SizedBox(width: 4),
          _LogCountBadge(label: '$warnCount', color: const Color(0xFFD29922)),
          const SizedBox(width: 4),
          _LogCountBadge(label: '$errorCount', color: const Color(0xFFF85149)),
          const Spacer(),
          _LogActionButton(
            icon: Icons.copy_rounded,
            tooltip: '复制全部',
            onTap: _logs.isEmpty ? null : _copyAllLogs,
          ),
          const SizedBox(width: 4),
          _LogActionButton(
            icon: Icons.delete_sweep_rounded,
            tooltip: '清空日志',
            onTap: _logs.isEmpty ? null : _clearLogs,
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(ColorScheme colors) {
    return Container(
      height: 240,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SelectionArea(
        child: _logs.isEmpty
            ? Center(
                child: Text(
                  '暂无日志',
                  style: TextStyle(
                    color: const Color(0xFF484F58),
                    fontSize: 13,
                  ),
                ),
              )
            : ListView.builder(
                controller: _logScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _logs.length,
                itemBuilder: (BuildContext context, int index) {
                  final LogEntry entry = _logs[index];
                  return _LogRow(entry: entry, levelColor: _levelColor(entry.level));
                },
              ),
      ),
    );
  }
}

class _StreamingBadge extends StatelessWidget {
  const _StreamingBadge({required this.pulseController});

  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (BuildContext context, Widget? child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF238636).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF3FB950).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF3FB950),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFF3FB950),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LogCountBadge extends StatelessWidget {
  const _LogCountBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LogActionButton extends StatelessWidget {
  const _LogActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: onTap != null
                ? const Color(0xFF8B949E)
                : const Color(0xFF484F58),
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.levelColor});

  final LogEntry entry;
  final Color levelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.time,
            style: const TextStyle(
              color: Color(0xFF484F58),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              entry.level.name.toUpperCase(),
              style: TextStyle(
                color: levelColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(
                color: Color(0xFFC9D1D9),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
