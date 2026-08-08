from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one source match, found {count}")
    return text.replace(old, new, 1)


main = Path("swift/Sources/Parakey/main.swift").read_text()
for required in [
    "private var productCaptureCommandObserver: ProductCaptureCommandObserver?",
    "productCaptureCommandObserver = ProductCaptureCommandObserver(",
    "private var productWindowController: NativeProductWindowController?",
    "private func showSystemStatusWindow()",
    "productWindowController?.refresh(",
]:
    if required not in main:
        raise SystemExit(f"runtime integration invariant missing: {required}")

view_path = Path("swift/Sources/SuperDictateUI/SuperDictateMainView.swift")
view = view_path.read_text()
view = replace_once(
    view,
    """                if snapshot.isCaptureActive {
                    RecordingNowRow(startedAt: snapshot.activeRecordingStartedAt, copy: copy)
                } else if snapshot.status == .transcribing {
                    ProcessingRow(copy: copy)
                } else if let issue = snapshot.issueMessage {
""",
    """                if snapshot.isCaptureActive {
                    RecordingNowRow(startedAt: snapshot.activeRecordingStartedAt, copy: copy)
                } else if snapshot.status == .starting {
                    ProcessingRow(text: copy.startingService)
                } else if snapshot.status == .transcribing {
                    ProcessingRow(text: copy.processingLatest)
                } else if let issue = snapshot.issueMessage {
""",
    "Today startup state",
)
view = replace_once(
    view,
    """        switch snapshot.status {
        case .recording: return copy.recordingLocally
        case .transcribing: return copy.transcribingLatest
        case .needsAttention: return copy.attentionSubtitle
        case .idle, .ready: return copy.todayDefaultSubtitle
        }
""",
    """        switch snapshot.status {
        case .starting: return copy.startingService
        case .recording: return copy.recordingLocally
        case .transcribing: return copy.transcribingLatest
        case .needsAttention: return copy.attentionSubtitle
        case .idle, .ready: return copy.todayDefaultSubtitle
        }
""",
    "Today subtitle startup state",
)
view = replace_once(
    view,
    """private struct ProcessingRow: View {
    let copy: SuperDictateCopy

    var body: some View {
        HStack(spacing: SuperDictateDesign.Spacing.compact) {
            ProgressView()
                .controlSize(.small)
            Text(copy.processingLatest)
                .font(SuperDictateDesign.TypeStyle.interface)
        }
    }
}
""",
    """private struct ProcessingRow: View {
    let text: String

    var body: some View {
        HStack(spacing: SuperDictateDesign.Spacing.compact) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(SuperDictateDesign.TypeStyle.interface)
        }
    }
}
""",
    "processing row copy",
)
view_path.write_text(view)
