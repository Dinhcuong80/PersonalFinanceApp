import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var transaction: Transaction
    
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var selectedType: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var selectedDate: Date = .now
    @State private var note: String = ""
    @State private var recurring: RecurringInterval = .none
    
    @State private var selectedCategory: Category?
    @State private var selectedSourceAccount: Account?
    @State private var selectedDestinationAccount: Account?
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
                        if selectedCategory?.isIncomeCategory != (selectedType == .income) {
                            selectedCategory = filteredCategories.first
                        }
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
                
                Section("Ghi chú") {
                    TextField("Nhập ghi chú...", text: $note)
                }
                
                if let validationError {
                    Section {
                        Text(validationError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Chỉnh sửa giao dịch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cập nhật") { updateTransaction() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedType = transaction.type
                amountText = "\(transaction.amount)"
                selectedDate = transaction.date
                note = transaction.note
                recurring = transaction.recurring
                selectedCategory = transaction.category
                selectedSourceAccount = transaction.sourceAccount
                selectedDestinationAccount = transaction.destinationAccount
            }
        }
    }
    
    private func updateTransaction() {
        let cleaned = amountText.FilteringDigits
        guard let newAmount = Decimal(string: cleaned), newAmount > 0 else {
            validationError = "Vui lòng nhập số tiền hợp lệ lớn hơn 0."
            return
        }
        
        guard let newSource = selectedSourceAccount else {
            validationError = "Vui lòng chọn tài khoản thanh toán."
            return
        }
        
        if selectedType == .transfer {
            guard let newDest = selectedDestinationAccount, newDest.id != newSource.id else {
                validationError = "Tài khoản nhận phải khác tài khoản nguồn."
                return
            }
        }
        
        // Bước 1: Hoàn tác số dư cũ trên các tài khoản cũ
        transaction.revertBalanceEffect()
        
        // Bước 2: Gán thông tin mới
        transaction.amount = newAmount
        transaction.type = selectedType
        transaction.date = selectedDate
        transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.recurring = recurring
        transaction.category = (selectedType == .transfer) ? nil : selectedCategory
        transaction.sourceAccount = newSource
        transaction.destinationAccount = (selectedType == .transfer) ? selectedDestinationAccount : nil
        
        // Bước 3: Áp dụng số dư mới
        transaction.applyBalanceEffect()
        try? modelContext.save()
        
        dismiss()
    }
}
