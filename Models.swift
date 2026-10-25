import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense = "EXPENSE"
    case income = "INCOME"
    case transfer = "TRANSFER"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .expense: return "Chi tiêu"
        case .income: return "Thu nhập"
        case .transfer: return "Chuyển khoản"
        }
    }
    
    var icon: String {
        switch self {
        case .expense: return "arrow.up.right.circle.fill"
        case .income: return "arrow.down.left.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }
    
    var tintColor: Color {
        switch self {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .blue
        }
    }
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash = "CASH"
    case bank = "BANK"
    case eWallet = "EWALLET"
    case savings = "SAVINGS"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .cash: return "Tiền mặt"
        case .bank: return "Ngân hàng"
        case .eWallet: return "Ví điện tử"
        case .savings: return "Tiết kiệm / Đầu tư"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .cash: return "banknote.fill"
        case .bank: return "building.columns.fill"
        case .eWallet: return "iphone.gen3"
        case .savings: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum RecurringInterval: String, Codable, CaseIterable, Identifiable {
    case none = "NONE"
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case yearly = "YEARLY"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .none: return "Không lặp lại"
        case .daily: return "Hàng ngày"
        case .weekly: return "Hàng tuần"
        case .monthly: return "Hàng tháng"
        case .yearly: return "Hàng năm"
        }
    }
}

// MARK: - 1. Account Entity

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var balance: Decimal
    var currencyCode: String
    var iconName: String
    var colorHex: String
    var excludeFromTotal: Bool // Học hỏi từ Money Lover: Không tính ví này vào Tổng số dư khả dụng
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.sourceAccount)
    var outgoingTransactions: [Transaction] = []
    
    @Relationship(deleteRule: .nullify, inverse: \Transaction.destinationAccount)
    var incomingTransfers: [Transaction] = []
    
    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .cash }
        set { typeRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        balance: Decimal,
        currencyCode: String = "VND",
        iconName: String? = nil,
        colorHex: String = "#007AFF",
        excludeFromTotal: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.balance = balance
        self.currencyCode = currencyCode
        self.iconName = iconName ?? type.defaultIcon
        self.colorHex = colorHex
        self.excludeFromTotal = excludeFromTotal
        self.createdAt = createdAt
    }
}

// MARK: - 2. Category Entity

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var isIncomeCategory: Bool
    
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        isIncomeCategory: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isIncomeCategory = isIncomeCategory
    }
}

// MARK: - 3. Transaction Entity

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var typeRaw: String
    var date: Date
    var note: String
    var recurringRaw: String
    
    var category: Category?
    var sourceAccount: Account?
    var destinationAccount: Account? // Chỉ dùng khi type == .transfer
    var event: SpendingEvent?        // Học hỏi từ Money Lover: Gắn giao dịch vào Sự kiện / Chuyến đi
    var withPerson: String           // Học hỏi từ Money Lover: Chi tiêu cùng ai
    var locationName: String         // Địa điểm chi tiêu / Cửa hàng
    @Attribute(.externalStorage) var receiptImageData: Data? // Ảnh chụp hóa đơn đính kèm
    
    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }
    
    var recurring: RecurringInterval {
        get { RecurringInterval(rawValue: recurringRaw) ?? .none }
        set { recurringRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionType,
        date: Date = .now,
        note: String = "",
        recurring: RecurringInterval = .none,
        category: Category? = nil,
        sourceAccount: Account? = nil,
        destinationAccount: Account? = nil,
        event: SpendingEvent? = nil,
        withPerson: String = "",
        locationName: String = "",
        receiptImageData: Data? = nil
    ) {
        self.id = id
        self.amount = amount
        self.typeRaw = type.rawValue
        self.date = date
        self.note = note
        self.recurringRaw = recurring.rawValue
        self.category = category
        self.sourceAccount = sourceAccount
        self.destinationAccount = destinationAccount
        self.event = event
        self.withPerson = withPerson
        self.locationName = locationName
        self.receiptImageData = receiptImageData
    }
    
    /// Áp dụng biến động số dư vào tài khoản khi tạo mới giao dịch
    func applyBalanceEffect() {
        switch type {
        case .income:
            sourceAccount?.balance += amount
        case .expense:
            sourceAccount?.balance -= amount
        case .transfer:
            sourceAccount?.balance -= amount
            destinationAccount?.balance += amount
        }
    }
    
    /// Hoàn tác biến động số dư trước khi xóa hoặc cập nhật giao dịch
    func revertBalanceEffect() {
        switch type {
        case .income:
            sourceAccount?.balance -= amount
        case .expense:
            sourceAccount?.balance += amount
        case .transfer:
            sourceAccount?.balance += amount
            destinationAccount?.balance -= amount
        }
    }
}

