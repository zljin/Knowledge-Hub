# opencode Skill 编写完整指南

> 本文用「repo-arch-diagram（仓库架构图生成）」这个真实案例，手把手讲清写一个 opencode Skill 的所有步骤、原理和坑。

---

## 一、什么是 Skill

Skill 是 opencode 的「可复用提示词胶囊」：把一段精心打磨的指令 + 流程，封装成一个文件。
你不需要复述指令，只要说出触发词（如「生成架构图」「分析仓库」），opencode 就会自动把这份指令注入给 AI，让它按流程执行。

一句话：**Skill = 把「怎么做一件事」沉淀成 AI 能自动调用的能力。**

### Skill 的底层概念（三层理解）

**① 它是「一次性对话」→「可复用能力」的封装**
Skill 不是把提示词存起来这么简单，它把三样东西绑在一起：
- **指令**：高质量、分步骤、带质量标准的提示词
- **触发条件**：description 里的语义匹配（说人话就激活）
- **经验**：每次实际使用中踩的坑、补的规则，持续回写

**② 它是「思维过程的编译」**
你做大任务的 SOP（先调研 → 再输出 → 再质量校验）写成自然语言，就是提示词；收敛成有 frontmatter 的文件，就是把它编译成了「机器可重复执行的流程」。隐性知识 → 显性流程 → 可复用代码，这是知识沉淀的过程。

**③ 它是「工作记忆」的外挂**
单次对话的上下文（context）是有限的、会丢失的。Skill 把「长期有效的做法」放在模型之外，每次按需注入，相当于给 AI 装了一块「可换硬盘」。

> 一句话总结：**SKILL = 把你会做的事，变成 AI 也默认会做的事。**

---

## 二、Skill 放在哪里（目录结构）

opencode 只认特定位置的 `SKILL.md`（文件名必须精确叫 `SKILL.md`，`SKILL.md`/`skill.md` 会识别不到）：

| 作用域 | 路径 | 说明 |
|---|---|---|
| 项目内（推荐） | `<项目>/.opencode/skills/<名称>/SKILL.md` | 只在本项目生效，零配置 |
| 全局 | `~/.config/opencode/skills/<名称>/SKILL.md` | 所有项目可用 |
| 外部兼容 | `~/.claude/skills/<名称>/SKILL.md` | opencode 自动扫描 |

```
项目根目录/
└── .opencode/
    └── skills/
        └── repo-arch-diagram/   ← 目录名必须与 skill 名一致
            └── SKILL.md         ← 必须这个文件名
```

> 踩坑记录：项目根目录建 `skills/`（不带 `.opencode/` 前缀）**不会被识别**。
> 那是自定义位置，必须在 `opencode.json` 里注册 `"skills": { "paths": ["./skills"] }` 才生效。
> 自己项目内部一律用默认的 `.opencode/skills/`，零配置最省心。

---

## 三、SKILL.md 文件结构

一个最小的 Skill 长这样：

```markdown
---
name: repo-arch-diagram
description: 当用户给出一段 GitHub 仓库地址或本地代码路径并要求「生成架构图 / 分析仓库结构 / 分析项目架构」时使用。仅在明确要求分析代码仓库并产出架构图时触发，其他编程问题不要触发。
---

# 角色
你是一名资深软件架构师……

# 任务
……

## 第一步：……
```

### 关键：frontmatter 两行

- **`name`**（必填）：小写连字符，最多 64 字符，**必须与文件夹名一致**
- **`description`**（必填）：Skill 能不能被触发就看这一句。没写 description 的 Skill 会被直接过滤掉，永远不生效。

### description 怎么写（决定触发精准度）

写法公式：`当用户说「触发词 A」「触发词 B」时使用 + 何时不该用`

- 触发词要放具体关键词/文件名，让 AI 一眼对齐语义
- 结尾加一句反例抑制：**「不要在……时触发」**，避免误伤（我们初期写了 7 个触发词，选项太多、容易误触发，后来收敛成 1 句核心判定）
- 用第三人称写（`Use when…`），不要写 `I help with…`

---

## 四、完整编写步骤流程（实战版）

