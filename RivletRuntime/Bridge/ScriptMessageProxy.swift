import WebKit

/// WKUserContentController retains its handlers. This proxy keeps the real
/// handler weak so the bridges and the web view can be released.
@MainActor
final class ScriptMessageProxy: NSObject, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {
    typealias Handler = @MainActor (WKScriptMessage) -> Void
    typealias ReplyHandler = @MainActor (WKScriptMessage) async -> Any?

    private let handler: Handler?
    private let replyHandler: ReplyHandler?

    init(handler: @escaping Handler) {
        self.handler = handler
        self.replyHandler = nil
    }

    init(replyHandler: @escaping ReplyHandler) {
        self.handler = nil
        self.replyHandler = replyHandler
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        handler?(message)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        guard let replyHandler else { return (nil, "no handler") }
        return (await replyHandler(message), nil)
    }
}
