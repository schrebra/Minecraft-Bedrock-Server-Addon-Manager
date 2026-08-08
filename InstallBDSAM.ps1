<#
.SYNOPSIS
    Bootstraps a modern, split-view GUI-based Bedrock Dedicated Server Addon Manager C# project, builds it, and runs it.
#>

[CmdletBinding()]
param()

 $ErrorActionPreference = 'Stop'

# ─── Configuration ──────────────────────────────────────────────────────────
 $ProjectDir = "C:\Bedrock\BedrockDedicatedServerAddonManager"
 $Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# ─── Helper Function ────────────────────────────────────────────────────────
function Write-ProjectFile {
    param (
        [string]$RelativePath,
        [string]$Content
    )
    $fullPath = Join-Path $ProjectDir $RelativePath
    $dir = Split-Path $fullPath -Parent
    
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    
    [System.IO.File]::WriteAllText($fullPath, $Content, $Utf8NoBom)
    Write-Host "[SETUP] Wrote file: $RelativePath" -ForegroundColor DarkGray
}

try {
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host " Bedrock Dedicated Server Addon Manager - Bootstrapper" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan
    
    # ─── 1. Create Project Directory ────────────────────────────────────────
    Write-Host "`n[1/4] Creating project directory..." -ForegroundColor Yellow
    if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) {
        New-Item -Path $ProjectDir -ItemType Directory -Force | Out-Null
    }
    Write-Host "      Directory: $ProjectDir" -ForegroundColor Green

    # ─── 2. Generate Files ──────────────────────────────────────────────────
    Write-Host "`n[2/4] Generating project files..." -ForegroundColor Yellow

    # BedrockDedicatedServerAddonManager.csproj
    $csproj = @'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <UseWindowsForms>true</UseWindowsForms>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>BedrockDedicatedServerAddonManager</AssemblyName>
    <RootNamespace>BedrockDedicatedServerAddonManager</RootNamespace>
  </PropertyGroup>

</Project>
'@
    Write-ProjectFile "BedrockDedicatedServerAddonManager.csproj" $csproj

    # Program.cs
    $programCs = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;
using BedrockDedicatedServerAddonManager.Models;

namespace BedrockDedicatedServerAddonManager;

// ─── Custom Flat Panel ──────────────────────────────────────────────────────
public class FlatPanel : Panel
{
    public Color BorderColor { get; set; } = Color.FromArgb(203, 213, 225); // Slate-300
    public float Progress { get; set; } = 0f; // 0.0 to 1.0
    public Color ProgressColor { get; set; } = Color.FromArgb(167, 243, 208); // Green-200
    public Color DragColor { get; set; } = Color.FromArgb(220, 252, 231);     // Green-50
    public Color FillColor { get; set; } = Color.White;

    private bool _isDragging = false;
    public bool IsDragging 
    { 
        get => _isDragging; 
        set { _isDragging = value; BackColor = _isDragging ? DragColor : FillColor; Invalidate(); } 
    }

    public FlatPanel()
    {
        DoubleBuffered = true;
        BackColor = FillColor;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        var g = e.Graphics;
        var rect = new Rectangle(0, 0, Width - 1, Height - 1);

        // Progress Bar Fill
        if (Progress > 0)
        {
            int fillWidth = (int)(Width * Math.Clamp(Progress, 0, 1));
            if (fillWidth > 0)
            {
                using var progBrush = new SolidBrush(ProgressColor);
                g.FillRectangle(progBrush, 0, 0, fillWidth, Height);
            }
        }

        // Border
        using var pen = new Pen(BorderColor, 1);
        g.DrawRectangle(pen, rect);
    }
}

// ─── Custom Flat Button (Inherits from Control to avoid OS Button Artifacts) ─────────────────────────────────────────────────────
public class FlatButton : Control
{
    public Color PrimaryColor { get; set; } = Color.FromArgb(129, 140, 248);
    public Color HoverColor { get; set; } = Color.FromArgb(99, 102, 241);
    public Color DownColor { get; set; } = Color.FromArgb(79, 70, 229);

    private Color _currentColor;

