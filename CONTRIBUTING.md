# 贡献指南

我们非常欢迎您为新闻邮件阅读器项目做出贡献！感谢您的时间和热情。

在提交贡献之前，请花些时间阅读以下指南，以确保您的贡献过程顺利且有效。

## 行为准则

我们致力于为所有贡献者和用户提供一个友好、安全和热情的环境。请遵守我们的 [行为准则](CODE_OF_CONDUCT.md)（稍后创建）。

## 如何贡献

我们欢迎各种形式的贡献，包括但不限于：
- 报告 Bug
- 提交功能需求
- 撰写或改进文档
- 提交 Pull Request (PR)

### 报告 Bug

如果您发现了 Bug，请通过提交 Issue 的方式告知我们。一个好的 Bug 报告应包含以下内容：
- **清晰的标题**: 简要描述问题。
- **复现步骤**: 详细说明如何一步步复现该 Bug。
- **期望行为**: 描述在正常情况下应该发生什么。
- **实际行为**: 描述实际发生了什么，并附上截图或日志（如果可能）。
- **您的环境**: 提供您的设备、操作系统和应用版本信息。

### 提交 Pull Request (PR)

我们非常欢迎您通过 PR 的方式为项目贡献代码。请遵循以下流程：

1.  **Fork 项目**: 将本仓库 Fork 到您自己的 GitHub 账户。
2.  **克隆您的 Fork**:
    ```bash
    git clone https://github.com/your-username/news_email_reader.git
    ```
3.  **创建新分支**:
    ```bash
    git checkout -b feature/your-feature-name
    ```
    或者
    ```bash
    git checkout -b fix/your-bug-fix-name
    ```
4.  **进行修改**: 在新分支上进行您的代码修改。
5.  **遵守代码风格**: 确保您的代码遵循项目现有的代码风格和规范。
    - 使用 `flutter format` 格式化您的 Dart 代码。
    - 遵循有效的 Dart 编程风格指南。
6.  **提交代码**:
    ```bash
    git commit -m "feat: 添加了某个很棒的功能"
    ```
    我们推荐使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范来撰写提交信息。
7.  **推送到您的 Fork**:
    ```bash
    git push origin feature/your-feature-name
    ```
8.  **创建 Pull Request**: 在 GitHub 上打开一个 Pull Request，将其指向本仓库的 `main` 分支。请在 PR 描述中清晰地说明您的修改内容和目的。

## 开发环境搭建

请参考 `README.md` 文件中的 [安装指南](#-安装指南) 部分来搭建您的本地开发环境。

## 代码风格要求

- **格式化**: 所有 Dart 代码都应使用 `flutter format .` 进行格式化。
- **命名规范**:
    - 文件名、类名、枚举、扩展等使用 `UpperCamelCase`。
    - 库、包、目录、源文件名使用 `lowercase_with_underscores`。
    - 变量名、方法名、参数名使用 `lowerCamelCase`。
- **注释**: 为公共 API 和复杂的逻辑添加清晰的文档注释。

感谢您的贡献！
