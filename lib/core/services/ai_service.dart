import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 提供商类型
enum AIProvider {
  openai('OpenAI', 'https://api.openai.com/v1'),
  claude('Claude', 'https://api.anthropic.com/v1'),
  gemini('Gemini', 'https://generativelanguage.googleapis.com/v1beta'),
  qwen('通义千问', 'https://dashscope.aliyuncs.com/api/v1'),
  deepseek('DeepSeek', 'https://api.deepseek.com/v1'),
  zhipu('智谱AI', 'https://open.bigmodel.cn/api/paas/v4'),
  moonshot('月之暗面', 'https://api.moonshot.cn/v1'),
  suanli('算力云（免费）', 'https://api.suanli.cn/v1'),
  custom('自定义', '');

  const AIProvider(this.displayName, this.defaultBaseUrl);
  final String displayName;
  final String defaultBaseUrl;
}

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal() {
    _initializeDio();
    _loadConfiguration();
  }

  void _initializeDio() {
    _dio = Dio();
    
    // 配置超时时间 - AI总结需要更长时间
    _dio.options.connectTimeout = const Duration(seconds: 60);
    _dio.options.receiveTimeout = const Duration(minutes: 5);
    _dio.options.sendTimeout = const Duration(seconds: 60);
  }

  late final Dio _dio;
  
  // 当前配置 - 默认使用算力云免费服务（开箱即用）
  AIProvider _provider = AIProvider.suanli;
  String _baseUrl = 'https://api.suanli.cn/v1';
  String _apiKey = 'sk-W0rpStc95T7JVYVwDYc29IyirjtpPPby6SozFMQr17m8KWeo';
  String _model = 'free:QwQ-32B';

  // SharedPreferences 键
  static const String _keyProvider = 'ai_provider';
  static const String _keyBaseUrl = 'ai_base_url';
  static const String _keyApiKey = 'ai_api_key';
  static const String _keyModel = 'ai_model';

  /// 加载配置
  Future<void> _loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final providerName = prefs.getString(_keyProvider);
      if (providerName != null) {
        _provider = AIProvider.values.firstWhere(
          (e) => e.name == providerName,
          orElse: () => AIProvider.suanli,
        );
      }
      
      _baseUrl = prefs.getString(_keyBaseUrl) ?? _provider.defaultBaseUrl;
      _apiKey = prefs.getString(_keyApiKey) ?? _apiKey;
      _model = prefs.getString(_keyModel) ?? _getDefaultModel(_provider);
    } catch (e) {
      debugPrint('加载 AI 配置失败: $e');
    }
  }

  /// 保存配置
  Future<void> saveConfiguration({
    AIProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (provider != null) {
        _provider = provider;
        await prefs.setString(_keyProvider, provider.name);
        
        // 如果切换提供商，更新默认 URL 和模型
        if (baseUrl == null || baseUrl.isEmpty) {
          _baseUrl = provider.defaultBaseUrl;
          await prefs.setString(_keyBaseUrl, _baseUrl);
        }
        
        if (model == null || model.isEmpty) {
          _model = _getDefaultModel(provider);
          await prefs.setString(_keyModel, _model);
        }
      }
      
      if (baseUrl != null && baseUrl.isNotEmpty) {
        _baseUrl = baseUrl;
        await prefs.setString(_keyBaseUrl, baseUrl);
      }
      
      if (apiKey != null && apiKey.isNotEmpty) {
        _apiKey = apiKey;
        await prefs.setString(_keyApiKey, apiKey);
      }
      
      if (model != null && model.isNotEmpty) {
        _model = model;
        await prefs.setString(_keyModel, model);
      }
    } catch (e) {
      debugPrint('保存 AI 配置失败: $e');
    }
  }

  /// 获取默认模型
  String _getDefaultModel(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return 'gpt-4o-mini';
      case AIProvider.claude:
        return 'claude-3-5-sonnet-20241022';
      case AIProvider.gemini:
        return 'gemini-1.5-flash';
      case AIProvider.qwen:
        return 'qwen-turbo';
      case AIProvider.deepseek:
        return 'deepseek-chat';
      case AIProvider.zhipu:
        return 'glm-4-flash';
      case AIProvider.moonshot:
        return 'moonshot-v1-8k';
      case AIProvider.suanli:
        return 'free:QwQ-32B';
      case AIProvider.custom:
        return 'gpt-3.5-turbo';
    }
  }

  /// 获取当前配置
  Map<String, dynamic> getConfiguration() {
    return {
      'provider': _provider,
      'baseUrl': _baseUrl,
      'apiKey': _apiKey,
      'model': _model,
    };
  }

  /// 生成邮件总结
  Future<String> generateSummary(String subject, String content) async {
    try {
      final prompt = _buildSummaryPrompt(subject, content);
      
      // 根据不同的提供商使用不同的 API 格式
      switch (_provider) {
        case AIProvider.claude:
          return await _generateSummaryClaude(prompt);
        case AIProvider.gemini:
          return await _generateSummaryGemini(prompt);
        default:
          return await _generateSummaryOpenAICompatible(prompt);
      }
    } catch (e) {
      debugPrint('AI总结生成失败: $e');
      throw Exception('生成总结失败: ${e.toString()}');
    }
  }

  /// OpenAI 兼容格式（适用于 OpenAI、DeepSeek、通义千问、智谱、月之暗面、算力云等）
  Future<String> _generateSummaryOpenAICompatible(String prompt) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        options: Options(
          headers: _buildHeaders(),
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (status) => status != null && status < 500,
        ),
        data: {
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 4000,
          'temperature': 0.7,
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          String summary = data['choices'][0]['message']['content'] ?? '';
          summary = _removeThinkingTags(summary);
          
          if (summary.isEmpty) {
            throw Exception('AI返回了空的总结内容');
          }
          
          return summary.trim();
        } else {
          throw Exception('AI响应格式错误：缺少choices字段');
        }
      } else if (response.statusCode == 401) {
        throw Exception('API Key 无效，请检查配置');
      } else if (response.statusCode == 429) {
        throw Exception('请求过于频繁，请稍后再试');
      } else if (response.statusCode == 503) {
        // 如果是默认的免费服务，提供更友好的提示
        if (_provider == AIProvider.suanli) {
          throw Exception('免费 AI 服务暂时繁忙，请稍后再试\n\n'
              '或者配置自己的 AI 服务以获得更稳定的体验：\n'
              '• DeepSeek（¥0.3/1M tokens）\n'
              '• 智谱AI（有免费额度）\n'
              '• OpenAI GPT-4o-mini\n\n'
              '进入"设置" → "AI与翻译" → "快速配置 AI 服务"');
        }
        throw Exception('AI 服务暂时不可用，请稍后再试或更换其他提供商');
      } else {
        final errorMsg = response.data is Map 
            ? (response.data['error']?['message'] ?? '') 
            : '';
        throw Exception('API请求失败 (${response.statusCode}): $errorMsg');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('连接超时，请检查网络连接');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('响应超时，AI 服务响应过慢');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('网络连接失败，请检查网络设置');
      } else {
        rethrow;
      }
    }
  }

  /// Claude API 格式
  Future<String> _generateSummaryClaude(String prompt) async {
    final response = await _dio.post(
      '$_baseUrl/messages',
      options: Options(
        headers: {
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(minutes: 2),
      ),
      data: {
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'max_tokens': 4000,
        'temperature': 0.7,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      if (data['content'] != null && data['content'].isNotEmpty) {
        String summary = data['content'][0]['text'] ?? '';
        return summary.trim();
      } else {
        throw Exception('Claude响应格式错误');
      }
    } else {
      throw Exception('API请求失败: ${response.statusCode}');
    }
  }

  /// Gemini API 格式
  Future<String> _generateSummaryGemini(String prompt) async {
    final response = await _dio.post(
      '$_baseUrl/models/$_model:generateContent?key=$_apiKey',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
        },
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(minutes: 2),
      ),
      data: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 4000,
        }
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        String summary = data['candidates'][0]['content']['parts'][0]['text'] ?? '';
        return summary.trim();
      } else {
        throw Exception('Gemini响应格式错误');
      }
    } else {
      throw Exception('API请求失败: ${response.statusCode}');
    }
  }

  /// 构建请求头
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // 通义千问使用特殊的认证方式
    if (_provider == AIProvider.qwen) {
      headers['Authorization'] = 'Bearer $_apiKey';
      headers['X-DashScope-SSE'] = 'disable';
    } else {
      headers['Authorization'] = 'Bearer $_apiKey';
    }

    return headers;
  }

  /// 批量生成邮件总结
  Future<List<String>> generateBatchSummary(List<Map<String, String>> emails) async {
    final summaries = <String>[];
    
    for (final email in emails) {
      try {
        final summary = await generateSummary(
          email['subject'] ?? '',
          email['content'] ?? '',
        );
        summaries.add(summary);
      } catch (e) {
        summaries.add('总结生成失败');
      }
    }
    
    return summaries;
  }

  /// 生成今日邮件汇总
  Future<String> generateDailySummary(List<Map<String, String>> todayEmails) async {
    try {
      final prompt = _buildDailySummaryPrompt(todayEmails);
      
      // 使用相同的生成逻辑
      switch (_provider) {
        case AIProvider.claude:
          return await _generateSummaryClaude(prompt);
        case AIProvider.gemini:
          return await _generateSummaryGemini(prompt);
        default:
          return await _generateSummaryOpenAICompatible(prompt);
      }
    } catch (e) {
      debugPrint('每日汇总生成失败: $e');
      throw Exception('生成每日汇总失败: ${e.toString()}');
    }
  }

  /// 构建总结提示词
  String _buildSummaryPrompt(String subject, String content) {
    return '''
请为以下邮件生成一个简洁的中文总结，重点突出关键信息和要点：

邮件主题：$subject

邮件内容：
$content

要求：
1. 总结长度控制在100-200字
2. 突出重要信息和关键点
3. 使用简洁明了的中文表达
4. 如果是新闻类邮件，重点提取新闻要点
5. 如果是技术类邮件，重点提取技术要点

请直接输出总结内容，不要包含其他说明文字。
''';
  }

  /// 构建每日汇总提示词
  String _buildDailySummaryPrompt(List<Map<String, String>> emails) {
    final emailList = emails.map((email) {
      final content = email['content'] ?? '';
      final preview = content.length > 200 ? content.substring(0, 200) : content;
      return '标题：${email['subject']}\n内容摘要：$preview...';
    }).join('\n\n');

    return '''
请为今天收到的以下邮件生成一个综合汇总报告：

今日邮件列表：
$emailList

要求：
1. 按主题分类整理邮件内容
2. 突出重要新闻和信息
3. 提供简洁的总体概述
4. 标注需要关注的重点内容
5. 汇总长度控制在300-500字

请生成结构化的每日邮件汇总报告。
''';
  }

  /// 测试API连接
  Future<bool> testConnection() async {
    try {
      final testPrompt = '请回复"连接成功"';
      
      switch (_provider) {
        case AIProvider.claude:
          await _generateSummaryClaude(testPrompt);
          break;
        case AIProvider.gemini:
          await _generateSummaryGemini(testPrompt);
          break;
        default:
          await _generateSummaryOpenAICompatible(testPrompt);
      }
      
      return true;
    } catch (e) {
      debugPrint('API连接测试失败: $e');
      return false;
    }
  }

  /// 去掉思考标签内的内容
  String _removeThinkingTags(String text) {
    // 移除 <thinking>...</thinking> 标签及其内容
    final thinkingRegex = RegExp(r'<thinking>.*?</thinking>', dotAll: true);
    text = text.replaceAll(thinkingRegex, '');
    
    // 移除 <think>...</think> 标签及其内容
    final thinkRegex = RegExp(r'<think>.*?</think>', dotAll: true);
    text = text.replaceAll(thinkRegex, '');
    
    // 清理多余的空白字符
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return text;
  }

  /// 获取推荐的模型列表
  static List<String> getRecommendedModels(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'];
      case AIProvider.claude:
        return ['claude-3-5-sonnet-20241022', 'claude-3-opus-20240229', 'claude-3-sonnet-20240229', 'claude-3-haiku-20240307'];
      case AIProvider.gemini:
        return ['gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-pro'];
      case AIProvider.qwen:
        return ['qwen-max', 'qwen-plus', 'qwen-turbo'];
      case AIProvider.deepseek:
        return ['deepseek-chat', 'deepseek-coder'];
      case AIProvider.zhipu:
        return ['glm-4-plus', 'glm-4', 'glm-4-flash'];
      case AIProvider.moonshot:
        return ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'];
      case AIProvider.suanli:
        return ['free:QwQ-32B', 'free:deepseek-chat'];
      case AIProvider.custom:
        return ['gpt-3.5-turbo', 'gpt-4'];
    }
  }
}
