import Foundation

/// Splits a byte stream into JSONL records on LF only. Never on CR or the Unicode
/// separators U+2028/U+2029, which are legal inside JSON strings.
struct LineBuffer {
    private var pending = Data()

    mutating func take(_ chunk: Data) -> [Data] {
        pending.append(chunk)
        var lines: [Data] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            var line = pending[pending.startIndex..<newline]
            if line.last == 0x0D {
                line = line.dropLast()
            }
            if !line.isEmpty {
                lines.append(Data(line))
            }
            pending = Data(pending[pending.index(after: newline)...])
        }
        return lines
    }
}
