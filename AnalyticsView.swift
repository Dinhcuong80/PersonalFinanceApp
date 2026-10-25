import SwiftUI
import SwiftData
import Charts

struct CategoryExpenseStat: Identifiable {
    let id = UUID()
    let categoryName: String
    let colorHex: String
    let amount: Double
}

struct MonthlyCashFlowStat: Identifiable {
    let id = UUID()
    let monthLabel: String
    let type: String
    let amount: Double
}

struct AnalyticsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    private var currentMonthTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date.now
        return transactions.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
    }
    
    private var monthlyIncome: Decimal {
        currentMonthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    private var monthlyExpense: Decimal {
        currentMonthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    private var netCashFlow: Decimal {
        monthlyIncome - monthlyExpense
    }
    
    private var savingRate: Double {
        guard monthlyIncome > 0 else { return 0 }
        let saved = max(Decimal.zero, monthlyIncome - monthlyExpense)
        return (saved.doubleValue / monthlyIncome.doubleValue) * 100
    }
    
    // Dữ liệu biểu đồ Donut phân bổ chi tiêu theo Danh mục
    private var categoryBreakdown: [CategoryExpenseStat] {
        let expenses = currentMonthTransactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Khác" }
        
        return grouped.map { key, list in
            let sum = list.reduce(Decimal.zero) { $0 + $1.amount }.doubleValue
            let colorHex = list.first?.category?.colorHex ?? "#8E8E93"
            return CategoryExpenseStat(categoryName: key, colorHex: colorHex, amount: sum)
        }
        .sorted { $0.amount > $1.amount }
    }
    
    // Dữ liệu xu hướng Thu - Chi 6 tháng gần nhất
    private var sixMonthTrend: [MonthlyCashFlowStat] {
        var result: [MonthlyCashFlowStat] = []
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        
        for offset in (0..<6).reversed() {
            guard let targetDate = cal.date(byAdding: .month, value: -offset, to: .now) else { continue }
            let label = formatter.string(from: targetDate)
            
            let monthTx = transactions.filter { cal.isDate($0.date, equalTo: targetDate, toGranularity: .month) }
            let inc = monthTx.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }.doubleValue
            let exp = monthTx.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }.doubleValue
            
            result.append(MonthlyCashFlowStat(monthLabel: label, type: "Thu nhập", amount: inc))
            result.append(MonthlyCashFlowStat(monthLabel: label, type: "Chi tiêu", amount: exp))
        }
        return result
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Thẻ chỉ số Dòng tiền thuần & Tỷ lệ tiết kiệm
                    HStack(spacing: 14) {
                        MetricBox(
                            title: "Dòng tiền thuần",
                            value: netCashFlow.formattedCurrency(),
                            subtitle: "Thu - Chi tháng này",
                            tint: netCashFlow >= 0 ? .green : .red
                        )
                        
                        MetricBox(
                            title: "Tỷ lệ tiết kiệm",
                            value: String(format: "%.1f%%", savingRate),
                            subtitle: savingRate >= 20 ? "Đạt mục tiêu tốt" : "Nên đạt ≥ 20%",
                            tint: savingRate >= 20 ? .blue : .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // 2. Biểu đồ Donut (SectorMark) phân bổ chi tiêu
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Cơ cấu chi tiêu tháng này")
                            .font(.headline)
                        
                        if categoryBreakdown.isEmpty {
                            Text("Chưa có dữ liệu chi tiêu trong tháng này.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            Chart(categoryBreakdown) { item in
                                SectorMark(
                                    angle: .value("Số tiền", item.amount),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 2.0
                                )
                                .cornerRadius(5)
                                .foregroundStyle(by: .value("Danh mục", item.categoryName))
                            }
                            .frame(height: 240)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // 3. Biểu đồ Cột (BarMark) xu hướng Thu - Chi 6 tháng
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Xu hướng Thu - Chi (6 tháng)")
                            .font(.headline)
                        
                        Chart(sixMonthTrend) { stat in
                            BarMark(
                                x: .value("Tháng", stat.monthLabel),
                                y: .value("Số tiền", stat.amount)
                            )
                            .foregroundStyle(by: .value("Loại", stat.type))
                            .position(by: .value("Loại", stat.type))
                            .cornerRadius(4)
                        }
                        .chartForegroundStyleScale([
                            "Thu nhập": Color.green,
                            "Chi tiêu": Color.red
                        ])
                        .frame(height: 240)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Phân tích & Báo cáo")
        }
    }
}

struct MetricBox: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(tint)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
