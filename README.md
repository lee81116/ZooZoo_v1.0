# 🐱 ZooZoo v0.2

可愛動物主題的叫車 App，使用 Flutter 開發。

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)

## 📱 功能特色

- 🚗 **乘客端**：叫車、選擇目的地、選擇車型
- 🚕 **司機端**：上線/下線(顯示)、背景模式(作業中)
- 🗺️ **地圖整合**：OpenStreetMap（可切換至 Mapbox）
- 🎨 **奶茶色主題**：焦糖奶茶 #D4A574 + 濃縮咖啡 #4A3728
- 🌓 **深色模式**：支援淺色/深色主題切換

## 🐾 車型介紹

| 車型 | 說明 |
|------|------|
| 🐕 元氣汪汪   | 標準舒適 |
| 🐱 招財貓貓   | 尊榮寬敞 |
| 🐻‍❄️ 北極熊阿北 | 減碳環保 |
| 🦘 袋鼠媽媽   | 親子座椅 |

---

## 🛠️ 環境建置

### 1. 安裝 Flutter SDK

#### Windows

```bash
# 1. 下載 Flutter SDK
# https://docs.flutter.dev/get-started/install/windows

# 2. 解壓縮到你想要的位置，例如：
C:\src\flutter

# 3. 加入系統環境變數 PATH
# 控制台 → 系統 → 進階系統設定 → 環境變數
# 在 Path 中新增：C:\src\flutter\bin

# 4. 重新開啟終端機，驗證安裝
flutter --version
```

#### macOS

```bash
# 使用 Homebrew 安裝
brew install --cask flutter

# 或手動下載
# https://docs.flutter.dev/get-started/install/macos

# 驗證安裝
flutter --version
```

#### Linux

```bash
# 使用 snap 安裝
sudo snap install flutter --classic

# 驗證安裝
flutter --version
```

### 2. 安裝開發工具

#### Antigravity（推薦）

1. 下載安裝 [Antigravity](https://antigravity.google/download)
2. 安裝擴充套件：
   - Flutter
   - Dart

#### VS Code（替代）

1. 下載安裝 [VS Code](https://code.visualstudio.com/)
2. 安裝擴充套件：
   - Flutter
   - Dart

#### Android Studio（推薦）

1. 下載安裝 [Android Studio](https://developer.android.com/studio)
2. 開啟 Android Studio → Settings → Plugins
3. 搜尋並安裝 **Flutter** 和 **Dart** 插件
4. 重啟 Android Studio

### 3. 執行 Flutter Doctor

```bash
flutter doctor
```

確認所有項目都打勾 ✓，如果有問題會顯示修復建議。

---

## 🚀 專案執行

### 1. Clone 專案

```bash
git clone https://github.com/lee81116/ZooZoo_v1.0.git
cd ZooZoo_v1.0
```

### 2. 安裝依賴

```bash
flutter pub get
```

### 3. 執行 App

#### Chrome（Web）

```bash
flutter run -d chrome
```

#### Android 模擬器

```bash
# 列出可用裝置
flutter devices

# 執行（會自動選擇模擬器）
flutter run
```

#### iOS 模擬器（僅限 macOS）

```bash
# 開啟 iOS 模擬器
open -a Simulator

# 執行
flutter run
```

#### 實體手機

1. 開啟手機的開發者模式和 USB 偵錯
2. 用 USB 連接電腦
3. 執行：

```bash
flutter devices  # 確認手機有被偵測到
flutter run
```

---

## 🧪 測試帳號

| 角色 | 帳號 | 密碼 |
|------|------|------|
| 乘客 | `00` | `00` |
| 司機 | `01` | `01` |

---

## 📁 專案結構

```
lib/
├── main.dart                 # 程式進入點
├── app/
│   └── router/               # 路由設定
├── core/
│   ├── constants/            # 常數定義
│   ├── theme/                # 主題樣式
│   └── services/
│       └── map/              # 地圖服務抽象層
├── shared/
│   └── widgets/              # 共用元件
└── features/
    ├── auth/                 # 登入/註冊
    ├── passenger/            # 乘客端功能
    │   ├── home/             # 首頁
    │   ├── booking/          # 叫車流程
    │   ├── store/            # 商店
    │   └── settings/         # 設定
    └── driver/               # 司機端功能
        ├── home/             # 首頁
        ├── history/          # 歷史紀錄
        └── settings/         # 設定
```

---

## 🔧 常見問題

### Q: `flutter pub get` 失敗？

```bash
# 清除快取後重試
flutter clean
flutter pub get
```

### Q: Chrome 無法執行？

```bash
# 確認 Web 支援已啟用
flutter config --enable-web
flutter run -d chrome
```

### Q: Android 模擬器跑不動？

1. 確認 Android Studio 已安裝 Android SDK
2. 開啟 AVD Manager 建立模擬器
3. 確認 HAXM 或 Hyper-V 已啟用（加速模擬器）

### Q: 地圖無法顯示？

- 地圖使用 OpenStreetMap，需要網路連線
- 如果在中國大陸，可能需要 VPN

---

## 📝 開發筆記

- **地圖抽象層**：已預留 Mapbox 切換功能，修改 `MapServiceFactory` 即可
- **顏色主題**：所有顏色定義在 `lib/core/theme/app_colors.dart`
- **路由管理**：使用 `go_router`，路由定義在 `lib/app/router/app_router.dart`

---

## 📄 License

MIT License

---

## 👨‍💻 作者

Made with ❤️ and 🧋
