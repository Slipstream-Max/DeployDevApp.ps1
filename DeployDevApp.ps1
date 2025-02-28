Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ����������
$form = New-Object System.Windows.Forms.Form
$form.Text = "��������һ����װ����"
$form.Size = New-Object System.Drawing.Size(520,690)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei", 10)

# Ӧ�����ã���ʾ���� | Winget ID | ��װĿ¼��
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

# Ŀ¼ѡ��ؼ�
$labelDir = New-Object System.Windows.Forms.Label
$labelDir.Location = New-Object System.Drawing.Point(20, 10)
$labelDir.Size = New-Object System.Drawing.Size(200, 30)
$labelDir.Text = "ѡ��װ����Ŀ¼:"

$txtDir = New-Object System.Windows.Forms.TextBox
$txtDir.Location = New-Object System.Drawing.Point(20, 40)
$txtDir.Size = New-Object System.Drawing.Size(370, 30)
$txtDir.Text = "C:\Develop"

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(400, 40)
$btnBrowse.Size = New-Object System.Drawing.Size(90, 30)
$btnBrowse.Text = "���..."

# ���ѡ����壨����������
$groupApps = New-Object System.Windows.Forms.GroupBox
$groupApps.Location = New-Object System.Drawing.Point(20, 80)
$groupApps.Size = New-Object System.Drawing.Size(460, 360)
$groupApps.Text = "ѡ��Ҫ��װ�����"

$scrollPanel = New-Object System.Windows.Forms.Panel
$scrollPanel.Location = New-Object System.Drawing.Point(10, 20)
$scrollPanel.Size = New-Object System.Drawing.Size(420, 320)
$scrollPanel.AutoScroll = $true

# ��̬���ɸ�ѡ��
$yPos = 0
foreach ($app in $appConfig) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Location = New-Object System.Drawing.Point(10, $yPos)
    $cb.Size = New-Object System.Drawing.Size(360, 30)
    $cb.Text = $app.Name
    $cb.Tag = $app.ID  # �洢ʵ��ID
    $cb.Checked = $true
    $scrollPanel.Controls.Add($cb)
    $yPos += 30
}
$scrollPanel.AutoScrollMinSize = New-Object System.Drawing.Size(0, $yPos)
$groupApps.Controls.Add($scrollPanel)

# ������ʾ����
$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 450)
$txtLog.Size = New-Object System.Drawing.Size(460, 90)  # ��С�߶�
$txtLog.ReadOnly = $true

# ������
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 550)
$progressBar.Size = New-Object System.Drawing.Size(460, 30)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous

# ��װ��ť��λ�����ƣ�
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(20, 600)
$btnInstall.Size = New-Object System.Drawing.Size(100, 35)
$btnInstall.Text = "��ʼ��װ"

# �ؼ���ӵ�����
$form.Controls.AddRange(@(
    $labelDir, $txtDir, $btnBrowse, $groupApps, 
    $txtLog, $progressBar, $btnInstall
))

# ���Ŀ¼�¼�
$btnBrowse.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "ѡ�������װĿ¼"
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtDir.Text = $folderDialog.SelectedPath
    }
})

# ��װ�¼�����
$btnInstall.Add_Click({
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        [System.Windows.Forms.MessageBox]::Show("��Ҫ����ԱȨ�����У�", "����")
        return
    }

    $btnInstall.Enabled = $false
    $baseDir = $txtDir.Text
    $selectedIDs = $scrollPanel.Controls | Where-Object {
        $_ -is [System.Windows.Forms.CheckBox] -and $_.Checked
    } | ForEach-Object { $_.Tag }

    # ��������Ŀ¼
    if (-not (Test-Path $baseDir)) {
        New-Item -Path $baseDir -ItemType Directory | Out-Null
    }

    $total = $selectedIDs.Count
    $current = 0
    $progressBar.Value = 0

    foreach ($id in $selectedIDs) {
        $current++
        $app = $appConfig | Where-Object { $_.ID -eq $id }
        $installPath = Join-Path $baseDir $app.Path

        # ���½���
        $progressBar.Value = [math]::Min(100, [int]($current/$total*100))
        $txtLog.AppendText("���ڰ�װ [$current/$total] $($app.Name)...`n")
        $txtLog.ScrollToCaret()

        # ִ�а�װ
        try {
            $command = "winget install --id $id -e --accept-package-agreements --accept-source-agreements --location `"$installPath`""
            Invoke-Expression $command -ErrorAction Stop
            $txtLog.SelectionColor = [System.Drawing.Color]::Green
            $txtLog.AppendText("�� ��װ�ɹ�`n`n")
        }
        catch {
            $txtLog.SelectionColor = [System.Drawing.Color]::Red
            $txtLog.AppendText("�� ��װʧ��: $_`n`n")
        }
    }

    $progressBar.Value = 100
    [System.Windows.Forms.MessageBox]::Show("���в�������ɣ�", "��ʾ")
    $btnInstall.Enabled = $true
})

# ��ʾ����
[void]$form.ShowDialog()
