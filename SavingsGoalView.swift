import SwiftUI
import SwiftData

struct SavingsGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavingsGoal.deadline, order: .forward) private var goals: [SavingsGoal]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    
    @State private var showingAddGoal = false
    @State private var selectedGoalForDeposit: SavingsGoal?
    
    var body: some View {
        List {
            Section {
                ForEach(goals) { goal in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: goal.iconName)
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Color(hex: goal.colorHex), in: RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.title)
                                    .font(.headline)
                                Text("Đích: \(goal.deadline.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(Int(goal.progress * 100))%")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(hex: goal.colorHex))
                        }
                        
                        ProgressView(value: goal.progress)
                            .tint(Color(hex: goal.colorHex))
                        
                        HStack {
                            Text("Đã tích lũy: \(goal.currentAmount.formattedCurrency())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Mục tiêu: \(goal.targetAmount.formattedCurrency())")
                                .font(.caption.weight(.semibold))
                        }
                        
                        if !goal.isCompleted {
                            HStack {
                                Text("Gợi ý: \(goal.suggestedMonthlySaving.formattedCurrency())/tháng")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    selectedGoalForDeposit = goal
                                } label: {
                                    Label("Nạp tích lũy", systemImage: "plus.circle.fill")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(hex: goal.colorHex))
                                .controlSize(.mini)
                            }
                        } else {
                            Label("Chúc mừng! Đã hoàn thành mục tiêu tiết kiệm", systemImage: "checkmark.seal.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteGoals)
                
                if goals.isEmpty {
                    ContentUnavailableView(
                        "Chưa có mục tiêu tiết kiệm",
                        systemImage: "star.circle",
                        description: Text("Tạo mục tiêu tích lũy (Mua nhà, Mua xe, Quỹ khẩn cấp) để theo dõi tiến độ.")
                    )
                }
            }
        }
        .navigationTitle("Mục tiêu Tiết kiệm")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddGoal = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddSavingsGoalSheet()
        }
        .sheet(item: $selectedGoalForDeposit) { goal in
            DepositSavingsSheet(goal: goal, accounts: accounts)
        }
    }
    
    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
        try? modelContext.save()
    }
}

struct AddSavingsGoalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var targetAmountText: String = ""
    @State private var currentAmountText: String = "0"
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var selectedIcon: String = "star.fill"
    @State private var selectedColorHex: String = "#34C759"
    
    private let icons = ["star.fill", "shield.lefthalf.filled", "car.fill", "house.fill", "airplane", "laptopcomputer", "gift.fill"]
    private let colors = ["#34C759", "#007AFF", "#AF52DE", "#FF9500", "#FF2D55", "#00C7BE"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin mục tiêu") {
                    TextField("Tên mục tiêu (VD: Mua xe, Du lịch...)", text: $title)
                    TextField("Số tiền mục tiêu (VND)", text: $targetAmountText)
                        .keyboardType(.decimalPad)
                    TextField("Số tiền đã có sẵn (VND)", text: $currentAmountText)
                        .keyboardType(.decimalPad)
                    DatePicker("Ngày dự kiến hoàn thành", selection: $deadline, displayedComponents: .date)
                }
                
                Section("Biểu tượng & Màu sắc") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(icons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                                    .background(selectedIcon == icon ? Color(hex: selectedColorHex) : Color(.systemGray5), in: Circle())
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .onTapGesture { selectedIcon = icon }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    HStack(spacing: 16) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 2.5 : 0)
                                )
                                .onTapGesture { selectedColorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Tạo Mục tiêu mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        guard !title.isEmpty,
                              let target = Decimal(string: targetAmountText.FilteringDigits),
                              target > 0 else { return }
                        let current = Decimal(string: currentAmountText.FilteringDigits) ?? 0
                        let goal = SavingsGoal(
                            title: title,
                            targetAmount: target,
                            currentAmount: current,
                            deadline: deadline,
                            iconName: selectedIcon,
                            colorHex: selectedColorHex,
                            isCompleted: current >= target
                        )
                        modelContext.insert(goal)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct DepositSavingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var goal: SavingsGoal
    let accounts: [Account]
    
    @State private var amountText: String = ""
    @State private var selectedAccount: Account?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Mục tiêu tích lũy") {
                    LabeledContent("Tên mục tiêu", value: goal.title)
                    LabeledContent("Còn thiếu", value: goal.remainingAmount.formattedCurrency())
                }
                
                Section("Số tiền nạp tích lũy") {
                    TextField("Nhập số tiền (VND)", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title3.bold())
                }
                
                Section("Trích từ tài khoản") {
                    Picker("Tài khoản nguồn", selection: $selectedAccount) {
                        ForEach(accounts) { acc in
                            Text("\(acc.name) (\(acc.balance.formattedCurrency()))")
                                .tag(Optional(acc))
                        }
                    }
                }
            }
            .navigationTitle("Nạp tiền tích lũy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xác nhận") {
                        if let amount = Decimal(string: amountText.FilteringDigits), amount > 0 {
                            goal.deposit(amount: amount, from: selectedAccount, context: modelContext)
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedAccount = accounts.first
            }
        }
        .presentationDetents([.medium])
    }
}
