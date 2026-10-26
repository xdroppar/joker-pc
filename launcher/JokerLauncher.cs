// Joker's launcher: the Start Menu and desktop shortcuts open this, not Joker.exe.
// It asks GitHub for the newest release (a few seconds at most), offers the update when there is one, installs it
// with the setup's own progress window, then starts the game. Offline or on any error, the game just starts.
// Built with the C# 5 compiler that ships in Windows (see build-launcher.ps1), so nothing else is needed.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Reflection;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: AssemblyTitle("Joker")]
[assembly: AssemblyProduct("Joker")]
[assembly: AssemblyDescription("Joker launcher")]

static class JokerLauncher
{
    const string Api = "https://api.github.com/repos/xdroppar/joker-pc/releases/latest";
    const string SetupName = "JokerSetup.exe";

    static string Dir { get { return Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); } }

    /// JOKER_LAUNCHER_TEST=<log file>: says yes to the update, downloads without the window, logs each step there,
    /// and never starts the game, so the whole update path can be checked without anything opening on screen.
    static readonly string TestLog = Environment.GetEnvironmentVariable("JOKER_LAUNCHER_TEST");

    static void Log(string text) { if (TestLog != null) File.AppendAllText(TestLog, text + Environment.NewLine); }

    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        try { MaybeUpdate(); } catch (Exception e) { Log("error: " + e.Message); }
        if (TestLog != null) { Log("would start the game"); return; }
        StartGame(args);
    }

    static void StartGame(string[] args)
    {
        var exe = Path.Combine(Dir, "Joker.exe");
        if (!File.Exists(exe))
        {
            MessageBox.Show("Joker isn't installed properly. Please download it again.", "Joker", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        var quoted = new List<string>();
        foreach (var a in args) quoted.Add("\"" + a.Replace("\"", "\\\"") + "\"");
        Process.Start(new ProcessStartInfo(exe, string.Join(" ", quoted.ToArray())) { WorkingDirectory = Dir, UseShellExecute = false });
    }

    static void MaybeUpdate()
    {
        foreach (var p in Process.GetProcessesByName("Joker")) { p.Dispose(); return; } // already playing: never swap files under it
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

        var request = (HttpWebRequest)WebRequest.Create(Api);
        request.UserAgent = "joker-launcher";
        request.Timeout = 4000;
        string json;
        using (var response = request.GetResponse())
        using (var reader = new StreamReader(response.GetResponseStream())) json = reader.ReadToEnd();

        var release = (Dictionary<string, object>)new JavaScriptSerializer().DeserializeObject(json);
        var tag = (string)release["tag_name"];
        string url = null;
        long size = 0;
        foreach (Dictionary<string, object> asset in (IEnumerable)release["assets"])
            if ((string)asset["name"] == SetupName) { url = (string)asset["browser_download_url"]; size = Convert.ToInt64(asset["size"]); }
        Log("latest " + tag + (url == null ? " (no setup attached)" : " " + size + " bytes"));
        if (url == null) return;

        var versionFile = Path.Combine(Dir, "version.txt");
        var have = File.Exists(versionFile) ? File.ReadAllText(versionFile).Trim() : "";
        Log("installed " + have);
        if (have == tag) return;

        var answer = TestLog != null ? DialogResult.Yes : MessageBox.Show(
            "A new version of Joker is ready (" + (size / (1024 * 1024)) + " MB).\n\nUpdate now?",
            "Joker update", MessageBoxButtons.YesNo, MessageBoxIcon.Information);
        if (answer != DialogResult.Yes) return;

        var setup = Path.Combine(Path.GetTempPath(), "JokerSetup-" + tag + ".exe");
        if (TestLog != null)
        {
            using (var client = new WebClient()) { client.Headers.Add("User-Agent", "joker-launcher"); client.DownloadFile(url, setup); }
            if (new FileInfo(setup).Length != size) { Log("download incomplete"); return; }
        }
        else if (!Download(url, setup, size)) return;
        Log("downloaded; installing");
        var quiet = TestLog != null ? "/VERYSILENT" : "/SILENT";
        using (var run = Process.Start(setup, quiet + " /SUPPRESSMSGBOXES /NORESTART /DIR=\"" + Dir + "\"")) { run.WaitForExit(); Log("setup exit " + run.ExitCode); }
        try { File.Delete(setup); } catch { }
    }

    /// The download with a small progress window; false if it was cancelled or failed.
    static bool Download(string url, string path, long size)
    {
        var form = new Form
        {
            Text = "Updating Joker",
            FormBorderStyle = FormBorderStyle.FixedDialog,
            MaximizeBox = false,
            MinimizeBox = true,
            StartPosition = FormStartPosition.CenterScreen,
            ClientSize = new Size(420, 110),
            BackColor = Color.FromArgb(18, 17, 16),
            ForeColor = Color.FromArgb(229, 214, 172),
            Font = new Font("Segoe UI", 10f),
        };
        try { form.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location); } catch { }
        var label = new Label { Text = "Downloading the new version...", AutoSize = false, Bounds = new Rectangle(20, 16, 380, 24) };
        var bar = new ProgressBar { Bounds = new Rectangle(20, 48, 380, 18), Maximum = 1000 };
        var detail = new Label { Text = "", AutoSize = false, Bounds = new Rectangle(20, 74, 380, 24), ForeColor = Color.FromArgb(160, 150, 125) };
        form.Controls.Add(label);
        form.Controls.Add(bar);
        form.Controls.Add(detail);

        bool ok = false;
        var client = new WebClient();
        client.Headers.Add("User-Agent", "joker-launcher");
        client.DownloadProgressChanged += (s, e) =>
        {
            long total = e.TotalBytesToReceive > 0 ? e.TotalBytesToReceive : size;
            if (total > 0) bar.Value = (int)Math.Min(1000, e.BytesReceived * 1000 / total);
            detail.Text = (e.BytesReceived / (1024 * 1024)) + " of " + (total / (1024 * 1024)) + " MB";
        };
        client.DownloadFileCompleted += (s, e) =>
        {
            ok = e.Error == null && !e.Cancelled && new FileInfo(path).Length == size;
            if (!ok && e.Error != null && !e.Cancelled)
                MessageBox.Show("The update couldn't be downloaded. Joker will start as it is.", "Joker update", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            form.Close();
        };
        form.FormClosing += (s, e) => { if (client.IsBusy) client.CancelAsync(); };
        form.Shown += (s, e) => client.DownloadFileAsync(new Uri(url), path);
        Application.Run(form);
        client.Dispose();
        return ok;
    }
}
