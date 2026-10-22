using System;
using System.Runtime.InteropServices;
namespace Dfuse.Telemetry {
    // Public Windows D3DKMT adapter queries; mirrors documented WDK structures.
    static class WindowsGpu {
        [StructLayout(LayoutKind.Sequential)] struct Luid {public uint Low;public int High;}
        [StructLayout(LayoutKind.Sequential)] struct Adapter {public uint Handle;public Luid Id;public uint Sources;public int Preferred;}
        [StructLayout(LayoutKind.Sequential)] struct Enumeration {public uint Count;public IntPtr Adapters;}
        [StructLayout(LayoutKind.Sequential)] struct Query {public uint Handle,Type;public IntPtr Data;public uint Size;}
        [StructLayout(LayoutKind.Sequential)] struct Close {public uint Handle;}
        [DllImport("gdi32.dll")] static extern int D3DKMTEnumAdapters2(ref Enumeration e);
        [DllImport("gdi32.dll")] static extern int D3DKMTQueryAdapterInfo(ref Query q);
        [DllImport("gdi32.dll")] static extern int D3DKMTCloseAdapter(ref Close c);
        public static float? Temperature(string expectedName){
            if(String.IsNullOrEmpty(expectedName)||expectedName=="GPU")return null;
            int stride=Marshal.SizeOf(typeof(Adapter));IntPtr adapters=Marshal.AllocHGlobal(stride*16),buffer=Marshal.AllocHGlobal(2080);var e=new Enumeration{Count=16,Adapters=adapters};bool enumerated=false;
            try {
                if(D3DKMTEnumAdapters2(ref e)!=0)return null;enumerated=true;
                for(int i=0;i<Math.Min(16,e.Count);i++){
                    var a=(Adapter)Marshal.PtrToStructure(IntPtr.Add(adapters,i*stride),typeof(Adapter));
                    var q=new Query{Handle=a.Handle,Type=8,Data=buffer,Size=2080};
                    if(D3DKMTQueryAdapterInfo(ref q)!=0)continue;
                    string name=Marshal.PtrToStringUni(buffer,260).TrimEnd('\0');
                    if(!name.Equals(expectedName,StringComparison.OrdinalIgnoreCase))continue;
                    for(int j=0;j<64;j++)Marshal.WriteByte(buffer,j,0);
                    q.Type=62;q.Size=64;
                    if(D3DKMTQueryAdapterInfo(ref q)==0){uint raw=(uint)Marshal.ReadInt32(buffer,56);if(raw>0&&raw<=2000)return raw/10f;}
                }
                return null;
            }catch{return null;}
            finally {
                if(enumerated)for(int i=0;i<Math.Min(16,e.Count);i++){var a=(Adapter)Marshal.PtrToStructure(IntPtr.Add(adapters,i*stride),typeof(Adapter));if(a.Handle!=0){var close=new Close{Handle=a.Handle};D3DKMTCloseAdapter(ref close);}}
                Marshal.FreeHGlobal(adapters);Marshal.FreeHGlobal(buffer);
            }
        }
    }
}
