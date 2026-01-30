//
//  LanguagePickerView.swift
//  Invoice
//
//  Language selection UI for Profile/Settings tab
//

import SwiftUI

/// Language picker view for Settings/Profile tab
struct LanguagePickerView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showLanguageSheet = false
    
    var body: some View {
        Button(action: {
            showLanguageSheet = true
        }) {
            HStack(spacing: 16) {
                Text("language")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.black)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(languageManager.currentLanguage.flag)
                        .font(.title3)
                    
                    Text(languageManager.currentLanguage.name)
                        .font(.system(size: 15))
                        .foregroundColor(Color.black.opacity(0.5))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showLanguageSheet) {
            LanguageSelectionSheet()
        }
    }
}

/// Full-screen language selection sheet
struct LanguageSelectionSheet: View {
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage: AppLanguage
    
    init() {
        _selectedLanguage = State(initialValue: LanguageManager.shared.currentLanguage)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageRow(
                            language: language,
                            isSelected: selectedLanguage == language
                        ) {
                            selectLanguage(language)
                        }
                    }
                } header: {
                    Text("select_language")
                } footer: {
                    Text("language_restart_note")
                        .font(.footnote)
                }
            }
            .navigationTitle("language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func selectLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Change language with slight delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            languageManager.changeLanguage(to: language)
            
            // Show restart alert
            showRestartAlert()
        }
    }
    
    private func showRestartAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("language_changed", comment: ""),
            message: NSLocalizedString("restart_app_message", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("restart_now", comment: ""),
            style: .default
        ) { _ in
            // Close sheet and trigger app restart
            dismiss()
            restartApp()
        })
        
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("later", comment: ""),
            style: .cancel
        ) { _ in
            dismiss()
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func restartApp() {
        // Trigger app to refresh by posting notification
        // The app's root view will listen to this and reset
        NotificationCenter.default.post(name: .languageChanged, object: nil)
        
        // Alternative: Force exit (not recommended by Apple, but works)
        // exit(0)
    }
}

/// Individual language row
struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 32))
                
                // Language name
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.name)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.primary)
                    
                    Text(language.englishName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        List {
            Section {
                LanguagePickerView()
            } header: {
                Text("Settings")
            }
        }
        .navigationTitle("Profile")
    }
}

#Preview("Language Sheet") {
    LanguageSelectionSheet()
}
