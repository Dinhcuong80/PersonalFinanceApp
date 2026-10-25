import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \SpendingEvent.endDate) private var events: [SpendingEvent]
    
    @State private var selectedType: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var selectedDate: Date = .now
    @State private var note: String = ""
    @State private var withPerson: String = ""
    @State private var locationName: String = ""
    @State private var recurring: RecurringInterval = .none
    
    @State private var selectedCategory: Category?
    @State private var selectedSourceAccount: Account?
    @State private var selectedDestinationAccount: Account?
    @State private var selectedEvent: SpendingEvent?
    @State private var validationError: String?
    
    private var filteredCategories: [Category] {
        switch selectedType {
        case .expense:
            return categories.filter { !$0.isIncomeCategory }
        case .income:
            return categories.filter { $0.isIncomeCategory }
        case .transfer:
            return []
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Loại giao dịch", selection: $selectedType) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedType) { _, _ in
                        selectedCategory = filteredCategories.first
                    }
                }
                
                Section("Số tiền (VND)") {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedType.tintColor)
                }
                
                Section("Chi tiết phân loại") {
                    Picker(selectedType == .transfer ? "Từ tài khoản" : "Tài khoản", selection: $selectedSourceAccount) {
                        ForEach(accounts) { account in
                            Text("\(account.name) (\(account.balance.formattedCurrency()))")
                                .tag(Optional(account))
                        }
                    }
                    
                    if selectedType == .transfer {
                        Picker("Đến tài khoản", selection: $selectedDestinationAccount) {
                            ForEach(accounts) { account in
                                Text("\(account.name) (\(account.balance.formattedCurrency()))")
                                    .tag(Optional(account))
                            }
                        }
                    } else {
                        Picker("Danh mục", selection: $selectedCategory) {
                            ForEach(filteredCategories) { category in
                                Label(category.name, systemImage: category.iconName)
                                    .tag(Optional(category))
                            }
                        }
                    }
                    
                    DatePicker("Thời gian", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    
                    Picker("Định kỳ", selection: $recurring) {
                        ForEach(RecurringInterval.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }
                
                Section("Mở rộng (Money Lover Pro)") {
                    Picker("Sự kiện / Chuyến đi", selection: $selectedEvent) {
                        Text("Không gắn sự kiện").tag(Optional<SpendingEvent>.none)
                        ForEach(events) { ev in
                            Text(ev.name).tag(Optional(ev))
                        }
                    }
                    TextField("👤 Với ai? (VD: Gia đình, Hội bạn)", text: $withPerson)
                    TextField("📍 Địa điểm / Cửa hàng", text: $locationName)
                    TextField("📝 Ghi chú giao dịch...", text: $note)
                }
                
                if let validationError {
                    Section {
                        Text(validationError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Thêm giao dịch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { saveTransaction() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if selectedSourceAccount == nil {
                    selectedSourceAccount = accounts.first
                }
                if selectedDestinationAccount == nil && accounts.count > 1 {
                    selectedDestinationAccount = accounts[1]
                }
                if selectedCategory == nil {
                    selectedCategory = filteredCategories.first
                }
            }
        }
    }
    
    private func saveTransaction() {
        let cleaned = amountText.FilteringDigits
        guard let amount = Decimal(string: cleaned), amount > 0 else {
            validationError = "Vui lòng nhập số tiền hợp lệ lớn hơn 0."
            return
        }
        
        guard let source = selectedSourceAccount else {
            validationError = "Vui lòng chọn tài khoản thanh toán."
            return
        }
        
        if selectedType == .transfer {
            guard let dest = selectedDestinationAccount, dest.id != source.id else {
                validationError = "Tài khoản nhận phải khác tài khoản nguồn."
                return
            }
        }
        
        let transaction = Transaction(
            amount: amount,
            type: selectedType,
            date: selectedDate,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            recurring: recurring,
            category: selectedType == .transfer ? nil : selectedCategory,
            sourceAccount: source,
            destinationAccount: selectedType == .transfer ? selectedDestinationAccount : nil,
            event: selectedEvent,
            withPerson: withPerson.trimmingCharacters(in: .whitespacesAndNewlines),
            locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        transaction.applyBalanceEffect()
        modelContext.insert(transaction)
        try? modelContext.save()
        
        dismiss()
    }
}
