import AppKit

/// The one symbol the stub looks up. Its signature never changes.
@_cdecl("RivletRuntimeMain")
public func RivletRuntimeMain(
    _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> Int32 {
    let arguments = (0..<Int(argc)).compactMap { index -> String? in
        guard let pointer = argv[index] else { return nil }
        return String(cString: pointer)
    }
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = RuntimeAppDelegate(arguments: arguments)
        RuntimeAppDelegate.retained = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
    return 0
}
