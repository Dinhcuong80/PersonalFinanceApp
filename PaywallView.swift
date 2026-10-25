import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var storeManager = StoreManager.shared
    @State private var selectedPlan: ProPlanID = .lifetime
    
    private let proFeatures: [(icon: String, title: String, subtitle: String)] = [
        ("wallet.pass.fill", "Không giới hạn số lượng Ví & Ngân sách", "Tạo thoải mái các ví ngân hàng, thẻ tín dụng, quỹ tiết kiệm"),
        ("doc.text.viewfinder", "Quét Hóa Đơn AI tự động (OCR)", "Chụp hóa đơn tự động nhận diện cửa hàng và số tiền"),
        ("person.3.fill", "Chia Tiền Nhóm thông minh (Split Bill)", "Tự động chia hóa đơn ăn uống và tạo khoản phải thu trong Sổ Nợ"),
        ("airplane.departure", "Chế độ Sự kiện & Du lịch không giới hạn", "Theo dõi riêng chi phí từng chuyến đi, dịp Tết, đám cưới"),
        ("square.and.arrow.up.fill", "Xuất dữ liệu CSV / Excel & Khóa Face ID", "Sao lưu toàn bộ lịch sử tài chính an toàn tuyệt đối")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // 1. Header Vương miện VIP
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 72, height: 72)
                                .shadow(color: .orange.opacity(0.4), radius: 12, x: 0, y: 6)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(.white)
                        }
                        
                        Text("Nâng cấp FinSmart Pro")
                            .font(.title2.bold())
                        
                        Text("Mở khóa toàn bộ sức mạnh quản lý tài chính cá nhân chuyên nghiệp như Money Lover Premium")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    
                    // 2. Danh sách Quyền lợi VIP
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(proFeatures, id: \.title) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                                    .frame(width: 32, height: 32)
                                    .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.subheadline.bold())
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)
                    
                    // 3. Chọn gói nâng cấp (Trọn đời / Năm / Tháng)
                    VStack(spacing: 10) {
                        ForEach([ProPlanID.lifetime, ProPlanID.yearly, ProPlanID.monthly], id: \.rawValue) { plan in
                            PlanSelectionRow(
                                plan: plan,
                                isSelected: selectedPlan == plan
                            ) {
                                selectedPlan = plan
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    if let status = storeManager.statusMessage {
                        Text(status)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // 4. Nút Thanh toán & Khôi phục bản quyền (Chuẩn Apple Guideline 3.1.1)
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await storeManager.purchase(plan: selectedPlan)
                            }
                        } label: {
                            HStack {
                                if storeManager.isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(storeManager.isProUnlocked ? "✓ Bạn đã sở hữu FinSmart Pro" : "Tiếp tục với \(selectedPlan.displayName)")
                                        .font(.headline.bold())
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(colors: [Color(hex: "#F7971E"), Color(hex: "#FFD200")], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .foregroundStyle(.black)
                        }
                        .disabled(storeManager.isPurchasing)
                        
                        Button {
                            Task {
                                await storeManager.restorePurchases()
                            }
                        } label: {
                            Text("Khôi phục giao dịch đã mua (Restore Purchases)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("Thanh toán an toàn qua tài khoản Apple ID (MoMo, VietQR, Thẻ ngân hàng). Bạn có thể hủy gia hạn bất cứ lúc nào trong phần Cài đặt iPhone.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

struct PlanSelectionRow: View {
    let plan: ProPlanID
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .orange : .secondary)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan.displayName)
                            .font(.subheadline.bold())
                        if let badge = plan.badgeText {
                            Text(badge)
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(plan.fallbackPrice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
