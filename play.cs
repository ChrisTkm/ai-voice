using System;
using System.IO;
using System.Media;
using System.Runtime.InteropServices;
using System.Threading;
using System.Text;

class Program
{
    [DllImport("winmm.dll", CharSet = CharSet.Auto)]
    static extern int mciSendString(string cmd, StringBuilder ret, int len, IntPtr cb);

    static string PickAudioFile(string target)
    {
        if (!Directory.Exists(target))
        {
            return target;
        }

        string[] wavFiles = Directory.GetFiles(target, "*.wav");
        string[] files = wavFiles.Length > 0 ? wavFiles : Directory.GetFiles(target, "*.mp3");
        if (files.Length == 0) return "";
        return files[new Random().Next(files.Length)];
    }

    static int PlayWav(string path)
    {
        using (SoundPlayer player = new SoundPlayer(path))
        {
            player.Load();
            player.PlaySync();
        }
        return 0;
    }

    static int PlayWithMci(string path)
    {
        string alias = "a" + Environment.TickCount.ToString();
        string openCmd = "open \"" + path + "\" type mpegvideo alias " + alias;
        int rc = mciSendString(openCmd, null, 0, IntPtr.Zero);
        if (rc != 0) return 2;
        StringBuilder lenBuf = new StringBuilder(64);
        mciSendString("status " + alias + " length", lenBuf, 64, IntPtr.Zero);
        int ms = 3000;
        int parsed;
        if (int.TryParse(lenBuf.ToString(), out parsed)) ms = parsed + 80;
        mciSendString("play " + alias, null, 0, IntPtr.Zero);
        Thread.Sleep(ms);
        mciSendString("close " + alias, null, 0, IntPtr.Zero);
        return 0;
    }

    [STAThread]
    static int Main(string[] args)
    {
        if (args.Length < 1) return 1;
        string path = PickAudioFile(args[0]);
        if (String.IsNullOrEmpty(path)) return 3;

        if (Path.GetExtension(path).Equals(".wav", StringComparison.OrdinalIgnoreCase))
        {
            return PlayWav(path);
        }

        return PlayWithMci(path);
    }
}
