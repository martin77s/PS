Add-Type -TypeDefinition @"

// References:
// http://msdn.microsoft.com/en-us/library/aa379887(v=vs.85).aspx
// http://msdn.microsoft.com/en-us/library/aa380285(v=vs.85).aspx

using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

public static class PIDLUtils {
    [DllImport("shell32.dll")]
    public static extern Int32 SHGetDesktopFolder(out IShellFolder ppshf);

    [DllImport("shell32.dll")]
    public static extern bool SHGetPathFromIDList(IntPtr pidl, StringBuilder pszPath);

    [DllImport("crypt32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CryptBinaryToString(IntPtr pcbBinary, int cbBinary, uint dwFlags, StringBuilder pszString, ref int pcchString);

    [DllImport("crypt32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CryptStringToBinary(string pszString, int cchString, uint dwFlags, IntPtr pbBinary, ref int pcbBinary, ref int pdwSkip, ref int pdwFlags);

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("000214E6-0000-0000-C000-000000000046")]
    public interface IShellFolder {
        Int32 ParseDisplayName(IntPtr hwnd, IntPtr pbc, String pszDisplayName, UInt32 pchEaten, out IntPtr ppidl, UInt32 pdwAttributes);
        Int32 EnumObjects(IntPtr hwnd, ESHCONTF grfFlags, out IntPtr ppenumIDList);
        Int32 BindToObject(IntPtr pidl, IntPtr pbc, [In]ref Guid riid, out IntPtr ppv);
        Int32 BindToStorage(IntPtr pidl, IntPtr pbc, [In]ref Guid riid, out IntPtr ppv);
        Int32 CompareIDs(Int32 lParam, IntPtr pidl1, IntPtr pidl2);
        Int32 CreateViewObject(IntPtr hwndOwner, [In] ref Guid riid, out IntPtr ppv);
        Int32 GetAttributesOf(UInt32 cidl, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 0)]IntPtr[] apidl, ref ESFGAO rgfInOut);
        Int32 GetUIObjectOf(IntPtr hwndOwner, UInt32 cidl, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 1)]IntPtr[] apidl, [In] ref Guid riid, UInt32 rgfReserved, out IntPtr ppv);
        Int32 GetDisplayNameOf(IntPtr pidl, ESHGDN uFlags, out ESTRRET pName);
        Int32 SetNameOf(IntPtr hwnd, IntPtr pidl, String pszName, ESHCONTF uFlags, out IntPtr ppidlOut);
    }

    public enum ESHCONTF {
        SHCONTF_FOLDERS = 0x0020,
        SHCONTF_NONFOLDERS = 0x0040,
        SHCONTF_INCLUDEHIDDEN = 0x0080,
        SHCONTF_INIT_ON_FIRST_NEXT = 0x0100,
        SHCONTF_NETPRINTERSRCH = 0x0200,
        SHCONTF_SHAREABLE = 0x0400,
        SHCONTF_STORAGE = 0x0800
    }

    public enum ESFGAO : uint {
        SFGAO_CANCOPY = 0x00000001,
        SFGAO_CANMOVE = 0x00000002,
        SFGAO_CANLINK = 0x00000004,
        SFGAO_LINK = 0x00010000,
        SFGAO_SHARE = 0x00020000,
        SFGAO_READONLY = 0x00040000,
        SFGAO_HIDDEN = 0x00080000,
        SFGAO_FOLDER = 0x20000000,
        SFGAO_FILESYSTEM = 0x40000000,
        SFGAO_HASSUBFOLDER = 0x80000000,
    }

    public enum ESHGDN {
        SHGDN_NORMAL = 0x0000,
        SHGDN_INFOLDER = 0x0001,
        SHGDN_FOREDITING = 0x1000,
        SHGDN_FORADDRESSBAR = 0x4000,
        SHGDN_FORPARSING = 0x8000,
    }

    public enum ESTRRET : int {
        eeRRET_WSTR = 0x0000,
        STRRET_OFFSET = 0x0001,
        STRRET_CSTR = 0x0002
    }

    private const uint CRYPT_STRING_BASE64 = 1;


    public static string Encode(string myPath) {
        IShellFolder folder;
        IntPtr pidl;
        string myPathEncrypted = "ERROR";
        string myPathInClearText = myPath;


        if (SHGetDesktopFolder(out folder) == 0) {
            folder.ParseDisplayName(IntPtr.Zero, IntPtr.Zero, myPathInClearText, 0, out pidl, 0);

            int k = 0;
            short cb = 0;
				
            // ONLY WORKS WITH .NET FRAMEWORK 4	
            //  while ((k = Marshal.ReadInt16(pidl + cb)) > 0) {
            //      cb += (short)k;
            //  }
			  
            IntPtr tempIntPtr = new IntPtr(pidl.ToInt64() + cb);
            while ((k = Marshal.ReadInt16(tempIntPtr)) > 0) {
                cb += (short)k;
                tempIntPtr = new IntPtr(pidl.ToInt64() + cb);
            }

            cb += 2;

            StringBuilder sb = new StringBuilder();
            int large = 0;

            CryptBinaryToString(pidl, cb, CRYPT_STRING_BASE64, null, ref large);
            sb.Capacity = large;
                
            if (CryptBinaryToString(pidl, cb, CRYPT_STRING_BASE64, sb, ref large)) {
                myPathEncrypted = sb.ToString();
            }
            Marshal.FreeCoTaskMem(pidl);
        }
        
        return myPathEncrypted;
    }
		

    public static string Decode (string myEncryptedPath) {
        IShellFolder folder;
        // IntPtr pidl;
        string myPathDecrypted = "ERROR";
        string mypathEncriptado = myEncryptedPath; // Regex.Escape(myEncryptedPath);

        if (SHGetDesktopFolder(out folder) == 0) {
              
            int a = 0;
            int b = 0;
            int large = 0;

            CryptStringToBinary(mypathEncriptado, mypathEncriptado.Length, CRYPT_STRING_BASE64, IntPtr.Zero, ref large, ref a, ref b);
            IntPtr pidl2 = Marshal.AllocCoTaskMem(large);
            StringBuilder sb = new StringBuilder();
            if (CryptStringToBinary(mypathEncriptado, mypathEncriptado.Length, CRYPT_STRING_BASE64, pidl2, ref large, ref a, ref b)) {
                //sb.Clear(); Only works with .NET 4
                sb.Length = 0;
                sb.Capacity = 261;
                SHGetPathFromIDList(pidl2, sb);
                myPathDecrypted = sb.ToString();
            }

            //Marshal.FreeCoTaskMem(pidl);
            Marshal.FreeCoTaskMem(pidl2);
        }
        return myPathDecrypted;
    }       
}

"@


$myPath = Read-Host "Enter the path you'd like to encypt"

$Encrypted = [PIDLUtils]::Encode($myPath)
$Encrypted
	
$Decrypted = [PIDLUtils]::Decode($Encrypted) 
$Decrypted
