import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

enum LogLevel { info, warn, error }
enum UrlInputMode { service, direct }
enum ServicePlayProtocol { hls, httpFlv, rtmp }

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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

class _HttpFlvPlayerPageState extends State<HttpFlvPlayerPage> {
  late final Player _player;
  late final VideoController _videoController;
  final ScrollController _logScrollController = ScrollController();
  final List<LogEntry> _logs = <LogEntry>[];

  final TextEditingController _urlController = TextEditingController(
    text: '',
  );
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

  bool get _isAndroidRuntime =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _canPull => !_loading && !_isStreaming;
  bool get _canStop => _loading || _isStreaming;

  @override
  void initState() {
    super.initState();
    _servicePlayProtocol =
        (kIsWeb || _isAndroidRuntime)
            ? ServicePlayProtocol.hls
            : ServicePlayProtocol.httpFlv;
    _player = Player();
    _videoController = VideoController(_player);
    _addLog('播放器初始化完成');
    _bindPlayerLogs();
  }

  Future<void> _play() async {
    if (_isStreaming || _loading) {
      return;
    }
    String url = _urlController.text.trim();
    if (_inputMode == UrlInputMode.service) {
      try {
        url = await _resolvePlayUrlFromGateway();
        _urlController.text = url;
      } catch (e) {
        setState(() {
          _error = '解析播放地址失败: $e';
        });
        _addLog('解析播放地址失败: $e', level: LogLevel.error);
        return;
      }
    }

    _addLog('点击拉流: $url');
    if (url.isEmpty) {
      setState(() {
        _error = '请输入 HTTP-FLV 地址';
      });
      _addLog('播放被拒绝: URL 为空', level: LogLevel.warn);
      return;
    }

    // Flutter Web(Chrome) 对 HTTP-FLV/RTMP 支持受限，常见表现是无画面。
    if (kIsWeb && _looksLikeFlvOrRtmp(url)) {
      const String msg =
          '当前为 Web 运行环境，HTTP-FLV/RTMP 可能无法渲染画面。请在服务模式切换到 HLS，或使用 Android 真机播放。';
      setState(() {
        _error = msg;
      });
      _addLog(msg, level: LogLevel.warn);
      return;
    }

    if (_isAndroidRuntime && _looksLikeFlvOrRtmp(url)) {
      const String msg =
          '当前为 Android 端，HTTP-FLV/RTMP 在部分机型/模拟器可能黑屏。建议优先使用 HLS，必要时改用真机测试。';
      _addLog(msg, level: LogLevel.warn);
    }

    setState(() {
      _error = null;
      _loading = true;
      _isStreaming = true;
    });

    try {
      await _player.open(Media(url), play: true);
      _addLog('open 调用成功，等待流数据');
    } catch (e) {
      setState(() {
        _error = '播放失败: $e';
        _isStreaming = false;
      });
      _addLog('播放异常: $e', level: LogLevel.error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _looksLikeFlvOrRtmp(String url) {
    final String v = url.toLowerCase();
    return v.startsWith('rtmp://') || v.contains('.flv');
  }

  Future<String> _resolvePlayUrlFromGateway() async {
    final String gateway = _gatewayController.text.trim().replaceAll(RegExp(r'/+$'), '');
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
      headers: <String, String>{
        'Accept': 'application/json',
      },
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
    final Map<String, dynamic> playUrls = (decoded['playUrls'] is Map<String, dynamic>)
        ? (decoded['playUrls'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final String rtmp = (playUrls['rtmp'] ?? '').toString().trim();
    final String hlsFromPlayUrls = (playUrls['hls'] ?? '').toString().trim();

    final ServicePlayProtocol protocol =
        _servicePlayProtocol ?? ServicePlayProtocol.httpFlv;
    final bool useRtmp = protocol == ServicePlayProtocol.rtmp;
    final bool useHls = protocol == ServicePlayProtocol.hls;
    final String selected = useRtmp ? rtmp : (useHls ? (hls.isNotEmpty ? hls : hlsFromPlayUrls) : flv);
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
    if (!_isStreaming && !_loading) {
      return;
    }
    _addLog('点击停止拉流');
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
      if (completed) {
        _addLog('流播放完成');
      }
    });
  }

  void _addLog(String message, {LogLevel level = LogLevel.info}) {
    final DateTime now = DateTime.now();
    final String time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    if (!mounted) {
      return;
    }

    setState(() {
      _logs.add(LogEntry(time: time, level: level, message: message));
      if (_logs.length > 200) {
        _logs.removeRange(0, _logs.length - 200);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScrollController.hasClients) {
        return;
      }
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('日志已清空');
  }

  Future<void> _copyAllLogs() async {
    if (_logs.isEmpty) {
      return;
    }
    final String content = _logs
        .map((LogEntry e) => '[${e.time}] [${_levelTag(e.level)}] ${e.message}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已复制到剪贴板')),
    );
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
        return Colors.greenAccent;
      case LogLevel.warn:
        return Colors.amberAccent;
      case LogLevel.error:
        return Colors.redAccent;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _gatewayController.dispose();
    _appController.dispose();
    _streamController.dispose();
    _logScrollController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('局域网服务流播放（HLS/FLV/RTMP）'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 12),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(
                      color: Colors.black,
                      child: Video(controller: _videoController),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<UrlInputMode>(
                segments: const <ButtonSegment<UrlInputMode>>[
                  ButtonSegment<UrlInputMode>(
                    value: UrlInputMode.service,
                    label: Text('服务地址模式'),
                  ),
                  ButtonSegment<UrlInputMode>(
                    value: UrlInputMode.direct,
                    label: Text('直接 URL 模式'),
                  ),
                ],
                selected: <UrlInputMode>{_inputMode},
                onSelectionChanged: (Set<UrlInputMode> selected) {
                  if (selected.isEmpty) {
                    return;
                  }
                  setState(() {
                    _inputMode = selected.first;
                  });
                },
              ),
            ),
            if (_inputMode == UrlInputMode.service)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _gatewayController,
                      decoration: const InputDecoration(
                        labelText: 'Service Gateway URL',
                        hintText: 'http://192.168.x.x:9000',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _appController,
                            decoration: const InputDecoration(
                              labelText: 'App',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _streamController,
                            decoration: const InputDecoration(
                              labelText: 'Stream',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<ServicePlayProtocol>(
                      segments: const <ButtonSegment<ServicePlayProtocol>>[
                        ButtonSegment<ServicePlayProtocol>(
                          value: ServicePlayProtocol.hls,
                          label: Text('HLS'),
                        ),
                        ButtonSegment<ServicePlayProtocol>(
                          value: ServicePlayProtocol.httpFlv,
                          label: Text('HTTP-FLV'),
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
                        if (selected.isEmpty) {
                          return;
                        }
                        setState(() {
                          _servicePlayProtocol = selected.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: _inputMode == UrlInputMode.service ? '播放 URL（自动解析结果）' : '播放 URL',
                  hintText: 'http://192.168.x.x:7001/live/test.flv 或 /hls.m3u8',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                readOnly: _inputMode == UrlInputMode.service,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: _canPull ? _play : null,
                      child: Text(_loading ? '拉流中...' : '拉流'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _canStop ? _stop : null,
                      child: const Text('停止'),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '日志',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _copyAllLogs,
                    child: const Text('复制全部'),
                  ),
                  TextButton(
                    onPressed: _clearLogs,
                    child: const Text('清空日志'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 260,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: SelectionArea(
                child: ListView.builder(
                  controller: _logScrollController,
                  itemCount: _logs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final LogEntry entry = _logs[index];
                    final Color color = _levelColor(entry.level);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: SelectableText(
                        '[${entry.time}] [${_levelTag(entry.level)}] ${entry.message}',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
