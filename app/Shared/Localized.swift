import Foundation

enum L10n {
    private static let russian: [String: String] = [
        "Naive VPN": "Наивный VPN",
        "Configs": "Конфигурации",
        "Saved Config": "Текущая конфигурация",
        "New": "Новый",
        "Duplicate": "Дублировать",
        "Delete": "Удалить",
        "Share": "Поделиться",
        "Link": "Ссылка",
        "Copy": "Копировать",
        "Copied": "Скопировано",
        "Scan QR Code": "Сканировать QR-код",
        "Paste configuration": "Вставить конфигурацию",
        "Import": "Импорт",
        "Cancel": "Отмена",
        "Paste from Clipboard": "Вставить из буфера",
        "Paste a share link or JSON configuration.": "Вставьте ссылку общего доступа или JSON-конфигурацию.",
        "Server": "Сервер",
        "Name": "Имя",
        "Host": "Хост",
        "Type": "Тип",
        "HTTPS": "HTTPS",
        "HTTP/2": "HTTP/2",
        "QUIC": "QUIC",
        "Port": "Порт",
        "User": "Пользователь",
        "Password": "Пароль",
        "Status": "Статус",
        "VPN": "VPN",
        "IP": "IP",
        "Connection Error": "Ошибка подключения",
        "OK": "ОК",
        "Unknown error.": "Неизвестная ошибка.",
        "Checking...": "Проверка...",
        "Unavailable": "Недоступно",
        "Connect": "Подключить",
        "Disconnect": "Отключить",
        "Invalid": "Недействительно",
        "Disconnected": "Отключено",
        "Connecting": "Подключение",
        "Connected": "Подключено",
        "Reconnecting": "Повторное подключение",
        "Disconnecting": "Отключение",
        "Unknown": "Неизвестно",
        "Untitled": "Без имени",
        "The QR code is empty.": "QR-код пуст.",
        "Unsupported QR format. Expected a Naive share link or JSON config.": "Неподдерживаемый формат QR-кода. Ожидается ссылка Naive или JSON-конфиг.",
        "The QR code contains invalid JSON.": "QR-код содержит некорректный JSON.",
        "The QR code contains an invalid Naive share link.": "QR-код содержит некорректную ссылку Naive.",
        "The imported config is missing a host.": "В импортированном конфиге отсутствует хост.",
        "Center the QR code inside the camera view.": "Поместите QR-код в центр области камеры.",
        "Close": "Закрыть",
        "Camera access was denied.": "Доступ к камере запрещен.",
        "Camera access is unavailable.": "Доступ к камере недоступен.",
        "No camera is available on this device.": "На этом устройстве нет камеры.",
        "Unable to configure the QR scanner.": "Не удалось настроить QR-сканер.",
        "Unable to start the camera.": "Не удалось запустить камеру.",
        "Host is required.": "Требуется хост.",
        "User is required.": "Требуется пользователь.",
        "Password is required.": "Требуется пароль.",
        "Port must be a number between 1 and 65535.": "Порт должен быть числом от 1 до 65535.",
        "DNS": "DNS",
        "Remote DNS": "Удалённый DNS",
        "DNS Transport": "Транспорт DNS",
        "DoH": "DoH",
        "UDP": "UDP",
        "Cloudflare": "Cloudflare",
        "Google": "Google",
        "Quad9": "Quad9",
        "Custom": "Свой",
        "DNS Server": "DNS-сервер",
        "DNS TLS Name": "TLS-имя DNS",
        "DNS Path": "Путь DNS",
        "DNS Port": "Порт DNS",
        "DNS server is required.": "Требуется DNS-сервер.",
        "DNS TLS name is required when the server is an IP address.": "TLS-имя DNS обязательно, если сервер указан как IP-адрес.",
        "DNS port must be a number between 1 and 65535.": "Порт DNS должен быть числом от 1 до 65535.",
        "DNS path must start with /.": "Путь DNS должен начинаться с /.",
        "Opens appdb in Safari": "Открывает appdb в Safari"
    ]

    private static var usesRussian: Bool {
        if Bundle.main.preferredLocalizations.contains(where: { $0.hasPrefix("ru") }) {
            return true
        }

        return Locale.preferredLanguages.first?.hasPrefix("ru") ?? false
    }

    static func tr(_ key: String) -> String {
        usesRussian ? (russian[key] ?? key) : key
    }

    static func configName(_ index: Int) -> String {
        usesRussian ? "Конфигурация \(index)" : "Config \(index)"
    }

    static func copiedName(from baseName: String, copyIndex: Int? = nil) -> String {
        if usesRussian {
            if let copyIndex {
                return "\(baseName) копия \(copyIndex)"
            }

            return "\(baseName) копия"
        }

        if let copyIndex {
            return "\(baseName) Copy \(copyIndex)"
        }

        return "\(baseName) Copy"
    }

    static func newVersionOnAppdbBanner(version: String) -> String {
        if usesRussian {
            return "Новая версия \(version) на appdb"
        }
        return "New version \(version) on appdb"
    }
}
