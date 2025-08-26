## 文件编辑与补丁策略（Windows 零确认）
- 禁止使用 `apply_patch` 或任何 heredoc 形式的 `apply_patch` 命令来修改文件；不要触发结构化补丁审批。
- 一律使用 shell 命令进行编辑：
  - Windows/PowerShell：`Set-Content`、`Add-Content`、`[IO.File]::WriteAllText(...)`、`Out-File -Encoding UTF8` 等；
  - 或通过 `echo` / `type` / 重定向（`>`/`>>`）组合创建与覆盖文件；
  - 多行内容优先使用 PowerShell here-string（@"..."@）后写入文件。
- 涉及重命名/删除/移动：使用 `Move-Item`、`Remove-Item`、`Copy-Item` 等标准命令。
- 需要展示差异：在回答中渲染简要 diff 文本，不调用 `apply_patch`。
- 原因：Windows 无系统沙箱时，`apply_patch` 会触发确认；为实现零确认，将其禁用并改走普通命令路径。

