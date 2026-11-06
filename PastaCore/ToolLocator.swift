import Foundation

public struct PastaToolStatus: Equatable, Codable, Sendable {
    public let name: String
    public let isOptional: Bool
    public let path: String?
    public let version: String?
    public let formula: String?
    public let isCask: Bool
    public let dependentActions: [String]

    public init(
        name: String,
        isOptional: Bool,
        path: String?,
        version: String? = nil,
        formula: String? = nil,
        isCask: Bool = false,
        dependentActions: [String] = []
    ) {
        self.name = name
        self.isOptional = isOptional
        self.path = path
        self.version = version
        self.formula = formula
        self.isCask = isCask
        self.dependentActions = dependentActions
    }

    public var isAvailable: Bool { path != nil }

    public var displayLine: String {
        let state = isAvailable ? "Available" : (isOptional ? "Optional missing" : "Missing")
        let ver = version.map { " (\($0))" } ?? ""
        let p = path.map { " — \($0)" } ?? ""
        let form = (!isAvailable && formula != nil) ? " [Formula: \(isCask ? "--cask " : "")\(formula!)]" : ""
        return "\(name): \(state)\(ver)\(p)\(form)"
    }
}

public struct PastaDoctorReport: Equatable, Codable, Sendable {
    public let tools: [PastaToolStatus]
    public let allRequiredAvailable: Bool
    public let missingRequired: [String]
    public let missingOptional: [String]
    public let requiredInstallCommand: String?
    public let optionalInstallCommand: String?
    public let unifiedInstallCommand: String?

    public init(
        tools: [PastaToolStatus],
        allRequiredAvailable: Bool,
        missingRequired: [String],
        missingOptional: [String],
        requiredInstallCommand: String?,
        optionalInstallCommand: String?,
        unifiedInstallCommand: String?
    ) {
        self.tools = tools
        self.allRequiredAvailable = allRequiredAvailable
        self.missingRequired = missingRequired
        self.missingOptional = missingOptional
        self.requiredInstallCommand = requiredInstallCommand
        self.optionalInstallCommand = optionalInstallCommand
        self.unifiedInstallCommand = unifiedInstallCommand
    }

    public func jsonString(prettyPrinted: Bool = true) -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

public struct ToolDefinition: Sendable {
    public let name: String
    public let isOptional: Bool
    public let formula: String?
    public let isCask: Bool
    public let versionFlag: String
    public let dependentActions: [String]

    public init(name: String, isOptional: Bool, formula: String?, isCask: Bool, versionFlag: String, dependentActions: [String]) {
        self.name = name
        self.isOptional = isOptional
        self.formula = formula
        self.isCask = isCask
        self.versionFlag = versionFlag
        self.dependentActions = dependentActions
    }
}

public final class ToolLocator {
    public static let shared = ToolLocator()

