# 执行计划：单例功能

## 目标

在 `src/main.zig` 的 `wWinMain` 入口处用命名互斥体实现单例守卫：重复实例静默退出，首实例不受影响。不改构建配置。

## 前置检查（Review Gate 1）

- [ ] `zig build` 基线通过。

## 执行清单（有序）

### Step 1 — 常量

- 在常量区新增：
  - `ERROR_ALREADY_EXISTS: u32 = 183`
  - `SINGLETON_MUTEX_NAME_DATA` / `SINGLETON_MUTEX_NAME`（宽字符串 `CClose_Singleton_Mutex_v1`，沿用 `CLASS_NAME_DATA` 的 `@ptrCast` 模式）。

### Step 2 — extern 声明

- `kernel32`：`CreateMutexW(lpMutexAttributes: ?*anyopaque, bInitialOwner: BOOL, lpName: ?LPCWSTR) ?HANDLE`、`GetLastError() u32`。

### Step 3 — 全局状态

- `var g_singleton_mutex: ?HANDLE = null;`（注释：持有至进程退出，内核自动释放）。

### Step 4 — 入口守卫

- `wWinMain` 最顶部（`SetProcessDPIAware` 之前）新增：
  - `CreateMutexW(null, 0, SINGLETON_MUTEX_NAME)`。
  - `GetLastError() == ERROR_ALREADY_EXISTS` → `return 0`（静默退出）。
  - 否则句柄存入 `g_singleton_mutex`（mutex 为 null 时容错继续）。

### Step 5 — 构建验证

- [ ] `zig build` 与 `zig build -Doptimize=ReleaseSafe` 均通过。

### Review Gate 2（质量检查）

- [ ] 守卫位于所有副作用（窗口/钩子/托盘/类注册）之前。
- [ ] 第二个实例路径不创建任何资源。
- [ ] extern 签名与 Win32 一致（`.winapi` 调用约定）。

## 验证命令

```bash
zig version
zig build
zig build -Doptimize=ReleaseSafe
```

**双实例冒烟测试**：
1. 启动第一个实例 `./zig-out/bin/CClose.exe`，确认进程存活。
2. 启动第二个实例，`sleep 2` 后确认系统仍只有 1 个 `CClose.exe` 进程（第二个已静默退出）。
3. 结束第一个实例后，再次启动新实例，确认能正常存活（无残留锁）。

## 回滚点

- 仅改动 `src/main.zig`；如出问题，`git checkout -- src/main.zig` 整体回滚。
- 既有逻辑（钩子/托盘/置顶）未动，回滚后与功能前一致。
