import 'package:flutter/material.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/theme/app_theme.dart';

/// AI 配置对话框
class AIConfigDialog extends StatefulWidget {
  const AIConfigDialog({super.key});

  @override
  State<AIConfigDialog> createState() => _AIConfigDialogState();
}

class _AIConfigDialogState extends State<AIConfigDialog> {
  final AIService _aiService = AIService();
  
  late AIProvider _selectedProvider;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    
    final config = _aiService.getConfiguration();
    _selectedProvider = config['provider'] as AIProvider;
    _baseUrlController = TextEditingController(text: config['baseUrl'] as String);
    _apiKeyController = TextEditingController(text: config['apiKey'] as String);
    _modelController = TextEditingController(text: config['model'] as String);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'AI 服务配置',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProviderSelector(),
                    const SizedBox(height: 16),
                    _buildBaseUrlField(),
                    const SizedBox(height: 16),
                    _buildApiKeyField(),
                    const SizedBox(height: 16),
                    _buildModelField(),
                    const SizedBox(height: 24),
                    _buildTestButton(),
                    if (_testResult != null) ...[
                      const SizedBox(height: 16),
                      _buildTestResult(),
                    ],
                    const SizedBox(height: 24),
                    _buildProviderInfo(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveConfiguration,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI 提供商',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<AIProvider>(
          value: _selectedProvider,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: AIProvider.values.map((provider) {
            return DropdownMenuItem(
              value: provider,
              child: Text(provider.displayName),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedProvider = value;
                _baseUrlController.text = value.defaultBaseUrl;
                _modelController.text = AIService.getRecommendedModels(value).first;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildBaseUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'API 地址',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _baseUrlController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'https://api.example.com/v1',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'API Key',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'sk-...',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildModelField() {
    final recommendedModels = AIService.getRecommendedModels(_selectedProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '模型',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'gpt-4o-mini',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down),
              tooltip: '推荐模型',
              onSelected: (model) {
                setState(() {
                  _modelController.text = model;
                });
              },
              itemBuilder: (context) {
                return recommendedModels.map((model) {
                  return PopupMenuItem(
                    value: model,
                    child: Text(model),
                  );
                }).toList();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTestButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isTesting ? null : _testConnection,
        icon: _isTesting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check_circle),
        label: Text(_isTesting ? '测试中...' : '测试连接'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTestResult() {
    final isSuccess = _testResult == 'success';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSuccess ? '连接成功！' : '连接失败：$_testResult',
              style: TextStyle(
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderInfo() {
    final info = _getProviderInfo(_selectedProvider);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                '提供商说明',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            info,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getProviderInfo(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return 'OpenAI GPT 系列模型，需要在 platform.openai.com 注册并获取 API Key。推荐使用 gpt-4o-mini 性价比高。';
      case AIProvider.claude:
        return 'Anthropic Claude 系列模型，需要在 console.anthropic.com 注册。Claude 3.5 Sonnet 效果最好。';
      case AIProvider.gemini:
        return 'Google Gemini 系列模型，需要在 ai.google.dev 获取 API Key。Gemini 1.5 Flash 速度快且免费。';
      case AIProvider.qwen:
        return '阿里云通义千问，需要在 dashscope.aliyun.com 开通服务。qwen-turbo 性价比高。';
      case AIProvider.deepseek:
        return 'DeepSeek 系列模型，需要在 platform.deepseek.com 注册。价格便宜，效果不错。';
      case AIProvider.zhipu:
        return '智谱 AI GLM 系列模型，需要在 open.bigmodel.cn 注册。glm-4-flash 免费且快速。';
      case AIProvider.moonshot:
        return '月之暗面 Kimi 系列模型，需要在 platform.moonshot.cn 注册。支持超长上下文。';
      case AIProvider.suanli:
        return '算力云免费 AI 服务，无需注册即可使用。适合测试和轻度使用。';
      case AIProvider.custom:
        return '自定义 OpenAI 兼容的 API 服务，需要手动配置 API 地址和密钥。';
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      // 临时保存配置用于测试
      await _aiService.saveConfiguration(
        provider: _selectedProvider,
        baseUrl: _baseUrlController.text,
        apiKey: _apiKeyController.text,
        model: _modelController.text,
      );

      final success = await _aiService.testConnection();
      
      setState(() {
        _testResult = success ? 'success' : '连接失败，请检查配置';
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _testResult = e.toString();
        _isTesting = false;
      });
    }
  }

  Future<void> _saveConfiguration() async {
    try {
      await _aiService.saveConfiguration(
        provider: _selectedProvider,
        baseUrl: _baseUrlController.text,
        apiKey: _apiKeyController.text,
        model: _modelController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
}