// MARK: - 4. Budget Entity

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var month: Int // 1...12
    var year: Int
    var limitAmount: Decimal
    var category: Category? // nil = Ngân sách tổng toàn tháng
    
    init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        limitAmount: Decimal,
        category: Category? = nil
    ) {
        self.id = id
        self.month = month
        self.year = year
        self.limitAmount = limitAmount
        self.category = category
    }
}

// MARK: - 5. Debt & Loan Entity (Quản lý Vay & Cho Vay)

enum DebtType: String, Codable, CaseIterable, Identifiable {
    case lent = "LENT"         // Mình cho người khác vay (Khoản phải thu)
    case borrowed = "BORROWED" // Mình đi vay (Khoản phải trả)
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .lent: return "Cho vay (Phải thu)"
        case .borrowed: return "Đi vay (Phải trả)"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .lent: return "Cho vay"
        case .borrowed: return "Đi vay"
        }
    }
    
    var icon: String {
        switch self {
        case .lent: return "arrow.up.forward.app.fill"
        case .borrowed: return "arrow.down.backward.app.fill"
        }
    }
    
    var tintColor: Color {
        switch self {
        case .lent: return .teal
        case .borrowed: return .orange
        }
    }
}

@Model
final class DebtLoan {
    @Attribute(.unique) var id: UUID
    var personName: String
    var typeRaw: String
    var totalAmount: Decimal
    var paidAmount: Decimal
    var interestRate: Double // Lãi suất %/năm (0 nếu vay bạn bè không lãi)
    var startDate: Date
    var dueDate: Date
    var note: String
    var isSettled: Bool
    
    var type: DebtType {
        get { DebtType(rawValue: typeRaw) ?? .borrowed }
        set { typeRaw = newValue.rawValue }
    }
    
    /// Số tiền còn lại cần thu hoặc cần trả
    var remainingAmount: Decimal {
        max(Decimal.zero, totalAmount - paidAmount)
    }
    
    /// Tiến độ hoàn thành (0.0 -> 1.0)
    var progress: Double {
        guard totalAmount > 0 else { return 1.0 }
        let ratio = NSDecimalNumber(decimal: paidAmount).doubleValue / NSDecimalNumber(decimal: totalAmount).doubleValue
        return min(max(ratio, 0.0), 1.0)
    }
    
    /// Kiểm tra đã quá hạn trả nợ hay chưa
    var isOverdue: Bool {
        !isSettled && remainingAmount > 0 && dueDate < Date.now
    }
    
    init(
        id: UUID = UUID(),
        personName: String,
        type: DebtType,
        totalAmount: Decimal,
        paidAmount: Decimal = 0,
        interestRate: Double = 0,
        startDate: Date = .now,
        dueDate: Date,
        note: String = "",
        isSettled: Bool = false
    ) {
        self.id = id
        self.personName = personName
        self.typeRaw = type.rawValue
        self.totalAmount = totalAmount
        self.paidAmount = paidAmount
        self.interestRate = interestRate
        self.startDate = startDate
        self.dueDate = dueDate
        self.note = note
        self.isSettled = isSettled
    }
    
    /// Ghi nhận một lần trả nợ hoặc thu nợ một phần / toàn bộ, đồng thời cập nhật số dư Ví
    func recordPayment(amount: Decimal, account: Account?, context: ModelContext) {
        guard amount > 0 else { return }
        let actualPay = min(amount, remainingAmount)
        paidAmount += actualPay
        if remainingAmount <= 0 {
            isSettled = true
        }
        
        guard let account else { return }
        // Nếu mình Cho vay (.lent) -> Khi thu nợ tiền cộng vào Ví (.income)
        // Nếu mình Đi vay (.borrowed) -> Khi trả nợ tiền trừ khỏi Ví (.expense)
        let txType: TransactionType = (type == .lent) ? .income : .expense
        let actionLabel = (type == .lent) ? "Thu nợ từ \(personName)" : "Trả nợ cho \(personName)"
        
        let tx = Transaction(
            amount: actualPay,
            type: txType,
            date: .now,
            note: actionLabel,
            sourceAccount: account
        )
        tx.applyBalanceEffect()
        context.insert(tx)
    }
}

