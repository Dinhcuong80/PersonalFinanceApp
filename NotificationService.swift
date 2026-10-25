import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    /// Yêu cầu quyền gửi thông báo cục bộ (Nhắc hạn trả nợ / thu nợ)
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }
    
    /// Đặt lịch nhắc nhở trước hạn thanh toán khoản Vay / Cho vay 1 ngày
    func scheduleDebtReminder(for debt: DebtLoan) {
        guard !debt.isSettled else { return }
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = debt.type == .lent ? "Nhắc lịch thu hồi nợ" : "Nhắc lịch thanh toán nợ"
        content.body = "\(debt.personName): Còn lại \(debt.remainingAmount.formattedCurrency()) đến hạn vào \(debt.dueDate.formatted(date: .numeric, time: .omitted))."
        content.sound = .default
        
        // Nhắc vào 9:00 sáng ngày đến hạn
        var components = Calendar.current.dateComponents([.year, .month, .day], from: debt.dueDate)
        components.hour = 9
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "debt_\(debt.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    func cancelDebtReminder(for debt: DebtLoan) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["debt_\(debt.id.uuidString)"]
        )
    }
}
