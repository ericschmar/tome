import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Settings view for app preferences
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared
    @State private var showingClearCacheAlert = false
    @State private var cacheSize: String = "Calculating..."
    @State private var syncMonitor = CloudSyncMonitor.shared
    @State private var accountService = CloudKitAccountService.shared
    @State private var showingDiagnostics = false
    @State private var diagnosticsCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Settings content
            ScrollView {
                VStack(spacing: 24) {
                    // Appearance section
                    settingsSection(title: "Appearance") {
                        themeSelector
                    }
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Language section
                    settingsSection(title: "Content") {
                        languageSelector
                    }
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // iCloud Sync section
                    settingsSection(title: "iCloud Sync") {
                        cloudSyncManagement
                    }
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Storage section
                    settingsSection(title: "Storage") {
                        cacheManagement
                    }

                    Divider()
                        .padding(.horizontal, 20)

                    // Diagnostics section
                    settingsSection(title: "Diagnostics") {
                        diagnosticsSection
                    }
                }
                .padding(.vertical, 20)
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 450)
        #endif
        .background(.ultraThinMaterial)
        .onAppear {
            updateCacheSize()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Settings Sections
    
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
            
            content()
        }
    }
    
    // MARK: - Theme Selector
    
    private var themeSelector: some View {
        VStack(spacing: 8) {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settings.theme = theme
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: theme.iconName)
                            .font(.system(size: 16))
                            .foregroundStyle(settings.theme == theme ? .white : .secondary)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(settings.theme == theme ? .white : .primary)
                            
                            Text(themeDescription(for: theme))
                                .font(.system(size: 12))
                                .foregroundStyle(settings.theme == theme ? .white.opacity(0.8) : .secondary)
                        }
                        
                        Spacer()
                        
                        if settings.theme == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(settings.theme == theme ? Color.accentColor : Color.gray.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                settings.theme == theme ? Color.clear : Color.gray.opacity(0.15),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func themeDescription(for theme: AppTheme) -> String {
        switch theme {
        case .system:
            return "Match system appearance"
        case .light:
            return "Always use light mode"
        case .dark:
            return "Always use dark mode"
        }
    }
    
    // MARK: - Language Selector
    
    private var languageSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Default Book Language")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
            
            Text("This language will be used as the default when adding new books")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            Picker("", selection: $settings.defaultBookLanguage) {
                ForEach(BookLanguage.allCases) { language in
                    Text("\(language.flag)  \(language.displayName)")
                        .tag(language)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Cache Management
    
    private var cloudSyncManagement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Status")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Sync status row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 6) {
                            if syncMonitor.isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.green)
                            }
                            
                            Text(syncMonitor.statusMessage)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.06))
                )
                .padding(.horizontal, 20)
            }
            
            // Info text
            Text("Your library syncs automatically with iCloud.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Cache Management
    
    private var cacheManagement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Cache")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cache Size")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    
                    Text(cacheSize)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button {
                    showingClearCacheAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                        Text("Clear Cache")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.06))
            )
            .padding(.horizontal, 20)
        }
        .alert("Clear Image Cache?", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Cache", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will remove all cached images. They will be downloaded again when needed.")
        }
    }
    
    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingDiagnostics.toggle()
                }
            } label: {
                HStack {
                    Text("Sync Diagnostics")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: showingDiagnostics ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)

            if showingDiagnostics {
                VStack(alignment: .leading, spacing: 8) {
                    diagnosticsRows
                    if !syncMonitor.eventLog.isEmpty {
                        Divider().padding(.horizontal, 20)
                        Text("Recent Sync Events")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                        ForEach(syncMonitor.eventLog.prefix(10)) { entry in
                            diagnosticsEventRow(entry)
                        }
                    }
                    copyDiagnosticsButton
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("Share these details when reporting sync issues.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
    }

    private var diagnosticsRows: some View {
        VStack(spacing: 0) {
            diagnosticsRow(label: "Container", value: "iCloud.com.ericschmar.tome")
            diagnosticsRow(label: "Account Status", value: accountService.statusMessage)
            diagnosticsRow(label: "User Record ID", value: accountService.userRecordIDString ?? "Unavailable")
            diagnosticsRow(label: "Last Sync", value: syncMonitor.lastSyncFormatted)
            if let error = syncMonitor.lastError {
                diagnosticsRow(label: "Last Error", value: error.localizedDescription, isError: true)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
        .padding(.horizontal, 20)
    }

    private func diagnosticsRow(label: String, value: String, isError: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isError ? .red : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func diagnosticsEventRow(_ entry: CloudSyncMonitor.SyncEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(entry.succeeded ? .green : .red)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.type) — \(entry.date.formatted(.dateTime.month().day().hour().minute().second()))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                if let err = entry.errorDescription {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var copyDiagnosticsButton: some View {
        Button {
            copyDiagnosticsToClipboard()
            diagnosticsCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                diagnosticsCopied = false
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: diagnosticsCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                Text(diagnosticsCopied ? "Copied!" : "Copy Diagnostics")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(diagnosticsCopied ? .green : .accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((diagnosticsCopied ? Color.green : Color.accentColor).opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.2), value: diagnosticsCopied)
    }

    private func copyDiagnosticsToClipboard() {
        var lines: [String] = [
            "=== Tome Sync Diagnostics ===",
            "Date: \(Date().formatted())",
            "Container: iCloud.com.ericschmar.tome",
            "Account Status: \(accountService.statusMessage)",
            "User Record ID: \(accountService.userRecordIDString ?? "Unavailable")",
            "Last Sync: \(syncMonitor.lastSyncFormatted)",
        ]
        if let error = syncMonitor.lastError {
            lines.append("Last Error: \(error.localizedDescription)")
        }
        if !syncMonitor.eventLog.isEmpty {
            lines.append("\nRecent Events:")
            for entry in syncMonitor.eventLog.prefix(20) {
                let status = entry.succeeded ? "✓" : "✗"
                var line = "  \(status) [\(entry.date.formatted(.dateTime.month().day().hour().minute().second()))] \(entry.type)"
                if let err = entry.errorDescription { line += " — \(err)" }
                lines.append(line)
            }
        }
        let report = lines.joined(separator: "\n")
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = report
        #endif
    }

    // MARK: - Actions

    private func updateCacheSize() {
        cacheSize = settings.getImageCacheSize()
    }
    
    private func clearCache() {
        settings.clearImageCache()
        
        // Animate the cache size update
        withAnimation {
            cacheSize = "Clearing..."
        }
        
        // Update after a brief delay to show the change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                updateCacheSize()
            }
        }
    }
}

#Preview {
    SettingsView()
}