    public FlatButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
        _currentColor = PrimaryColor;
        BackColor = Color.Transparent;
        ForeColor = Color.White;
        Font = new Font("Segoe UI Semibold", 9F);
        Size = new Size(150, 38); // Strict uniform size
        Anchor = AnchorStyles.None; // Prevent stretching
        Cursor = Cursors.Hand;
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        _currentColor = HoverColor;
        Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        _currentColor = PrimaryColor;
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        _currentColor = DownColor;
        Invalidate();
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        _currentColor = HoverColor;
        Invalidate();
        base.OnMouseUp(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        
        using var brush = new SolidBrush(_currentColor);
        g.FillRectangle(brush, 0, 0, Width, Height);

        TextRenderer.DrawText(g, Text, Font, ClientRectangle, ForeColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
    }
}

// ─── Main Program ───────────────────────────────────────────────────────────
public static class Program
{
    [STAThread]
    public static void Main()
    {
        try
        {
            ApplicationConfiguration.Initialize();
            Application.Run(new MainForm());
        }
        catch (Exception ex)
        {
            MessageBox.Show($"A fatal error occurred:\n\n{ex}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}

public class MainForm : Form
{
    private readonly RichTextBox _logTxt;
    private readonly TextBox _serverPathTxt;
    private readonly CheckBox _overwriteChk;
    private readonly FlatPanel _dropPanel;
    private readonly Label _dropLabel;
    private readonly ToolStripStatusLabel _statusLabel;
    private readonly ToolStripProgressBar _progressBar;
    
    private readonly ListView _packsListView;
    private readonly SplitContainer _mainSplit;

    private static readonly string ConfigPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "BedrockDedicatedServerAddonManager", "config.txt");

    public MainForm()
    {
        Text = "Bedrock Dedicated Server Addon Manager";
        Width = 1375;  // 25% larger
        Height = 940;  // 25% larger
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(1100, 750);
        BackColor = Color.FromArgb(226, 232, 240); // Slate-200 Background
        ForeColor = Color.FromArgb(51, 65, 85);    // Slate-800
        DoubleBuffered = true;
        Font = new Font("Segoe UI", 9F);

        // ─── Main Layout Table ──────────────────────────────────────────
        var mainLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            BackColor = Color.FromArgb(226, 232, 240),
            Padding = new Padding(20)
        };
        mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 60));  // Header
        mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 80));  // Settings
        mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));  // Split Container

        // ─── Header Panel ───────────────────────────────────────────────
        var headerPanel = new Panel 
        { 
            Dock = DockStyle.Fill, 
            BackColor = Color.FromArgb(226, 232, 240) 
        };
        
        var titleLbl = new Label 
        { 
            Text = "BEDROCK DEDICATED SERVER ADDON MANAGER", 
            Font = new Font("Segoe UI Semibold", 16F), 
            ForeColor = Color.FromArgb(51, 65, 85), 
            Dock = DockStyle.Fill, 
            TextAlign = ContentAlignment.MiddleLeft 
        };
        headerPanel.Controls.Add(titleLbl);

        // ─── Settings Panel ─────────────────────────────────────────────
        var settingsPanel = new FlatPanel
        {
            Dock = DockStyle.Fill,
            FillColor = Color.White,
            BorderColor = Color.FromArgb(203, 213, 225),
            Margin = new Padding(0, 0, 0, 20)
        };

        var settingsLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 4,
            RowCount = 1,
            Padding = new Padding(20, 10, 20, 10),
            BackColor = Color.White
        };
        settingsLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 140)); // Label
        settingsLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));  // TextBox
        settingsLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 170)); // Browse Btn
        settingsLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 180)); // Checkbox

        var pathLbl = new Label 
        { 
            Text = "Server Path", 
            Font = new Font("Segoe UI Semibold", 10F), 
            ForeColor = Color.FromArgb(100, 116, 139), 
            Dock = DockStyle.Fill, 
            TextAlign = ContentAlignment.MiddleLeft,
            BackColor = Color.White
        };
        
        _serverPathTxt = new TextBox 
        { 
            Dock = DockStyle.Fill, 
            BackColor = Color.FromArgb(248, 249, 252),
            ForeColor = Color.FromArgb(51, 65, 85),
            BorderStyle = BorderStyle.FixedSingle,
            Font = new Font("Segoe UI", 10F),
            Margin = new Padding(0, 8, 20, 8)
        };

        var browseBtn = new FlatButton
        {
            Text = "Browse...",
            PrimaryColor = Color.FromArgb(129, 140, 248),
            HoverColor = Color.FromArgb(99, 102, 241)
        };
        browseBtn.Click += BrowseBtn_Click;

        _overwriteChk = new CheckBox 
        { 
            Text = "Overwrite existing", 
            Font = new Font("Segoe UI", 9F),
            ForeColor = Color.FromArgb(51, 65, 85),
            FlatStyle = FlatStyle.Flat,
            AutoSize = false,
            Dock = DockStyle.Fill, 
            CheckAlign = ContentAlignment.MiddleLeft,
            TextAlign = ContentAlignment.MiddleLeft,
            BackColor = Color.White
        };
        _overwriteChk.FlatAppearance.CheckedBackColor = Color.FromArgb(129, 140, 248);

        settingsLayout.Controls.Add(pathLbl, 0, 0);
        settingsLayout.Controls.Add(_serverPathTxt, 1, 0);
        settingsLayout.Controls.Add(browseBtn, 2, 0);
        settingsLayout.Controls.Add(_overwriteChk, 3, 0);
        settingsPanel.Controls.Add(settingsLayout);

        // ─── Main Split Container ───────────────────────────────────────
        _mainSplit = new SplitContainer 
        { 
            Dock = DockStyle.Fill, 
            Orientation = Orientation.Vertical, 
            BackColor = Color.FromArgb(226, 232, 240),
            SplitterWidth = 20,
            BorderStyle = BorderStyle.None
        };

        // ─── LEFT PANEL (Drop Zone + Log) ───────────────────────────────
        var leftLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            BackColor = Color.FromArgb(226, 232, 240)
        };
        leftLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 140)); // Drop zone
        leftLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));  // Log

        _dropPanel = new FlatPanel
        {
            Dock = DockStyle.Fill,
            FillColor = Color.White,
            BorderColor = Color.FromArgb(203, 213, 225),
            Margin = new Padding(0, 0, 0, 20)
        };
        
        _dropLabel = new Label 
        { 
            Text = "⬇  Drag & Drop .mcaddon or .mcpack file here  ⬇", 
            Dock = DockStyle.Fill, 
            TextAlign = ContentAlignment.MiddleCenter, 
            Font = new Font("Segoe UI Semibold", 12F),
            ForeColor = Color.FromArgb(100, 116, 139),
            BackColor = Color.Transparent
        };
        _dropPanel.Controls.Add(_dropLabel);
        leftLayout.Controls.Add(_dropPanel, 0, 0);

        var logContainer = new FlatPanel 
        { 
            Dock = DockStyle.Fill, 
            FillColor = Color.White, 
            BorderColor = Color.FromArgb(203, 213, 225) 
        };
        
        _logTxt = new RichTextBox
        {
            Dock = DockStyle.Fill,
            ReadOnly = true,
            BackColor = Color.FromArgb(30, 41, 59), // Slate-800 (Dark Console)
            ForeColor = Color.FromArgb(226, 232, 240),
            Font = new Font("Consolas", 10F),
            BorderStyle = BorderStyle.None,
            Margin = new Padding(1)
        };
        logContainer.Controls.Add(_logTxt);
        leftLayout.Controls.Add(logContainer, 0, 1);

        _mainSplit.Panel1.Controls.Add(leftLayout);

        // ─── RIGHT PANEL (Manage Addons) ────────────────────────────────
        var rightLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            BackColor = Color.FromArgb(226, 232, 240)
        };
        rightLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 80));  // Manage Top
        rightLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));  // List

        var manageTopPanel = new FlatPanel
        {
            Dock = DockStyle.Fill,
            FillColor = Color.White,
            BorderColor = Color.FromArgb(203, 213, 225),
            Margin = new Padding(0, 0, 0, 20)
        };

        var manageLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 3,
            RowCount = 1,
            Padding = new Padding(20, 10, 20, 10),
            BackColor = Color.White
        };
        manageLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));   // Title
        manageLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 60));   // Refresh Btn (Icon)
        manageLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 170));  // Remove Btn

        var manageTitleLbl = new Label 
        { 
            Text = "Installed Addons", 
            Font = new Font("Segoe UI Semibold", 12F), 
            ForeColor = Color.FromArgb(51, 65, 85), 
            Dock = DockStyle.Fill, 
            TextAlign = ContentAlignment.MiddleLeft,
            BackColor = Color.White
        };

        var refreshBtn = new FlatButton
        {
            Text = "\uE72C", // Segoe MDL2 Assets Refresh Icon
            Font = new Font("Segoe MDL2 Assets", 12F),
            Size = new Size(45, 38),
            Margin = new Padding(0, 0, 15, 0),
            PrimaryColor = Color.FromArgb(129, 140, 248),
            HoverColor = Color.FromArgb(99, 102, 241)
        };
        refreshBtn.Click += (s, e) => LoadInstalledPacks();

        var removeBtn = new FlatButton
        {
            Text = "Remove Selected",
            PrimaryColor = Color.FromArgb(248, 113, 113), // Pastel Red
            HoverColor = Color.FromArgb(239, 68, 68)
        };
        removeBtn.Click += RemoveBtn_Click;

        manageLayout.Controls.Add(manageTitleLbl, 0, 0);
        manageLayout.Controls.Add(refreshBtn, 1, 0);
        manageLayout.Controls.Add(removeBtn, 2, 0);
        manageTopPanel.Controls.Add(manageLayout);
        rightLayout.Controls.Add(manageTopPanel, 0, 0);

        var listContainer = new FlatPanel 
        { 
            Dock = DockStyle.Fill, 
            FillColor = Color.White, 
            BorderColor = Color.FromArgb(203, 213, 225) 
        };
        
        _packsListView = new ListView 
        { 
            Dock = DockStyle.Fill, 
            View = View.Details, 
            FullRowSelect = true, 
            BackColor = Color.White, 
            ForeColor = Color.FromArgb(51, 65, 85),
            Font = new Font("Segoe UI", 10F),
            BorderStyle = BorderStyle.None,
            GridLines = true, 
            Margin = new Padding(1)
        };
        _packsListView.Columns.Add("Type", 100);
        _packsListView.Columns.Add("Pack Name", 400);
        _packsListView.Columns.Add("Version", 100);
        listContainer.Controls.Add(_packsListView);
        rightLayout.Controls.Add(listContainer, 0, 1);

        _mainSplit.Panel2.Controls.Add(rightLayout);

        mainLayout.Controls.Add(headerPanel, 0, 0);
        mainLayout.Controls.Add(settingsPanel, 0, 1);
        mainLayout.Controls.Add(_mainSplit, 0, 2);

        // ─── Bottom Status Strip ────────────────────────────────────────
        var statusStrip = new StatusStrip 
        { 
            BackColor = Color.FromArgb(226, 232, 240), 
            ForeColor = Color.FromArgb(100, 116, 139),
            Padding = new Padding(20, 5, 20, 5)
        };
        _statusLabel = new ToolStripStatusLabel 
        { 
            Text = "Ready.", 
            Margin = new Padding(0, 0, 10, 0) 
        };
        _progressBar = new ToolStripProgressBar 
        { 
            Visible = false, 
            Style = ProgressBarStyle.Marquee, 
            Size = new Size(200, 16) 
        };
        statusStrip.Items.Add(_statusLabel);
        statusStrip.Items.Add(new ToolStripSeparator());
        statusStrip.Items.Add(_progressBar);

        // Add controls to Form
        Controls.Add(mainLayout);
        Controls.Add(statusStrip);

        ConsoleExt.OnLog = LogToUI;

        // Enable drag and drop anywhere on the left panel
        _mainSplit.Panel1.AllowDrop = true;
        _mainSplit.Panel1.DragEnter += MainForm_DragEnter;
        _mainSplit.Panel1.DragDrop += MainForm_DragDrop;
        _mainSplit.Panel1.DragLeave += MainForm_DragLeave;
        
        _dropPanel.AllowDrop = true;
        _dropPanel.DragEnter += MainForm_DragEnter;
        _dropPanel.DragDrop += MainForm_DragDrop;
        _dropPanel.DragLeave += MainForm_DragLeave;
        
        _logTxt.AllowDrop = true;
        _logTxt.DragEnter += MainForm_DragEnter;
        _logTxt.DragDrop += MainForm_DragDrop;
        _logTxt.DragLeave += MainForm_DragLeave;

        LoadSettings();
        FormClosed += (s, e) => SaveSettings();
        
        // Safely initialize UI after window is fully drawn and sized
        Shown += (s, e) => 
        {
            SetSplitterSafely();
            LoadInstalledPacks();
            
            // Prevent text from auto-highlighting on startup
            _serverPathTxt.SelectionStart = 0;
            _serverPathTxt.SelectionLength = 0;
            this.ActiveControl = null; 
        };
    }

    private void SetSplitterSafely()
    {
        try
        {
            if (_mainSplit.Width > 100)
            {
                _mainSplit.SplitterDistance = _mainSplit.Width / 2;
            }
        }
        catch 
        { 
            // Ignore WinForms sizing quirks if it complains 
        }
    }

    private void LoadInstalledPacks()
    {
        if (_packsListView.InvokeRequired)
        {
            _packsListView.Invoke(new Action(LoadInstalledPacks));
            return;
        }

        _packsListView.Items.Clear();
        ConsoleExt.Info("Scanning for registered world packs...");
        
        try
        {
            string serverPath = _serverPathTxt.Text;
            if (!Directory.Exists(serverPath)) return;

            var packs = PackManager.GetInstalledPacks(serverPath);
            foreach (var pack in packs)
            {
                var item = new ListViewItem(pack.Type.ToString());
                item.SubItems.Add(pack.Name);
                item.SubItems.Add(string.Join(".", pack.Version));
                item.Tag = pack;
                _packsListView.Items.Add(item);
            }
            ConsoleExt.Ok($"Found {packs.Count} active pack(s).");
        }
        catch (Exception ex)
        {
            ConsoleExt.Error($"Failed to load packs: {ex.Message}");
        }
    }

    private async void RemoveBtn_Click(object? sender, EventArgs e)
    {
        if (_packsListView.SelectedItems.Count == 0) return;
        
        var confirm = MessageBox.Show($"Are you sure you want to remove {_packsListView.SelectedItems.Count} pack(s)?\nThis will delete the folders and unregister them.", "Confirm Removal", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
        if (confirm != DialogResult.Yes) return;

        SetBusy(true);
        
        await Task.Run(() =>
        {
            try
            {
                string serverPath = _serverPathTxt.Text;
                string worldDir = ServerConfig.GetWorldDirectory(serverPath);
                var packsToRemove = new List<PackInfo>();

                Invoke(new Action(() => 
                {
                    foreach (ListViewItem item in _packsListView.SelectedItems)
                    {
                        if (item.Tag is PackInfo p) packsToRemove.Add(p);
                    }
                }));

                foreach (var pack in packsToRemove)
                {
                    PackManager.RemovePack(serverPath, worldDir, pack);
                    ConsoleExt.Ok($"Removed: {pack.Name}");
                }
            }
            catch (Exception ex)
            {
                ConsoleExt.Error($"Failed to remove pack: {ex.Message}");
            }
        });

        LoadInstalledPacks();
        SetBusy(false);
    }

    private void LoadSettings()
    {
        try
        {
            if (File.Exists(ConfigPath))
            {
                var lines = File.ReadAllLines(ConfigPath);
                if (lines.Length > 0) _serverPathTxt.Text = lines[0];
                if (lines.Length > 1) _overwriteChk.Checked = bool.Parse(lines[1]);
            }
            else
            {
                _serverPathTxt.Text = @"C:\Bedrock\server";
            }
        }
        catch
        {
            _serverPathTxt.Text = @"C:\Bedrock\server";
        }
    }

    private void SaveSettings()
    {
        try
        {
            var dir = Path.GetDirectoryName(ConfigPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir)) 
                Directory.CreateDirectory(dir);
                
            File.WriteAllLines(ConfigPath, new[] { _serverPathTxt.Text, _overwriteChk.Checked.ToString() });
        }
        catch { /* Ignore save errors */ }
    }

    private void BrowseBtn_Click(object? sender, EventArgs e)
    {
        using var dialog = new FolderBrowserDialog();
        dialog.Description = "Select Bedrock Server Folder";
        if (Directory.Exists(_serverPathTxt.Text))
            dialog.SelectedPath = _serverPathTxt.Text;
            
        if (dialog.ShowDialog() == DialogResult.OK)
        {
            _serverPathTxt.Text = dialog.SelectedPath;
            LoadInstalledPacks();
        }
    }

    private void LogToUI(string message, ConsoleColor color)
    {
        if (_logTxt.InvokeRequired)
        {
            _logTxt.Invoke(new Action<string, ConsoleColor>(LogToUI), message, color);
            return;
        }

        var winColor = color switch
        {
            ConsoleColor.Cyan => Color.FromArgb(56, 189, 248),   // Sky-400
            ConsoleColor.Green => Color.FromArgb(74, 222, 128),  // Green-400
            ConsoleColor.Yellow => Color.FromArgb(250, 204, 21), // Yellow-400
            ConsoleColor.Red => Color.FromArgb(248, 113, 113),   // Red-400
            _ => Color.FromArgb(226, 232, 240)                   // Slate-200
        };

        _logTxt.SelectionColor = winColor;
        _logTxt.AppendText(message + "\n");
        _logTxt.ScrollToCaret();
    }

    private void UpdateDropProgress(float val)
    {
        if (_dropPanel.InvokeRequired)
        {
            _dropPanel.Invoke(new Action<float>(UpdateDropProgress), val);
            return;
        }
        _dropPanel.Progress = val;
        _dropPanel.Invalidate();
    }

    private void SetBusy(bool isBusy)
    {
        if (InvokeRequired)
        {
            Invoke(new Action<bool>(SetBusy), isBusy);
            return;
        }

        _progressBar.Visible = isBusy;
        _statusLabel.Text = isBusy ? "Working..." : "Ready.";
        UseWaitCursor = isBusy;
        
        if (!isBusy)
        {
            _dropPanel.Progress = 0f;
            _dropPanel.IsDragging = false;
            _dropPanel.Invalidate();
        }
        
        _dropLabel.Text = isBusy ? "Installing..." : "⬇  Drag & Drop .mcaddon or .mcpack file here  ⬇";
        _dropLabel.ForeColor = isBusy ? Color.FromArgb(34, 197, 94) : Color.FromArgb(100, 116, 139);
    }

    private void MainForm_DragEnter(object? sender, DragEventArgs e)
    {
        if (e.Data is not null && e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            var files = (string[]?)e.Data.GetData(DataFormats.FileDrop);
            if (files is not null && files.Any(f => f.EndsWith(".mcaddon", StringComparison.OrdinalIgnoreCase) ||
                               f.EndsWith(".mcpack", StringComparison.OrdinalIgnoreCase)))
            {
                e.Effect = DragDropEffects.Copy;
                _dropPanel.IsDragging = true;
                _dropPanel.BorderColor = Color.FromArgb(74, 222, 128); // Green-400
                _dropPanel.Invalidate();
                return;
            }
        }
        e.Effect = DragDropEffects.None;
    }

    private void MainForm_DragLeave(object? sender, EventArgs e)
    {
        _dropPanel.IsDragging = false;
        _dropPanel.BorderColor = Color.FromArgb(203, 213, 225);
        _dropPanel.Invalidate();
    }

    private async void MainForm_DragDrop(object? sender, DragEventArgs e)
    {
        _dropPanel.IsDragging = false;
        _dropPanel.Progress = 0.01f;
        _dropPanel.Invalidate();

        if (e.Data is null) return;

        var files = (string[]?)e.Data.GetData(DataFormats.FileDrop);
        if (files is null) return;

        // Support multiple files dropped at once
        var addonFiles = files.Where(f => f.EndsWith(".mcaddon", StringComparison.OrdinalIgnoreCase) ||
                                          f.EndsWith(".mcpack", StringComparison.OrdinalIgnoreCase)).ToList();

        if (addonFiles.Count == 0) return;

        SetBusy(true);
        _logTxt.Clear();
        
        try
        {
            await InstallAddonsAsync(addonFiles);
            LoadInstalledPacks(); // Refresh list after install
        }
        catch (Exception ex)
        {
            ConsoleExt.Error($"Fatal error: {ex.Message}");
        }
        finally
        {
            SetBusy(false);
            ConsoleExt.Info("Ready for next file...");
        }
    }

    private async Task InstallAddonsAsync(List<string> archivePaths)
    {
        string serverPath = _serverPathTxt.Text;
        bool overwrite = _overwriteChk.Checked;

        await Task.Run(() =>
        {
            try
            {
                ConsoleExt.Info("Step 1: Validating server path...");
                ConsoleExt.Info($"  Server: {serverPath}");
                ServerConfig.ValidateServerPath(serverPath);
                ConsoleExt.Ok("Server path validated.");
                UpdateDropProgress(0.1f);

                ConsoleExt.Info("Step 2: Resolving world name from server.properties...");
                var levelName = ServerConfig.GetLevelName(serverPath);
                var worldDir = Path.Combine(serverPath, "worlds", levelName);

                if (!Directory.Exists(worldDir))
                {
                    ConsoleExt.Warn($"World directory '{worldDir}' not found. Creating it.");
                    Directory.CreateDirectory(worldDir);
                }
                ConsoleExt.Ok($"World directory: {worldDir}");
                UpdateDropProgress(0.2f);

                var installer = new PackInstaller(serverPath, worldDir);
                var allResults = new List<InstallationResult>();
                
                float baseProgress = 0.2f;
                float stepPerFile = 0.8f / archivePaths.Count;

                for (int i = 0; i < archivePaths.Count; i++)
                {
                    var archivePath = archivePaths[i];
                    ConsoleExt.Info($"Processing file {i + 1} of {archivePaths.Count}: {Path.GetFileName(archivePath)}");
                    UpdateDropProgress(baseProgress + (stepPerFile * i));

                    ConsoleExt.Info("Step 3: Extracting addon archive...");
                    AddonExtractor extractor = new AddonExtractor();
                    List<string> packDirs;
                    
                    try
                    {
                        packDirs = extractor.Extract(archivePath);
                    }
                    catch (Exception ex)
                    {
                        ConsoleExt.Error($"Failed to extract archive: {ex.Message}");
                        continue;
                    }

                    if (packDirs.Count == 0)
                    {
                        ConsoleExt.Error("No packs (manifest.json) found in the addon file.");
                        continue;
                    }

                    ConsoleExt.Ok($"Discovered {packDirs.Count} pack(s) inside the archive.");

                    ConsoleExt.Info("Step 4: Parsing pack manifests...");
                    var packs = new List<PackInfo>();
                    var jsonOpts = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };

                    foreach (var dir in packDirs)
                    {
                        var manifestPath = Path.Combine(dir, "manifest.json");
                        try
                        {
                            var manifest = System.Text.Json.JsonSerializer.Deserialize<PackManifest>(
                                File.ReadAllText(manifestPath), jsonOpts);

                            if (manifest == null || string.IsNullOrEmpty(manifest.Header.Uuid))
                            {
                                ConsoleExt.Warn($"  Skipping invalid manifest at {manifestPath}");
                                continue;
                            }

                            string packName = manifest.Header.Name;
                            if (string.IsNullOrWhiteSpace(packName) || packName.Equals("pack.name", StringComparison.OrdinalIgnoreCase))
                            {
                                packName = new DirectoryInfo(dir).Name;
                            }

                            // Strip Minecraft formatting codes (e.g., §7, §b, §r)
                            packName = Regex.Replace(packName, "§.", "");

                            var pack = new PackInfo
                            {
                                Name = packName,
                                Uuid = manifest.Header.Uuid,
                                Version = VersionParser.Parse(manifest.Header.Version),
                                Type = PackTypeDetector.Detect(manifest),
                                Manifest = manifest,
                                SourcePath = dir
                            };

                            packs.Add(pack);
                            ConsoleExt.Info($"  [{pack.Type}] {pack.Name}");
                            ConsoleExt.Info($"    UUID: {pack.Uuid}");
                            ConsoleExt.Info($"    Version: [{string.Join(", ", pack.Version)}]");
                        }
                        catch (Exception ex)
                        {
                            ConsoleExt.Warn($"  Failed to parse manifest at {manifestPath}: {ex.Message}");
                        }
                    }

                    if (packs.Count == 0)
                    {
                        ConsoleExt.Error("No valid packs found after parsing manifests.");
                        continue;
                    }

                    ConsoleExt.Info("Step 5: Installing packs...");
                    var results = new List<InstallationResult>();

                    for (int j = 0; j < packs.Count; j++)
                    {
                        var pack = packs[j];
                        ConsoleExt.Info(new string('-', 60));
                        var result = installer.InstallPack(pack, overwrite);
                        results.Add(result);
                        
                        float fileProgress = stepPerFile * ((float)j / packs.Count);
                        UpdateDropProgress(baseProgress + (stepPerFile * i) + fileProgress);
                    }

                    allResults.AddRange(results);
                    extractor.Cleanup();
                }

                ConsoleExt.Info(new string('=', 60));
                ConsoleExt.Ok("Installation Summary:");
                ConsoleExt.Info(new string('=', 60));

                foreach (var r in allResults)
                {
                    if (r.Skipped)
                        ConsoleExt.Warn($"  [SKIP] {r.PackName}: {r.SkipReason}");
                    else if (r.AlreadyInstalled)
                        ConsoleExt.Ok($"  [EXISTS] {r.PackName}: Already installed.");
                    else if (r.Success)
                        ConsoleExt.Ok($"  [OK] {r.PackName}: Installed successfully.");
                    else
                        ConsoleExt.Error($"  [FAIL] {r.PackName}: Installation failed.");
                }

                ConsoleExt.Info(new string('=', 60));
                ConsoleExt.Ok("Done!");
                ConsoleExt.Warn("IMPORTANT: Restart your Bedrock server for changes to take effect.");
                ConsoleExt.Info(new string('=', 60));
                
                UpdateDropProgress(1.0f);
                Thread.Sleep(500); // Brief pause to show 100% completion
            }
            catch (Exception ex)
            {
                ConsoleExt.Error($"Fatal error: {ex.Message}");
            }
        });
    }
}
'@
    Write-ProjectFile "Program.cs" $programCs

    # Models.cs
    $modelsCs = @'
