// Windows companion to the Telemetry Plasma widget. Hardware access is supplied
// by the unmodified LibreHardwareMonitor library (MPL-2.0).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using LibreHardwareMonitor.Hardware;

namespace Dfuse.Telemetry {
    public sealed class Reading {
        public int schema=1;
        public double capturedAt;
        public string provider="Telemetry/LibreHardwareMonitor",cpuName="CPU",gpuName="GPU",status="CONNECTING";
        public float? cpuTemp,gpuTemp,cpuLoad,gpuLoad,frequency,vramUsedGiB,vramTotalGiB;
        public float ram,disk;
        public bool fahrenheit;
    }
    public static class Store {
        public static readonly string DirectoryPath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"DFUSE","Telemetry");
        public static readonly string SnapshotPath=Path.Combine(DirectoryPath,"sensors.json");
        public static void Write(Reading data){
            Directory.CreateDirectory(DirectoryPath);
            string pending=SnapshotPath+".tmp";
            File.WriteAllText(pending,new JavaScriptSerializer().Serialize(data));
            if(File.Exists(SnapshotPath))File.Replace(pending,SnapshotPath,null);else File.Move(pending,SnapshotPath);
        }
        public static bool Fresh(Reading r,double now){return r!=null&&r.schema==1&&now-r.capturedAt>=0&&now-r.capturedAt<=8000;}
        public static double Now(){return (DateTime.UtcNow-new DateTime(1970,1,1)).TotalMilliseconds;}
    }
    sealed class Collector : IDisposable {
        readonly Computer computer=new Computer {IsCpuEnabled=true,IsGpuEnabled=true,IsMemoryEnabled=true};
        readonly PerformanceCounter cpu=new PerformanceCounter("Processor","% Processor Time","_Total",true);
        public Collector(){computer.Open();cpu.NextValue();}
        static float? Sensor(IHardware h,SensorType type,params string[] labels){
            foreach(string label in labels)foreach(ISensor s in h.Sensors)
                if(s.SensorType==type&&s.Name.Equals(label,StringComparison.OrdinalIgnoreCase)&&Valid(s.Value))return s.Value;
            return null;
        }
        static bool Valid(float? value){return value.HasValue&&!float.IsNaN(value.Value)&&!float.IsInfinity(value.Value);}
        static void Update(IHardware h){h.Update();foreach(IHardware sub in h.SubHardware)Update(sub);}
        public Reading Read(){
            Reading r=new Reading();List<string> errors=new List<string>();
            foreach(IHardware h in computer.Hardware){
                try {Update(h);
                    if(h.HardwareType==HardwareType.Cpu){
                        r.cpuName=h.Name;r.cpuTemp=Sensor(h,SensorType.Temperature,"Core (Tctl/Tdie)","CPU Package","Core (Tdie)","Core Max","CPU (Tctl/Tdie)");
                        r.cpuLoad=Sensor(h,SensorType.Load,"CPU Total");
                        var clocks=h.Sensors.Where(s=>s.SensorType==SensorType.Clock&&s.Name.StartsWith("CPU Core")&&Valid(s.Value)).ToArray();
                        if(clocks.Length>0)r.frequency=clocks.Average(s=>s.Value.Value)/1000f;
                        else r.frequency=Sensor(h,SensorType.Clock,"Cores (Average)")/1000f;
                    }
                    if(h.HardwareType==HardwareType.GpuAmd||h.HardwareType==HardwareType.GpuNvidia||h.HardwareType==HardwareType.GpuIntel){
                        // Prefer a GPU with dedicated memory over one without it.
                        float? memory=Sensor(h,SensorType.SmallData,"GPU Memory Total");
                        if(r.gpuName!="GPU"&&(!memory.HasValue||(r.vramTotalGiB.HasValue&&memory.Value/1024<=r.vramTotalGiB)))continue;
                        r.gpuName=h.Name;r.gpuTemp=Sensor(h,SensorType.Temperature,"GPU Core","GPU Temperature");
                        r.gpuLoad=Sensor(h,SensorType.Load,"GPU Core","GPU D3D 3D");
                        var used=Sensor(h,SensorType.SmallData,"GPU Memory Used");r.vramUsedGiB=used/1024;r.vramTotalGiB=memory/1024;
                    }
                    if(h.HardwareType==HardwareType.Memory){var load=Sensor(h,SensorType.Load,"Memory");if(load.HasValue)r.ram=load.Value;}
                }catch(Exception ex){errors.Add(h.Name+": "+ex.Message);}
            }
            if(!r.gpuTemp.HasValue)r.gpuTemp=WindowsGpu.Temperature(r.gpuName);
            if(!r.cpuLoad.HasValue)try{r.cpuLoad=Math.Max(0,Math.Min(100,cpu.NextValue()));}catch{}
            try{var drive=new DriveInfo(Path.GetPathRoot(Environment.SystemDirectory));r.disk=(float)(100.0*(drive.TotalSize-drive.AvailableFreeSpace)/drive.TotalSize);}catch{}
            if(r.cpuTemp.HasValue&&(r.cpuTemp<0||r.cpuTemp>130))r.cpuTemp=null;
            if(r.gpuTemp.HasValue&&(r.gpuTemp<0||r.gpuTemp>130))r.gpuTemp=null;
            r.status=errors.Count>0?String.Join("; ",errors):r.cpuTemp.HasValue?"SYSTEM ONLINE":"CPU SENSOR UNAVAILABLE / check PawnIO and administrator access";
            r.capturedAt=Store.Now();return r;
        }
        public string Diagnostics(){return computer.GetReport();}
        public void Dispose(){computer.Close();cpu.Dispose();}
    }
    static class Program {
        [STAThread] static void Main(string[] args){
            Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
            if(args.Contains("--test")){Tests.Run();return;}
            bool fresh;
            using(var mutex=new Mutex(true,"Local\\DFUSE.Telemetry.Collector",out fresh)){
                if(!fresh){try{using(var ev=EventWaitHandle.OpenExisting("Local\\DFUSE.Telemetry.Show"))ev.Set();}catch{}return;}
                try{
                    if(args.Contains("--probe")){using(var collector=new Collector()){Thread.Sleep(1000);var r=collector.Read();Store.Write(r);File.WriteAllText(Path.Combine(Store.DirectoryPath,"sensor-report.txt"),collector.Diagnostics());}return;}
                    Application.Run(new Dashboard(args.Contains("--tray")));
                }catch(Exception ex){Directory.CreateDirectory(Store.DirectoryPath);File.WriteAllText(Path.Combine(Store.DirectoryPath,"error.txt"),ex.ToString());if(!args.Contains("--probe"))MessageBox.Show(ex.Message,"Telemetry could not start");}
            }
        }
    }
    sealed class Dashboard : Form {
        readonly System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer();
        readonly NotifyIcon tray=new NotifyIcon();readonly Queue<float?> history=new Queue<float?>();
        readonly ComboBox themes=new ComboBox();readonly CheckBox fahrenheit=new CheckBox();
        readonly EventWaitHandle showSignal=new EventWaitHandle(false,EventResetMode.AutoReset,"Local\\DFUSE.Telemetry.Show");
        Collector collector;Reading reading=new Reading();bool busy,exit,hidden;string theme="original";
        Color Accent{get{return theme=="ember"?Color.FromArgb(255,155,67):theme=="cyber"?Color.FromArgb(223,117,255):theme=="mono"?Color.FromArgb(229,233,240):theme=="arctic"?Color.FromArgb(67,217,255):Color.FromArgb(0,240,228);}}
        Color Secondary{get{return theme=="ember"?Color.FromArgb(255,89,100):theme=="arctic"?Color.FromArgb(71,138,255):Color.FromArgb(177,108,255);}}
        readonly Color text=Color.FromArgb(241,246,255),muted=Color.FromArgb(182,198,220);
        public Dashboard(bool startHidden){
            hidden=startHidden;Text="Telemetry | DFUSE";ClientSize=new Size(480,650);MinimumSize=new Size(496,689);BackColor=Color.FromArgb(8,14,29);ForeColor=text;
            Font=new Font("Segoe UI",10);DoubleBuffered=true;
            themes.Items.AddRange(new object[]{"original","arctic","ember","cyber","mono"});themes.DropDownStyle=ComboBoxStyle.DropDownList;themes.SetBounds(22,608,150,26);themes.SelectedIndex=0;
            themes.SelectedIndexChanged+=delegate{theme=Convert.ToString(themes.SelectedItem);SaveSettings();Invalidate();};Controls.Add(themes);
            fahrenheit.Text="Taskbar Fahrenheit";fahrenheit.SetBounds(205,608,220,26);fahrenheit.CheckedChanged+=delegate{SaveSettings();};Controls.Add(fahrenheit);
            try{var settings=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(Store.DirectoryPath,"settings.json")));theme=Convert.ToString(settings["theme"]);themes.SelectedItem=theme;fahrenheit.Checked=Convert.ToBoolean(settings["fahrenheit"]);}catch{}
            var menu=new ContextMenuStrip();menu.Items.Add("Open Telemetry",null,delegate{ShowDashboard();});menu.Items.Add("Exit Telemetry",null,delegate{exit=true;Close();});
            tray.Icon=SystemIcons.Application;tray.Text="Telemetry";tray.ContextMenuStrip=menu;tray.Visible=true;tray.DoubleClick+=delegate{ShowDashboard();};
            timer.Interval=1000;timer.Tick+=delegate{
                string request=Path.Combine(Store.DirectoryPath,"open-dashboard.request");
                bool open=showSignal.WaitOne(0);
                try{if(File.Exists(request)){File.Delete(request);open=true;}}catch{}
                if(open)ShowDashboard();Poll();
            };timer.Start();Poll();
            FormClosing+=delegate(object sender,FormClosingEventArgs e){if(!exit&&e.CloseReason==CloseReason.UserClosing){e.Cancel=true;Hide();}};
        }
        protected override void SetVisibleCore(bool value){if(hidden){hidden=false;base.SetVisibleCore(false);}else base.SetVisibleCore(value);}
        void ShowDashboard(){Show();WindowState=FormWindowState.Normal;Activate();}
        void SaveSettings(){Directory.CreateDirectory(Store.DirectoryPath);File.WriteAllText(Path.Combine(Store.DirectoryPath,"settings.json"),new JavaScriptSerializer().Serialize(new {theme=theme,fahrenheit=fahrenheit.Checked}));}
        void Poll(){
            if(busy)return;busy=true;
            bool displayFahrenheit=fahrenheit.Checked;
            ThreadPool.QueueUserWorkItem(delegate{
                Reading next;
                try{if(collector==null)collector=new Collector();next=collector.Read();next.fahrenheit=displayFahrenheit;Store.Write(next);}catch(Exception ex){next=new Reading {status=ex.Message,capturedAt=Store.Now()};}
                try{BeginInvoke((MethodInvoker)delegate{reading=next;history.Enqueue(next.cpuLoad);while(history.Count>60)history.Dequeue();busy=false;Invalidate();});}catch(InvalidOperationException){}
            });
        }
        protected override void OnFormClosed(FormClosedEventArgs e){timer.Stop();tray.Dispose();showSignal.Dispose();if(!busy&&collector!=null)collector.Dispose();base.OnFormClosed(e);}
        void Label(Graphics g,string value,float size,Color color,float x,float y,bool bold=false){using(Font f=new Font("Segoe UI",size,bold?FontStyle.Bold:FontStyle.Regular))using(Brush b=new SolidBrush(color))g.DrawString(value,f,b,x,y);}
        void Tile(Graphics g,Rectangle r){using(Brush b=new SolidBrush(Color.FromArgb(15,25,45)))g.FillRectangle(b,r);using(Pen p=new Pen(Color.FromArgb(50,65,95)))g.DrawRectangle(p,r);}
        void Gauge(Graphics g,int x,string title,float? value,float max,string unit,Color color){
            Rectangle arc=new Rectangle(x+8,105,116,116);using(Pen p=new Pen(Color.FromArgb(40,55,80),8))g.DrawArc(p,arc,135,270);
            if(value.HasValue)using(Pen p=new Pen(color,8)){p.StartCap=p.EndCap=LineCap.Round;g.DrawArc(p,arc,135,270*Math.Max(0,Math.Min(1,value.Value/max)));}
            Label(g,title,9,muted,x+20,80,true);Label(g,value.HasValue?value.Value.ToString("0")+unit:"N/A",23,color,x+25,145,true);
        }
        void Meter(Graphics g,int x,int y,string name,float? value,Color color){
            Label(g,name,9,muted,x,y,true);Label(g,value.HasValue?value.Value.ToString("0")+"%":"N/A",12,color,x+140,y-3,true);
            using(Brush b=new SolidBrush(Color.FromArgb(35,50,75)))g.FillRectangle(b,x,y+27,204,7);
            if(value.HasValue)using(Brush b=new SolidBrush(color))g.FillRectangle(b,x,y+27,204*Math.Max(0,Math.Min(1,value.Value/100)),7);
        }
        protected override void OnPaint(PaintEventArgs e){
            base.OnPaint(e);Graphics g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;
            Label(g,"TELEMETRY",20,Secondary,22,16,true);Label(g,reading.cpuName,9,muted,24,49);
            Gauge(g,24,"CPU TEMP / F",reading.cpuTemp*1.8f+32,212,"°",Accent);
            Gauge(g,173,"CPU TEMP / C",reading.cpuTemp,100,"°",Secondary);
            Gauge(g,322,"CPU LOAD",reading.cpuLoad,100,"%",Accent);
            Rectangle chart=new Rectangle(22,260,436,115);Tile(g,chart);Label(g,"CPU ACTIVITY",10,text,34,269,true);
            for(int j=1;j<=3;j++)using(Pen p=new Pen(Color.FromArgb(35,54,80)))g.DrawLine(p,34,296+j*18,446,296+j*18);
            var points=history.ToArray();using(Pen p=new Pen(Accent,2))for(int i=1;i<points.Length;i++)if(points[i-1].HasValue&&points[i].HasValue)g.DrawLine(p,34+(i-1)*412f/59,366-points[i-1].Value*.65f,34+i*412f/59,366-points[i].Value*.65f);
            Label(g,"SYSTEM RESOURCES",10,Secondary,22,390,true);Meter(g,22,418,"MEMORY",reading.ram,Accent);Meter(g,254,418,"STORAGE",reading.disk,Secondary);
            Tile(g,new Rectangle(22,471,436,104));
            Label(g,reading.gpuName,10,muted,34,480,true);
            string gpu=reading.gpuTemp.HasValue?String.Format("{0:0.0}°F / {1:0.0}°C",reading.gpuTemp*1.8f+32,reading.gpuTemp):"TEMPERATURE N/A";
            Label(g,gpu,14,Accent,34,505,true);
            Label(g,"GPU "+(reading.gpuLoad.HasValue?reading.gpuLoad.Value.ToString("0")+"%":"N/A"),11,Secondary,335,509,true);
            Label(g,"CPU CLOCK  "+(reading.frequency.HasValue?reading.frequency.Value.ToString("0.00")+" GHz":"N/A"),10,Secondary,34,544,true);
            Label(g,"VRAM "+(reading.vramUsedGiB.HasValue&&reading.vramTotalGiB.HasValue?reading.vramUsedGiB.Value.ToString("0.0")+" / "+reading.vramTotalGiB.Value.ToString("0.0")+" GiB":"N/A"),9,Accent,260,545);
            Label(g,reading.status,8,reading.cpuTemp.HasValue?Accent:Color.Orange,22,584);
        }
    }
    static class Tests {
        public static void Run(){
            double now=Store.Now();var r=new Reading{capturedAt=now,cpuTemp=62.5f,gpuTemp=40f};
            if(!Store.Fresh(r,now)||Store.Fresh(r,now+9000)||Store.Fresh(r,now-1))throw new Exception("Freshness bounds");
            var copy=new JavaScriptSerializer().Deserialize<Reading>(new JavaScriptSerializer().Serialize(r));
            if(copy.cpuTemp!=62.5f||copy.gpuTemp!=40f)throw new Exception("Round trip");
            r.cpuTemp=null;if(new JavaScriptSerializer().Deserialize<Reading>(new JavaScriptSerializer().Serialize(r)).cpuTemp.HasValue)throw new Exception("Missing sensor");
            File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"test-result.txt"),"PASS: freshness, clock bounds, JSON schema round trip, missing sensors");
        }
    }
}
