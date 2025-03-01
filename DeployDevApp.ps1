Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 主窗体设置
$form = New-Object System.Windows.Forms.Form
$form.Text = "开发环境一键安装工具"
$form.Size = New-Object System.Drawing.Size(520,690)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)

# 应用配置（显示名称 | Winget ID | 安装目录）
$appConfig = @(
    [PSCustomObject]@{Name="Miniconda3"; ID="Anaconda.Miniconda3"; Path="Miniconda3"},
    [PSCustomObject]@{Name="UV"; ID="astral-sh.uv"; Path="uv"},
    [PSCustomObject]@{Name="LLVM"; ID="LLVM.LLVM"; Path="llvm"},
    [PSCustomObject]@{Name="MSYS2"; ID="MSYS2.MSYS2"; Path="msys2"},
    [PSCustomObject]@{Name="Rustup"; ID="Rustlang.Rustup"; Path="rustup"},
    [PSCustomObject]@{Name="JetBrains ToolBox"; ID="JetBrains.Toolbox"; Path="jetBrains\toolbox"},
    [PSCustomObject]@{Name="VSCode"; ID="Microsoft.VisualStudioCode"; Path="vscode"},
    [PSCustomObject]@{Name="VS2022 Build Tool"; ID="Microsoft.VisualStudio.2022.BuildTools"; Path="vs2022_buildtools"}
)

# 目录选择控件
$labelDir = New-Object System.Windows.Forms.Label
$labelDir.Location = New-Object System.Drawing.Point(20, 10)
$labelDir.Size = New-Object System.Drawing.Size(200, 30)
$labelDir.Text = "选择基础安装目录:"

$txtDir = New-Object System.Windows.Forms.TextBox
$txtDir.Location = New-Object System.Drawing.Point(20, 40)
$txtDir.Size = New-Object System.Drawing.Size(370, 30)
$txtDir.Text = "C:\Develop"

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(400, 40)
$btnBrowse.Size = New-Object System.Drawing.Size(90, 30)
$btnBrowse.Text = "浏览..."

# 软件选择面板（带滚动条）
$groupApps = New-Object System.Windows.Forms.GroupBox
$groupApps.Location = New-Object System.Drawing.Point(20, 80)
$groupApps.Size = New-Object System.Drawing.Size(460, 360)
$groupApps.Text = "选择要安装的软件"

$scrollPanel = New-Object System.Windows.Forms.Panel
$scrollPanel.Location = New-Object System.Drawing.Point(10, 20)
$scrollPanel.Size = New-Object System.Drawing.Size(420, 320)
$scrollPanel.AutoScroll = $true

# 动态生成复选框
$yPos = 0
foreach ($app in $appConfig) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Location = New-Object System.Drawing.Point(10, $yPos)
    $cb.Size = New-Object System.Drawing.Size(360, 30)
    $cb.Text = $app.Name
    $cb.Tag = $app.ID  # 存储实际ID
    $cb.Checked = $true
    $scrollPanel.Controls.Add($cb)
    $yPos += 30
}
$scrollPanel.AutoScrollMinSize = New-Object System.Drawing.Size(0, $yPos)
$groupApps.Controls.Add($scrollPanel)

# 进度显示区域
$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 450)
$txtLog.Size = New-Object System.Drawing.Size(460, 90)  # 调小高度
$txtLog.ReadOnly = $true

# 进度条
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 550)
$progressBar.Size = New-Object System.Drawing.Size(460, 30)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous

# 安装按钮
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(20, 600)
$btnInstall.Size = New-Object System.Drawing.Size(100, 35)
$btnInstall.Text = "开始安装"

# 控件添加到窗体
$form.Controls.AddRange(@(
    $labelDir, $txtDir, $btnBrowse, $groupApps, 
    $txtLog, $progressBar, $btnInstall
))

# 浏览目录事件
$btnBrowse.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "选择基础安装目录"
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtDir.Text = $folderDialog.SelectedPath
    }
})

