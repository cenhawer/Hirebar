import Foundation

final class ResponseBox: @unchecked Sendable {
    var value: Data?
}

enum TelegramHTTP {
    static func encode(_ body: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: body)
    }

    static func postJSON(_ url: URL, _ body: [String: Any], timeout: TimeInterval = 30) -> [String: Any]? {
        postJSON(url, data: encode(body), timeout: timeout)
    }

    static func postJSON(_ url: URL, data body: Data?, timeout: TimeInterval = 30) -> [String: Any]? {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let box = ResponseBox()
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, _, _ in
            box.value = data
            done.signal()
        }.resume()
        done.wait()
        guard let data = box.value else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func postMultipart(
        _ url: URL,
        fields: [String: String],
        fileField: String,
        file: URL,
        timeout: TimeInterval = 60
    ) -> [String: Any]? {
        guard let content = try? Data(contentsOf: file) else { return nil }
        let boundary = "hirebar-\(UUID().uuidString)"
        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }
        for (name, value) in fields {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(file.lastPathComponent)\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(content)
        append("\r\n--\(boundary)--\r\n")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let box = ResponseBox()
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, _, _ in
            box.value = data
            done.signal()
        }.resume()
        done.wait()
        guard let data = box.value else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
