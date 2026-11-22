# Urban Byte Windows Printer Bridge

This local bridge runs on the Windows PC connected to the USB or Bluetooth ESC/POS printer. It polls the Urban Byte API for queued jobs and reports print success/failure.

## Requirements
- Windows 10/11
- .NET 8 SDK
- A Windows-installed USB printer queue, or a Bluetooth serial COM port (SPP)
- A dedicated staff account/token with `printing.bridge`
- Branch ID and printer device ID from Printer Management

## Configuration
Copy `appsettings.example.json` to `appsettings.json` and set:
- ApiBaseUrl, e.g. `http://127.0.0.1:4000/api/v1`
- AccessToken (use a dedicated bridge account; do not commit it)
- BranchId and PrinterId
- WindowsPrinterName for USB, exactly as shown in Windows Printers & scanners
- BluetoothComPort for paired Bluetooth SPP devices, e.g. COM5. Leave blank for USB.

## Run
`dotnet run`

The bridge claims one queued job at a time, sends the server-rendered receipt text to the configured Windows printer or Bluetooth serial port, and marks the job printed or failed. Keep the PC awake and on the same network as the API. For production, use a dedicated least-privilege account and store the token outside source control.

This is a local bridge: it does not expose an inbound HTTP port and does not make the printer publicly reachable. USB printing requires a working Windows printer driver/queue. Bluetooth must expose a paired serial (SPP) COM port; BLE-only printers are not supported by this first bridge version.
