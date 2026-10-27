#include "flutter_window.h"

#include <optional>
#include <shellapi.h>
#include <flutter/standard_method_codec.h>
#include "resource.h"

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  companion_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "yopet/desktop_companion",
      &flutter::StandardMethodCodec::GetInstance());
  companion_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "enter") {
      if (EnterCompanion()) result->Success();
      else result->Error("companion_unavailable", "Tray or recovery hotkey unavailable");
    } else if (call.method_name() == "exit") {
      RestoreCompanion();
      result->Success();
    } else if (call.method_name() == "frame") {
      const auto* frame = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
      if (frame && PresentFrame(*frame)) {
        POINT cursor;
        RECT bounds;
        GetCursorPos(&cursor);
        GetWindowRect(overlay_, &bounds);
        result->Success(flutter::EncodableValue(flutter::EncodableMap{
          {flutter::EncodableValue("x"), flutter::EncodableValue(static_cast<int32_t>(cursor.x - bounds.left))},
          {flutter::EncodableValue("y"), flutter::EncodableValue(static_cast<int32_t>(cursor.y - bounds.top))}}));
      }
      else result->Error("frame_failed", "Unable to present transparent frame; Win32=" + std::to_string(GetLastError()));
    } else {
      result->NotImplemented();
    }
  });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (companion_) RestoreCompanion();
  companion_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_HOTKEY && wparam == 701) {
    RestoreCompanion();
    return 0;
  }
  if (message == WM_APP + 71) {
    if (lparam == WM_LBUTTONDBLCLK) RestoreCompanion();
    if (lparam == WM_RBUTTONUP) {
      POINT point;
      GetCursorPos(&point);
      HMENU menu = CreatePopupMenu();
      AppendMenuW(menu, MF_STRING, 1, L"\u8fd4\u56de\u9c7c\u7f38");
      AppendMenuW(menu, MF_STRING, 3, L"\u966a\u6211\u4e00\u4f1a\u513f");
      AppendMenuW(menu, MF_STRING, 2, L"\u9000\u51fa Yopet");
      SetForegroundWindow(hwnd);
      const auto command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY,
          point.x, point.y, 0, hwnd, nullptr);
      DestroyMenu(menu);
      if (command == 1) RestoreCompanion();
      if (command == 3 && companion_channel_) companion_channel_->InvokeMethod("company", nullptr);
      if (command == 2) PostMessage(hwnd, WM_CLOSE, 0, 0);
    }
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

bool FlutterWindow::EnterCompanion() {
  if (companion_) return true;
  HWND hwnd = GetHandle();
  if (!RegisterHotKey(hwnd, 701, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, 'Y')) return false;
  NOTIFYICONDATAW icon{};
  icon.cbSize = sizeof(icon);
  icon.hWnd = hwnd;
  icon.uID = 71;
  icon.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  icon.uCallbackMessage = WM_APP + 71;
  icon.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(icon.szTip, L"Yopet - Ctrl+Alt+Y \u8fd4\u56de\u9c7c\u7f38");
  if (!Shell_NotifyIconW(NIM_ADD, &icon)) {
    UnregisterHotKey(hwnd, 701);
    return false;
  }
  saved_style_ = GetWindowLongPtr(hwnd, GWL_STYLE);
  saved_ex_style_ = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
  GetWindowPlacement(hwnd, &saved_placement_);
  MONITORINFO monitor{sizeof(MONITORINFO)};
  const POINT origin{0, 0};
  GetMonitorInfo(MonitorFromPoint(origin, MONITOR_DEFAULTTOPRIMARY), &monitor);
  companion_ = true;
  SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
  SetWindowLongPtr(hwnd, GWL_EXSTYLE,
      (saved_ex_style_ & ~WS_EX_APPWINDOW) | WS_EX_LAYERED | WS_EX_TRANSPARENT |
      WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);
  overlay_ = CreateWindowExW(WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW |
      WS_EX_NOACTIVATE | WS_EX_TOPMOST, L"STATIC", L"Yopet companion", WS_POPUP,
      monitor.rcMonitor.left, monitor.rcMonitor.top,
      monitor.rcMonitor.right - monitor.rcMonitor.left,
      monitor.rcMonitor.bottom - monitor.rcMonitor.top, nullptr, nullptr,
      GetModuleHandle(nullptr), nullptr);
  if (!overlay_ || !SetLayeredWindowAttributes(hwnd, 0, 0, LWA_ALPHA)) {
    RestoreCompanion();
    return false;
  }
  SetWindowPos(hwnd, HWND_TOPMOST, monitor.rcMonitor.left, monitor.rcMonitor.top,
      monitor.rcMonitor.right - monitor.rcMonitor.left,
      monitor.rcMonitor.bottom - monitor.rcMonitor.top,
      SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_SHOWWINDOW);
  return true;
}

