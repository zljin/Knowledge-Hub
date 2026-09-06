# OpenAI-compatible CLI — MCP 配置实操速查

> 保存目的：重启 opencode 后快速对上，不用重新翻聊天记录。

## 配置位置
`~/.config/opencode/opencode.jsonc`

## 当前已配的 MCP（2 个）

```jsonc
{
  "mcp": {
    "playwright": {
      "type": "local",
      "command": ["npx", "-y", "@playwright/mcp@latest"],
      "enabled": true
    },
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "environment": { "GITHUB_PERSONAL_ACCESS_TOKEN": "{env:GITHUB_TOKEN}" },
      "enabled": true
    }
  }
}
```

### playwright（浏览器自动化）
- 能力：打开网页、截图、点击、填表单、读取网络请求、执行 JS
- 服务端：`@playwright/mcp@latest`（官方，随 npx 即时拉取最新版）
- 使用姿势：「用 playwright 打开 <url> 并截图」「读取这个页面」「点击/输入……」

### github（GitHub API 操作）
- 能力：读写仓库文件、建分支 / PR / issue、查用户 / 仓库、搜索代码
- 服务端：`@modelcontextprotocol/server-github`（官方）
- 鉴权：通过 `GITHUB_PERSONAL_ACCESS_TOKEN` 环境变量传给子进程
- ⚠️ **必须用 classic token（`ghp_` 前缀）**。Fine-grained token（`github_pat_` 前缀）跑写操作会失败（见下方「实操记录」）
- 使用姿势：「创建分支 + PR」「读 github.com/zljin/Knowledge-Hub 的信息」「查 issue #xx」

## Token 环境变量
- 位置：`~/.zshrc` 里的 `export GITHUB_TOKEN="..."`，classic token（`ghp_`，40 位）已验证有效（`/user` 200）
- ⚠️ **类型必须是 classic**，不要用 fine-grained（`github_pat_`）——官方 MCP server 按 `repo` scope 方式鉴权，fine-grained 会失败
- ⚠️ opencode 启动时必须已 `source ~/.zshrc`，否则 MCP 子进程拿到的 `GITHUB_TOKEN` 是**空**的 → 任何写操作报 `Authentication Failed`。**换 token 后必须重启 opencode**

### 生成 token 步骤（classic）
1. GitHub 右上角头像 → `Settings` → `Developer settings` → `Personal access tokens` → `Tokens (classic)`
2. `Generate new token (classic)`，填名字和过期时间
3. 勾选 scopes：
   - `repo`（或至少 `public_repo`，读写仓库、PR、issue 必需）
   - 需要组织数据时加 `read:org`
   - 不需要 `admin` 相关权限
4. 生成后立即复制，只显示一次
5. 写入 shell 配置：`echo 'export GITHUB_TOKEN="ghp_xxx"' >> ~/.zshrc && source ~/.zshrc`
6. 验证（见下节）通过后，**重启 opencode**

### 快速验证 token
```bash
# 检查类型与长度：classic = ghp_ (40位)，fine-grained = github_pat_ (93位)
echo "prefix: ${GITHUB_TOKEN:0:12}  len: ${#GITHUB_TOKEN}"
# API 验证
curl -s -D - -o /dev/null -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user | grep -i -E "^(HTTP|x-oauth-scopes)"
# 期望：HTTP 200 + x-oauth-scopes 里包含 repo
```
返回码含义：
| 返回码 | 含义 |
| --- | --- |
| 200 + `repo` scope | 正常，可读写仓库/PR |
| 401 | token 失效/被 revoke，或**值为空**（没 source 或没设置） |
| 403 | token 有效但权限不足（常见于 fine-grained 没勾对应权限） |

## 关键规则
- `command` 必须是**字符串数组**，不能是单个字符串
- `type` 必填：`local`（本地进程）/ `remote`（远程 URL）
- Key 用 `{env:变量名}` 插值，别明文写死
- **改配置 / 换 token / 重启后才生效**；改完需退出重开 opencode
- opencode 的环境变量继承自启动它的 shell：必须先 `source ~/.zshrc` 再启动 opencode

