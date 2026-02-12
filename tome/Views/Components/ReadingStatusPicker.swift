import SwiftUI

/// Status selection UI component
struct ReadingStatusPicker: View {
    @Binding var selectedStatus: ReadingStatus
    var allowsNil = false

    var body: some View {
        Picker("Reading Status", selection: $selectedStatus) {
            ForEach(ReadingStatus.allCases, id: \.self) { status in
                Label(status.displayName, systemImage: status.icon)
                    .tag(status)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Alternative reading status selector with buttons
struct ReadingStatusButtonGroup: View {
    @Binding var selectedStatus: ReadingStatus

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ReadingStatus.allCases, id: \.self) { status in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedStatus = status
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(selectedStatus == status ? status.color.opacity(0.15) : Color.secondary.opacity(0.08))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: status.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(selectedStatus == status ? status.color : .secondary)
                        }
                        
                        Text(status.displayName)
                            .font(.system(size: 12, weight: selectedStatus == status ? .semibold : .regular))
                            .foregroundStyle(selectedStatus == status ? status.color : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedStatus == status ? status.color.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                selectedStatus == status ? status.color.opacity(0.3) : Color.secondary.opacity(0.15),
                                lineWidth: selectedStatus == status ? 2 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension ReadingStatus {
    var color: Color {
        switch self {
        case .toRead: return .orange
        case .reading: return .blue
        case .read: return .green
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        VStack(alignment: .leading) {
            Text("Segmented Picker")
                .font(.headline)
            ReadingStatusPicker(selectedStatus: .constant(.toRead))
        }

        VStack(alignment: .leading) {
            Text("Button Group")
                .font(.headline)
            ReadingStatusButtonGroup(selectedStatus: .constant(.reading))
        }
    }
    .padding()
}