void FlutterWindow::RestoreCompanion() {
  if (!companion_) return;
  HWND hwnd = GetHandle();
  companion_ = false;
  for (const auto& entry : fish_overlays_) DestroyWindow(entry.second);
  fish_overlays_.clear();
  if (overlay_) { DestroyWindow(overlay_); overlay_ = nullptr; }
  NOTIFYICONDATAW icon{};
  icon.cbSize = sizeof(icon);
  icon.hWnd = hwnd;
  icon.uID = 71;
  Shell_NotifyIconW(NIM_DELETE, &icon);
  UnregisterHotKey(hwnd, 701);
  SetWindowLongPtr(hwnd, GWL_STYLE, saved_style_);
  SetWindowLongPtr(hwnd, GWL_EXSTYLE, saved_ex_style_);
  SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
      SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);
  SetWindowPlacement(hwnd, &saved_placement_);
  if (companion_channel_) companion_channel_->InvokeMethod("restored", nullptr);
  ShowWindow(hwnd, SW_SHOW);
  SetForegroundWindow(hwnd);
}

bool FlutterWindow::PresentFrame(const flutter::EncodableMap& frame) {
  if (!companion_ || !overlay_) return false;
  const auto id_entry = frame.find(flutter::EncodableValue("id"));
  const auto x_entry = frame.find(flutter::EncodableValue("x"));
  const auto y_entry = frame.find(flutter::EncodableValue("y"));
  if (id_entry == frame.end() || x_entry == frame.end() || y_entry == frame.end()) return false;
  const auto* id = std::get_if<std::string>(&id_entry->second);
  const auto* x = std::get_if<int32_t>(&x_entry->second);
  const auto* y = std::get_if<int32_t>(&y_entry->second);
  if (!id || !x || !y) return false;
  if (!fish_overlays_.count(*id)) {
    if (fish_overlays_.size() >= 5) return false;
    HWND fish = CreateWindowExW(WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TOPMOST,
        L"STATIC", L"Yopet fish", WS_POPUP, 0, 0, 1, 1, nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
    if (!fish) return false;
    fish_overlays_[*id] = fish;
  }
  HWND fish_window = fish_overlays_[*id];
  const auto w = frame.find(flutter::EncodableValue("width"));
  const auto h = frame.find(flutter::EncodableValue("height"));
  const auto p = frame.find(flutter::EncodableValue("pixels"));
  if (w == frame.end() || h == frame.end() || p == frame.end()) return false;
  const auto* width = std::get_if<int32_t>(&w->second);
  const auto* height = std::get_if<int32_t>(&h->second);
  const auto* pixels = std::get_if<std::vector<uint8_t>>(&p->second);
  if (!width || !height || !pixels || *width <= 0 || *height <= 0 ||
      *width > 8192 || *height > 8192 || pixels->size() != static_cast<size_t>(*width) * *height * 4) return false;
  HDC screen = GetDC(nullptr);
  HDC dc = CreateCompatibleDC(screen);
  BITMAPINFO info{};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = *width;
  info.bmiHeader.biHeight = -*height;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* bits = nullptr;
  HBITMAP bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
  bool ok = false;
  if (bitmap && dc && bits) {
    memcpy(bits, pixels->data(), pixels->size());
    HGDIOBJ old = SelectObject(dc, bitmap);
    RECT bounds;
    GetWindowRect(overlay_, &bounds);
    POINT position{bounds.left + *x, bounds.top + *y}, source{0, 0};
    SIZE size{*width, *height};
    BLENDFUNCTION blend{AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
    ok = UpdateLayeredWindow(fish_window, screen, &position, &size, dc,
        &source, 0, &blend, ULW_ALPHA) != 0;
    SelectObject(dc, old);
    if (ok) ShowWindow(fish_window, SW_SHOWNOACTIVATE);
  }
  if (bitmap) DeleteObject(bitmap);
  if (dc) DeleteDC(dc);
  ReleaseDC(nullptr, screen);
  return ok;
}
