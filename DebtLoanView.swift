import SwiftUI
import SwiftData

struct DebtLoanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DebtLoan.dueDate, order: .forward) private var debtLoans: [DebtLoan]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    
    @State private var selectedFilter: DebtFilter = .active
    @State private var showingAddDebt = false
    @State private var selectedDebtForPayment: DebtLoan?
    
    enum DebtFilter: String, CaseIterable, Identifiable {
        case active = "Đang theo dõi"
        case lent = "Cho vay"
        case borrowed = "Đi vay"
        case settled = "Đã tất toán"
        
        var id: String { rawValue }
    }
    
    // Tổng phải thu (Mình cho vay còn lại)
    private var totalReceivable: Decimal {
        debtLoans
            .filter { $0.type == .lent && !$0.isSettled }
            .reduce(Decimal.zero) { $0 + $1.remainingAmount }
    }
    
    // Tổng phải trả (Mình đi vay còn lại)
    private var totalPayable: Decimal {
        debtLoans
            .filter { $0.type == .borrowed && !$0.isSettled }
            .reduce(Decimal.zero) { $0 + $1.remainingAmount }
    }
    
    private var filteredDebts: [DebtLoan] {
        switch selectedFilter {
        case .active:
            return debtLoans.filter { !$0.isSettled }
        case .lent:
            return debtLoans.filter { $0.type == .lent && !$0.isSettled }
        case .borrowed:
            return debtLoans.filter { $0.type == .borrowed && !$0.isSettled }
        case .settled:
            return debtLoans.filter { $0.isSettled }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 1. Thẻ tổng hợp Công nợ (Phải thu vs Phải trả)
                Section {
                    debtSummaryHeader
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                
                // 2. Bộ lọc trạng thái
                Section {
                    Picker("Bộ lọc", selection: $selectedFilter) {
                        ForEach(DebtFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                
                // 3. Danh sách các khoản Vay / Cho vay
                Section("Danh sách sổ nợ (\(filteredDebts.count))") {
                    if filteredDebts.isEmpty {
                        ContentUnavailableView(
                            "Không có khoản vay/nợ nào",
                            systemImage: "checkmark.shield",
                            description: Text("Nhấn nút (+) ở góc trên để thêm khoản Đi vay hoặc Cho vay mới.")
                        )
                    } else {
                        ForEach(filteredDebts) { item in
                            DebtLoanRow(debt: item) {
                                selectedDebtForPayment = item
                            }
                        }
                        .onDelete(perform: deleteDebts)
                    }
                }
            }
            .navigationTitle("Sổ Nợ & Vay")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddDebt = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDebt) {
                AddDebtLoanSheet(accounts: accounts)
            }
            .sheet(item: $selectedDebtForPayment) { debt in
                RecordDebtPaymentSheet(debt: debt, accounts: accounts)
            }
        }
    }
    
    private var debtSummaryHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Cần thu về (Cho vay)", systemImage: "arrow.up.forward.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.teal)
                Text(totalReceivable.formattedCurrency())
                    .font(.headline.bold())
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            
            VStack(alignment: .leading, spacing: 6) {
                Label("Phải trả (Đi vay)", systemImage: "arrow.down.backward.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                Text(totalPayable.formattedCurrency())
                    .font(.headline.bold())
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }
    
    private func deleteDebts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredDebts[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Dòng hiển thị từng khoản Vay / Nợ

struct DebtLoanRow: View {
    let debt: DebtLoan
    let onRecordPayment: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: debt.type.icon)
                    .font(.title3)
                    .foregroundStyle(debt.type.tintColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(debt.personName)
                            .font(.headline)
                        Text(debt.type.shortTitle)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(debt.type.tintColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(debt.type.tintColor)
                    }
                    if !debt.note.isEmpty {
                        Text(debt.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(debt.remainingAmount.formattedCurrency())
                        .font(.subheadline.bold())
                        .foregroundStyle(debt.isSettled ? .secondary : debt.type.tintColor)
                    Text("Gốc: \(debt.totalAmount.formattedCurrency())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            ProgressView(value: debt.progress)
                .tint(debt.isSettled ? .green : debt.type.tintColor)
            
            HStack {
                if debt.isSettled {
                    Label("Đã tất toán hoàn tất", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if debt.isOverdue {
                    Label("Quá hạn trả (\(debt.dueDate.formatted(date: .numeric, time: .omitted)))", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                } else {
                    Label("Hạn: \(debt.dueDate.formatted(date: .numeric, time: .omitted))", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if debt.interestRate > 0 {
                    Text("Lãi: \(String(format: "%.1f", debt.interestRate))%/năm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if !debt.isSettled {
                    Button(action: onRecordPayment) {
                        Text(debt.type == .lent ? "Thu nợ" : "Trả nợ")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(debt.type.tintColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Sheet Thêm Khoản Vay / Cho Vay Mới

struct AddDebtLoanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let accounts: [Account]
    
    @State private var personName: String = ""
    @State private var selectedType: DebtType = .borrowed
    @State private var totalAmountText: String = ""
    @State private var interestRateText: String = "0"
    @State private var startDate: Date = .now
    @State private var dueDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var note: String = ""
    
    @State private var syncWithAccount: Bool = true
    @State private var selectedAccount: Account?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Loại giao dịch nợ", selection: $selectedType) {
                        ForEach(DebtType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Thông tin đối tác & Số tiền") {
                    TextField(selectedType == .lent ? "Tên người vay" : "Tên chủ nợ / Ngân hàng", text: $personName)
                    
                    TextField("Số tiền gốc (VND)", text: $totalAmountText)
                        .keyboardType(.decimalPad)
                        .font(.headline)
                        .foregroundStyle(selectedType.tintColor)
                    
                    HStack {
                        Text("Lãi suất (%/năm)")
                        Spacer()
                        TextField("0", text: $interestRateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Section("Thời hạn & Ghi chú") {
                    DatePicker("Ngày bắt đầu", selection: $startDate, displayedComponents: .date)
                    DatePicker("Hạn thanh toán", selection: $dueDate, displayedComponents: .date)
                    TextField("Ghi chú thêm...", text: $note)
                }
                
                Section {
                    Toggle("Cập nhật số dư Ví ngay", isOn: $syncWithAccount)
                    if syncWithAccount {
                        Picker(selectedType == .lent ? "Trích từ Ví" : "Nhận tiền vào Ví", selection: $selectedAccount) {
                            ForEach(accounts) { acc in
                                Text("\(acc.name) (\(acc.balance.formattedCurrency()))")
                                    .tag(Optional(acc))
                            }
                        }
                    }
                } footer: {
                    Text(selectedType == .lent
                         ? "Nếu bật, số tiền cho vay sẽ được trừ trực tiếp khỏi ví đã chọn."
                         : "Nếu bật, số tiền đi vay sẽ được cộng vào ví đã chọn.")
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Thêm khoản Vay / Nợ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { saveDebt() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedAccount = accounts.first
            }
        }
    }
    
    private func saveDebt() {
        let trimmedName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Vui lòng nhập tên người vay hoặc chủ nợ."
            return
        }
        guard let amount = Decimal(string: totalAmountText.FilteringDigits), amount > 0 else {
            errorMessage = "Vui lòng nhập số tiền hợp lệ lớn hơn 0."
            return
        }
        let rate = Double(interestRateText.FilteringDigits) ?? 0
        
        let debt = DebtLoan(
            personName: trimmedName,
            type: selectedType,
            totalAmount: amount,
            paidAmount: 0,
            interestRate: rate,
            startDate: startDate,
            dueDate: dueDate,
            note: note
        )
        modelContext.insert(debt)
        
        if syncWithAccount, let account = selectedAccount {
            // Cho vay -> Tiền ra khỏi ví (.expense)
            // Đi vay -> Tiền vào ví (.income)
            let txType: TransactionType = (selectedType == .lent) ? .expense : .income
            let txNote = (selectedType == .lent) ? "Cho \(trimmedName) vay" : "Vay tiền từ \(trimmedName)"
            let tx = Transaction(
                amount: amount,
                type: txType,
                date: startDate,
                note: txNote,
                sourceAccount: account
            )
            tx.applyBalanceEffect()
            modelContext.insert(tx)
        }
        
        try? modelContext.save()
        Task {
            _ = await NotificationService.shared.requestAuthorization()
            NotificationService.shared.scheduleDebtReminder(for: debt)
        }
        dismiss()
    }
}

// MARK: - Sheet Ghi nhận Trả Nợ / Thu Nợ (Một phần hoặc Tất toán)

struct RecordDebtPaymentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var debt: DebtLoan
    let accounts: [Account]
    
    @State private var paymentAmountText: String = ""
    @State private var selectedAccount: Account?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin khoản nợ") {
                    LabeledContent("Đối tác", value: debt.personName)
                    LabeledContent("Loại", value: debt.type.title)
                    LabeledContent("Số tiền còn lại", value: debt.remainingAmount.formattedCurrency())
                        .fontWeight(.semibold)
                }
                
                Section("Số tiền thanh toán đợt này") {
                    TextField("Nhập số tiền (VND)", text: $paymentAmountText)
                        .keyboardType(.decimalPad)
                        .font(.title3.bold())
                    
                    Button("Điền 100% số tiền còn lại (Tất toán)") {
                        paymentAmountText = "\(debt.remainingAmount)"
                    }
                    .font(.subheadline)
                }
                
                Section("Tài khoản giao dịch") {
                    Picker(debt.type == .lent ? "Nhận tiền vào Ví" : "Trích tiền từ Ví", selection: $selectedAccount) {
                        ForEach(accounts) { account in
                            Text("\(account.name) (\(account.balance.formattedCurrency()))")
                                .tag(Optional(account))
                        }
                    }
                }
            }
            .navigationTitle(debt.type == .lent ? "Thu hồi nợ" : "Thanh toán nợ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xác nhận") {
                        if let amount = Decimal(string: paymentAmountText.FilteringDigits), amount > 0 {
                            debt.recordPayment(amount: amount, account: selectedAccount, context: modelContext)
                            if debt.isSettled {
                                NotificationService.shared.cancelDebtReminder(for: debt)
                            }
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                paymentAmountText = "\(debt.remainingAmount)"
                selectedAccount = accounts.first
            }
        }
        .presentationDetents([.medium, .large])
    }
}
