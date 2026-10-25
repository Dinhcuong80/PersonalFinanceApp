import Foundation
import SwiftData

@MainActor
final class DataController {
    static let shared = DataController()
    let container: ModelContainer
    
    private init() {
        let schema = Schema([
            Account.self,
            Category.self,
            Transaction.self,
            Budget.self,
            DebtLoan.self,
            SavingsGoal.self,
            SpendingEvent.self,
            RecurringBill.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            seedInitialDataIfNeeded(context: container.mainContext)
        } catch {
            fatalError("Không thể khởi tạo SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }
    
    /// Khởi tạo danh mục và tài khoản mặc định trong lần mở ứng dụng đầu tiên
    private func seedInitialDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }
        
        // 1. Tạo các tài khoản mặc định
        let cashAccount = Account(name: "Tiền mặt", type: .cash, balance: 2_500_000, iconName: "banknote.fill", colorHex: "#34C759")
        let bankAccount = Account(name: "Thẻ Ngân hàng", type: .bank, balance: 15_000_000, iconName: "building.columns.fill", colorHex: "#007AFF")
        let savingsAccount = Account(name: "Quỹ Tiết kiệm", type: .savings, balance: 30_000_000, iconName: "chart.line.uptrend.xyaxis", colorHex: "#AF52DE")
        
        context.insert(cashAccount)
        context.insert(bankAccount)
        context.insert(savingsAccount)
        
        // 2. Tạo danh mục Chi tiêu
        let foodCat = Category(name: "Ăn uống", iconName: "fork.knife", colorHex: "#FF9500", isIncomeCategory: false)
        let transportCat = Category(name: "Di chuyển", iconName: "car.fill", colorHex: "#5856D6", isIncomeCategory: false)
        let billsCat = Category(name: "Hóa đơn & Tiện ích", iconName: "bolt.fill", colorHex: "#FF3B30", isIncomeCategory: false)
        let shoppingCat = Category(name: "Mua sắm", iconName: "bag.fill", colorHex: "#FF2D55", isIncomeCategory: false)
        let healthCat = Category(name: "Sức khỏe", iconName: "cross.case.fill", colorHex: "#30B0C7", isIncomeCategory: false)
        
        // 3. Tạo danh mục Thu nhập
        let salaryCat = Category(name: "Tiền lương", iconName: "briefcase.fill", colorHex: "#34C759", isIncomeCategory: true)
        let investCat = Category(name: "Lợi nhuận đầu tư", iconName: "chart.bar.fill", colorHex: "#00C7BE", isIncomeCategory: true)
        
        [foodCat, transportCat, billsCat, shoppingCat, healthCat, salaryCat, investCat].forEach {
            context.insert($0)
        }
        
        // 4. Tạo Ngân sách mẫu cho tháng hiện tại
        let now = Date.now
        let cal = Calendar.current
        let month = cal.component(.month, from: now)
        let year = cal.component(.year, from: now)
        
        let foodBudget = Budget(month: month, year: year, limitAmount: 4_000_000, category: foodCat)
        let shoppingBudget = Budget(month: month, year: year, limitAmount: 3_000_000, category: shoppingCat)
        context.insert(foodBudget)
        context.insert(shoppingBudget)
        
        // 5. Tạo dữ liệu mẫu Sổ nợ (Vay & Cho vay)
        let nextMonth = cal.date(byAdding: .day, value: 20, to: now) ?? now
        let sampleLent = DebtLoan(
            personName: "Nguyễn Văn A",
            type: .lent,
            totalAmount: 5_000_000,
            paidAmount: 2_000_000,
            interestRate: 0,
            startDate: now,
            dueDate: nextMonth,
            note: "Cho mượn xoay sở công việc"
        )
        let sampleBorrowed = DebtLoan(
            personName: "Trả góp Thẻ tín dụng",
            type: .borrowed,
            totalAmount: 12_000_000,
            paidAmount: 4_000_000,
            interestRate: 8.5,
            startDate: now,
            dueDate: nextMonth,
            note: "Mua Macbook trả góp"
        )
        context.insert(sampleLent)
        context.insert(sampleBorrowed)
        
        // 6. Tạo dữ liệu mẫu Mục tiêu Tiết kiệm (SavingsGoal)
        let sixMonthsLater = cal.date(byAdding: .month, value: 6, to: now) ?? now
        let emergencyGoal = SavingsGoal(
            title: "Quỹ Dự phòng Khẩn cấp",
            targetAmount: 50_000_000,
            currentAmount: 20_000_000,
            deadline: sixMonthsLater,
            iconName: "shield.lefthalf.filled",
            colorHex: "#34C759",
            note: "Dự phòng 6 tháng sinh hoạt phí"
        )
        context.insert(emergencyGoal)
        
        // 7. Tạo dữ liệu mẫu Sự kiện Du lịch & Hóa đơn định kỳ (Tinh hoa Money Lover)
        let tripEvent = SpendingEvent(
            name: "Chuyến đi Đà Nẵng",
            iconName: "airplane.departure",
            budgetAmount: 8_000_000,
            endDate: nextMonth
        )
        context.insert(tripEvent)
        
        let electricBill = RecurringBill(
            title: "Tiền Điện & Internet FPT",
            amount: 1_150_000,
            dueDayOfMonth: 28,
            category: billsCat,
            account: bankAccount
        )
        context.insert(electricBill)
        
        try? context.save()
    }
}