using System.Text.Json;
using System.Text.Json.Serialization;

namespace BedrockDedicatedServerAddonManager.Models;

public class PackManifest
{
    [JsonPropertyName("format_version")]
    public int FormatVersion { get; set; }

    [JsonPropertyName("header")]
    public ManifestHeader Header { get; set; } = new();

    [JsonPropertyName("modules")]
    public List<ManifestModule> Modules { get; set; } = new();

    [JsonPropertyName("dependencies")]
    public List<ManifestDependency> Dependencies { get; set; } = new();
}

public class ManifestHeader
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("uuid")]
    public string Uuid { get; set; } = string.Empty;

    [JsonPropertyName("version")]
    public JsonElement Version { get; set; }

    [JsonPropertyName("min_engine_version")]
    public JsonElement? MinEngineVersion { get; set; }
}

public class ManifestModule
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("uuid")]
    public string Uuid { get; set; } = string.Empty;

    [JsonPropertyName("version")]
    public JsonElement Version { get; set; }

    [JsonPropertyName("language")]
    public string? Language { get; set; }

    [JsonPropertyName("entry")]
    public string? Entry { get; set; }
}

public class ManifestDependency
{
    [JsonPropertyName("module_name")]
    public string? ModuleName { get; set; }

    [JsonPropertyName("uuid")]
    public string? Uuid { get; set; }

