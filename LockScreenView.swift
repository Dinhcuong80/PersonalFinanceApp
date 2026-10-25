import SwiftUI

struct LockScreenView: View {
    @Bindable var securityService: SecurityService
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.pulse)
            
            VStack(spacing: 8) {
                Text("FinSmart Bảo Mật")
                    .font(.title2.bold())
                
                Text("Dữ liệu tài chính của bạn được mã hóa và bảo vệ cục bộ trên iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let errorMessage = securityService.authErrorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button {
                Task {
                    await securityService.authenticate()
                }
            } label: {
                Label("Mở khóa bằng Face ID / Passcode", systemImage: "faceid")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await securityService.authenticate()
        }
    }
}
