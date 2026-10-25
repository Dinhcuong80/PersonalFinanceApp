import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(filter: #Predicate<Category> { !$0.isIncomeCategory }) private var expenseCategories: [Category]
    
    @State private var showingAddBudget = false
    @State private var selectedCategory: Category?
    @State private var limitAmountText = ""
    
    private var currentMonth: Int { Calendar.current.component(.month, from: .now) }
    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    
    private var currentMonthBudgets: [Budget] {
        budgets.filter { $0.month == currentMonth && $0.year == currentYear }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(currentMonthBudgets) { budget in
                        let spent = spentAmount(for: budget)
                        BudgetCardRow(budget: budget, spent: spent)
                    }
                    .onDelete(perform: deleteBudgets)
                    
                    if currentMonthBudgets.isEmpty {
                        ContentUnavailableView(
                            "Chưa có hạn mức chi tiêu",
                            systemImage: "chart.pie",
                            description: Text("Thiết lập ngân sách cho từng danh mục để kiểm soát chi tiêu tháng \(currentMonth)/\(currentYear).")
                        )
                    }
                } header: {
                    Text("Ngân sách Tháng \(currentMonth)/\(currentYear)")
                } footer: {
                    Text("Màu xanh: An toàn (<80%) • Màu cam: Sắp chạm trần (80-99%) • Màu đỏ: Đã vượt hạn mức (≥100%).")
                }
            }
            .navigationTitle("Ngân sách")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        selectedCategory = expenseCategories.first
                        showingAddBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBudget) {
                NavigationStack {
                    Form {
                        Picker("Danh mục chi tiêu", selection: $selectedCategory) {
                            Text("Tổng toàn bộ chi tiêu tháng").tag(Optional<Category>.none)
                            ForEach(expenseCategories) { category in
                                Label(category.name, systemImage: category.iconName)
                                    .tag(Optional(category))
                            }
                        }
                        
                        TextField("Hạn mức tối đa (VND)", text: $limitAmountText)
                            .keyboardType(.decimalPad)
                    }
                    .navigationTitle("Tạo hạn mức")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Hủy") { showingAddBudget = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Lưu") {
                                if let limit = Decimal(string: limitAmountText.FilteringDigits), limit > 0 {
                                    let budget = Budget(
                                        month: currentMonth,
                                        year: currentYear,
                                        limitAmount: limit,
                                        category: selectedCategory
                                    )
                                    modelContext.insert(budget)
                                    try? modelContext.save()
                                    limitAmountText = ""
                                    showingAddBudget = false
                                }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private func spentAmount(for budget: Budget) -> Decimal {
        let cal = Calendar.current
        return transactions
            .filter { tx in
                guard tx.type == .expense else { return false }
                let m = cal.component(.month, from: tx.date)
                let y = cal.component(.year, from: tx.date)
                guard m == budget.month && y == budget.year else { return false }
                if let budgetCat = budget.category {
                    return tx.category?.id == budgetCat.id
                }
                return true
            }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    private func deleteBudgets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(currentMonthBudgets[index])
        }
        try? modelContext.save()
    }
}

struct BudgetCardRow: View {
    let budget: Budget
    let spent: Decimal
    
    private var ratio: Double {
        guard budget.limitAmount > 0 else { return 0 }
        return spent.doubleValue / budget.limitAmount.doubleValue
    }
    
    private var statusColor: Color {
        if ratio >= 1.0 { return .red }
        if ratio >= 0.8 { return .orange }
        return .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: budget.category?.iconName ?? "sum")
                    .foregroundStyle(statusColor)
                Text(budget.category?.name ?? "Ngân sách tổng tháng")
                    .font(.headline)
                Spacer()
                Text("\(Int(ratio * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(statusColor)
            }
            
            ProgressView(value: min(ratio, 1.0))
                .tint(statusColor)
            
            HStack {
                Text("Đã chi: \(spent.formattedCurrency())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Hạn mức: \(budget.limitAmount.formattedCurrency())")
                    .font(.caption.weight(.medium))
            }
            
            if ratio >= 1.0 {
                Label("Cảnh báo: Bạn đã chi vượt hạn mức!", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
            } else if ratio >= 0.8 {
                Label("Lưu ý: Đã sử dụng trên 80% ngân sách.", systemImage: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
    }
}
