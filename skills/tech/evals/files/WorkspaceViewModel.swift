import AppKit
import Observation

@Observable
@MainActor
final class WorkspaceViewModel {
    var folder: URL
    var errorMessage: String?

    init(folder: URL) {
        self.folder = folder
    }

    // TODO: "Open in Terminal" — open `folder` with Terminal.app via
    // NSWorkspace.shared.open(_:withApplicationAt:configuration:completionHandler:)
    // and set errorMessage if it fails.
}