    public static let toolDefinitions: [ToolDefinition] = [
        ToolDefinition(name: "ffmpeg", isOptional: false, formula: "ffmpeg", isCask: false, versionFlag: "-version", dependentActions: [
            "video.to.mp4", "video.to.mov", "video.to.mkv", "video.to.webm", "video.to.avi", "video.to.gif", "video.extract.audio",
            "video.speed", "video.crop", "video.mute", "video.reverse", "video.split", "video.compress",
            "audio.to.mp3", "audio.to.wav", "audio.to.m4a", "audio.to.flac", "audio.to.aac", "audio.speed", "audio.volume", "audio.reverse", "audio.compress"
        ]),
        ToolDefinition(name: "ffprobe", isOptional: false, formula: "ffmpeg", isCask: false, versionFlag: "-version", dependentActions: [
            "video.probe", "audio.probe", "video.split", "video.crop"
        ]),
        ToolDefinition(name: "cwebp", isOptional: false, formula: "webp", isCask: false, versionFlag: "-version", dependentActions: [
            "image.to.webp"
        ]),
        ToolDefinition(name: "magick", isOptional: false, formula: "imagemagick", isCask: false, versionFlag: "-version", dependentActions: [
            "image.to.png", "image.to.jpg", "image.to.bmp", "image.to.tiff", "image.resize", "image.rotate", "image.flip", "image.compress"
        ]),
        ToolDefinition(name: "gs", isOptional: false, formula: "ghostscript", isCask: false, versionFlag: "--version", dependentActions: [
            "pdf.to.docx", "pdf.compress"
        ]),
        ToolDefinition(name: "qpdf", isOptional: false, formula: "qpdf", isCask: false, versionFlag: "--version", dependentActions: [
            "pdf.decrypt", "pdf.encrypt", "pdf.rotate", "pdf.extract.pages"
        ]),
        ToolDefinition(name: "pdftoppm", isOptional: false, formula: "poppler", isCask: false, versionFlag: "-v", dependentActions: [
            "pdf.to.png", "pdf.to.jpg", "pdf.to.images"
        ]),
        ToolDefinition(name: "pdftotext", isOptional: false, formula: "poppler", isCask: false, versionFlag: "-v", dependentActions: [
            "pdf.to.txt"
        ]),
        ToolDefinition(name: "exiftool", isOptional: false, formula: "exiftool", isCask: false, versionFlag: "-ver", dependentActions: [
            "image.view.metadata", "image.remove.exif"
        ]),
        ToolDefinition(name: "pandoc", isOptional: false, formula: "pandoc", isCask: false, versionFlag: "--version", dependentActions: [
            "doc.to.md", "doc.to.html", "doc.to.pdf", "md.to.html", "md.to.pdf"
        ]),
        ToolDefinition(name: "rsvg-convert", isOptional: false, formula: "librsvg", isCask: false, versionFlag: "--version", dependentActions: [
            "svg.to.png", "svg.to.pdf"
        ]),
        ToolDefinition(name: "unar", isOptional: false, formula: "unar", isCask: false, versionFlag: "-v", dependentActions: [
            "archive.extract"
        ]),
        ToolDefinition(name: "7zz", isOptional: false, formula: "sevenzip", isCask: false, versionFlag: "--help", dependentActions: [
            "archive.extract", "archive.create.7z"
        ]),
        ToolDefinition(name: "sips", isOptional: false, formula: nil, isCask: false, versionFlag: "--version", dependentActions: [
            "image.to.png", "image.to.jpg"
        ]),
        ToolDefinition(name: "ditto", isOptional: false, formula: nil, isCask: false, versionFlag: "-h", dependentActions: [
            "archive.extract", "archive.create.zip"
        ]),
        ToolDefinition(name: "tar", isOptional: false, formula: nil, isCask: false, versionFlag: "--version", dependentActions: [
            "archive.extract", "archive.create.tar"
        ]),
        ToolDefinition(name: "soffice", isOptional: true, formula: "libreoffice", isCask: true, versionFlag: "--version", dependentActions: [
            "office.doc.to.pdf", "office.sheet.to.pdf", "office.slides.to.pdf"
        ]),
        ToolDefinition(name: "ebook-convert", isOptional: true, formula: "calibre", isCask: true, versionFlag: "--version", dependentActions: [
            "ebook.epub.to.pdf", "ebook.mobi.to.epub"
        ]),
        ToolDefinition(name: "avifenc", isOptional: true, formula: "libavif", isCask: false, versionFlag: "--version", dependentActions: [
            "image.to.avif"
        ])
    ]

    public static let doctorRequiredToolNames = toolDefinitions.filter { !$0.isOptional }.map(\.name)
    public static let doctorOptionalToolNames = toolDefinitions.filter { $0.isOptional }.map(\.name)

    private let searchPaths = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/local/sbin",
        "/opt/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin"
    ]

    private var overrides: [String: URL] = [:]
    private var unavailableOverrides: Set<String> = []
    private var cache: [String: URL] = [:]
    private let lock = NSLock()

    public init() {}

    public func setOverride(tool: String, url: URL?) {
        lock.lock()
        defer { lock.unlock() }
        if let url = url {
            unavailableOverrides.remove(tool)
            overrides[tool] = url
        } else {
            overrides.removeValue(forKey: tool)
        }
    }

    /// Forces a tool to be unavailable without consulting the machine's PATH or app bundle.
    /// This is used by deterministic tests for optional conversion engines.
    public func setUnavailableOverride(tool: String, isUnavailable: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if isUnavailable {
            overrides.removeValue(forKey: tool)
            unavailableOverrides.insert(tool)
        } else {
            unavailableOverrides.remove(tool)
        }
    }

    public func findTool(_ name: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }

        if unavailableOverrides.contains(name) {
            return nil
        }
        if let overridden = overrides[name] {
            return overridden
        }

        if let cached = cache[name] {
            return cached
        }

