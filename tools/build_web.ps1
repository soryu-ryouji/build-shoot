## 导出 Web 版并套上横屏舞台。产物在 build/web，可直接交给站点发布。
## 用法：.\tools\build_web.ps1 [-Godot <Godot 控制台可执行文件>]

param(
	[string]$Godot = "F:\Environment\Godot\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if (-not (Test-Path $Godot)) {
	throw "找不到 Godot：$Godot（用 -Godot 指定路径）"
}

New-Item -ItemType Directory -Force build\web | Out-Null

& $Godot --headless --path . --export-release "Web" build/web/index.html
if ($LASTEXITCODE -ne 0) {
	throw "Web 导出失败，退出码 $LASTEXITCODE"
}

# Godot 默认入口改名，外层用 web/index.html 提供横屏舞台
Move-Item build\web\index.html build\web\app.html -Force
Copy-Item web\index.html build\web\index.html -Force

$total = (Get-ChildItem build\web -File | Measure-Object Length -Sum).Sum
Write-Output "导出完成：build/web（$([math]::Round($total / 1MB, 1)) MB）"
Write-Output "本地预览：python -m http.server 8060 --directory build/web"