以本次「repo-arch-diagram」为例，完整走一遍：

### Step 1. 先在草稿文件里写提示词（prompt 阶段）
在 `prompt/` 下写一份自由格式的指令，反复打磨内容和措辞。
本案例经历了 4 轮迭代：
1. 初版只有 6 行（Mermaid + PlantUML 双输出）
2. 补充「角色设定」+「调研步骤」+ 范围控制 + 防幻觉约束
3. 加「输入源」：支持本地路径 / GitHub 地址，clone 到 `~/<年月日>_codes/<仓库名>`
4. 加「输出约定」：写到 `artifacts/<项目名>_architecture.md`，而不是随便贴

> 原则：**先把提示词在普通文档里写顺，再封装成 Skill**。Skill 只是把验证过的指令固定下来。

### Step 2. 建目录、写 SKILL.md
```bash
mkdir -p .opencode/skills/repo-arch-diagram
```
把验证过的提示词正文复制进 `SKILL.md`，加上 `name` 和精心打磨的 `description`。

### Step 3.（可选）对照官方 schema 校验
字段不确定就去查官方 schema：`https://opencode.ai/config.json`
（本次用的都是 skills 的标准字段，无需查表。）

### Step 4. 重启 opencode ⚠️
**配置不会热加载。** 创建 Skill 后当前会话里它并不存在，必须退出重启 opencode 才会被扫描到。
（本会话就是踩了这个坑——直接调用时返回 "Skill not found"，于是手动读文件执行。）

### Step 5. 实弹测试
重启后，用一句自然语言触发，观察：
- ✔ 是否被激活（AI 是否自动按 Skill 流程走）
- ✘ 有没有误触发（不该激活的场景检查）
- ✔ 产出是否符合预期（本例：`artifacts/gulimall-backend_architecture.md`）

### Step 6. 持续迭代，把经验回写进 Skill
测试中发现的问题要**回填到 SKILL.md 里**，让下一版更强：
- 发现 PlantUML 复杂图会布局死循环 → 规则里加「每张 PlantUML 图第一行必须 `!pragma layout smetana`」
- 发现「class 图必选」太死板 → 改成「component 图（宏观）+ sequence 图（微观）都生成」

这样 Skill 就从「能用」进化成「好用」，且每个知识点都固化下来了。

### Step 7. 提交 GitHub 版本管理
```bash
git add .opencode/skills/repo-arch-diagram/SKILL.md
git commit -m "feat: add repo-arch-diagram skill"
git push
```

---

## 五、Skill / Command / Agent 怎么选

| 类型 | 触发 | 适合 |
|---|---|---|
| **Skill** | 语义自动触发（说人话就能用） | 通用能力，如「生成架构图」「面试官出题」 |
| **Command** | 手动 `/命令名 参数`，可传参 | 参数明确、要确定性执行的脚本化操作 |
| **Agent** | 指定 agent 时生效，可有独立模型/权限 | 垂直角色（如 code review 专家）、需隔离权限的场景 |

选型口诀：
- 想「说一句话就自动干活」→ **Skill**
- 想「敲命令带参数、行为可控」→ **Command**
- 想「单独开个角色、不同模型、限制它不能改文件」→ **Agent**

---

## 六、经验清单（Checklist）

新建 Skill 前过一遍：

- [ ] 目录：`.opencode/skills/<name>/SKILL.md`（文件名严格 `SKILL.md`）
- [ ] frontmatter：`name` 与文件夹同名 + `description` 有触发词、有反例抑制
- [ ] 正文：角色 → 任务 → 分步流程 → 输出约定 → 质量标准，逐层清晰
- [ ] 有「什么情况不要做」的负向约束（防幻觉）
- [ ] 重启 opencode 后测试「能触发 + 不误触发」
- [ ] 踩坑经验回写进 SKILL.md
- [ ] git 提交存档

---

## 七、相关文件速查

- 本文案例制品：`artifacts/gulimall-backend_architecture.md`
- 提示词草稿历史：`prompt/repo-arch-diagram.md`（早期草稿，可留作对照）
- 可运行 Skill：`.opencode/skills/repo-arch-diagram/SKILL.md`