# 安装事件处理
$btnInstall.Add_Click({
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        [System.Windows.Forms.MessageBox]::Show("需要管理员权限运行！", "警告")
        return
    }

    $btnInstall.Enabled = $false
    $baseDir = $txtDir.Text
    $selectedIDs = $scrollPanel.Controls | Where-Object {
        $_ -is [System.Windows.Forms.CheckBox] -and $_.Checked
    } | ForEach-Object { $_.Tag }

    # 创建基础目录
    if (-not (Test-Path $baseDir)) {
        New-Item -Path $baseDir -ItemType Directory | Out-Null
    }

    $total = $selectedIDs.Count
    $current = 0
    $progressBar.Value = 0

    # 检测系统架构
    $a = [System.Reflection.Assembly]::LoadWithPartialName("System.Runtime.InteropServices.RuntimeInformation")
    $t = $a.GetType("System.Runtime.InteropServices.RuntimeInformation")
    $p = $t.GetProperty("OSArchitecture")
    $osArch = $p.GetValue($null).ToString()
    $txtLog.AppendText("检测到系统架构: $osArch`n")

    foreach ($id in $selectedIDs) {
        $current++
        $app = $appConfig | Where-Object { $_.ID -eq $id }
        $installPath = Join-Path $baseDir $app.Path

        # 更新进度
        $progressBar.Value = [math]::Min(100, [int]($current/$total*100))
        $txtLog.AppendText("正在安装 [$current/$total] $($app.Name)...`n")
        $txtLog.ScrollToCaret()

        # 执行安装
        try {
            if ($id -eq "astral-sh.uv") {
                # UV的特殊安装方式
                $env:UV_INSTALL_DIR = $installPath
                powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" -ErrorAction Stop
                $txtLog.SelectionColor = [System.Drawing.Color]::Green
                $txtLog.AppendText("√ 安装成功 (使用官方脚本)`n`n")
            }
            elseif ($id -eq "LLVM.LLVM" -and $osArch -eq "Arm64") {
                # ARM64架构下的LLVM安装，优先尝试arm64版本
                $txtLog.AppendText("检测到ARM64架构，尝试安装ARM64版本...`n")
                try {
                    $command = "winget install --id $id -e --accept-package-agreements --accept-source-agreements --architecture arm64 --location `"$installPath`""
                    Invoke-Expression $command -ErrorAction Stop
                    $txtLog.SelectionColor = [System.Drawing.Color]::Green
                    $txtLog.AppendText("√ ARM64版本安装成功`n`n")
                }
                catch {
                    $txtLog.SelectionColor = [System.Drawing.Color]::Orange
                    $txtLog.AppendText("! ARM64版本安装失败，回退到默认版本: $_`n")
                    # 回退到默认安装
                    $command = "winget install --id $id -e --accept-package-agreements --accept-source-agreements --location `"$installPath`""
                    Invoke-Expression $command -ErrorAction Stop
                    $txtLog.SelectionColor = [System.Drawing.Color]::Green
                    $txtLog.AppendText("√ 默认版本安装成功`n`n")
                }
            }
            else {
                # 其他应用的默认安装方式
                $command = "winget install --id $id -e --accept-package-agreements --accept-source-agreements --location `"$installPath`""
                Invoke-Expression $command -ErrorAction Stop
                $txtLog.SelectionColor = [System.Drawing.Color]::Green
                $txtLog.AppendText("√ 安装成功`n`n")
            }
        }
        catch {
            $txtLog.SelectionColor = [System.Drawing.Color]::Red
            $txtLog.AppendText("× 安装失败: $_`n`n")
        }
    }

    $progressBar.Value = 100
    [System.Windows.Forms.MessageBox]::Show("所有操作已完成！", "提示")
    $btnInstall.Enabled = $true
})

# 显示窗体
[void]$form.ShowDialog()
