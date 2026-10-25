import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class SecurityService {
    var isUnlocked: Bool = false
    var isBiometricEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBiometricEnabled, forKey: "isBiometricEnabled")
        }
    }
    var authErrorMessage: String?
    
    init() {
        let savedPref = UserDefaults.standard.object(forKey: "isBiometricEnabled") as? Bool ?? true
        self.isBiometricEnabled = savedPref
        if !savedPref {
            self.isUnlocked = true
        }
    }
    
    func authenticate() async {
        guard isBiometricEnabled else {
            isUnlocked = true
            return
        }
        
        let context = LAContext()
        var error: NSError?
        let reason = "Xác thực để mở khóa dữ liệu tài chính cá nhân của bạn."
        
        // Sử dụng .deviceOwnerAuthentication để hỗ trợ cả Face ID / Touch ID và fallback về Passcode thiết bị
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                self.isUnlocked = success
                self.authErrorMessage = nil
            } catch {
                self.isUnlocked = false
                self.authErrorMessage = "Xác thực không thành công. Vui lòng thử lại."
            }
        } else {
            // Thiết bị không cài đặt mật khẩu hoặc chạy trên Simulator chưa bật Face ID
            self.isUnlocked = true
        }
    }
    
    func lockAppIfNeeded() {
        if isBiometricEnabled {
            isUnlocked = false
        }
    }
}
