import SwiftUI

/// Settings view for app preferences
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared
    @State private var showingClearCacheAlert = false
    @State private var cacheSize: String = "Calculating..."
    
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
                    
                    // Storage section
                    settingsSection(title: "Storage") {
                        cacheManagement
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .frame(width: 500, height: 450)
        .background(Color(nsColor: .windowBackgroundColor))
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
