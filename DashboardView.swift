import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    @Binding var showingAddSheet: Bool
    @State private var selectedWallet: Account? = nil // nil = Tất cả ví khả dụng
    @State private var searchText: String = ""
    @State private var selectedFilter: TransactionType? = nil
    @State private var transactionToEdit: Transaction? = nil
    @State private var showingAdjustBalance: Bool = false
    @State private var actualBalanceInput: String = ""
    
    // Tổng số dư khả dụng (không tính các ví đánh dấu excludeFromTotal)
    private var totalSpendableBalance: Decimal {
        if let selectedWallet {
            return selectedWallet.balance
        }
        return accounts
            .filter { !$0.excludeFromTotal }
            .reduce(Decimal.zero) { $0 + $1.balance }
    }
    
    // Lọc giao dịch theo Ví đang chọn và Tháng hiện tại
    private var walletTransactions: [Transaction] {
        guard let selectedWallet else { return transactions }
        return transactions.filter {
            $0.sourceAccount?.id == selectedWallet.id || $0.destinationAccount?.id == selectedWallet.id
        }
    }
    
    private var currentMonthTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date.now
        return walletTransactions.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
    }
    
    private var monthlyIncome: Decimal {
        currentMonthTransactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    private var monthlyExpense: Decimal {
        currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    private var filteredTransactions: [Transaction] {
        walletTransactions.filter { tx in
            let matchesType = selectedFilter == nil || tx.type == selectedFilter
            let matchesSearch = searchText.isEmpty ||
                tx.note.localizedCaseInsensitiveContains(searchText) ||
                tx.withPerson.localizedCaseInsensitiveContains(searchText) ||
                tx.locationName.localizedCaseInsensitiveContains(searchText) ||
                (tx.category?.name.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (tx.sourceAccount?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesType && matchesSearch
        }
    }
    
    // Gom nhóm giao dịch theo Ngày (Chuẩn Money Lover)
    private var groupedByDay: [(Date, [Transaction])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { tx in
            cal.startOfDay(for: tx.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // 1. Thanh chọn Ví & Thẻ Tổng quan Dòng tiền
                    Section {
                        summaryCard
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    
                    // 2. Thanh lọc nhanh theo loại giao dịch & Điều chỉnh số dư
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                FilterChip(title: "Tất cả", isSelected: selectedFilter == nil) {
                                    selectedFilter = nil
                                }
                                ForEach(TransactionType.allCases) { type in
                                    FilterChip(title: type.title, isSelected: selectedFilter == type) {
                                        selectedFilter = type
                                    }
                                }
                                Button {
                                    let target = selectedWallet ?? accounts.first
                                    actualBalanceInput = "\(target?.balance ?? 0)"
                                    showingAdjustBalance = true
                                } label: {
                                    Label("Điều chỉnh số dư", systemImage: "slider.horizontal.3")
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.orange.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    }
                    
                    // 3. Sổ giao dịch gom nhóm theo từng Ngày
                    if groupedByDay.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "Chưa có giao dịch",
                                systemImage: "tray",
                                description: Text("Nhấn nút (+) ở góc dưới để ghi chép khoản thu chi đầu tiên.")
                            )
                        }
                    } else {
                        ForEach(groupedByDay, id: \.0) { dayDate, dayTxList in
                            Section {
                                ForEach(dayTxList) { tx in
                                    Button {
                                        transactionToEdit = tx
                                    } label: {
                                        TransactionRowView(transaction: tx)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete { offsets in
                                    for index in offsets {
                                        let tx = dayTxList[index]
                                        tx.revertBalanceEffect()
                                        modelContext.delete(tx)
                                    }
                                    try? modelContext.save()
                                }
                            } header: {
                                HStack {
                                    Text(dayDate, format: .dateTime.day().month().weekday(.wide))
                                        .font(.caption.weight(.bold))
                                    Spacer()
                                    let dayNet = dayTxList.reduce(Decimal.zero) { acc, t in
                                        if t.type == .income { return acc + t.amount }
                                        if t.type == .expense { return acc - t.amount }
                                        return acc
                                    }
                                    Text((dayNet >= 0 ? "+" : "") + dayNet.formattedCurrency())
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(dayNet >= 0 ? .green : .secondary)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Tìm ghi chú, danh mục, người, địa điểm...")
                
                // Nút Floating Action Button (FAB)
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Color.green.gradient, in: Circle())
                        .shadow(color: .green.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .accessibilityLabel("Thêm giao dịch mới")
            }
            .navigationTitle("Sổ giao dịch")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            selectedWallet = nil
                        } label: {
                            Label("Tất cả ví khả dụng", systemImage: selectedWallet == nil ? "checkmark" : "wallet.pass")
                        }
                        Divider()
                        ForEach(accounts) { acc in
                            Button {
                                selectedWallet = acc
                            } label: {
                                Label("\(acc.name) (\(acc.balance.formattedCurrency()))", systemImage: selectedWallet?.id == acc.id ? "checkmark" : acc.iconName)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedWallet?.iconName ?? "wallet.pass.fill")
                            Text(selectedWallet?.name ?? "Tất cả ví")
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .sheet(item: $transactionToEdit) { tx in
                EditTransactionView(transaction: tx)
            }
            .alert("Điều chỉnh số dư thực tế", isPresented: $showingAdjustBalance) {
                TextField("Số dư thực tế trong ví (VND)", text: $actualBalanceInput)
                    .keyboardType(.decimalPad)
                Button("Hủy", role: .cancel) {}
                Button("Cân bằng") {
                    adjustWalletBalance()
                }
            } message: {
                let target = selectedWallet ?? accounts.first
                Text("Nhập số tiền thực tế đang có trong ví '\(target?.name ?? "Ví")'. Ứng dụng sẽ tự tạo giao dịch bù trừ khoản chênh lệch.")
            }
        }
    }
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedWallet == nil ? "SỐ DƯ KHẢ DỤNG (CÁC VÍ)" : "SỐ DƯ VÍ: \(selectedWallet!.name.uppercased())")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(totalSpendableBalance.formattedCurrency())
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            Divider()
                .overlay(.white.opacity(0.25))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Tiền vào tháng này", systemImage: "arrow.down.left.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(monthlyIncome.formattedCurrency())
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.95), in: Capsule())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Label("Tiền ra tháng này", systemImage: "arrow.up.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(monthlyExpense.formattedCurrency())
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.95), in: Capsule())
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "#11998E"), Color(hex: "#1E3C72")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }
    
    private func adjustWalletBalance() {
        guard let target = selectedWallet ?? accounts.first,
              let actual = Decimal(string: actualBalanceInput.FilteringDigits) else { return }
        let diff = actual - target.balance
        guard diff != 0 else { return }
        
        let tx = Transaction(
            amount: abs(diff),
            type: diff > 0 ? .income : .expense,
            date: .now,
            note: "Điều chỉnh cân bằng số dư thực tế",
            sourceAccount: target
        )
        tx.applyBalanceEffect()
        modelContext.insert(tx)
        try? modelContext.save()
    }
}

// MARK: - Subcomponents

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.green : Color(.secondarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(titleText)
                        .font(.subheadline.weight(.semibold))
                    if let event = transaction.event {
                        Text(event.name)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(accountSubtitle)
                    if !transaction.note.isEmpty {
                        Text("• \(transaction.note)")
                            .lineLimit(1)
                    }
                    if !transaction.withPerson.isEmpty {
                        Text("• 👤 \(transaction.withPerson)")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(amountPrefix + transaction.amount.formattedCurrency())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(transaction.type.tintColor)
                
                if !transaction.locationName.isEmpty {
                    Text("📍 \(transaction.locationName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private var iconName: String {
        if transaction.type == .transfer { return "arrow.left.arrow.right" }
        return transaction.category?.iconName ?? "questionmark.circle"
    }
    
    private var iconColor: Color {
        if transaction.type == .transfer { return .blue }
        if let hex = transaction.category?.colorHex { return Color(hex: hex) }
        return transaction.type.tintColor
    }
    
    private var titleText: String {
        if transaction.type == .transfer { return "Chuyển khoản nội bộ" }
        return transaction.category?.name ?? "Chưa phân loại"
    }
    
    private var accountSubtitle: String {
        if transaction.type == .transfer {
            let src = transaction.sourceAccount?.name ?? "Ví nguồn"
            let dst = transaction.destinationAccount?.name ?? "Ví đích"
            return "\(src) → \(dst)"
        }
        return transaction.sourceAccount?.name ?? "Tài khoản"
    }
    
    private var amountPrefix: String {
        switch transaction.type {
        case .income: return "+"
        case .expense: return "-"
        case .transfer: return ""
        }
    }
}
