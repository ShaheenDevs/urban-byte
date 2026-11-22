using System.IO.Ports;
using System.Net.Http.Headers;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;

var configPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
if (!File.Exists(configPath)) configPath = Path.Combine(Directory.GetCurrentDirectory(), "appsettings.json");
if (!File.Exists(configPath)) throw new FileNotFoundException("Create appsettings.json from appsettings.example.json.");
var cfg = JsonSerializer.Deserialize<BridgeConfig>(await File.ReadAllTextAsync(configPath), new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? throw new Exception("Invalid appsettings.json.");
if (string.IsNullOrWhiteSpace(cfg.AccessToken) || cfg.AccessToken.StartsWith("PASTE_")) throw new Exception("Configure a dedicated bridge access token.");
using var http = new HttpClient { BaseAddress = new Uri(cfg.ApiBaseUrl.TrimEnd('/') + "/"), Timeout = TimeSpan.FromSeconds(20) };
http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", cfg.AccessToken);
Console.WriteLine("Urban Byte local printer bridge started. Ctrl+C to stop.");
var stopping = false;
Console.CancelKeyPress += (_, eventArgs) => { eventArgs.Cancel = true; stopping = true; };
while (!stopping)
{
    try
    {
        var body = JsonSerializer.Serialize(new { branchId = cfg.BranchId, printerId = cfg.PrinterId });
        using var response = await http.PostAsync("printing/jobs/claim", new StringContent(body, Encoding.UTF8, "application/json"));
        var raw = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode) throw new Exception($"Claim failed ({(int)response.StatusCode}): {raw}");
        using var doc = JsonDocument.Parse(raw);
        var data = doc.RootElement.GetProperty("data");
        if (data.ValueKind == JsonValueKind.Null) { await Task.Delay(cfg.PollIntervalMilliseconds); continue; }
        var jobId = data.GetProperty("id").ToString();
        try
        {
            var text = data.GetProperty("renderedText").GetString() ?? "";
            var bytes = Encoding.GetEncoding(437).GetBytes(text + "\n\n");
            if (!string.IsNullOrWhiteSpace(cfg.BluetoothComPort))
            {
                using var port = new SerialPort(cfg.BluetoothComPort, 9600, Parity.None, 8, StopBits.One) { WriteTimeout = 8000 };
                port.Open(); port.Write(new byte[] { 0x1B, 0x40 }, 0, 2); port.Write(bytes, 0, bytes.Length); port.Write(new byte[] { 0x1D, 0x56, 0x00 }, 0, 3); port.Close();
            }
            else
            {
                RawPrinter.Send(cfg.WindowsPrinterName, new byte[] { 0x1B, 0x40 }.Concat(bytes).Concat(new byte[] { 0x1D, 0x56, 0x00 }).ToArray());
            }
            await SetStatus(http, jobId, "printed", null);
            Console.WriteLine($"Printed job {jobId}.");
        }
        catch (Exception ex)
        {
            await SetStatus(http, jobId, "failed", ex.Message);
            Console.Error.WriteLine($"Print job {jobId} failed: {ex.Message}");
        }
    }
    catch (Exception ex) { Console.Error.WriteLine(ex.Message); await Task.Delay(Math.Max(cfg.PollIntervalMilliseconds, 3000)); }
}
static async Task SetStatus(HttpClient client, string id, string status, string? error)
{
    var body = JsonSerializer.Serialize(new { status, error });
    using var response = await client.PatchAsync($"printing/jobs/{id}/status", new StringContent(body, Encoding.UTF8, "application/json"));
    var content = await response.Content.ReadAsStringAsync();
    if (!response.IsSuccessStatusCode) throw new Exception($"Could not update print job {id}: {content}");
}
record BridgeConfig(string ApiBaseUrl, string AccessToken, long BranchId, long PrinterId, string WindowsPrinterName, string BluetoothComPort, int PollIntervalMilliseconds);

static class RawPrinter
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private class DOCINFO { public string pDocName = "Urban Byte Receipt"; public string? pOutputFile; public string pDataType = "RAW"; }
    [DllImport("winspool.drv", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool OpenPrinter(string name, out IntPtr handle, IntPtr defaults);
    [DllImport("winspool.drv", SetLastError = true)] private static extern bool ClosePrinter(IntPtr handle);
    [DllImport("winspool.drv", SetLastError = true, CharSet = CharSet.Unicode)] private static extern int StartDocPrinter(IntPtr handle, int level, [In] DOCINFO info);
    [DllImport("winspool.drv", SetLastError = true)] private static extern bool EndDocPrinter(IntPtr handle);
    [DllImport("winspool.drv", SetLastError = true)] private static extern bool StartPagePrinter(IntPtr handle);
    [DllImport("winspool.drv", SetLastError = true)] private static extern bool EndPagePrinter(IntPtr handle);
    [DllImport("winspool.drv", SetLastError = true)] private static extern bool WritePrinter(IntPtr handle, byte[] bytes, int count, out int written);
    public static void Send(string printerName, byte[] bytes)
    {
        if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException("Windows printer output requires Windows.");
        if (!OpenPrinter(printerName, out var handle, IntPtr.Zero)) throw new Exception($"Cannot open Windows printer '{printerName}'. Win32 error {Marshal.GetLastWin32Error()}.");
        try
        {
            if (StartDocPrinter(handle, 1, new DOCINFO()) == 0) throw new Exception("StartDocPrinter failed: " + Marshal.GetLastWin32Error());
            try
            {
                if (!StartPagePrinter(handle)) throw new Exception("StartPagePrinter failed: " + Marshal.GetLastWin32Error());
                if (!WritePrinter(handle, bytes, bytes.Length, out var written) || written != bytes.Length) throw new Exception("WritePrinter failed: " + Marshal.GetLastWin32Error());
                EndPagePrinter(handle);
            }
            finally { EndDocPrinter(handle); }
        }
        finally { ClosePrinter(handle); }
    }
}
