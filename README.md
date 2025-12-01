# 新闻邮件阅读器 News Email Reader

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License">
</div>

> 本项目为蒟蒻计算机学生学习flutter时使用大量ai工具缝合出来的拼凑App，有大量问题且不定时维护，请谨慎使用。
>
> 如果您愿意的话，可以直接修改本项目并自行分发。对于本项目而言，pr比issue有用（）。

**新闻邮件阅读器** 是一款专为高效阅读和管理新闻类邮件而设计的开源 Flutter 应用。它集成了 AI 智能服务、笔记系统和强大的自定义功能，旨在提供一个纯净、无干扰的阅读体验。

## ? 功能特性

- **多账户支持**: 轻松添加和管理多个邮箱账户。
- **智能邮件同步**: 自定义同步频率，及时获取最新邮件。
- **AI 智能服务**:
    - 邮件内容智能摘要（需配置）。
    - 邮件翻译功能。
- **白名单机制**: 只接收来自您信任的发件人的邮件，屏蔽干扰信息。
- **沉浸式阅读**: 简洁的阅读界面，支持网页视图和纯文本视图。
- **笔记与收藏**:
    - 为重要邮件添加笔记，支持 Markdown 格式。
    - 编辑/预览双模式，实时查看格式效果。
    - 一键收藏关键邮件，方便日后查阅。
- **全文搜索**: 快速在所有邮件中查找需要的信息。
- **高度可定制**:
    - 支持浅色与深色主题切换。
    - 灵活配置 AI 服务、同步选项和白名单规则。
- **多语言支持**: 内置中文和英文支持。

## ? 安装指南

请访问本项目的[releases](https://github.com/AullChen/news_email_reader/releases)界面，或：

1.  **环境准备**:
    
    - 确保您已安装 [Flutter SDK](https://flutter.dev/docs/get-started/install) (版本 >= 3.0.0)。
    - 配置好您的开发环境(如 Android Studio, VS Code)。
    
2.  **克隆项目**:
    ```bash
    git clone https://github.com/your-username/news_email_reader.git
    cd news_email_reader
    ```

3.  **安装依赖**:
    ```bash
    flutter pub get
    ```

4.  **运行应用**:
    ```bash
    flutter run
    ```

## ? 使用说明

1.  **添加账户**: 首次启动应用时，请在"设置"页面添加您的邮箱账户（目前支持 IMAP 协议）。
2.  **邮件同步**: 添加账户后，应用将自动开始同步邮件。您可以在设置中调整同步频率。
3.  **阅读邮件**: 在主页点击邮件即可进入阅读界面。您可以切换视图、翻译内容或添加笔记。
4.  **管理白名单**: 在"设置"中管理白名单，只有白名单中的发件人邮件才会被接收。
5.  **使用 AI 功能**: 在"设置"中配置您的 AI 服务密钥，即可使用邮件摘要等高级功能。

## ?? 配置选项

应用的所有配置项都集中在 **设置** 页面：

- **账户管理**: 添加、编辑或删除您的邮箱账户。
- **AI与翻译**: 配置第三方 AI 与 翻译 服务的 API Key 和 Endpoint。
- **邮件同步配置**: 设置自动同步的时间间隔。
- **白名单管理**: 添加或移除信任的发件人邮箱地址。
- **外观**: 切换浅色/深色主题。

## ? 如何贡献

我们欢迎任何形式的贡献！请阅读我们的 [CONTRIBUTING.md](https://github.com/AullChen/news_email_reader/blob/main/CONTRIBUTING.md) 文件，了解如何参与改进这个项目。

## ? 开源许可

本项目采用 MIT 许可证。详情请见 [LICENSE](https://github.com/AullChen/news_email_reader/blob/main/LICENSE) 文件。

## ? 致谢

- [CodeBuddy](https://www.codebuddy.ai/) - IDE
- [Claude AI](https://www.anthropic.com/) [OpenAI](https://openai.com/) [Gemini](https://gemini.google.com/) - 代码助手
- [Flutter](https://flutter.dev/) - 跨平台UI框架
- [Free-QWQ](https://qwq.aigpu.cn/) - 免费无限制分布式AI算力平台——提供本项目的默认大模型API
- [通用翻译免费API](https://api.aa1.cn/doc/translates.html) - 免费接口调用平台，提供本项目的默认翻译API

## ? 联系方式

- **项目主页**: [GitHub Repository](https://github.com/AullChen/news_email_reader)
- **问题反馈**: [Issues](https://github.com/AullChen/news_email_reader/issues)
- **功能建议**: [Discussions](https://github.com/AullChen/news_email_reader/discussions)

------

<div align="center">
  <p>如果这个项目对您有帮助、使您感兴趣或者给您带来了欢乐，请给我们一个 ??</p>
  <p>Made with ?? by AullChen</p>
</div>