    [JsonPropertyName("version")]
    public JsonElement Version { get; set; }
}

public enum PackType
{
    Behavior,
    Resource,
    Skin,
    WorldTemplate,
    Unknown
}

public class PackInfo
{
    public string Name { get; set; } = string.Empty;
    public string Uuid { get; set; } = string.Empty;
    public int[] Version { get; set; } = { 1, 0, 0 };
    public PackType Type { get; set; }
    public PackManifest Manifest { get; set; } = new();
    public string SourcePath { get; set; } = string.Empty;
}

public class WorldPackEntry
{
    [JsonPropertyName("pack_id")]
    public string PackId { get; set; } = string.Empty;

    [JsonPropertyName("version")]
    public int[] Version { get; set; } = { 1, 0, 0 };
}

public class InstallationResult
{
    public string PackName { get; set; } = string.Empty;
    public string Uuid { get; set; } = string.Empty;
    public bool Success { get; set; }
    public bool Skipped { get; set; }
    public bool AlreadyInstalled { get; set; }
    public string SkipReason { get; set; } = string.Empty;
    public string InstalledPath { get; set; } = string.Empty;
}
'@
    Write-ProjectFile "Models.cs" $modelsCs

    # ConsoleExt.cs
    $consoleExtCs = @'
using System;

