# FFUAD - Fast File Upload and Download

<p align="center">
  <img src="https://img.shields.io/badge/version-3.0-blue?style=for-the-badge" />
  <img src="https://img.shields.io/badge/platform-Termux%20%7C%20Linux-green?style=for-the-badge" />
  <img src="https://img.shields.io/badge/license-MIT-orange?style=for-the-badge" />
  <img src="https://img.shields.io/badge/shell-bash-yellow?style=for-the-badge" />
</p>

**FFUAD** is a lightweight CLI tool for uploading and downloading files instantly from your terminal — with optional AES-256 encryption and a clean progress bar.

---

## ✨ Features

- 🚀 Upload any file or folder in one command
- 🔐 AES-256 encryption with password protection
- 📦 Auto zip and upload folders
- 📥 Download files by short code
- 📋 Upload/download history
- 🎨 Colorful progress bar
- 🌍 Multi-language support

---

## 📦 Installation

```bash
pkg install curl zip openssl-tool
curl -fsSL https://raw.githubusercontent.com/rasul-utelbayev/ffuad/main/ffuad.sh -o $PREFIX/bin/ffuad
chmod +x $PREFIX/bin/ffuad
```

---

## 🚀 Usage

### Upload a file
```bash
ffuad -f myfile.txt
```

### Upload with password (AES-256 encrypted)
```bash
ffuad -f myfile.txt -p mypassword
```

### Upload a folder
```bash
ffuad -fl myfolder/
```

### Download a file
```bash
ffuad -d ABC123.txt
```

### Download encrypted file
```bash
ffuad -d ABC123.txt -p mypassword
```

### Show history
```bash
ffuad --list
```

---

## 🌍 Languages

| Language | File |
|----------|------|
| 🇬🇧 English | `ffuad.sh` (default) |
| 🇺🇿 Uzbek | `languages/ffuad_uz.sh` |
| 🇰🇿 Karakalpak | `languages/ffuad_kk.sh` (coming soon) |

To use another language:
```bash
cp languages/ffuad_uz.sh $PREFIX/bin/ffuad
chmod +x $PREFIX/bin/ffuad
```

---

## 🔐 How Encryption Works

When `-p` flag is used, FFUAD encrypts your file using **AES-256-CBC** via OpenSSL before uploading. The file can only be decrypted with the correct password. Without the password, the file is unreadable.

---

## 📋 Requirements

- Termux or any Linux terminal
- `curl`
- `zip`
- `openssl`

Install on Termux:
```bash
pkg install curl zip openssl-tool
```

---

## 📁 Project Structure

```
ffuad/
├── ffuad.sh          # Main script (English)
└── languages/
    ├── ffuad_uz.sh   # Uzbek
    └── ffuad_kk.sh   # Karakalpak (coming soon)
```

---

## 👨‍💻 Author

Made with ❤️ by **Rasul Utelbayev**

- GitHub: [@rasul-utelbayev](https://github.com/rasul-utelbayev)

---

## 📄 License

MIT License — free to use, modify and share.
