import Foundation

enum L10n {
    private static let russian: [String: String] = [
        "Naive VPN": "Наивный VPN",
        "Configs": "Конфигурации",
        "Saved Config": "Текущая конфигурация",
        "New": "Новый",
        "Duplicate": "Дублировать",
        "Delete": "Удалить",
        "Scan QR Code": "Сканировать QR-код",
        "Server": "Сервер",
        "Name": "Имя",
        "Host": "Хост",
        "Type": "Тип",
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
        "Port must be a number between 1 and 65535.": "Порт должен быть числом от 1 до 65535."
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
}