namespace BedrockDedicatedServerAddonManager;

public static class ConsoleExt
{
    public static Action<string, ConsoleColor>? OnLog { get; set; }

    public static void Info(string message)
    {
        OnLog?.Invoke($"[INFO] {message}", ConsoleColor.Cyan);
    }

    public static void Ok(string message)
    {
        OnLog?.Invoke($"[OK]   {message}", ConsoleColor.Green);
    }

    public static void Warn(string message)
    {
        OnLog?.Invoke($"[WARN] {message}", ConsoleColor.Yellow);
    }

    public static void Error(string message)
    {
        OnLog?.Invoke($"[ERROR] {message}", ConsoleColor.Red);
    }
}
'@
    Write-ProjectFile "ConsoleExt.cs" $consoleExtCs

    # AddonExtractor.cs (Fixed Long Path Slash Syntax)
    $addonExtractorCs = @'
using System.IO.Compression;

namespace BedrockDedicatedServerAddonManager;

public class AddonExtractor
{
    private readonly string _tempBasePath;

    public AddonExtractor()
    {
        // Use a short path on the system drive to help avoid 260 character path limits
        string root = Path.GetPathRoot(Environment.SystemDirectory) ?? "C:\\";
        _tempBasePath = Path.Combine(root, "Bedrock\\Temp", "BDSAM_" + Guid.NewGuid().ToString("N")[..8]);
    }

    public List<string> Extract(string archivePath)
    {
        Directory.CreateDirectory(_tempBasePath);
        
        // Name the extraction folder after the archive file name to prevent "extracted" from becoming the pack name
        string archiveName = Path.GetFileNameWithoutExtension(archivePath);
        foreach (char c in Path.GetInvalidPathChars())
        {
            archiveName = archiveName.Replace(c, '_');
        }
        var extractionDir = Path.Combine(_tempBasePath, archiveName);

        ExtractZip(archivePath, extractionDir);
        ExtractNestedArchives(extractionDir);

        var packDirs = FindPackDirectories(extractionDir);

        if (packDirs.Count == 0)
            throw new InvalidOperationException("No manifest.json files found. This does not appear to be a valid addon.");

        return packDirs;
    }

