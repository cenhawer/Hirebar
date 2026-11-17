import Foundation
import HirebarApplication
import HirebarDomain

extension Telegram {
    public static func parse(_ update: [String: Any]) -> ChatMessage? {
        if let callback = update["callback_query"] as? [String: Any] {
            let message = callback["message"] as? [String: Any]
            let chat = message?["chat"] as? [String: Any]
            var result = ChatMessage(
                chatId: (chat?["id"] as? NSNumber)?.int64Value ?? 0,
                text: callback["data"] as? String ?? "",
                replyTo: (message?["message_id"] as? NSNumber)?.intValue,
                callbackId: callback["id"] as? String)
            result.sender = sender(from: callback["from"] as? [String: Any], chat: chat, sentAt: Date(), viaButton: true)
            return result
        }
        guard let message = update["message"] as? [String: Any], let chat = message["chat"] as? [String: Any] else { return nil }
        guard let chatId = (chat["id"] as? NSNumber)?.int64Value else { return nil }
        let reply = (message["reply_to_message"] as? [String: Any])?["message_id"] as? NSNumber
        let sentAt = (message["date"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) } ?? Date()
        let from = sender(from: message["from"] as? [String: Any], chat: chat, sentAt: sentAt)
        let attachment = (message["voice"] ?? message["audio"] ?? message["video_note"]) as? [String: Any]
        if let audio = attachment, let fileId = audio["file_id"] as? String {
            let name = (audio["file_name"] as? String) ?? ""
            let ext =
                message["voice"] != nil
                ? "oga"
                : (message["video_note"] != nil
                    ? "mp4"
                    : (name.contains(".") ? String(name.split(separator: ".").last ?? "m4a") : "m4a"))
            var result = ChatMessage(
                chatId: chatId, text: message["caption"] as? String ?? "", replyTo: reply?.intValue, callbackId: nil)
            result.audioFileId = fileId
            result.audioExtension = ext
            result.audioBytes = (audio["file_size"] as? NSNumber)?.intValue
            result.audioSeconds = (audio["duration"] as? NSNumber)?.intValue
            result.sender = from
            return result
        }
        guard let text = message["text"] as? String else { return nil }
        var result = ChatMessage(chatId: chatId, text: text, replyTo: reply?.intValue, callbackId: nil)
        result.sender = from
        return result
    }

    static let privateChatType = "private"

    static func sender(from user: [String: Any]?, chat: [String: Any]?, sentAt: Date, viaButton: Bool = false) -> ChannelSender? {
        guard let user, let userId = (user["id"] as? NSNumber)?.int64Value,
            let chatId = (chat?["id"] as? NSNumber)?.int64Value
        else { return nil }
        let name = [user["first_name"] as? String, user["last_name"] as? String].compactMap { $0 }.joined(separator: " ")
        return ChannelSender(
            userId: userId, chatId: chatId, name: name, username: user["username"] as? String,
            isPrivateChat: (chat?["type"] as? String) == privateChatType, sentAt: sentAt, viaButton: viaButton)
    }
}