// MARK: - 6. Savings Goal Entity (Mục tiêu Tiết kiệm & Tích lũy)

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var deadline: Date
    var iconName: String
    var colorHex: String
    var note: String
    var isCompleted: Bool
    
    var remainingAmount: Decimal {
        max(Decimal.zero, targetAmount - currentAmount)
    }
    
    var progress: Double {
        guard targetAmount > 0 else { return 1.0 }
        let ratio = NSDecimalNumber(decimal: currentAmount).doubleValue / NSDecimalNumber(decimal: targetAmount).doubleValue
        return min(max(ratio, 0.0), 1.0)
    }
    
    /// Gợi ý số tiền cần tiết kiệm mỗi tháng từ nay đến hạn
    var suggestedMonthlySaving: Decimal {
        guard remainingAmount > 0 else { return 0 }
        let months = max(1, Calendar.current.dateComponents([.month], from: .now, to: deadline).month ?? 1)
        return remainingAmount / Decimal(months)
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        deadline: Date,
        iconName: String = "star.fill",
        colorHex: String = "#AF52DE",
        note: String = "",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.iconName = iconName
        self.colorHex = colorHex
        self.note = note
        self.isCompleted = isCompleted
    }
    
    /// Nạp thêm tiền tích lũy vào mục tiêu từ một tài khoản
    func deposit(amount: Decimal, from account: Account?, context: ModelContext) {
        guard amount > 0 else { return }
        currentAmount += amount
        if currentAmount >= targetAmount {
            isCompleted = true
        }
        
        guard let account else { return }
        let tx = Transaction(
            amount: amount,
            type: .expense,
            date: .now,
            note: "Tích lũy mục tiêu: \(title)",
            sourceAccount: account
        )
        tx.applyBalanceEffect()
        context.insert(tx)
    }
}

// MARK: - 7. Spending Event Entity (Chế độ Sự kiện / Chuyến đi học hỏi từ Money Lover)

@Model
final class SpendingEvent {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var budgetAmount: Decimal
    var endDate: Date
    var isFinished: Bool
    
    @Relationship(deleteRule: .nullify, inverse: \Transaction.event)
    var transactions: [Transaction] = []
    
    var totalSpent: Decimal {
        transactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "airplane.departure",
        budgetAmount: Decimal = 0,
        endDate: Date,
        isFinished: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.budgetAmount = budgetAmount
        self.endDate = endDate
        self.isFinished = isFinished
    }
}

// MARK: - 8. Recurring Bill Entity (Hóa đơn định kỳ thanh toán 1 chạm - Money Lover)

@Model
final class RecurringBill {
    @Attribute(.unique) var id: UUID
    var title: String
    var amount: Decimal
    var dueDayOfMonth: Int // Ngày đến hạn hàng tháng (1...31)
    var isPaidThisMonth: Bool
    var category: Category?
    var account: Account?
    
    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        dueDayOfMonth: Int,
        isPaidThisMonth: Bool = false,
        category: Category? = nil,
        account: Account? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.dueDayOfMonth = dueDayOfMonth
        self.isPaidThisMonth = isPaidThisMonth
        self.category = category
        self.account = account
    }
    
    /// Thanh toán hóa đơn 1 chạm: tự động tạo giao dịch và trừ tiền ví
    func payBillNow(context: ModelContext) {
        guard !isPaidThisMonth else { return }
        isPaidThisMonth = true
        let tx = Transaction(
            amount: amount,
            type: .expense,
            date: .now,
            note: "Thanh toán hóa đơn: \(title)",
            recurring: .monthly,
            category: category,
            sourceAccount: account
        )
        tx.applyBalanceEffect()
        context.insert(tx)
    }
}