    private static void ExtractNestedArchives(string directory)
    {
        string longDir = directory.StartsWith(@"\\?\") ? directory : @"\\?\" + Path.GetFullPath(directory);
        
        // Search for any nested archive types
        var nestedArchives = Directory.GetFiles(longDir, "*.*", SearchOption.AllDirectories)
            .Where(f => f.EndsWith(".mcpack", StringComparison.OrdinalIgnoreCase) ||
                        f.EndsWith(".mcaddon", StringComparison.OrdinalIgnoreCase) ||
                        f.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
            .ToList();

        if (nestedArchives.Count > 0)
        {
            ConsoleExt.Info($"Found {nestedArchives.Count} nested archive(s). Extracting...");
        }

        foreach (var archive in nestedArchives)
        {
            var extractDir = Path.Combine(
                Path.GetDirectoryName(archive)!,
                Path.GetFileNameWithoutExtension(archive) + "_unpacked");

            try
            {
                ExtractZip(archive, extractDir);
                File.Delete(archive); // Delete the nested archive after extraction to prevent reprocessing
                ExtractNestedArchives(extractDir); // Recursively check for archives inside the extracted archive
            }
            catch (Exception ex)
            {
                ConsoleExt.Warn($"Failed to extract nested archive '{Path.GetFileName(archive)}': {ex.Message}");
            }
        }
    }

    private static void ExtractZip(string archivePath, string destinationDir)
    {
        Directory.CreateDirectory(destinationDir);
        using var archive = ZipFile.OpenRead(archivePath);
        foreach (var entry in archive.Entries)
        {
            // Skip directories
            if (entry.FullName.EndsWith("/") || entry.FullName.EndsWith("\\"))
                continue;

            // Replace forward slashes with backslashes to prevent Win32 long path syntax errors
            string entryPath = entry.FullName.Replace('/', '\\');
            string destPath = Path.GetFullPath(Path.Combine(destinationDir, entryPath));
            
            // Prepend \\?\ to bypass the 260 character path limit entirely
            string longPath = destPath.StartsWith(@"\\?\") ? destPath : @"\\?\" + destPath;
            
            string? dir = Path.GetDirectoryName(longPath);
            if (!string.IsNullOrEmpty(dir))
                Directory.CreateDirectory(dir);

            entry.ExtractToFile(longPath, overwrite: true);
        }
    }

    private static List<string> FindPackDirectories(string rootDir)
    {
        var result = new List<string>();
        string longRoot = rootDir.StartsWith(@"\\?\") ? rootDir : @"\\?\" + Path.GetFullPath(rootDir);
        var manifestFiles = Directory.GetFiles(longRoot, "manifest.json", SearchOption.AllDirectories);

        foreach (var manifestPath in manifestFiles)
        {
            var packDir = Path.GetDirectoryName(manifestPath)!;
            result.Add(packDir);
        }

        return result;
    }

    public void Cleanup()
    {
        try
        {
            if (Directory.Exists(_tempBasePath))
                Directory.Delete(_tempBasePath, recursive: true);
        }
        catch { }
    }
}
'@
    Write-ProjectFile "AddonExtractor.cs" $addonExtractorCs

    # ManifestParser.cs
    $manifestParserCs = @'
using System.Text.Json;
using BedrockDedicatedServerAddonManager.Models;

namespace BedrockDedicatedServerAddonManager;

public static class VersionParser
{
    public static int[] Parse(JsonElement version)
    {
        if (version.ValueKind == JsonValueKind.Array)
        {
            var result = new List<int>();
            foreach (var item in version.EnumerateArray())
            {
                result.Add(item.TryGetInt32(out var n) ? n : 0);
            }
            return result.Count > 0 ? result.ToArray() : new[] { 1, 0, 0 };
        }

        if (version.ValueKind == JsonValueKind.String)
        {
            var parts = version.GetString()!.Split('.');
            var result = new List<int>();
            foreach (var part in parts)
            {
                result.Add(int.TryParse(part, out var n) ? n : 0);
            }
            return result.Count > 0 ? result.ToArray() : new[] { 1, 0, 0 };
        }

        if (version.ValueKind == JsonValueKind.Number)
        {
            return new[] { version.GetInt32(), 0, 0 };
        }

        return new[] { 1, 0, 0 };
    }
}

public static class PackTypeDetector
{
    public static PackType Detect(PackManifest manifest)
    {
        if (manifest.Modules == null || manifest.Modules.Count == 0)
        {
            return PackType.Behavior;
        }

        var types = manifest.Modules
            .Select(m => m.Type?.ToLowerInvariant() ?? "")
            .ToHashSet();

        if (types.Contains("data") || types.Contains("script") || types.Contains("client_data"))
            return PackType.Behavior;

        if (types.Contains("resources"))
            return PackType.Resource;

        if (types.Contains("skin_pack"))
            return PackType.Skin;

        if (types.Contains("world_template"))
            return PackType.WorldTemplate;

        return PackType.Unknown;
    }
}
'@
    Write-ProjectFile "ManifestParser.cs" $manifestParserCs

    # PackInstaller.cs (Long Path Support for Copy/Move)
    $packInstallerCs = @'
using System.Text;
using System.Text.Json;
using BedrockDedicatedServerAddonManager.Models;

namespace BedrockDedicatedServerAddonManager;

public class PackInstaller
{
    private static readonly UTF8Encoding Utf8NoBom = new(false);

    private readonly string _serverPath;
    private readonly string _worldDir;

    public PackInstaller(string serverPath, string worldDir)
    {
        _serverPath = serverPath;
        _worldDir = worldDir;
    }

    public InstallationResult InstallPack(PackInfo pack, bool overwrite = false)
    {
        var result = new InstallationResult
        {
            PackName = pack.Name,
            Uuid = pack.Uuid
        };

        if (pack.Type is PackType.Skin or PackType.WorldTemplate or PackType.Unknown)
        {
            ConsoleExt.Warn($"Skipping '{pack.Name}' — {pack.Type} packs are not supported on dedicated servers.");
            result.Skipped = true;
            result.SkipReason = $"{pack.Type} packs are not supported on dedicated servers.";
            return result;
        }

        var packsRoot = pack.Type == PackType.Behavior
            ? Path.Combine(_serverPath, "behavior_packs")
            : Path.Combine(_serverPath, "resource_packs");

        var folderName = SanitizeFolderName(pack.Name, pack.Uuid);
        var targetPath = Path.Combine(packsRoot, folderName);
        string longTargetPath = @"\\?\" + Path.GetFullPath(targetPath);

        ConsoleExt.Info($"Installing [{pack.Type}] '{pack.Name}' ...");
        ConsoleExt.Info($"  UUID: {pack.Uuid}");
        ConsoleExt.Info($"  Target: {targetPath}");

        if (Directory.Exists(longTargetPath))
        {
            var existingManifestPath = Path.Combine(longTargetPath, "manifest.json");
            if (File.Exists(existingManifestPath))
            {
                try
                {
                    var existingManifest = JsonSerializer.Deserialize<PackManifest>(
                        File.ReadAllText(existingManifestPath),
                        new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                    if (existingManifest?.Header.Uuid.Equals(pack.Uuid, StringComparison.OrdinalIgnoreCase) == true)
                    {
                        if (overwrite)
                        {
                            ConsoleExt.Info("  Overwriting existing identical pack.");
                            Directory.Delete(longTargetPath, recursive: true);
                        }
                        else
                        {
                            ConsoleExt.Ok("  Pack already installed with same UUID. Ensuring world registration.");
                            WorldPackRegistry.RegisterPack(_worldDir, pack);
                            result.AlreadyInstalled = true;
                            result.InstalledPath = targetPath;
                            return result;
                        }
                    }
                    else
                    {
                        var suffix = pack.Uuid.Length >= 8 ? pack.Uuid[..8] : pack.Uuid;
                        folderName = $"{folderName}_{suffix}";
                        targetPath = Path.Combine(packsRoot, folderName);
                        longTargetPath = @"\\?\" + Path.GetFullPath(targetPath);
                        ConsoleExt.Warn($"  Folder name collision. Using: {folderName}");
                    }
                }
                catch (Exception ex)
                {
                    ConsoleExt.Warn($"  Could not read existing manifest: {ex.Message}. Appending UUID suffix.");
                    var suffix = pack.Uuid.Length >= 8 ? pack.Uuid[..8] : pack.Uuid;
                    folderName = $"{folderName}_{suffix}";
                    targetPath = Path.Combine(packsRoot, folderName);
                    longTargetPath = @"\\?\" + Path.GetFullPath(targetPath);
                }
            }
            else
            {
                if (overwrite)
                {
                    ConsoleExt.Info("  Overwriting existing directory (no manifest found).");
                    Directory.Delete(longTargetPath, recursive: true);
                }
                else
                {
                    var suffix = pack.Uuid.Length >= 8 ? pack.Uuid[..8] : pack.Uuid;
                    folderName = $"{folderName}_{suffix}";
                    targetPath = Path.Combine(packsRoot, folderName);
                    longTargetPath = @"\\?\" + Path.GetFullPath(targetPath);
                }
            }
        }

        try
        {
            CopyDirectory(pack.SourcePath, longTargetPath);
            ConsoleExt.Ok("  Files copied successfully.");
        }
        catch (Exception ex)
        {
            ConsoleExt.Error($"  Failed to copy files: {ex.Message}");
            return result;
        }

        result.InstalledPath = targetPath;
        WorldPackRegistry.RegisterPack(_worldDir, pack);

        result.Success = true;
        return result;
    }

    public static string SanitizeFolderName(string name, string uuid)
    {
        if (string.IsNullOrWhiteSpace(name))
            name = "UnnamedPack";

        var invalid = Path.GetInvalidFileNameChars();
        var sanitized = new string(name.Select(c => invalid.Contains(c) ? '_' : c).ToArray());

        sanitized = sanitized.Trim().Trim('.');

        if (sanitized.Length > 50)
            sanitized = sanitized[..50];

        return sanitized;
    }

    private static void CopyDirectory(string source, string destination)
    {
        // Prepend \\?\ to all paths to bypass the 260 character limit
        string longSource = source.StartsWith(@"\\?\") ? source : @"\\?\" + Path.GetFullPath(source);
        string longDest = destination.StartsWith(@"\\?\") ? destination : @"\\?\" + Path.GetFullPath(destination);

        Directory.CreateDirectory(longDest);

        foreach (var file in Directory.GetFiles(longSource, "*", SearchOption.TopDirectoryOnly))
        {
            var destFile = Path.Combine(longDest, Path.GetFileName(file));
            File.Copy(file, destFile, overwrite: true);
        }

        foreach (var dir in Directory.GetDirectories(longSource, "*", SearchOption.TopDirectoryOnly))
        {
            var dirName = Path.GetFileName(dir);
            if (dirName.EndsWith("_unpacked", StringComparison.OrdinalIgnoreCase))
            {
                dirName = dirName[..^"_unpacked".Length];
            }
            var destDir = Path.Combine(longDest, dirName);
            CopyDirectory(dir, destDir);
        }
    }
}
'@
    Write-ProjectFile "PackInstaller.cs" $packInstallerCs

    # PackManager.cs
    $packManagerCs = @'
using System.Text.Json;
using System.Text.RegularExpressions;
using BedrockDedicatedServerAddonManager.Models;

namespace BedrockDedicatedServerAddonManager;

public static class PackManager
{
    private static readonly JsonSerializerOptions JsonOpts = new() { PropertyNameCaseInsensitive = true };

    public static List<PackInfo> GetInstalledPacks(string serverPath)
    {
        var packs = new List<PackInfo>();
        string worldDir = ServerConfig.GetWorldDirectory(serverPath);
        
        var bpJson = Path.Combine(worldDir, "world_behavior_packs.json");
        var rpJson = Path.Combine(worldDir, "world_resource_packs.json");

        var bpDir = Path.Combine(serverPath, "behavior_packs");
        var rpDir = Path.Combine(serverPath, "resource_packs");

        ScanRegisteredPacks(bpJson, bpDir, PackType.Behavior, packs);
        ScanRegisteredPacks(rpJson, rpDir, PackType.Resource, packs);

        return packs;
    }

    private static void ScanRegisteredPacks(string jsonPath, string packsDir, PackType type, List<PackInfo> list)
    {
        if (!File.Exists(jsonPath) || !Directory.Exists(packsDir)) return;

        try
        {
            var entries = JsonSerializer.Deserialize<List<WorldPackEntry>>(File.ReadAllText(jsonPath), JsonOpts);
            if (entries == null) return;

            var folderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var dir in Directory.GetDirectories(packsDir))
            {
                var manifestPath = Path.Combine(dir, "manifest.json");
                if (!File.Exists(manifestPath)) continue;
                try
                {
                    var manifest = JsonSerializer.Deserialize<PackManifest>(File.ReadAllText(manifestPath), JsonOpts);
                    if (manifest?.Header != null && !string.IsNullOrEmpty(manifest.Header.Uuid))
                    {
                        folderMap[manifest.Header.Uuid] = dir;
                    }
                }
                catch { }
            }

            foreach (var entry in entries)
            {
                if (folderMap.TryGetValue(entry.PackId, out var dir))
                {
                    var manifestPath = Path.Combine(dir, "manifest.json");
                    var manifest = JsonSerializer.Deserialize<PackManifest>(File.ReadAllText(manifestPath), JsonOpts);
                    if (manifest?.Header == null) continue;

                    string packName = manifest.Header.Name;
                    if (string.IsNullOrWhiteSpace(packName) || packName.Equals("pack.name", StringComparison.OrdinalIgnoreCase))
                    {
                        packName = new DirectoryInfo(dir).Name;
                    }

                    // Strip Minecraft formatting codes (e.g., §7, §b, §r)
                    packName = Regex.Replace(packName, "§.", "");

                    list.Add(new PackInfo
                    {
                        Name = packName,
                        Uuid = manifest.Header.Uuid,
                        Version = VersionParser.Parse(manifest.Header.Version),
                        Type = type,
                        SourcePath = dir,
                        Manifest = manifest
                    });
                }
            }
        }
        catch (Exception ex)
        {
            ConsoleExt.Warn($"Failed to read {Path.GetFileName(jsonPath)}: {ex.Message}");
        }
    }

    public static void RemovePack(string serverPath, string worldDir, PackInfo pack)
    {
        if (Directory.Exists(pack.SourcePath))
        {
            // Use long path syntax for deletion to prevent errors
            string longPath = @"\\?\" + Path.GetFullPath(pack.SourcePath);
            Directory.Delete(longPath, recursive: true);
        }

        WorldPackRegistry.UnregisterPack(worldDir, pack);
    }
}
'@
    Write-ProjectFile "PackManager.cs" $packManagerCs

    # ServerConfig.cs
    $serverConfigCs = @'
namespace BedrockDedicatedServerAddonManager;

public static class ServerConfig
{
    public static void ValidateServerPath(string serverPath)
    {
        if (!Directory.Exists(serverPath))
            throw new DirectoryNotFoundException($"Server path '{serverPath}' does not exist or is not a directory.");

        var hasProperties = File.Exists(Path.Combine(serverPath, "server.properties"));
        var hasWorldsDir = Directory.Exists(Path.Combine(serverPath, "worlds"));
        var hasExe = Directory.GetFiles(serverPath, "bedrock_server*", SearchOption.TopDirectoryOnly).Length > 0;

        if (!hasProperties && !hasWorldsDir && !hasExe)
        {
            throw new InvalidOperationException(
                $"The path '{serverPath}' does not appear to be a Bedrock server directory.\n" +
                "Expected: server.properties, worlds/ directory, or bedrock_server executable.");
        }

        var bpDir = Path.Combine(serverPath, "behavior_packs");
        var rpDir = Path.Combine(serverPath, "resource_packs");

        if (!Directory.Exists(bpDir))
        {
            Directory.CreateDirectory(bpDir);
            ConsoleExt.Info("Created 'behavior_packs' directory.");
        }

        if (!Directory.Exists(rpDir))
        {
            Directory.CreateDirectory(rpDir);
            ConsoleExt.Info("Created 'resource_packs' directory.");
        }
    }

    public static string GetLevelName(string serverPath)
    {
        var propertiesPath = Path.Combine(serverPath, "server.properties");
        var defaultName = "Bedrock level";

        if (!File.Exists(propertiesPath))
        {
            ConsoleExt.Warn($"server.properties not found at '{propertiesPath}'. Using default '{defaultName}'.");
            return defaultName;
        }

        foreach (var line in File.ReadAllLines(propertiesPath))
        {
            var trimmed = line.Trim();
            if (trimmed.StartsWith('#') || string.IsNullOrEmpty(trimmed))
                continue;

            if (trimmed.StartsWith("level-name=", StringComparison.OrdinalIgnoreCase))
            {
                var value = trimmed["level-name=".Length..].Trim();
                ConsoleExt.Info($"  level-name = '{value}'");
                return value;
            }
        }

        ConsoleExt.Warn($"Could not find 'level-name' in server.properties. Using default '{defaultName}'.");
        return defaultName;
    }

    public static string GetWorldDirectory(string serverPath)
    {
        var levelName = GetLevelName(serverPath);
        return Path.Combine(serverPath, "worlds", levelName);
    }
}
'@
    Write-ProjectFile "ServerConfig.cs" $serverConfigCs

    # WorldPackRegistry.cs
    $worldPackRegistryCs = @'
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using BedrockDedicatedServerAddonManager.Models;

namespace BedrockDedicatedServerAddonManager;

public static class WorldPackRegistry
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private static readonly UTF8Encoding Utf8NoBom = new(false);

    public static string GetJsonFileName(PackType type)
    {
        return type == PackType.Behavior
            ? "world_behavior_packs.json"
            : "world_resource_packs.json";
    }

    public static void RegisterPack(string worldDir, PackInfo pack)
    {
        var jsonFileName = GetJsonFileName(pack.Type);
        var jsonPath = Path.Combine(worldDir, jsonFileName);

        var entries = ReadExistingEntries(jsonPath);

        if (entries.Any(e => e.PackId.Equals(pack.Uuid, StringComparison.OrdinalIgnoreCase)))
        {
            ConsoleExt.Ok($"  Already registered in {jsonFileName}.");
            return;
        }

        entries.Add(new WorldPackEntry
        {
            PackId = pack.Uuid,
            Version = pack.Version
        });

        WriteEntries(jsonPath, entries);
        ConsoleExt.Ok($"  Registered in {jsonFileName}.");
    }

    public static void UnregisterPack(string worldDir, PackInfo pack)
    {
        var jsonFileName = GetJsonFileName(pack.Type);
        var jsonPath = Path.Combine(worldDir, jsonFileName);

        if (!File.Exists(jsonPath)) return;

        var entries = ReadExistingEntries(jsonPath);
        var toRemove = entries.Where(e => e.PackId.Equals(pack.Uuid, StringComparison.OrdinalIgnoreCase)).ToList();

        if (toRemove.Count > 0)
        {
            foreach (var entry in toRemove)
                entries.Remove(entry);

            WriteEntries(jsonPath, entries);
            ConsoleExt.Ok($"  Unregistered from {jsonFileName}.");
        }
    }

    private static List<WorldPackEntry> ReadExistingEntries(string path)
    {
        if (!File.Exists(path))
        {
            ConsoleExt.Info($"  {Path.GetFileName(path)} does not exist yet. Creating new.");
            return new List<WorldPackEntry>();
        }

        try
        {
            var raw = File.ReadAllText(path);
            if (string.IsNullOrWhiteSpace(raw))
                return new List<WorldPackEntry>();

            var entries = JsonSerializer.Deserialize<List<WorldPackEntry>>(raw, JsonOptions);
            
            if (entries != null && entries.Count > 0)
                ConsoleExt.Info($"  Found {entries.Count} existing pack(s) in {Path.GetFileName(path)}.");

            return entries ?? new List<WorldPackEntry>();
        }
        catch (Exception ex)
        {
            ConsoleExt.Warn($"  Failed to parse {Path.GetFileName(path)}: {ex.Message}");
            ConsoleExt.Warn("  The file will be recreated. Existing entries may be lost.");
            return new List<WorldPackEntry>();
        }
    }

    private static void WriteEntries(string path, List<WorldPackEntry> entries)
    {
        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        var json = JsonSerializer.Serialize(entries, JsonOptions);
        File.WriteAllText(path, json, Utf8NoBom);
    }
}
'@
    Write-ProjectFile "WorldPackRegistry.cs" $worldPackRegistryCs

    # ─── 3. Build Project ───────────────────────────────────────────────────
    Write-Host "`n[3/4] Building project with dotnet..." -ForegroundColor Yellow
    
    Push-Location $ProjectDir
    try {
        dotnet restore --nologo --verbosity quiet
        if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed." }
        
        dotnet build -c Release --nologo --verbosity quiet
        if ($LASTEXITCODE -ne 0) { throw "dotnet build failed." }
    }
    finally {
        Pop-Location
    }
    Write-Host "      Build successful!" -ForegroundColor Green

    # ─── 4. Run Executable ──────────────────────────────────────────────────
    Write-Host "`n[4/4] Launching Bedrock Dedicated Server Addon Manager GUI..." -ForegroundColor Yellow
    
    $exePath = Join-Path $ProjectDir "bin\Release\net8.0-windows\BedrockDedicatedServerAddonManager.exe"
    if (-not (Test-Path $exePath)) {
        throw "Executable not found at $exePath"
    }

    Write-Host "      Starting GUI application... You can close this PowerShell window." -ForegroundColor DarkGray
    Start-Process -FilePath $exePath

} catch {
    Write-Host "`n[FATAL ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host "`nPress Enter to exit..." -ForegroundColor Cyan
    Read-Host
}