## 重启后怎么验证
1. 输入 `/exit` 或 `Ctrl+C` 退出，重新 `opencode`
2. 测试 Playwright：让我「用 playwright 打开 https://example.com 并截图」
3. 测试 GitHub：让我「用 GitHub MCP 读 github.com/zljin/Knowledge-Hub 的信息」

### 上次实测结果（classic token，验证通过 ✅）
- ✅ `$GITHUB_TOKEN` = `ghp_` 前缀、40 位，`/user` 返回 200，scopes 含完整 `repo`
- ✅ GitHub MCP 读取公开仓库（无鉴权也能过）：`github_get_file_contents` 返回仓库文件列表
- ✅ 用 REST API 建 PR（`POST /pulls`）成功：https://github.com/zljin/Knowledge-Hub/pull/1
- ✅ git 凭据链里的 OAuth token（`gho_`，存于 macOS keychain）可直接建 PR / 写仓库

## 实操记录（2026-08-29，本次排查全流程）
1. 重启 opencode 后，`github_get_file_contents` 读公开仓库**成功**（公开数据匿名可读，不代表 token 有效）
2. 用 GitHub MCP 建 PR 报错 `Authentication Failed: Requires authentication`
3. 排查发现当前 opencode 环境里 `$GITHUB_TOKEN` 是**空**的 → 空 token 调 API 返回 401
4. `~/.zshrc` 里实际是 **fine-grained token**（`github_pat_` 前缀，93 位），curl `/user` 返回 401
   —— 该 token 疑似已被 revoke（曾明文暴露在聊天里）
5. git 凭据链（`gho_` OAuth token）有效 → 用它走 REST API 建 PR 成功
6. 用户重新生成 **classic token**（`ghp_`，40 位，含 `repo` scope），curl 验证 200 ✅
7. 结论：① MCP server 要 **classic token**；② token 必须是 opencode 启动时就注入（先 source 再启动）

⚠️ 下一步待办：重启 opencode 后，用「GitHub MCP 建 PR / 读文件」验证 classic token 在 MCP 内生效。

## 诊断与排查
| 现象 | 可能原因 | 排查方法 |
| --- | --- | --- |
| 工具列表里没有某 MCP 的工具 | 未重启 / enabled 为 false | 改配置后完全退出重开；检查 `enabled: true` |
| MCP 写操作报 `Authentication Failed` | `GITHUB_TOKEN` 为空（没 source / 没设）或类型不对 | `echo ${GITHUB_TOKEN:0:12}` 看前缀；确认 `ghp_`；确认启动 opencode 前 source 过 |
| 用 fine-grained token 报鉴权失败 | MCP server 只认 classic token | 换 `Tokens (classic)` 生成 `ghp_`，勾 `repo` scope |
| curl 返回 401 | token 失效/被 revoke/为空 | 用文档「快速验证 token」测试；空了就重新生成 |
| curl 返回 403 | token 有效但权限不足 | 检查 scope / fine-grained 的仓库与权限勾选 |
| npx 拉取失败 / 网络问题 | 网络代理、缓存损坏 | `npx -y <server>` 手动跑一次看报错 |
| JSONC 配置报语法错 | 多写逗号 / command 不是数组 | 用编辑器格式化检查，末尾不要逗号 |

## 配置 remote MCP（可选）
```jsonc
{
  "mcp": {
    "example-remote": {
      "type": "remote",
      "url": "https://example.com/mcp"
    }
  }
}
```
`type: remote` 走 HTTP/SSE，无需本地 command；url 需为 MCP 服务端点。

## 常用 MCP（备选，未装）
- 数据库：`["npx","-y","@modelcontextprotocol/server-postgres"]`，`DATABASE_URL` 环境变量
- 官方服务端索引：见 https://github.com/modelcontextprotocol/servers