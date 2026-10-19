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

    public func action(for fileURL: URL, actionID: String) -> ConversionAction? {
        return availableActions(for: fileURL).first { $0.id == actionID }
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
        case "mp4", "mov", "mkv", "webm", "avi", "m4v", "flv":
            return videoActions(for: fileURL, inputExt: ext)
        case "mp3", "m4a", "wav", "flac", "aac", "ogg", "opus":
            return audioActions(for: fileURL, inputExt: ext)
        case "pdf":
            return pdfActions(for: fileURL)
        case "docx":
            return docxActions(for: fileURL)
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
            [Invocation(toolName: "exiftool", arguments: ["-all=", "-o", output.path, input.path])]
        })

        list.append(ConversionAction(
            id: "image.advanced.compress",
            displayName: "Compress Image",
            outputExtension: inputExt == "svg" ? "png" : inputExt,
            isAdvanced: true,
            category: .image,
            iconName: "arrow.down.circle"
        ) { input, output in
            if inputExt == "jpg" || inputExt == "jpeg" {
                return [Invocation(toolName: "sips", arguments: ["-s", "format", "jpeg", "-s", "formatOptions", "60", input.path, "--out", output.path])]
            } else if inputExt == "png" {
                return [Invocation(toolName: "magick", arguments: [input.path, "-quality", "80", output.path])]
            } else if inputExt == "webp" {
                return [Invocation(toolName: "cwebp", arguments: ["-q", "60", input.path, "-o", output.path])]
            } else {
                return [Invocation(toolName: "sips", arguments: ["-s", "format", "jpeg", "-s", "formatOptions", "60", input.path, "--out", output.path])]
            }
        })

        list.append(ConversionAction(
            id: "image.advanced.resize_50",
            displayName: "Resize (Max 1200px)",
            outputExtension: inputExt == "svg" ? "png" : inputExt,
            isAdvanced: true,
            category: .image,
            iconName: "arrow.up.left.and.arrow.down.right"
        ) { input, output in
            [Invocation(toolName: "sips", arguments: ["-Z", "1200", input.path, "--out", output.path])]
        })

        // Standard compress to zip
        list.append(archiveCreateZipAction())

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

        // Advanced actions
        list.append(ConversionAction(
            id: "video.advanced.compress",
            displayName: "Compress Video (CRF 28)",
            outputExtension: "mp4",
            isAdvanced: true,
            category: .video,
            iconName: "arrow.down.circle"
        ) { input, output in
            [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-c:v", "libx264", "-crf", "28", "-preset", "medium", "-c:a", "aac", "-b:a", "128k", output.path])]
        })

        list.append(ConversionAction(
            id: "video.advanced.trim10",
            displayName: "Trim First 10 Seconds",
            outputExtension: inputExt,
            isAdvanced: true,
            category: .video,
            iconName: "scissors"
        ) { input, output in
            [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-ss", "00:00:00", "-to", "00:00:10", "-c", "copy", output.path])]
        })

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

        list.append(archiveCreateZipAction())
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

        // Advanced
        list.append(ConversionAction(
            id: "audio.advanced.compress",
            displayName: "Compress Audio (96k)",
            outputExtension: "mp3",
            isAdvanced: true,
            category: .audio,
            iconName: "arrow.down.circle"
        ) { input, output in
            [Invocation(toolName: "ffmpeg", arguments: ["-nostdin", "-n", "-i", input.path, "-vn", "-c:a", "libmp3lame", "-b:a", "96k", output.path])]
        })

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

        list.append(archiveCreateZipAction())
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
                iconName: "photo.stack"
            ) { input, output in
                // pdftoppm outputs output-1.png, output-2.png...
                // output is used as the prefix path
                let prefix = output.deletingPathExtension().path
                return [Invocation(toolName: "pdftoppm", arguments: ["-png", "-r", "150", input.path, prefix])]
            },
            ConversionAction(
                id: "pdf.advanced.compress",
                displayName: "Compress PDF (eBook)",
                outputExtension: "pdf",
                isAdvanced: true,
                category: .pdf,
                iconName: "arrow.down.circle"
            ) { input, output in
                [Invocation(toolName: "gs", arguments: [
                    "-sDEVICE=pdfwrite",
                    "-dCompatibilityLevel=1.4",
                    "-dPDFSETTINGS=/ebook",
                    "-dNOPAUSE",
                    "-dQUIET",
                    "-dBATCH",
                    "-sOutputFile=\(output.path)",
                    input.path
                ])]
            },
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
                    Invocation(toolName: "ditto", arguments: [input.path, tempCopy.path]),
                    Invocation(toolName: "exiftool", arguments: ["-all=", "-overwrite_original", tempCopy.path]),
                    Invocation(toolName: "qpdf", arguments: [tempCopy.path, output.path])
                ]
            },
            ConversionAction(
                id: "pdf.advanced.split",
                displayName: "Split PDF Pages",
                outputExtension: "",
                isAdvanced: true,
                category: .pdf,
                iconName: "scissors"
            ) { input, output in
                let pattern = output.appendingPathComponent("page-%d.pdf").path
                return [Invocation(toolName: "qpdf", arguments: [input.path, "--split-pages", pattern])]
            },
            archiveCreateZipAction()
        ]
    }

    // MARK: - Documents
    private func docxActions(for url: URL) -> [ConversionAction] {
        return [
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
            archiveCreateZipAction()
        ]
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
            archiveCreateZipAction()
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
            archiveCreateZipAction()
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
            archiveCreateZipAction()
        ]
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
            archiveCreateZipAction()
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
            archiveCreateZipAction()
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
                iconName: "archivebox"
            ) { input, output in
                if inputExt == "zip" {
                    return [Invocation(toolName: "ditto", arguments: ["-x", "-k", input.path, output.path])]
                } else if ["tar", "gz", "tgz"].contains(inputExt) {
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
            }
        ]
    }

    private func genericFileActions(for url: URL) -> [ConversionAction] {
        return [
            archiveCreateZipAction(),
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
}
