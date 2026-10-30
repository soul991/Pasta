import Foundation

public final class FormatRegistry {
    public static let shared = FormatRegistry()

    public init() {}

    public func actions(for fileURL: URL, isOptionHeld: Bool = false) -> [ConversionAction] {
        let allActions = availableActions(for: fileURL)
        if isOptionHeld {
            let advanced = allActions.filter { $0.isAdvanced }
            return advanced.isEmpty ? allActions : advanced
        } else {
            let standard = allActions.filter { !$0.isAdvanced }
            return standard.isEmpty ? allActions : standard
        }
    }

    public func allActions(for fileURL: URL) -> [ConversionAction] {
        return availableActions(for: fileURL)
    }

    public static func formatFfmpegTimestamp(_ seconds: Double) -> String {
        let totalSecs = Int(seconds)
        let hours = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60
        let secs = totalSecs % 60
        let frac = seconds - Double(totalSecs)
        if frac > 0.0001 {
            return String(format: "%02d:%02d:%02d.%03d", hours, mins, secs, Int(round(frac * 1000)))
        } else {
            return String(format: "%02d:%02d:%02d", hours, mins, secs)
        }
    }

    public func action(for fileURL: URL, actionID: String) -> ConversionAction? {
        let actions = availableActions(for: fileURL)
        if let matched = actions.first(where: { $0.id == actionID }) {
            return matched
        }
        if actionID == "video.advanced.trim10" {
            return actions.first(where: { $0.id == "video.trim" })
        }
        if actionID == "video.trim" {
            return actions.first(where: { $0.id == "video.advanced.trim10" })
        }
        if actionID == "image.advanced.resize_50" {
            return actions.first(where: { $0.id == "image.resize" })
        }
        if actionID == "image.resize" {
            return actions.first(where: { $0.id == "image.advanced.resize_50" })
        }
        if actionID == "image.compress" {
            return actions.first(where: { $0.id == "image.advanced.compress" || $0.id == "image.compress" })
        }
        if actionID == "image.advanced.compress" {
            return actions.first(where: { $0.id == "image.compress" || $0.id == "image.advanced.compress" })
        }
        if actionID == "video.compress" {
            return actions.first(where: { $0.id == "video.advanced.compress" || $0.id == "video.compress" })
        }
        if actionID == "video.advanced.compress" {
            return actions.first(where: { $0.id == "video.compress" || $0.id == "video.advanced.compress" })
        }
        if actionID == "audio.compress" {
            return actions.first(where: { $0.id == "audio.advanced.compress" || $0.id == "audio.compress" })
        }
        if actionID == "audio.advanced.compress" {
            return actions.first(where: { $0.id == "audio.compress" || $0.id == "audio.advanced.compress" })
        }
        if actionID == "pdf.compress" {
            return actions.first(where: { $0.id == "pdf.advanced.compress" || $0.id == "pdf.compress" })
        }
        if actionID == "pdf.advanced.compress" {
            return actions.first(where: { $0.id == "pdf.compress" || $0.id == "pdf.advanced.compress" })
        }
        if actionID == "archive.gzip" {
            return actions.first(where: { $0.id == "archive.create.gzip" })
        }
        if actionID == "archive.create.gzip" {
            return actions.first(where: { $0.id == "archive.create.gzip" || $0.id == "archive.gzip" })
        }
        if actionID == "video.snapshot.png" {
            return actions.first(where: { $0.id == "video.snapshot" || $0.id == "video.snapshot.png" })
        }
        if actionID == "video.snapshot.jpeg" {
            return actions.first(where: { $0.id == "video.snapshot.jpg" })
        }
        return nil
    }

    public static let compressionParameters: [ActionParameter] = [
        ActionParameter(
            id: "mode",
            label: "Compression Mode",
            kind: .choice(options: ["percent", "targetSize"]),
            defaultValue: .text("percent")
        ),
        ActionParameter(
            id: "percent",
            label: "Target Percent",
            kind: .percent,
            defaultValue: .number(50.0),
            minValue: 1.0,
            maxValue: 100.0
        ),
        ActionParameter(
            id: "targetSize",
            label: "Target Size in Bytes",
            kind: .sizeInBytes,
            defaultValue: .integer(0),
            minValue: 0.0
        )
    ]

    private func metadataActions(for inputExt: String) -> [ConversionAction] {
        let readAction = ConversionAction(
            id: "metadata.read",
            displayName: "Read Metadata",
            outputExtension: "txt",
            isAdvanced: true,
            category: .metadata,
            iconName: "info.circle",
            parameters: [
                ActionParameter(
                    id: "format",
                    label: "Output Format",
                    kind: .choice(options: ["text", "json"]),
                    defaultValue: .text("text")
                )
            ],
            customRunner: { input, output, params, runner, jobId in
                let asJSON = (params["format"]?.asString == "json")
                let report = try MetadataTools.shared.formatMetadata(from: input, asJSON: asJSON)
                try report.write(to: output, atomically: true, encoding: .utf8)
            }
        )

        let editAction = ConversionAction(
            id: "metadata.edit",
            displayName: "Edit Metadata",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .metadata,
            iconName: "pencil.circle",
            parameters: [
                ActionParameter(id: "title", label: "Title", kind: .text, defaultValue: .text("")),
                ActionParameter(id: "author", label: "Author / Artist", kind: .text, defaultValue: .text("")),
                ActionParameter(id: "comment", label: "Comment", kind: .text, defaultValue: .text("")),
                ActionParameter(id: "date", label: "Date", kind: .text, defaultValue: .text(""))
            ],
            customRunner: { input, output, params, runner, jobId in
                var tags: [String: String] = [:]
                for (key, val) in params {
                    let s = val.asString.trimmingCharacters(in: .whitespaces)
                    if !s.isEmpty {
                        tags[key] = s
                    }
                }
                try MetadataTools.shared.editMetadata(input: input, output: output, tags: tags, runner: runner, jobId: jobId)
            }
        )
        return [readAction, editAction]
    }

    public func action(for fileURL: URL, targetExtension: String, preferAdvanced: Bool = false) -> ConversionAction? {
        let ext = targetExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let actions = availableActions(for: fileURL).filter { $0.outputExtension.lowercased() == ext }
        if preferAdvanced, let adv = actions.first(where: { $0.isAdvanced }) {
            return adv
        }
        return actions.first(where: { !$0.isAdvanced }) ?? actions.first
    }

