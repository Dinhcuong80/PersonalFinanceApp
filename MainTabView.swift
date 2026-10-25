import SwiftUI
import SwiftData

struct MainTabView: View {
    @Bindable var securityService: SecurityService
    @State private var selectedTab: Int = 0
    @State private var showingAddTransaction: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(showingAddSheet: $showingAddTransaction)
                    .tabItem {
                        Label("Sổ thu chi", systemImage: "book.pages.fill")
                    }
                    .tag(0)
                
                BudgetView()
                    .tabItem {
                        Label("Ngân sách", systemImage: "chart.pie.fill")
                    }
                    .tag(1)
                
                DebtLoanView()
                    .tabItem {
                        Label("Sổ nợ", systemImage: "arrow.left.arrow.right.square.fill")
                    }
                    .tag(2)
                
                EventsAndBillsView()
                    .tabItem {
                        Label("Tiện ích Pro", systemImage: "sparkles.rectangle.stack.fill")
                    }
                    .tag(3)
                
                SettingsAndAccountsView(securityService: securityService)
                    .tabItem {
                        Label("Ví & Báo cáo", systemImage: "creditcard.fill")
                    }
                    .tag(4)
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView()
        }
    }
}

// MARK: - Settings, Wallets & Analytics Hub

struct SettingsAndAccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Bindable var securityService: SecurityService
    @Bindable var storeManager = StoreManager.shared
    
    @State private var showingAddAccount = false
    @State private var showingPaywall = false
    @State private var newAccountName = ""
    @State private var newAccountType: AccountType = .bank
    @State private var newAccountBalance: String = ""
    @State private var excludeFromTotal: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                // Thẻ Thương mại hóa FinSmart Pro VIP
                Section {
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.25), in: Circle())
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(storeManager.isProUnlocked ? "FinSmart Pro VIP (Đã kích hoạt)" : "Nâng cấp FinSmart Pro VIP")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                Text(storeManager.isProUnlocked
                                     ? "Bạn đang sử dụng trọn bộ tính năng cao cấp không giới hạn."
                                     : "Mở khóa không giới hạn Ví, Quét HĐ AI, Chia tiền nhóm & Sao lưu")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#1E3C72"), Color(hex: "#2A5298")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                Section("Báo cáo & Tích lũy") {
                    NavigationLink {
                        AnalyticsView()
                    } label: {
                        Label("Biểu đồ Phân tích Tài chính (Swift Charts)", systemImage: "chart.xyaxis.line")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    
                    NavigationLink {
                        SavingsGoalView()
                    } label: {
                        Label("Mục tiêu Tiết kiệm (Savings Goals)", systemImage: "star.circle.fill")
                    }
                    
                    NavigationLink {
                        CategoryManagementView()
                    } label: {
                        Label("Quản lý Danh mục Thu / Chi", systemImage: "square.grid.2x2.fill")
                    }
                }
                
                Section {
                    ForEach(accounts) { account in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Image(systemName: account.iconName)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color(hex: account.colorHex), in: RoundedRectangle(cornerRadius: 10))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                        .font(.headline)
                                    Text(account.excludeFromTotal ? "🔒 Đang ẩn khỏi tổng khả dụng" : "✓ Tính vào tổng khả dụng")
                                        .font(.caption2)
                                        .foregroundStyle(account.excludeFromTotal ? .orange : .secondary)
                                }
                                
                                Spacer()
                                
                                Text(account.balance.formattedCurrency(code: account.currencyCode))
                                    .font(.subheadline.weight(.semibold))
                            }
                            
                            Toggle("Không tính vào tổng số dư khả dụng", isOn: Binding(
                                get: { account.excludeFromTotal },
                                set: { newVal in
                                    account.excludeFromTotal = newVal
                                    try? modelContext.save()
                                }
                            ))
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button {
                        if storeManager.canAddMoreWallets(currentCount: accounts.count) {
                            showingAddAccount = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("Thêm tài khoản / ví mới", systemImage: "plus.circle.fill")
                            Spacer()
                            if !storeManager.isProUnlocked && accounts.count >= StoreManager.freeMaxWallets {
                                Text("PRO")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                } header: {
                    Text("Danh sách Ví & Tài khoản")
                } footer: {
                    Text("Bật 'Không tính vào tổng' đối với các sổ tiết kiệm dài hạn hoặc quỹ giữ hộ để không làm lệch số tiền được phép chi tiêu hàng ngày.")
                }
                
                Section("Bảo mật, Sao lưu & Đánh giá") {
                    Toggle(isOn: $securityService.isBiometricEnabled) {
                        Label("Khóa bằng Face ID / Passcode", systemImage: "faceid")
                    }
                    
                    if let csvURL = CSVExporter.generateCSV(from: transactions) {
                        ShareLink(item: csvURL) {
                            Label("Xuất toàn bộ giao dịch (CSV)", systemImage: "square.and.arrow.up")
                        }
                    }
                    
                    Button {
                        requestReview()
                    } label: {
                        Label("Đánh giá 5 sao trên App Store", systemImage: "star.bubble.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Ví & Báo cáo")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert("Thêm Tài khoản mới", isPresented: $showingAddAccount) {
                TextField("Tên tài khoản (VD: Techcombank, MoMo)", text: $newAccountName)
                TextField("Số dư ban đầu (VND)", text: $newAccountBalance)
                    .keyboardType(.decimalPad)
                Button("Hủy", role: .cancel) {
                    newAccountName = ""
                    newAccountBalance = ""
                }
                Button("Lưu") {
                    let initialBalance = Decimal(string: newAccountBalance.FilteringDigits) ?? 0
                    let account = Account(
                        name: newAccountName.isEmpty ? "Ví mới" : newAccountName,
                        type: newAccountType,
                        balance: initialBalance,
                        excludeFromTotal: excludeFromTotal
                    )
                    modelContext.insert(account)
                    try? modelContext.save()
                    newAccountName = ""
                    newAccountBalance = ""
                }
            }
        }
    }
}

extension String {
    var FilteringDigits: String {
        self.filter { "0123456789.".contains($0) }
    }
}
