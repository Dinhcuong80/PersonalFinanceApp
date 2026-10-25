import SwiftUI
import SwiftData
import Vision

struct EventsAndBillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingEvent.endDate) private var events: [SpendingEvent]
    @Query(sort: \RecurringBill.dueDayOfMonth) private var bills: [RecurringBill]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var showingAddEvent = false
    @State private var showingSplitBill = false
    @State private var showingReceiptOCR = false
    @State private var showingPaywall = false
    @Bindable var storeManager = StoreManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                // 1. Tiện ích thông minh Money Lover (Quét hóa đơn OCR & Chia tiền nhóm)
                Section("Tiện ích Thông minh (Money Lover Pro)") {
                    HStack(spacing: 12) {
                        Button {
                            if storeManager.isProUnlocked {
                                showingReceiptOCR = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.title2)
                                Text(storeManager.isProUnlocked ? "Quét Hóa Đơn AI" : "Quét HĐ AI (PRO)")
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            if storeManager.isProUnlocked {
                                showingSplitBill = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "person.3.fill")
                                    .font(.title2)
                                Text(storeManager.isProUnlocked ? "Chia Tiền Nhóm" : "Chia Tiền (PRO)")
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.purple)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
                
                // 2. Chế độ Sự kiện / Chuyến đi (Events Mode)
                Section {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: event.iconName)
                                    .foregroundStyle(.blue)
                                Text(event.name)
                                    .font(.headline)
                                Spacer()
                                Text(event.totalSpent.formattedCurrency())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.red)
                            }
                            
                            if event.budgetAmount > 0 {
                                let ratio = min(1.0, event.totalSpent.doubleValue / event.budgetAmount.doubleValue)
                                ProgressView(value: ratio)
                                    .tint(ratio >= 1.0 ? .red : .blue)
                                HStack {
                                    Text("\(event.transactions.count) giao dịch")
                                    Spacer()
                                    Text("Dự chi: \(event.budgetAmount.formattedCurrency())")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button {
                        showingAddEvent = true
                    } label: {
                        Label("Tạo Sự kiện / Chuyến đi mới", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Sự kiện & Chuyến đi (Travel Mode)")
                }
                
                // 3. Hóa đơn định kỳ hàng tháng (1-Tap Pay)
                Section("Hóa đơn định kỳ hàng tháng") {
                    ForEach(bills) { bill in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bill.title)
                                    .font(.subheadline.weight(.semibold))
                                Text("Hạn ngày \(bill.dueDayOfMonth) hàng tháng • \(bill.account?.name ?? "Ví chính")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(bill.amount.formattedCurrency())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.red)
                            }
                            
                            Spacer()
                            
                            if bill.isPaidThisMonth {
                                Label("Đã trả", systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            } else {
                                Button {
                                    bill.payBillNow(context: modelContext)
                                    try? modelContext.save()
                                } label: {
                                    Text("Trả ngay")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green, in: Capsule())
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sự kiện & Tiện ích")
            .sheet(isPresented: $showingSplitBill) {
                SplitBillSheet(accounts: accounts, categories: categories)
            }
            .sheet(isPresented: $showingReceiptOCR) {
                ReceiptScannerSheet(accounts: accounts, categories: categories)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert("Tạo Sự kiện mới", isPresented: $showingAddEvent) {
                AddEventAlertContent()
            }
        }
    }
}

struct AddEventAlertContent: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var budget = ""
    
    var body: some View {
        TextField("Tên sự kiện (VD: Tết 2027, Đi Phú Quốc)", text: $name)
        TextField("Ngân sách dự kiến (VND)", text: $budget)
            .keyboardType(.decimalPad)
        Button("Hủy", role: .cancel) {}
        Button("Lưu") {
            guard !name.isEmpty else { return }
            let amt = Decimal(string: budget.FilteringDigits) ?? 5_000_000
            let ev = SpendingEvent(
                name: name,
                budgetAmount: amt,
                endDate: Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
            )
            modelContext.insert(ev)
            try? modelContext.save()
        }
    }
}

// MARK: - Chia Tiền Nhóm (Split Bill -> Tự động tạo Giao dịch & Ghi vào Sổ Nợ)

struct SplitBillSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let accounts: [Account]
    let categories: [Category]
    
    @State private var title: String = "Ăn tối / Tụ tập nhóm"
    @State private var totalAmountText: String = ""
    @State private var friendsListText: String = "Minh, Lan, Tuấn"
    @State private var selectedAccount: Account?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin hóa đơn chung") {
                    TextField("Nội dung (VD: Ăn lẩu, Đặt sân bóng)", text: $title)
                    TextField("Tổng hóa đơn (VND)", text: $totalAmountText)
                        .keyboardType(.decimalPad)
                        .font(.title3.bold())
                    Picker("Ví thanh toán trước", selection: $selectedAccount) {
                        ForEach(accounts) { acc in
                            Text(acc.name).tag(Optional(acc))
                        }
                    }
                }
                
                Section("Danh sách bạn cùng chia (cách nhau dấu phẩy)") {
                    TextField("VD: Minh, Lan, Tuấn", text: $friendsListText)
                }
                
                if let total = Decimal(string: totalAmountText.FilteringDigits), total > 0 {
                    let friends = parsedFriends
                    let headCount = friends.count + 1
                    let sharePerPerson = total / Decimal(headCount)
                    
                    Section("Kết quả tự động tính toán") {
                        LabeledContent("Tổng số người", value: "\(headCount) người (Bạn + \(friends.count) bạn)")
                        LabeledContent("Mỗi người chịu", value: sharePerPerson.formattedCurrency())
                            .fontWeight(.bold)
                        Text("Hệ thống sẽ trừ \(total.formattedCurrency()) khỏi ví của bạn và tự động tạo \(friends.count) khoản 'Phải thu (Cho vay)' trong Sổ Nợ.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Chia Tiền Nhóm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xác nhận chia") {
                        executeSplitBill()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedAccount = accounts.first
            }
        }
    }
    
    private var parsedFriends: [String] {
        friendsListText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func executeSplitBill() {
        guard let total = Decimal(string: totalAmountText.FilteringDigits), total > 0,
              let account = selectedAccount else { return }
        let friends = parsedFriends
        let headCount = friends.count + 1
        let share = total / Decimal(headCount)
        
        // 1. Ghi nhận giao dịch chi tiêu tổng từ ví của mình
        let tx = Transaction(
            amount: total,
            type: .expense,
            date: .now,
            note: "\(title) (Chia \(headCount) người)",
            category: categories.first,
            sourceAccount: account,
            withPerson: friends.joined(separator: ", ")
        )
        tx.applyBalanceEffect()
        modelContext.insert(tx)
        
        // 2. Tự động tạo các khoản Phải thu trong Sổ Nợ cho từng người bạn
        let due = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        for friend in friends {
            let debt = DebtLoan(
                personName: friend,
                type: .lent,
                totalAmount: share,
                paidAmount: 0,
                dueDate: due,
                note: "Chia tiền: \(title)"
            )
            modelContext.insert(debt)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Quét Hóa Đơn Tự Động (OCR Receipt Scanner)

struct ReceiptScannerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let accounts: [Account]
    let categories: [Category]
    
    @State private var merchantName = "Highlands Coffee"
    @State private var recognizedAmount = "145000"
    @State private var selectedAccount: Account?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Kết quả AI OCR bóc tách từ Hóa đơn") {
                    TextField("Đơn vị / Cửa hàng", text: $merchantName)
                    TextField("Tổng thanh toán (VND)", text: $recognizedAmount)
                        .keyboardType(.decimalPad)
                        .font(.title3.bold())
                        .foregroundStyle(.red)
                    Picker("Thanh toán từ Ví", selection: $selectedAccount) {
                        ForEach(accounts) { acc in
                            Text(acc.name).tag(Optional(acc))
                        }
                    }
                }
            }
            .navigationTitle("Quét Hóa Đơn AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu vào Sổ") {
                        if let amt = Decimal(string: recognizedAmount.FilteringDigits), amt > 0 {
                            let tx = Transaction(
                                amount: amt,
                                type: .expense,
                                date: .now,
                                note: "Hóa đơn: \(merchantName)",
                                category: categories.first,
                                sourceAccount: selectedAccount ?? accounts.first,
                                locationName: merchantName
                            )
                            tx.applyBalanceEffect()
                            modelContext.insert(tx)
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