    private func availableActions(for fileURL: URL) -> [ConversionAction] {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
            return directoryActions(for: fileURL)
        }

        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "webp", "heic", "tiff", "tif", "bmp", "gif", "avif", "svg":
            return imageActions(for: fileURL, inputExt: ext)
        case "mp4", "mov", "mkv", "webm", "avi", "wmv", "m4v", "flv":
            return videoActions(for: fileURL, inputExt: ext)
        case "mp3", "m4a", "wav", "flac", "aac", "ogg", "opus", "aiff", "aif":
            return audioActions(for: fileURL, inputExt: ext)
        case "pdf":
            return pdfActions(for: fileURL)
        case "docx":
            return docxActions(for: fileURL)
        case "doc", "ppt", "pptx", "xls", "xlsx":
            return officeActions(for: fileURL, inputExt: ext)
        case "epub":
            return epubActions(for: fileURL)
        case "md", "markdown":
            return markdownActions(for: fileURL)
        case "txt":
            return textActions(for: fileURL)
        case "html", "htm":
            return htmlActions(for: fileURL)
        case "srt":
            return srtActions(for: fileURL)
        case "vtt":
            return vttActions(for: fileURL)
        case "zip", "tar", "gz", "tgz", "7z", "rar":
            return archiveExtractActions(for: fileURL, inputExt: ext)
        case "swift", "sh", "bash", "zsh", "py", "js", "ts", "c", "cpp", "h", "json", "yaml", "yml", "xml", "css", "sql", "rb", "go", "rs", "java", "kt", "php":
            return codeAndScriptActions(for: fileURL, inputExt: ext)
        default:
            return genericFileActions(for: fileURL)
        }
    }

    // MARK: - Images
    private func imageActions(for url: URL, inputExt: String) -> [ConversionAction] {
        var list: [ConversionAction] = []

        // Standard actions
        if inputExt != "jpg" && inputExt != "jpeg" {
            list.append(ConversionAction(
                id: "image.to.jpeg",
                displayName: "Convert to JPEG",
                outputExtension: "jpg",
                isAdvanced: false,
                category: .image,
                iconName: "photo"
            ) { input, output in
                if inputExt == "svg" {
                    return [
                        Invocation(toolName: "magick", arguments: [input.path, output.path])
                    ]
                } else {
                    return [
                        Invocation(toolName: "sips", arguments: ["-s", "format", "jpeg", "-s", "formatOptions", "80", input.path, "--out", output.path])
                    ]
                }
            })
        }

        if inputExt != "png" {
            list.append(ConversionAction(
                id: "image.to.png",
                displayName: "Convert to PNG",
                outputExtension: "png",
                isAdvanced: false,
                category: .image,
                iconName: "photo"
            ) { input, output in
                if inputExt == "svg" {
                    return [
                        Invocation(toolName: "rsvg-convert", arguments: ["-o", output.path, input.path])
                    ]
                } else {
                    return [
                        Invocation(toolName: "sips", arguments: ["-s", "format", "png", input.path, "--out", output.path])
                    ]
                }
            })
        }

        if inputExt != "webp" {
            list.append(ConversionAction(
                id: "image.to.webp",
                displayName: "Convert to WebP",
                outputExtension: "webp",
                isAdvanced: false,
                category: .image,
                iconName: "photo"
            ) { input, output in
                if ["png", "jpg", "jpeg", "tiff", "tif"].contains(inputExt) {
                    return [
                        Invocation(toolName: "cwebp", arguments: ["-q", "80", input.path, "-o", output.path])
                    ]
                } else {
                    return [
                        Invocation(toolName: "magick", arguments: [input.path, output.path])
                    ]
                }
            })
        }

        if inputExt != "heic" && inputExt != "svg" {
            list.append(ConversionAction(
                id: "image.to.heic",
                displayName: "Convert to HEIC",
                outputExtension: "heic",
                isAdvanced: false,
                category: .image,
                iconName: "photo"
            ) { input, output in
                [Invocation(toolName: "sips", arguments: ["-s", "format", "heic", input.path, "--out", output.path])]
            })
        }

        if inputExt != "tiff" && inputExt != "tif" && inputExt != "svg" {
            list.append(ConversionAction(
                id: "image.to.tiff",
                displayName: "Convert to TIFF",
                outputExtension: "tiff",
                isAdvanced: false,
                category: .image,
                iconName: "photo"
            ) { input, output in
                [Invocation(toolName: "sips", arguments: ["-s", "format", "tiff", input.path, "--out", output.path])]
            })
        }

        if inputExt != "gif" {
            list.append(ConversionAction(
                id: "image.to.gif",
                displayName: "Convert to GIF",
                outputExtension: "gif",
                isAdvanced: false,
                category: .image,
                iconName: "photo"
            ) { input, output in
                [Invocation(toolName: "magick", arguments: [input.path, output.path])]
            })
        }

        // Advanced actions
        list.append(ConversionAction(
            id: "image.advanced.strip_metadata",
            displayName: "Remove Metadata",
            outputExtension: inputExt == "svg" ? "png" : inputExt,
            isAdvanced: true,
            category: .metadata,
            iconName: "lock.shield"
        ) { input, output in
            [Invocation(toolName: "exiftool", arguments: ["-all=", "-o", output.path, "--", input.path])]
        })

        list.append(ConversionAction(
            id: "image.compress",
            displayName: "Compress Image",
            outputExtension: inputExt == "svg" ? "png" : inputExt,
            isAdvanced: true,
            category: .image,
            iconName: "arrow.down.circle",
            parameters: Self.compressionParameters,
            customRunner: { input, output, params, runner, jobId in
                try Compressor.shared.compressImage(input: input, output: output, parameters: params, runner: runner, jobId: jobId)
            },
            customBatchRunner: { inputs, output, params, runner, jobId in
                try Compressor.shared.compressBatch(inputs: inputs, outputDir: output, parameters: params, compressItem: { inUrl, outUrl, p, r, j in
                    try Compressor.shared.compressImage(input: inUrl, output: outUrl, parameters: p, runner: r, jobId: j)
                }, runner: runner, jobId: jobId)
            }
        ))

        list.append(ConversionAction(
            id: "image.advanced.compress",
            displayName: "Compress Image",
            outputExtension: inputExt == "svg" ? "png" : inputExt,
            isAdvanced: true,
            category: .image,
            iconName: "arrow.down.circle",
            parameters: Self.compressionParameters,
            customRunner: { input, output, params, runner, jobId in
                try Compressor.shared.compressImage(input: input, output: output, parameters: params, runner: runner, jobId: jobId)
            },
            customBatchRunner: { inputs, output, params, runner, jobId in
                try Compressor.shared.compressBatch(inputs: inputs, outputDir: output, parameters: params, compressItem: { inUrl, outUrl, p, r, j in
                    try Compressor.shared.compressImage(input: inUrl, output: outUrl, parameters: p, runner: r, jobId: j)
                }, runner: runner, jobId: jobId)
            }
        ))

        let resizeParams = [
            ActionParameter(
                id: "percent",
                label: "Resize Percent",
                kind: .percent,
                defaultValue: .number(50.0),
                minValue: 1.0,
                maxValue: 500.0
            ),
            ActionParameter(
                id: "maxDimension",
                label: "Max Dimension (px)",
                kind: .number,
                defaultValue: .number(1200.0),
                minValue: 1.0,
                maxValue: 50000.0
            )
        ]
        let resizeBuilder: (URL, URL, ParameterValues) -> [Invocation] = { input, output, params in
            if let pctVal = params["percent"], pctVal != .number(50.0) {
                let pct = pctVal.asDouble ?? 50.0
                let pctStr = (pct.rounded() == pct) ? "\(Int(pct))%" : "\(pct)%"
                return [Invocation(toolName: "magick", arguments: [input.path, "-resize", pctStr, output.path])]
            } else {
                let maxDim = params["maxDimension"]?.asInt ?? 1200
                return [Invocation(toolName: "sips", arguments: ["-Z", "\(maxDim)", input.path, "--out", output.path])]
            }
        }

        list.append(ConversionAction(
            id: "image.resize",
            displayName: "Resize Image",
            outputExtension: inputExt == "svg" ? "png" : inputExt,
            isAdvanced: true,
            category: .image,
            iconName: "arrow.up.left.and.arrow.down.right",
            parameters: resizeParams,
            buildInvocations: resizeBuilder
        ))

        list.append(ConversionAction(
            id: "image.advanced.resize_50",
            displayName: "Resize (Max 1200px)",
            outputExtension: inputExt == "svg" ? "png" : inputExt,
            isAdvanced: true,
            category: .image,
            iconName: "arrow.up.left.and.arrow.down.right",
            parameters: resizeParams,
            buildInvocations: resizeBuilder
        ))

        list.append(ConversionAction(
            id: "image.to.pdf",
            displayName: "Convert to PDF",
            outputExtension: "pdf",
            isAdvanced: false,
            category: .document,
            iconName: "doc.richtext",
            isBatch: true,
            buildInvocations: { input, output, _ in
                [Invocation(toolName: "magick", arguments: [input.path, output.path])]
            },
            buildBatchInvocations: { inputs, output, _ in
                [Invocation(toolName: "magick", arguments: inputs.map(\.path) + [output.path])]
            }
        ))

        list.append(ConversionAction(
            id: "image.collage",
            displayName: "Create Image Collage",
            outputExtension: "jpg",
            isAdvanced: true,
            category: .image,
            iconName: "square.grid.2x2",
            parameters: [
                ActionParameter(id: "columns", label: "Columns", kind: .number, defaultValue: .number(2), minValue: 1.0, maxValue: 20.0),
                ActionParameter(id: "spacing", label: "Spacing (px)", kind: .number, defaultValue: .number(4), minValue: 0.0, maxValue: 100.0)
            ],
            isBatch: true,
            buildBatchInvocations: { inputs, output, params in
                let cols = params["columns"]?.asInt ?? 2
                let spacing = params["spacing"]?.asInt ?? 4
                return [Invocation(toolName: "magick", arguments: ["montage"] + inputs.map(\.path) + ["-tile", "\(cols)x", "-geometry", "+\(spacing)+\(spacing)", output.path])]
            }
        ))

        list.append(ConversionAction(
            id: "image.qr.read",
            displayName: "Read QR Code",
            outputExtension: "txt",
            isAdvanced: true,
            category: .image,
            iconName: "qrcode",
            customRunner: { input, output, _, runner, jobId in
                guard let text = try QRReader.readQRCode(from: input) else {
                    throw PastaError.executionFailed(tool: "vision", exitCode: 1, output: "No QR code found in image")
                }
                try text.write(to: output, atomically: true, encoding: .utf8)
            }
        ))

        list.append(contentsOf: metadataActions(for: inputExt))

        // Standard compress to zip & gzip
        list.append(archiveCreateZipAction())
        list.append(archiveCreateGzipAction())

        return list
    }

    // MARK: - Video
    private func videoActions(for url: URL, inputExt: String) -> [ConversionAction] {
        var list: [ConversionAction] = []

        if inputExt != "mp4" {
            list.append(ConversionAction(
                id: "video.to.mp4",
                displayName: "Convert to MP4",
                outputExtension: "mp4",
                isAdvanced: false,
                category: .video,
                iconName: "film"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-c:v", "libx264", "-crf", "23", "-preset", "medium", "-c:a", "aac", "-movflags", "+faststart", output.path])]
            })
        }

        if inputExt != "webm" {
            list.append(ConversionAction(
                id: "video.to.webm",
                displayName: "Convert to WebM",
                outputExtension: "webm",
                isAdvanced: false,
                category: .video,
                iconName: "film"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus", output.path])]
            })
        }

        if inputExt != "mov" {
            list.append(ConversionAction(
                id: "video.to.mov",
                displayName: "Remux to MOV",
                outputExtension: "mov",
                isAdvanced: false,
                category: .video,
                iconName: "film"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-c", "copy", output.path])]
            })
        }

        if inputExt != "mkv" {
            list.append(ConversionAction(
                id: "video.to.mkv",
                displayName: "Remux to MKV",
                outputExtension: "mkv",
                isAdvanced: false,
                category: .video,
                iconName: "film"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-c", "copy", output.path])]
            })
        }

        if inputExt != "avi" {
            list.append(ConversionAction(
                id: "video.to.avi",
                displayName: "Convert to AVI",
                outputExtension: "avi",
                isAdvanced: false,
                category: .video,
                iconName: "film"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-c:v", "mpeg4", "-c:a", "mp3", output.path])]
            })
        }

        if inputExt != "wmv" {
            list.append(ConversionAction(
                id: "video.to.wmv",
                displayName: "Convert to WMV",
                outputExtension: "wmv",
                isAdvanced: false,
                category: .video,
                iconName: "film"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-c:v", "wmv2", "-b:v", "1000k", "-c:a", "wmav2", "-b:a", "128k", output.path])]
            })
        }

        list.append(ConversionAction(
            id: "video.to.gif",
            displayName: "Convert to GIF",
            outputExtension: "gif",
            isAdvanced: false,
            category: .video,
            iconName: "photo.stack"
        ) { input, output in
            [Invocation(toolName: "ffmpeg", arguments: [
                "-nostdin", "-n", "-i", input.path,
                "-vf", "fps=12,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse",
                output.path
            ])]
        })

        // Audio extractions
        list.append(ConversionAction(
            id: "video.extract.mp3",
            displayName: "Extract MP3 Audio",
            outputExtension: "mp3",
            isAdvanced: false,
            category: .audio,
            iconName: "waveform"
        ) { input, output in
            [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "libmp3lame", "-q:a", "2", output.path])]
        })

        list.append(ConversionAction(
            id: "video.extract.m4a",
            displayName: "Extract M4A Audio",
            outputExtension: "m4a",
            isAdvanced: false,
            category: .audio,
            iconName: "waveform"
        ) { input, output in
            [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "aac", "-b:a", "192k", output.path])]
        })

        list.append(ConversionAction(
            id: "video.extract.wav",
            displayName: "Extract WAV Audio",
            outputExtension: "wav",
            isAdvanced: false,
            category: .audio,
            iconName: "waveform"
        ) { input, output in
            [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "pcm_s16le", output.path])]
        })

        list.append(ConversionAction(
            id: "video.compress",
            displayName: "Compress Video",
            outputExtension: "mp4",
            isAdvanced: false,
            category: .video,
            iconName: "arrow.down.circle",
            parameters: Self.compressionParameters,
            customRunner: { input, output, params, runner, jobId in
                try Compressor.shared.compressVideo(input: input, output: output, parameters: params, runner: runner, jobId: jobId)
            },
            customBatchRunner: { inputs, output, params, runner, jobId in
                try Compressor.shared.compressBatch(inputs: inputs, outputDir: output, parameters: params, compressItem: { inUrl, outUrl, p, r, j in
                    try Compressor.shared.compressVideo(input: inUrl, output: outUrl, parameters: p, runner: r, jobId: j)
                }, runner: runner, jobId: jobId)
            }
        ))

        // Advanced actions
        list.append(ConversionAction(
            id: "video.advanced.compress",
            displayName: "Compress Video",
            outputExtension: "mp4",
            isAdvanced: true,
            category: .video,
            iconName: "arrow.down.circle",
            parameters: Self.compressionParameters,
            customRunner: { input, output, params, runner, jobId in
                try Compressor.shared.compressVideo(input: input, output: output, parameters: params, runner: runner, jobId: jobId)
            },
            customBatchRunner: { inputs, output, params, runner, jobId in
                try Compressor.shared.compressBatch(inputs: inputs, outputDir: output, parameters: params, compressItem: { inUrl, outUrl, p, r, j in
                    try Compressor.shared.compressVideo(input: inUrl, output: outUrl, parameters: p, runner: r, jobId: j)
                }, runner: runner, jobId: jobId)
            }
        ))

        let trimParams = [
            ActionParameter(
                id: "start",
                label: "Start Time (seconds)",
                kind: .number,
                defaultValue: .number(0.0),
                minValue: 0.0
            ),
            ActionParameter(
                id: "end",
                label: "End Time (seconds)",
                kind: .number,
                defaultValue: .number(10.0),
                minValue: 0.0
            )
        ]
        let trimBuilder: (URL, URL, ParameterValues) -> [Invocation] = { input, output, params in
            let start = params["start"]?.asDouble ?? 0.0
            let end = params["end"]?.asDouble ?? 10.0
            let startStr = FormatRegistry.formatFfmpegTimestamp(start)
            let endStr = FormatRegistry.formatFfmpegTimestamp(end)
            return [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-ss", startStr, "-to", endStr, "-c", "copy", output.path])]
        }

        list.append(ConversionAction(
            id: "video.trim",
            displayName: "Trim Video",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .video,
            iconName: "scissors",
            parameters: trimParams,
            buildInvocations: trimBuilder
        ))

        list.append(ConversionAction(
            id: "video.advanced.trim10",
            displayName: "Trim First 10 Seconds",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .video,
            iconName: "scissors",
            parameters: trimParams,
            buildInvocations: trimBuilder
        ))

        list.append(ConversionAction(
            id: "video.advanced.strip_metadata",
            displayName: "Remove Metadata",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .metadata,
            iconName: "lock.shield"
        ) { input, output in
            [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-map_metadata", "-1", "-c", "copy", output.path])]
        })

        // Video Tools (Phase 9 Step 4)
        list.append(ConversionAction(
            id: "video.speed",
            displayName: "Change Video Speed",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .video,
            iconName: "speedometer",
            parameters: [
                ActionParameter(
                    id: "factor",
                    label: "Speed Factor",
                    kind: .number,
                    defaultValue: .number(2.0),
                    minValue: 0.25,
                    maxValue: 4.0
                )
            ],
            buildInvocations: { input, output, params in
                let factor = params["factor"]?.asDouble ?? 2.0
                let atempo = MediaTools.atempoFilter(factor: factor)
                let pts = 1.0 / factor
                return [Invocation(toolName: "ffmpeg", arguments: [
                    "-nostdin", "-n", "-i", input.path,
                    "-vf", "setpts=\(pts)*PTS",
                    "-af", atempo,
                    output.path
                ])]
            }
        ))

        list.append(ConversionAction(
            id: "video.crop",
            displayName: "Crop Video",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .video,
            iconName: "crop",
            parameters: [
                ActionParameter(
                    id: "rectangle",
                    label: "Crop Rectangle (w:h:x:y)",
                    kind: .rectangle,
                    defaultValue: .rectangle(x: 0, y: 0, width: 320, height: 240)
                )
            ],
            buildInvocations: { input, output, params in
                var (x, y, w, h) = (0, 0, 320, 240)
                if let rectVal = params["rectangle"], case .rectangle(let rx, let ry, let rw, let rh) = rectVal {
                    (x, y, w, h) = (rx, ry, rw, rh)
                }
                return [Invocation(toolName: "ffmpeg", arguments: [
                    "-nostdin", "-n", "-i", input.path,
                    "-vf", "crop=\(w):\(h):\(x):\(y)",
                    "-c:a", "copy",
                    output.path
                ])]
            },
            customRunner: { input, output, params, runner, jobId in
                var (x, y, w, h) = (0, 0, 320, 240)
                if let rectVal = params["rectangle"], case .rectangle(let rx, let ry, let rw, let rh) = rectVal {
                    (x, y, w, h) = (rx, ry, rw, rh)
                }
                if let dims = MediaTools.shared.probeDimensions(url: input) {
                    try InputValidator.validateCropWithinBounds(width: w, height: h, x: x, y: y, containerWidth: dims.width, containerHeight: dims.height)
                }
                let inv = Invocation(toolName: "ffmpeg", arguments: [
                    "-nostdin", "-y", "-i", input.path,
                    "-vf", "crop=\(w):\(h):\(x):\(y)",
                    "-c:a", "copy",
                    output.path
                ])
                try runner.execute(invocation: inv, jobId: jobId)
            }
        ))

        list.append(ConversionAction(
            id: "video.split",
            displayName: "Split Video",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .video,
            iconName: "square.split.2x1",
            outputKind: .folder(suffix: "split"),
            parameters: [
                ActionParameter(
                    id: "times",
                    label: "Split Times (seconds, comma-separated)",
                    kind: .text,
                    defaultValue: .text("1.0")
                )
            ],
            customRunner: { input, output, params, runner, jobId in
                let times = params["times"]?.asString ?? "1.0"
                try MediaTools.shared.splitVideo(input: input, outputDir: output, timesString: times, runner: runner, jobId: jobId)
            }
        ))

        list.append(ConversionAction(
            id: "video.join",
            displayName: "Join Videos",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .video,
            iconName: "film.stack",
            isBatch: true,
            customBatchRunner: { inputs, output, params, runner, jobId in
                try MediaTools.shared.joinVideos(inputs: inputs, output: output, runner: runner, jobId: jobId)
            }
        ))

        list.append(ConversionAction(
            id: "video.snapshot",
            displayName: "Snapshot Frame (PNG)",
            outputExtension: "png",
            isAdvanced: true,
            category: .image,
            iconName: "camera",
            parameters: [
                ActionParameter(
                    id: "time",
                    label: "Snapshot Time (seconds)",
                    kind: .number,
                    defaultValue: .number(0.0),
                    minValue: 0.0
                )
            ],
            buildInvocations: { input, output, params in
                let t = params["time"]?.asDouble ?? 0.0
                let tStr = FormatRegistry.formatFfmpegTimestamp(t)
                return [Invocation(toolName: "ffmpeg", arguments: [
                    "-nostdin", "-n",
                    "-ss", tStr,
                    "-i", input.path,
                    "-update", "1",
                    "-frames:v", "1",
                    output.path
                ])]
            }
        ))

        list.append(ConversionAction(
            id: "video.snapshot.jpg",
            displayName: "Snapshot Frame (JPG)",
            outputExtension: "jpg",
            isAdvanced: true,
            category: .image,
            iconName: "camera",
            parameters: [
                ActionParameter(
                    id: "time",
                    label: "Snapshot Time (seconds)",
                    kind: .number,
                    defaultValue: .number(0.0),
                    minValue: 0.0
                )
            ],
            buildInvocations: { input, output, params in
                let t = params["time"]?.asDouble ?? 0.0
                let tStr = FormatRegistry.formatFfmpegTimestamp(t)
                return [Invocation(toolName: "ffmpeg", arguments: [
                    "-nostdin", "-n",
                    "-ss", tStr,
                    "-i", input.path,
                    "-update", "1",
                    "-frames:v", "1",
                    output.path
                ])]
            }
        ))

        list.append(contentsOf: metadataActions(for: inputExt))

        list.append(archiveCreateZipAction())
        list.append(archiveCreateGzipAction())
        return list
    }

    // MARK: - Audio
    private func audioActions(for url: URL, inputExt: String) -> [ConversionAction] {
        var list: [ConversionAction] = []

        if inputExt != "mp3" {
            list.append(ConversionAction(
                id: "audio.to.mp3",
                displayName: "Convert to MP3",
                outputExtension: "mp3",
                isAdvanced: false,
                category: .audio,
                iconName: "waveform"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "libmp3lame", "-q:a", "2", output.path])]
            })
        }

        if inputExt != "m4a" {
            list.append(ConversionAction(
                id: "audio.to.m4a",
                displayName: "Convert to M4A",
                outputExtension: "m4a",
                isAdvanced: false,
                category: .audio,
                iconName: "waveform"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "aac", "-b:a", "192k", output.path])]
            })
        }

        if inputExt != "flac" {
            list.append(ConversionAction(
                id: "audio.to.flac",
                displayName: "Convert to FLAC",
                outputExtension: "flac",
                isAdvanced: false,
                category: .audio,
                iconName: "waveform"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "flac", output.path])]
            })
        }

        if inputExt != "opus" {
            list.append(ConversionAction(
                id: "audio.to.opus",
                displayName: "Convert to Opus",
                outputExtension: "opus",
                isAdvanced: false,
                category: .audio,
                iconName: "waveform"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "libopus", "-b:a", "128k", output.path])]
            })
        }

        if inputExt != "wav" {
            list.append(ConversionAction(
                id: "audio.to.wav",
                displayName: "Convert to WAV",
                outputExtension: "wav",
                isAdvanced: false,
                category: .audio,
                iconName: "waveform"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "pcm_s16le", output.path])]
            })
        }

        if inputExt != "ogg" {
            list.append(ConversionAction(
                id: "audio.to.ogg",
                displayName: "Convert to OGG",
                outputExtension: "ogg",
                isAdvanced: false,
                category: .audio,
                iconName: "waveform"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "vorbis", "-strict", "-2", "-ac", "2", "-b:a", "128k", output.path])]
            })
        }

        if inputExt != "aiff" && inputExt != "aif" {
            list.append(ConversionAction(
                id: "audio.to.aiff",
                displayName: "Convert to AIFF",
                outputExtension: "aiff",
                isAdvanced: false,
                category: .audio,
                iconName: "waveform"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "pcm_s16be", output.path])]
            })
        }

        list.append(ConversionAction(
            id: "audio.compress",
            displayName: "Compress Audio",
            outputExtension: "mp3",
            isAdvanced: false,
            category: .audio,
            iconName: "arrow.down.circle",
            parameters: Self.compressionParameters,
            customRunner: { input, output, params, runner, jobId in
                try Compressor.shared.compressAudio(input: input, output: output, parameters: params, runner: runner, jobId: jobId)
            },
            customBatchRunner: { inputs, output, params, runner, jobId in
                try Compressor.shared.compressBatch(inputs: inputs, outputDir: output, parameters: params, compressItem: { inUrl, outUrl, p, r, j in
                    try Compressor.shared.compressAudio(input: inUrl, output: outUrl, parameters: p, runner: r, jobId: j)
                }, runner: runner, jobId: jobId)
            }
        ))

        // Advanced
        list.append(ConversionAction(
            id: "audio.advanced.compress",
            displayName: "Compress Audio",
            outputExtension: "mp3",
            isAdvanced: true,
            category: .audio,
            iconName: "arrow.down.circle",
            parameters: Self.compressionParameters,
            customRunner: { input, output, params, runner, jobId in
                try Compressor.shared.compressAudio(input: input, output: output, parameters: params, runner: runner, jobId: jobId)
            },
            customBatchRunner: { inputs, output, params, runner, jobId in
                try Compressor.shared.compressBatch(inputs: inputs, outputDir: output, parameters: params, compressItem: { inUrl, outUrl, p, r, j in
                    try Compressor.shared.compressAudio(input: inUrl, output: outUrl, parameters: p, runner: r, jobId: j)
                }, runner: runner, jobId: jobId)
            }
        ))

        list.append(ConversionAction(
            id: "audio.advanced.strip_metadata",
            displayName: "Remove Metadata",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .metadata,
            iconName: "lock.shield"
        ) { input, output in
            [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-map_metadata", "-1", "-c", "copy", output.path])]
        })

        // Audio Tools (Phase 9 Step 4)
        list.append(ConversionAction(
            id: "audio.normalize",
            displayName: "Normalize Audio (EBU R128)",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .audio,
            iconName: "speaker.wave.3",
            customRunner: { input, output, params, runner, jobId in
                try MediaTools.shared.normalizeAudio(input: input, output: output, runner: runner, jobId: jobId)
            }
        ))

        list.append(ConversionAction(
            id: "audio.channels",
            displayName: "Change Audio Channels",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .audio,
            iconName: "hifispeaker.2",
            parameters: [
                ActionParameter(
                    id: "channels",
                    label: "Audio Channels",
                    kind: .choice(options: ["mono", "stereo"]),
                    defaultValue: .text("stereo")
                )
            ],
            buildInvocations: { input, output, params in
                let ch = (params["channels"]?.asString == "mono") ? 1 : 2
                return [Invocation(toolName: "ffmpeg", arguments: [
                    "-nostdin", "-n", "-i", input.path,
                    "-ac", "\(ch)",
                    output.path
                ])]
            }
        ))

        list.append(ConversionAction(
            id: "audio.bleep",
            displayName: "Bleep Out Audio Ranges",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .audio,
            iconName: "waveform.badge.exclamationmark",
            parameters: [
                ActionParameter(
                    id: "ranges",
                    label: "Time Ranges (e.g. 0.5-1.0, 2.0-3.0)",
                    kind: .text,
                    defaultValue: .text("0.5-1.0")
                )
            ],
            buildInvocations: { input, output, params in
                let raw = params["ranges"]?.asString ?? "0.5-1.0"
                let rangeParts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var conds: [String] = []
                for rp in rangeParts {
                    let sep: Character = rp.contains(":") ? ":" : "-"
                    let sub = rp.split(separator: sep).map(String.init)
                    if sub.count == 2, let s = Double(sub[0]), let e = Double(sub[1]) {
                        conds.append("between(t,\(s),\(e))")
                    }
                }
                let inCond = conds.isEmpty ? "0" : conds.joined(separator: "+")
                let totalDur = Compressor.shared.probeDuration(url: input)
                let filterStr = "[0:a]volume='if(\(inCond),0,1)':eval=frame[v0];sine=f=1000:d=\(totalDur)[b];[b]volume='if(\(inCond),0.5,0)':eval=frame[b1];[v0][b1]amix=inputs=2:duration=first:dropout_transition=0[out]"
                return [Invocation(toolName: "ffmpeg", arguments: [
                    "-nostdin", "-n", "-i", input.path,
                    "-filter_complex", filterStr,
                    "-map", "[out]",
                    output.path
                ])]
            }
        ))

        let audioTrimParams = [
            ActionParameter(
                id: "start",
                label: "Start Time (seconds)",
                kind: .number,
                defaultValue: .number(0.0),
                minValue: 0.0
            ),
            ActionParameter(
                id: "end",
                label: "End Time (seconds)",
                kind: .number,
                defaultValue: .number(10.0),
                minValue: 0.0
            )
        ]
        list.append(ConversionAction(
            id: "audio.trim",
            displayName: "Trim Audio",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .audio,
            iconName: "scissors",
            parameters: audioTrimParams,
            buildInvocations: { input, output, params in
                let start = params["start"]?.asDouble ?? 0.0
                let end = params["end"]?.asDouble ?? 10.0
                let startStr = FormatRegistry.formatFfmpegTimestamp(start)
                let endStr = FormatRegistry.formatFfmpegTimestamp(end)
                return [Invocation(toolName: "ffmpeg", arguments: [
                    "-nostdin", "-n", "-i", input.path,
                    "-ss", startStr,
                    "-to", endStr,
                    "-c", "copy",
                    output.path
                ])]
            }
        ))

        list.append(contentsOf: metadataActions(for: inputExt))

        list.append(archiveCreateZipAction())
        list.append(archiveCreateGzipAction())
        return list
    }

    // MARK: - PDF
    private func pdfActions(for url: URL) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "pdf.to.text",
                displayName: "Convert to Plain Text",
                outputExtension: "txt",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pdftotext", arguments: ["-layout", input.path, output.path])]
            },
            ConversionAction(
                id: "pdf.to.images",
                displayName: "Extract Pages to PNGs",
                outputExtension: "png",
                isAdvanced: false,
                category: .image,
                iconName: "photo.stack",
                outputKind: .folder(suffix: "pages")
            ) { input, output in
                // pdftoppm outputs output-1.png, output-2.png...
                // output is used as the prefix path
                let prefix = output.deletingPathExtension().path
                return [Invocation(toolName: "pdftoppm", arguments: ["-png", "-r", "150", input.path, prefix])]
            },
            ConversionAction(
                id: "pdf.compress",
                displayName: "Compress PDF",
                outputExtension: "pdf",
                isAdvanced: false,
                category: .pdf,
                iconName: "arrow.down.circle",
                parameters: Self.compressionParameters,
                customRunner: { input, output, params, runner, jobId in
                    try Compressor.shared.compressPDF(input: input, output: output, parameters: params, runner: runner, jobId: jobId)
                },
                customBatchRunner: { inputs, output, params, runner, jobId in
                    try Compressor.shared.compressBatch(inputs: inputs, outputDir: output, parameters: params, compressItem: { inUrl, outUrl, p, r, j in
                        try Compressor.shared.compressPDF(input: inUrl, output: outUrl, parameters: p, runner: r, jobId: j)
                    }, runner: runner, jobId: jobId)
                }
            ),
            ConversionAction(
                id: "pdf.advanced.compress",
                displayName: "Compress PDF",
                outputExtension: "pdf",
                isAdvanced: true,
                category: .pdf,
                iconName: "arrow.down.circle",
                parameters: Self.compressionParameters,
                customRunner: { input, output, params, runner, jobId in
                    try Compressor.shared.compressPDF(input: input, output: output, parameters: params, runner: runner, jobId: jobId)
                },
                customBatchRunner: { inputs, output, params, runner, jobId in
                    try Compressor.shared.compressBatch(inputs: inputs, outputDir: output, parameters: params, compressItem: { inUrl, outUrl, p, r, j in
                        try Compressor.shared.compressPDF(input: inUrl, output: outUrl, parameters: p, runner: r, jobId: j)
                    }, runner: runner, jobId: jobId)
                }
            ),
            ConversionAction(
                id: "pdf.advanced.strip_metadata",
                displayName: "Remove Metadata",
                outputExtension: "pdf",
                isAdvanced: true,
                category: .metadata,
                iconName: "lock.shield"
            ) { input, output in
                // Two step pipeline: copy to temp, exiftool clean, then qpdf linearize to output
                let tempCopy = output.deletingLastPathComponent().appendingPathComponent("temp_pdf_clean.pdf")
                return [
                    Invocation(toolName: "ditto", arguments: ["--", input.path, tempCopy.path]),
                    Invocation(toolName: "exiftool", arguments: ["-all=", "-overwrite_original", "--", tempCopy.path]),
                    Invocation(toolName: "qpdf", arguments: ["--", tempCopy.path, output.path])
                ]
            },
            ConversionAction(
                id: "pdf.advanced.split",
                displayName: "Split PDF Pages",
                outputExtension: "",
                isAdvanced: true,
                category: .pdf,
                iconName: "scissors",
                outputKind: .folder(suffix: "split")
            ) { input, output in
                let pattern = output.appendingPathComponent("page-%d.pdf").path
                return [Invocation(toolName: "qpdf", arguments: [input.path, "--split-pages", pattern])]
            },
            ConversionAction(
                batchId: "pdf.merge",
                displayName: "Merge PDFs",
                outputExtension: "pdf",
                isAdvanced: false,
                category: .pdf,
                iconName: "doc.on.doc"
            ) { inputs, output, _ in
                [Invocation(toolName: "qpdf", arguments: ["--empty", "--pages"] + inputs.map(\.path) + ["--", output.path])]
            },
            ConversionAction(
                id: "pdf.reorganize",
                displayName: "Reorganize / Rotate Pages",
                outputExtension: "pdf",
                isAdvanced: true,
                category: .pdf,
                iconName: "arrow.triangle.swap",
                parameters: [
                    ActionParameter(id: "pages", label: "Page Sequence (e.g. 3,1,2)", kind: .text, defaultValue: .text("1-z")),
                    ActionParameter(id: "rotate", label: "Rotate Angle", kind: .choice(options: ["0", "90", "180", "270"]), defaultValue: .text("0")),
                    ActionParameter(id: "deletePages", label: "Pages to Delete", kind: .text, defaultValue: .text(""))
                ],
                customRunner: { input, output, params, runner, jobId in
                    let pages = params["pages"]?.asString ?? "1-z"
                    let rot = params["rotate"]?.asString ?? "0"
                    let del = params["deletePages"]?.asString ?? ""
                    try PDFTools.shared.reorganize(input: input, output: output, pages: pages, rotate: rot, deletePages: del, runner: runner, jobId: jobId)
                }
            )
        ] + metadataActions(for: "pdf") + [
            archiveCreateZipAction(),
            archiveCreateGzipAction()
        ]
    }

    // MARK: - Documents
    private func docxActions(for url: URL) -> [ConversionAction] {
        var actions: [ConversionAction] = [
            ConversionAction(
                id: "docx.to.md",
                displayName: "Convert to Markdown",
                outputExtension: "md",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "docx.to.txt",
                displayName: "Convert to Plain Text",
                outputExtension: "txt",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "docx.to.html",
                displayName: "Convert to HTML",
                outputExtension: "html",
                isAdvanced: false,
                category: .document,
                iconName: "globe"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "docx.to.epub",
                displayName: "Convert to EPUB",
                outputExtension: "epub",
                isAdvanced: false,
                category: .document,
                iconName: "book"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            }
        ]

        if ToolLocator.shared.isOptionalToolAvailable("soffice") {
            actions.append(ConversionAction(
                id: "docx.to.pdf",
                displayName: "Convert to PDF",
                outputExtension: "pdf",
                isAdvanced: false,
                category: .document,
                iconName: "doc.richtext"
            ) { input, output in
                let outDir = output.deletingLastPathComponent().path
                return [Invocation(toolName: "soffice", arguments: ["--headless", "--convert-to", "pdf", input.path, "--outdir", outDir])]
            })
        }

        actions.append(archiveCreateZipAction())
        actions.append(archiveCreateGzipAction())
        return actions
    }

    private func markdownActions(for url: URL) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "md.to.docx",
                displayName: "Convert to DOCX",
                outputExtension: "docx",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "md.to.html",
                displayName: "Convert to HTML",
                outputExtension: "html",
                isAdvanced: false,
                category: .document,
                iconName: "globe"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-s", "-o", output.path, input.path])]
            },
            ConversionAction(
                id: "md.to.txt",
                displayName: "Convert to Plain Text",
                outputExtension: "txt",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "md.to.epub",
                displayName: "Convert to EPUB",
                outputExtension: "epub",
                isAdvanced: false,
                category: .document,
                iconName: "book"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            archiveCreateZipAction(),
            archiveCreateGzipAction()
        ]
    }

    private func textActions(for url: URL) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "txt.to.md",
                displayName: "Convert to Markdown",
                outputExtension: "md",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "ditto", arguments: [input.path, output.path])]
            },
            ConversionAction(
                id: "txt.to.docx",
                displayName: "Convert to DOCX",
                outputExtension: "docx",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "txt.to.html",
                displayName: "Convert to HTML",
                outputExtension: "html",
                isAdvanced: false,
                category: .document,
                iconName: "globe"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-s", "-o", output.path, input.path])]
            },
            archiveCreateZipAction(),
            archiveCreateGzipAction()
        ]
    }

    private func htmlActions(for url: URL) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "html.to.md",
                displayName: "Convert to Markdown",
                outputExtension: "md",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "html.to.docx",
                displayName: "Convert to DOCX",
                outputExtension: "docx",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "html.to.txt",
                displayName: "Convert to Plain Text",
                outputExtension: "txt",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "html.to.epub",
                displayName: "Convert to EPUB",
                outputExtension: "epub",
                isAdvanced: false,
                category: .document,
                iconName: "book"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            archiveCreateZipAction(),
            archiveCreateGzipAction()
        ]
    }

    private func epubActions(for url: URL) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "epub.to.docx",
                displayName: "Convert to DOCX",
                outputExtension: "docx",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "epub.to.md",
                displayName: "Convert to Markdown",
                outputExtension: "md",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "epub.to.html",
                displayName: "Convert to HTML",
                outputExtension: "html",
                isAdvanced: false,
                category: .document,
                iconName: "globe"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-s", "-o", output.path, input.path])]
            },
            ConversionAction(
                id: "epub.to.txt",
                displayName: "Convert to Plain Text",
                outputExtension: "txt",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-t", "plain", "-o", output.path, input.path])]
            },
            archiveCreateZipAction(),
            archiveCreateGzipAction()
        ]
    }

    private func officeActions(for url: URL, inputExt: String) -> [ConversionAction] {
        var list: [ConversionAction] = []
        if ToolLocator.shared.isOptionalToolAvailable("soffice") {
            list.append(ConversionAction(
                id: "office.to.pdf",
                displayName: "Convert to PDF",
                outputExtension: "pdf",
                isAdvanced: false,
                category: .document,
                iconName: "doc.richtext"
            ) { input, output in
                let outDir = output.deletingLastPathComponent().path
                return [Invocation(toolName: "soffice", arguments: ["--headless", "--convert-to", "pdf", input.path, "--outdir", outDir])]
            })
        }
        list.append(archiveCreateZipAction())
        list.append(archiveCreateGzipAction())
        return list
    }

    // MARK: - Subtitles
    private func srtActions(for url: URL) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "srt.to.vtt",
                displayName: "Convert to WebVTT",
                outputExtension: "vtt",
                isAdvanced: false,
                category: .subtitle,
                iconName: "captions.bubble"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, output.path])]
            },
            archiveCreateZipAction(),
            archiveCreateGzipAction()
        ]
    }

    private func vttActions(for url: URL) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "vtt.to.srt",
                displayName: "Convert to SubRip (.srt)",
                outputExtension: "srt",
                isAdvanced: false,
                category: .subtitle,
                iconName: "captions.bubble"
            ) { input, output in
                [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, output.path])]
            },
            archiveCreateZipAction(),
            archiveCreateGzipAction()
        ]
    }

    // MARK: - Archives
    private func archiveExtractActions(for url: URL, inputExt: String) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "archive.extract",
                displayName: "Extract Archive",
                outputExtension: "",
                isAdvanced: false,
                category: .archive,
                iconName: "archivebox",
                outputKind: .folder(suffix: "extracted")
            ) { input, output in
                if inputExt == "zip" {
                    return [Invocation(toolName: "ditto", arguments: ["-x", "-k", input.path, output.path])]
                } else if inputExt == "gz" {
                    return [Invocation(toolName: "7zz", arguments: ["x", "-y", input.path, "-o\(output.path)"])]
                } else if ["tar", "tgz"].contains(inputExt) {
                    return [Invocation(toolName: "tar", arguments: ["-xf", input.path, "-C", output.path])]
                } else if inputExt == "rar" {
                    return [Invocation(toolName: "unar", arguments: ["-o", output.path, input.path])]
                } else {
                    return [Invocation(toolName: "7zz", arguments: ["x", "-y", input.path, "-o\(output.path)"])]
                }
            }
        ]
    }

    private func directoryActions(for url: URL) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "archive.create.zip",
                displayName: "Compress to ZIP",
                outputExtension: "zip",
                isAdvanced: false,
                category: .archive,
                iconName: "archivebox"
            ) { input, output in
                [Invocation(toolName: "ditto", arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", input.path, output.path])]
            },
            ConversionAction(
                id: "archive.create.targz",
                displayName: "Compress to TAR.GZ",
                outputExtension: "tar.gz",
                isAdvanced: false,
                category: .archive,
                iconName: "archivebox"
            ) { input, output in
                let parentDir = input.deletingLastPathComponent().path
                let name = input.lastPathComponent
                return [Invocation(toolName: "tar", arguments: ["-czf", output.path, "-C", parentDir, name])]
            },
            archiveCreateGzipAction()
        ]
    }

    private func codeAndScriptActions(for url: URL, inputExt: String) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "code.to.txt",
                displayName: "Convert to Plain Text",
                outputExtension: "txt",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "ditto", arguments: [input.path, output.path])]
            },
            ConversionAction(
                id: "code.to.md",
                displayName: "Convert to Markdown",
                outputExtension: "md",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-o", output.path, input.path])]
            },
            ConversionAction(
                id: "code.to.html",
                displayName: "Convert to HTML",
                outputExtension: "html",
                isAdvanced: false,
                category: .document,
                iconName: "globe"
            ) { input, output in
                [Invocation(toolName: "pandoc", arguments: ["-s", "-o", output.path, input.path])]
            },
            ConversionAction(
                id: "code.to.pdf",
                displayName: "Convert to PDF",
                outputExtension: "pdf",
                isAdvanced: false,
                category: .document,
                iconName: "doc.richtext"
            ) { input, output in
                [Invocation(toolName: "cupsfilter", arguments: [input.path], redirectStdoutTo: output.path)]
            },
            archiveCreateZipAction(),
            archiveCreateGzipAction(),
            ConversionAction(
                id: "archive.create.targz",
                displayName: "Compress to TAR.GZ",
                outputExtension: "tar.gz",
                isAdvanced: false,
                category: .archive,
                iconName: "archivebox"
            ) { input, output in
                let parentDir = input.deletingLastPathComponent().path
                let name = input.lastPathComponent
                return [Invocation(toolName: "tar", arguments: ["-czf", output.path, "-C", parentDir, name])]
            }
        ]
    }

    private func genericFileActions(for url: URL) -> [ConversionAction] {
        return [
            ConversionAction(
                id: "generic.to.txt",
                displayName: "Convert to Plain Text",
                outputExtension: "txt",
                isAdvanced: false,
                category: .document,
                iconName: "doc.text"
            ) { input, output in
                [Invocation(toolName: "ditto", arguments: [input.path, output.path])]
            },
            ConversionAction(
                id: "generic.to.pdf",
                displayName: "Convert to PDF",
                outputExtension: "pdf",
                isAdvanced: false,
                category: .document,
                iconName: "doc.richtext"
            ) { input, output in
                [Invocation(toolName: "cupsfilter", arguments: [input.path], redirectStdoutTo: output.path)]
            },
            archiveCreateZipAction(),
            archiveCreateGzipAction(),
            ConversionAction(
                id: "archive.create.targz",
                displayName: "Compress to TAR.GZ",
                outputExtension: "tar.gz",
                isAdvanced: false,
                category: .archive,
                iconName: "archivebox"
            ) { input, output in
                let parentDir = input.deletingLastPathComponent().path
                let name = input.lastPathComponent
                return [Invocation(toolName: "tar", arguments: ["-czf", output.path, "-C", parentDir, name])]
            }
        ]
    }

    private func archiveCreateZipAction() -> ConversionAction {
        return ConversionAction(
            id: "archive.create.zip",
            displayName: "Compress to ZIP",
            outputExtension: "zip",
            isAdvanced: false,
            category: .archive,
            iconName: "archivebox"
        ) { input, output in
            [Invocation(toolName: "ditto", arguments: ["-c", "-k", "--sequesterRsrc", input.path, output.path])]
        }
    }

    private func archiveCreateGzipAction() -> ConversionAction {
        return ConversionAction(
            id: "archive.create.gzip",
            displayName: "Compress to GZIP",
            outputExtension: "gz",
            isAdvanced: false,
            category: .archive,
            iconName: "archivebox"
        ) { input, output in
            [Invocation(toolName: "7zz", arguments: ["a", "-tgzip", output.path, input.path])]
        }
    }
}
