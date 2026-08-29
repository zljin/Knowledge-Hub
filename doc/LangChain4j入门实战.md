# LangChain4j 入门实战（AI 编程小助手项目）

> 来源：微信文章《用 Java 开发 AI 项目，太爽了！》作者：程序员鱼皮
> 原链接：https://mp.weixin.qq.com/s/7cNh7ndeiWiHBjnkTkz_Zg
> 留档：`doc/raw/mp_weixin_qq_com_s_7cNh7ndeiWiHBjnkTkz_Zg.md`
> 配套：视频 B站 BV1X4GGziEyr · 开源代码 github.com/liyupi/ai-code-helper

## 一句话主旨

用「AI 编程小助手」一个实战项目串起 **LangChain4j**（Java 主流 AI 应用开发框架）的几乎全部主流玩法：基础对话、多模态、AI Service、会话记忆、结构化输出、RAG 知识库、工具调用、MCP、护轨、SSE 流式输出。

## 前置知识

- Java 21 + Spring Boot 3.5.x 基础（IoC、@Bean、@Configuration、@Resource）
- 会依赖注入即可，不需要懂 LLM 底层原理
- 有任意一个大模型的 API Key（文中用阿里云百炼 DashScope）

## 核心概念速查

| 概念 | 一句话解释 |
|------|-----------|
| ChatModel | 最底层，负责和大模型交互的入口对象 |
| AI Service | 招牌模式——写接口 + 注解，框架用 Java 反射生成代理，免手拼消息 |
| ChatMemory | 会话记忆，`MessageWindowChatMemory` 最多留 N 条自动淘汰 |
| 结构化输出 | 改返回值类型（`record Report(...)`），框架自动把文本转 JSON/对象 |
| RAG | 给 AI 配「小抄本」，回答前先查自己的知识库，治时效性和幻觉 |
| 工具调用 (Tool Calling) | 写 `@Tool` 方法，AI 提出要求、你的程序真正执行 |
| MCP | AI 应用的「USB 接口」，标准化接入外部工具/服务 |
| 护轨 (Guardrail) | 拦截器：请求前鉴权、响应后记日志 |
| SSE | 流式输出，打字机效果 |

## 实操脉络

1. **部署**：Java 21 + Spring Boot 3.5.x，配 `application-local.yml`（敏感配置 gitignore）
2. **最简**：ChatModel → 对话；SystemMessage 设人格/角色
3. **核心**：AI Service（必须掌握）→ `@SystemMessage` + `AiServices.create`，反射代理
4. **增强**：会话记忆 → 结构化输出 → RAG（极简/标准/进阶三档）→ 工具/MCP → 护轨 → SSE 流式
5. **前端提效**：Cursor + 写详细 Prompt 生成 Vue3 前端，提示里要写「用 Windows 命令」

## 关键技术片段

### AI Service（核心模式）
```java
public interface AiCodeHelperService {
    @SystemMessage(fromResource = "system-prompt.txt")
    String chat(String userMessage);
}
// 工厂
AiCodeHelperService svc = AiServices.builder(AiCodeHelperService.class)
        .chatModel(qwenChatModel)
        .chatMemory(chatMemory)
        .contentRetriever(contentRetriever)      // RAG
        .tools(new InterviewQuestionTool())      // 工具调用
        .toolProvider(mcpToolProvider)           // MCP
        .streamingChatModel(qwenStreamingChatModel) // 流式
        .chatMemoryProvider(memoryId -> MessageWindowChatMemory.withMaxMessages(10))
        .build();
```
关键点：所有高级能力都是「给 AI Service 装配组件」，这与 Spring AI 是一套心智。

### 标准版 RAG（学习用内存，生产换独立存储）
```java
DocumentByParagraphSplitter splitter = new DocumentByParagraphSplitter(1000, 200);
EmbeddingStoreIngestor ingestor = EmbeddingStoreIngestor.builder()
        .documentSplitter(splitter)
        .textSegmentTransformer(seg -> TextSegment.from(
            seg.metadata().getString("file_name") + "\n" + seg.text(), seg.metadata()))
        .embeddingModel(qwenEmbeddingModel)
        .embeddingStore(embeddingStore)
        .build();
ingestor.ingest(documents);
ContentRetriever retriever = EmbeddingStoreContentRetriever.builder()
        .embeddingStore(embeddingStore).embeddingModel(qwenEmbeddingModel)
        .maxResults(5).minScore(0.75).build();
```

## 易错点（实测坑）

- **多模态取决于大模型本身**：qwen-max 看不了图，框架适配也一般
- **跨域**：`.allowedOrigins("*")` 与 `.allowCredentials(true)` 互斥，必须用 `allowedOriginPatterns("*")`
- **Qwen 日志**：QwenChatModel 不支持 `logRequests`，只能自建 Listener + 手动构造 QwenChatModel
- **MCP 依赖缺失**：官方文档没写，需自找 `langchain4j-mcp`；体验一般，不建议用 Java 开发 MCP
- **结构化输出**：JSON Schema 模式最可靠；Prompt 拼接模式偶发不准；流式不支持结构化输出
- **内存存储**：重启即丢，生产建议 RAG 用 PG Vector、记忆用 MySQL

## 待补充 / 关联

- 与 **Spring AI** 是二选一对照框架，宜补一篇「选型对比」笔记
- 本文所有存储/记忆是内存实现，生产落地迁移成本待深挖

## 重点问题清单

| # | 问题 | 状态 |
|---|------|------|
| 1 | AI Service 反射代理到底帮你做了哪些转换？ | 待答 |
| 2 | LangChain4j vs Spring AI 实际开发怎么选？ | 待答 |
| 3 | 什么项目值得上 RAG + MCP，什么场景过度设计？ | 待答 |
| 4 | 内存存储 → MySQL/PG Vector 的迁移要改哪些代码？ | 待答 |
| 5 | 工具调用在上生产的可靠性（超时/限流/降级/合规）怎么设计？ | 待答 |
