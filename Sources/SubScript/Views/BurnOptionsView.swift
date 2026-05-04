import SwiftUI

struct BurnOptionsView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(String(localized: "burn_settings_title"))
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.top)
            .padding(.horizontal)

            Form {
                Section(String(localized: "burn_section_video_codec")) {
                    Picker(String(localized: "burn_codec_label"), selection: $appState.burnConfig.videoCodec) {
                        ForEach(VideoCodec.allCases, id: \.self) { codec in
                            Text(codec.displayName).tag(codec)
                        }
                    }
                    
                    if appState.burnConfig.videoCodec.supportsCRF {
                        Picker(String(localized: "burn_quality_label"), selection: $appState.burnConfig.quality) {
                            ForEach(QualityMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        
                        if appState.burnConfig.quality == .custom {
                            Stepper(String(format: String(localized: "burn_crf_label"), appState.burnConfig.customCRF), 
                                   value: Binding(
                                       get: { appState.burnConfig.customCRF },
                                       set: { newValue in 
                                           appState.burnConfig.customCRF = newValue
                                           appState.burnConfig.quality = .custom
                                       }
                                   ), in: 0...51)
                        }
                    } else {
                        Picker(String(localized: "burn_quality_label"), selection: $appState.burnConfig.quality) {
                            ForEach(QualityMode.allCases, id: \.self) { mode in
                                Text("\(mode.rawValue) (\(mode.bitrate))").tag(mode)
                            }
                        }
                    }
                }

                Section(String(localized: "burn_section_subtitle_style")) {
                    Stepper(String(format: String(localized: "burn_font_size_label"), appState.burnConfig.fontSize), 
                           value: $appState.burnConfig.fontSize, in: 12...72, step: 2)
                    
                    Picker(String(localized: "burn_position_label"), selection: $appState.burnConfig.position) {
                        ForEach(SubtitlePosition.allCases, id: \.self) { pos in
                            Text(pos.rawValue).tag(pos)
                        }
                    }
                    
                    Toggle(String(localized: "burn_shadow_label"), isOn: $appState.burnConfig.shadowEnabled)
                }
                
                Section(String(localized: "burn_section_color")) {
                    HStack {
                        Text(String(localized: "burn_primary_color"))
                        Spacer()
                        ColorPicker(String(localized: "burn_primary_color"), selection: Binding(
                            get: { Color(hex: appState.burnConfig.primaryColor) },
                            set: { appState.burnConfig.primaryColor = $0.toASSColor() }
                        ))
                        .labelsHidden()
                    }
                    
                    HStack {
                        Text(String(localized: "burn_outline_color"))
                        Spacer()
                        ColorPicker(String(localized: "burn_outline_color"), selection: Binding(
                            get: { Color(hex: appState.burnConfig.outlineColor) },
                            set: { appState.burnConfig.outlineColor = $0.toASSColor() }
                        ))
                        .labelsHidden()
                    }
                    
                    Stepper(String(format: String(localized: "burn_outline_width_label"), appState.burnConfig.outlineWidth), 
                           value: $appState.burnConfig.outlineWidth, in: 0...5)
                }

                Section(String(localized: "burn_section_output_format")) {
                    Picker(String(localized: "burn_format_label"), selection: $appState.burnConfig.outputFormat) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    
                    HStack {
                        Text(appState.burnConfig.outputFolder?.path ?? String(localized: "burn_default_folder"))
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button(String(localized: "burn_select_button")) {
                            selectOutputFolder()
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack(spacing: 16) {
                Button(String(localized: "burn_cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "burn_start_button")) {
                    appState.showBurnOptions = false
                    appState.showBurnSheet = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom)
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 480, minHeight: 650)
    }

    private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            appState.burnConfig.outputFolder = panel.url
        }
    }
}

extension Color {
    init(hex assHex: String) {
        let hex = assHex.replacingOccurrences(of: "&H", with: "").replacingOccurrences(of: "00", with: "")
        
        if hex.count == 6 {
            let b = String(hex.prefix(2))
            let g = String(hex.dropFirst(2).prefix(2))
            let r = String(hex.dropFirst(4).prefix(2))
            let fullHex = "#" + r + g + b
            let nsColor = NSColor(hex: fullHex)
            self = Color(nsColor)
        } else {
            self = .white
        }
    }

    func toASSColor() -> String {
        let nsColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        let converted = nsColor.usingColorSpace(.sRGB)
        converted?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let b = String(format: "%02X", Int(blue * 255))
        let g = String(format: "%02X", Int(green * 255))
        let r = String(format: "%02X", Int(red * 255))
        
        return "&H\(b)\(g)\(r)"
    }
}

extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
