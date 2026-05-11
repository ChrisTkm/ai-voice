using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Text;

class Program
{
    [DllImport("winmm.dll", CharSet = CharSet.Auto)]
    static extern int mciSendString(string cmd, StringBuilder ret, int len, IntPtr cb);

    [STAThread]
    static int Main(string[] args)
    {
        if (args.Length < 1) return 1;
        string target = args[0];
        string path;
        if (Directory.Exists(target))
        {
            string[] files = Directory.GetFiles(target, "*.mp3");
            if (files.Length == 0) return 3;
            path = files[new Random().Next(files.Length)];
        }
        else
        {
            path = target;
        }
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
}
