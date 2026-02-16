import SwiftUI

/// Hybrid input component combining a TextField with a Stepper for copy count
struct CopyCountInputView: View {
    @Binding var copyCount: String
    @State private var stepperValue: Int

    init(copyCount: Binding<String>) {
        self._copyCount = copyCount
        self._stepperValue = State(initialValue: Int(copyCount.wrappedValue) ?? 1)
    }

    var body: some View {
        HStack {
            TextField("Copies", text: $copyCount)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
                .textFieldStyle(.roundedBorder)
                .onChange(of: copyCount) { _, newValue in
                    if let value = Int(newValue), value > 0 {
                        stepperValue = value
                    }
                }

            Stepper("", value: $stepperValue, in: 1...999)
                .labelsHidden()
                .onChange(of: stepperValue) { _, newValue in
                    copyCount = "\(newValue)"
                }
        }.frame(maxWidth: 120)
    }
}

#Preview {
    @Previewable @State var copyCount = "1"

    CopyCountInputView(copyCount: $copyCount)
        .padding()
}