        let fm = FileManager.default
        for path in searchPaths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: candidate.path) {
                cache[name] = candidate
                return candidate
            }
        }

        if name == "soffice" {
            let defaultAppPath = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
            if fm.isExecutableFile(atPath: defaultAppPath) {
                let candidate = URL(fileURLWithPath: defaultAppPath)
                cache[name] = candidate
                return candidate
            }
        }

        return nil
    }

    public func requireTool(_ name: String) throws -> URL {
        guard let url = findTool(name) ?? findOptionalTool(name) else {
            throw PastaError.missingTool(name)
        }
        return url
    }

    public func findOptionalTool(_ name: String) -> URL? {
        if name == "soffice" {
            lock.lock()
            let isForcedUnavailable = unavailableOverrides.contains("soffice")
            let overridden = overrides["soffice"]
            lock.unlock()
            if isForcedUnavailable {
                return nil
            }
            if let overridden = overridden {
                if FileManager.default.isExecutableFile(atPath: overridden.path) {
                    return overridden
                }
            }
            let defaultAppPath = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
            if FileManager.default.isExecutableFile(atPath: defaultAppPath) {
                return URL(fileURLWithPath: defaultAppPath)
            }
            return findTool("soffice")
        }
        if name == "ebook-convert" {
            lock.lock()
            let isForcedUnavailable = unavailableOverrides.contains("ebook-convert")
            let overridden = overrides["ebook-convert"]
            lock.unlock()
            if isForcedUnavailable {
                return nil
            }
            if let overridden = overridden {
                if FileManager.default.isExecutableFile(atPath: overridden.path) {
                    return overridden
                }
            }
            let defaultAppPath = "/Applications/Calibre.app/Contents/MacOS/ebook-convert"
            if FileManager.default.isExecutableFile(atPath: defaultAppPath) {
                return URL(fileURLWithPath: defaultAppPath)
            }
            return findTool("ebook-convert")
        }
        return findTool(name)
    }

    public func isOptionalToolAvailable(_ name: String) -> Bool {
        return findOptionalTool(name) != nil
    }

    public static func fetchToolVersion(executableURL: URL, flag: String, timeout: TimeInterval = 1.0) -> String? {
        let proc = Process()
        proc.executableURL = executableURL
        proc.arguments = [flag]
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        proc.standardInput = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return nil
        }

        let start = Date()
        while proc.isRunning && Date().timeIntervalSince(start) < timeout {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if proc.isRunning {
            proc.terminate()
            return nil
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let text = (String(data: outData, encoding: .utf8) ?? "") + "\n" + (String(data: errData, encoding: .utf8) ?? "")
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return String(trimmed.prefix(80))
            }
        }
        return nil
    }

    public func doctorStatuses(fetchVersions: Bool = false) -> [PastaToolStatus] {
        return Self.toolDefinitions.map { def in
            let pathURL: URL?
            if def.isOptional {
                pathURL = findOptionalTool(def.name)
            } else {
                pathURL = findTool(def.name)
            }
            let path = pathURL?.path
            let ver: String?
            if fetchVersions, let pathURL = pathURL {
                ver = Self.fetchToolVersion(executableURL: pathURL, flag: def.versionFlag)
            } else {
                ver = nil
            }
            return PastaToolStatus(
                name: def.name,
                isOptional: def.isOptional,
                path: path,
                version: ver,
                formula: def.formula,
                isCask: def.isCask,
                dependentActions: def.dependentActions
            )
        }
    }

    public func doctorStatuses() -> [PastaToolStatus] {
        return doctorStatuses(fetchVersions: false)
    }

    public func doctorReportData(fetchVersions: Bool = false) -> PastaDoctorReport {
        let statuses = doctorStatuses(fetchVersions: fetchVersions)
        let missingReq = statuses.filter { !$0.isOptional && !$0.isAvailable }
        let missingOpt = statuses.filter { $0.isOptional && !$0.isAvailable }

        let reqFormulas = Array(Set(missingReq.compactMap(\.formula))).sorted()
        let requiredCmd = reqFormulas.isEmpty ? nil : "brew install \(reqFormulas.joined(separator: " "))"

        let optNonCask = Array(Set(missingOpt.filter { !$0.isCask }.compactMap(\.formula))).sorted()
        let optCask = Array(Set(missingOpt.filter { $0.isCask }.compactMap(\.formula))).sorted()

        var optParts: [String] = []
        if !optNonCask.isEmpty {
            optParts.append("brew install \(optNonCask.joined(separator: " "))")
        }
        if !optCask.isEmpty {
            optParts.append("brew install --cask \(optCask.joined(separator: " "))")
        }
        let optionalCmd = optParts.isEmpty ? nil : optParts.joined(separator: " && ")

        let unifiedCmd: String?
        if let r = requiredCmd, let o = optionalCmd {
            unifiedCmd = "\(r) && \(o)"
        } else {
            unifiedCmd = requiredCmd ?? optionalCmd
        }

        return PastaDoctorReport(
            tools: statuses,
            allRequiredAvailable: missingReq.isEmpty,
            missingRequired: missingReq.map(\.name),
            missingOptional: missingOpt.map(\.name),
            requiredInstallCommand: requiredCmd,
            optionalInstallCommand: optionalCmd,
            unifiedInstallCommand: unifiedCmd
        )
    }

    public func doctorReport(fetchVersions: Bool = false) -> String {
        let rep = doctorReportData(fetchVersions: fetchVersions)
        var lines: [String] = []
        lines.append("Pasta Environment & Engine Doctor:")
        lines.append("--------------------------------------------------")
        for t in rep.tools {
            lines.append("  \(t.displayLine)")
            if !t.dependentActions.isEmpty {
                lines.append("    Actions: \(t.dependentActions.joined(separator: ", "))")
            }
        }
        lines.append("--------------------------------------------------")
        if rep.allRequiredAvailable {
            lines.append("Status: All required engine binaries are available.")
        } else {
            lines.append("Status: WARNING — \(rep.missingRequired.count) required tools are missing.")
        }

        if let reqCmd = rep.requiredInstallCommand {
            lines.append("\nRequired tools install command:")
            lines.append("  \(reqCmd)")
        }
        if let optCmd = rep.optionalInstallCommand {
            lines.append("\nOptional tools install command:")
            lines.append("  \(optCmd)")
        }
        return lines.joined(separator: "\n")
    }

    public func doctorReport() -> String {
        return doctorReport(fetchVersions: false)
    }
}
