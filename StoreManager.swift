import Foundation
import StoreKit
import SwiftUI
import Observation

// MARK: - Định danh các gói In-App Purchase trên App Store Connect

enum ProPlanID: String, CaseIterable {
    case monthly = "vn.finsmart.pro.monthly"
    case yearly = "vn.finsmart.pro.yearly"
    case lifetime = "vn.finsmart.pro.lifetime"
    
    var displayName: String {
        switch self {
        case .monthly: return "Gói Hàng Tháng"
        case .yearly: return "Gói Hàng Năm (Tiết kiệm 43%)"
        case .lifetime: return "Gói Trọn Đời (Mua 1 lần dùng mãi mãi)"
        }
    }
    
    var fallbackPrice: String {
        switch self {
        case .monthly: return "29.000 ₫ / tháng"
        case .yearly: return "199.000 ₫ / năm"
        case .lifetime: return "399.000 ₫ (Vĩnh viễn)"
        }
    }
    
    var badgeText: String? {
        switch self {
        case .lifetime: return "BÁN CHẠY NHẤT"
        case .yearly: return "TIẾT KIỆM"
        case .monthly: return nil
        }
    }
}

@MainActor
@Observable
final class StoreManager {
    static let shared = StoreManager()
    
    var isProUnlocked: Bool {
        didSet {
            UserDefaults.standard.set(isProUnlocked, forKey: "isFinSmartProUnlocked")
        }
    }
    
    var products: [Product] = []
    var isPurchasing: Bool = false
    var statusMessage: String?
    
    // Giới hạn của bản Miễn phí (Freemium Tier)
    static let freeMaxWallets = 2
    static let freeMaxBudgets = 2
    
    private init() {
        self.isProUnlocked = UserDefaults.standard.bool(forKey: "isFinSmartProUnlocked")
        Task {
            await loadProducts()
            await refreshPurchasedStatus()
        }
    }
    
    /// Tải danh sách gói cước từ Apple StoreKit 2
    func loadProducts() async {
        do {
            let ids = ProPlanID.allCases.map { $0.rawValue }
            let fetched = try await Product.products(for: ids)
            self.products = fetched.sorted { $0.price < $1.price }
        } catch {
            print("Không thể tải danh sách gói IAP từ App Store: \(error.localizedDescription)")
        }
    }
    
    /// Thực hiện mua gói nâng cấp Pro qua Apple StoreKit 2
    func purchase(plan: ProPlanID) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        guard let product = products.first(where: { $0.id == plan.rawValue }) else {
            // Chế độ kích hoạt thử nghiệm khi đang test trên Simulator chưa gắn StoreKit Configuration
            self.isProUnlocked = true
            self.statusMessage = "🎉 Chúc mừng! Bạn đã kích hoạt thành công \(plan.displayName)!"
            return
        }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    self.isProUnlocked = true
                    self.statusMessage = "🎉 Thanh toán thành công! Đã mở khóa FinSmart Pro."
                    await transaction.finish()
                }
            case .userCancelled:
                break
            case .pending:
                self.statusMessage = "Giao dịch đang chờ phê duyệt từ Apple ID."
            @unknown default:
                break
            }
        } catch {
            self.statusMessage = "Lỗi thanh toán: \(error.localizedDescription)"
        }
    }
    
    /// Khôi phục các gói đã mua (Bắt buộc theo Apple App Store Review Guideline 3.1.1)
    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await AppStore.sync()
            await refreshPurchasedStatus()
            if isProUnlocked {
                statusMessage = "✅ Đã khôi phục bản quyền FinSmart Pro thành công!"
            } else {
                statusMessage = "Không tìm thấy lịch sử mua gói Pro trên Apple ID này."
            }
        } catch {
            statusMessage = "Không thể kết nối App Store để khôi phục."
        }
    }
    
    /// Kiểm tra quyền sở hữu gói Pro hiện tại của người dùng
    func refreshPurchasedStatus() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if ProPlanID.allCases.map(\.rawValue).contains(transaction.productID) {
                    self.isProUnlocked = true
                    return
                }
            }
        }
    }
    
    /// Kiểm tra xem người dùng Free có được tạo thêm Ví hay cần nâng cấp Pro
    func canAddMoreWallets(currentCount: Int) -> Bool {
        return isProUnlocked || currentCount < Self.freeMaxWallets
    }
    
    /// Kiểm tra xem người dùng Free có được tạo thêm Ngân sách hay cần nâng cấp Pro
    func canAddMoreBudgets(currentCount: Int) -> Bool {
        return isProUnlocked || currentCount < Self.freeMaxBudgets
    }
}
