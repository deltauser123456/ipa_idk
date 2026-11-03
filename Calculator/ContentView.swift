import SwiftUI

struct ContentView: View {
    @State private var display = "0"
    @State private var storedValue: Double?
    @State private var pendingOperation: String?
    @State private var startsNewNumber = true
    @State private var lastOperation: String?
    @State private var lastOperand: Double?

    private let rows = [
        ["AC", "+/-", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["0", ".", "="]
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                Spacer()
                HStack {
                    Spacer()
                    Text(display)
                        .font(.system(size: min(geometry.size.width * 0.19, 76), weight: .light, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.35)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 8)
                }
                .frame(height: geometry.size.height * 0.22)

                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { item in
                            Button {
                                withAnimation(.easeOut(duration: 0.12)) { tap(item) }
                            } label: {
                                Text(item)
                                    .font(.system(size: 29, weight: .medium, design: .rounded))
                                    .foregroundStyle(textColor(item))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: (geometry.size.height * 0.66 - 48) / 5)
                                    .background(buttonColor(item), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
        }
    }

    private func buttonColor(_ key: String) -> Color {
        if ["÷", "×", "−", "+", "="].contains(key) { return Color.orange }
        if ["AC", "+/-", "%"].contains(key) { return Color(white: 0.62) }
        return Color(white: 0.20)
    }

    private func textColor(_ key: String) -> Color {
        ["AC", "+/-", "%"].contains(key) ? .black : .white
    }

    private func tap(_ key: String) {
        if let digit = Int(key), (0...9).contains(digit) {
            if startsNewNumber || display == "0" {
                display = key
                startsNewNumber = false
            } else if display.count < 12 {
                display += key
            }
            return
        }

        switch key {
        case "AC":
            display = "0"
            storedValue = nil
            pendingOperation = nil
            lastOperation = nil
            lastOperand = nil
            startsNewNumber = true
        case ".":
            if startsNewNumber {
                display = "0."
                startsNewNumber = false
            } else if !display.contains(".") {
                display += "."
            }
        case "+/-":
            if let value = currentValue { display = format(-value) }
        case "%":
            if let value = currentValue { display = format(value / 100) }
        case "+", "−", "×", "÷":
            if let value = currentValue {
                if let previous = storedValue, let operation = pendingOperation {
                    let result = calculate(previous, value, operation)
                    display = format(result)
                    storedValue = result
                } else {
                    storedValue = value
                }
            }
            pendingOperation = key
            startsNewNumber = true
            lastOperation = nil
            lastOperand = nil
        case "=":
            if let operation = pendingOperation, let first = storedValue, let second = currentValue {
                let result = calculate(first, second, operation)
                display = format(result)
                lastOperation = operation
                lastOperand = second
                storedValue = nil
                pendingOperation = nil
                startsNewNumber = true
            } else if let operation = lastOperation, let operand = lastOperand, let first = currentValue {
                display = format(calculate(first, operand, operation))
            }
        default:
            break
        }
    }

    private var currentValue: Double? { Double(display) }

    private func calculate(_ a: Double, _ b: Double, _ operation: String) -> Double {
        switch operation {
        case "+": return a + b
        case "−": return a - b
        case "×": return a * b
        case "÷": return b == 0 ? 0 : a / b
        default: return b
        }
    }

    private func format(_ value: Double) -> String {
        guard value.isFinite else { return "Error" }
        if abs(value) < 1_000_000_000_000, value.rounded() == value {
            return String(Int64(value))
        }
        return String(format: "%.8g", value)
    }
}
