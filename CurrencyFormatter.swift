import Foundation
import SwiftUI

enum SupportedCurrency: String, CaseIterable, Identifiable {
    case vnd = "VND"
    case usd = "USD"
    case eur = "EUR"
    
    var id: String { rawValue }
    
    var localeIdentifier: String {
        switch self {
        case .vnd: return "vi_VN"
        case .usd: return "en_US"
        case .eur: return "de_DE"
        }
    }
    
    var maximumFractionDigits: Int {
        switch self {
        case .vnd: return 0
        case .usd, .eur: return 2
        }
    }
}

extension Decimal {
    /// Định dạng số tiền chuẩn theo mã tiền tệ (VND, USD, EUR)
    func formattedCurrency(code: String = "VND") -> String {
        let currency = SupportedCurrency(rawValue: code) ?? .vnd
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.locale = Locale(identifier: currency.localeIdentifier)
        formatter.maximumFractionDigits = currency.maximumFractionDigits
        
        let number = NSDecimalNumber(decimal: self)
        return formatter.string(from: number) ?? "\(self) \(code)"
    }
    
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

extension Color {
    /// Khởi tạo màu từ chuỗi mã Hex (VD: "#FF6B6B")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 122, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - CSV Exporter Utility

struct CSVExporter {
    static func generateCSV(from transactions: [Transaction]) -> URL? {
        var csvText = "Ngày,Loại giao dịch,Danh mục,Số tiền,Tài khoản nguồn,Tài khoản đích,Ghi chú\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        for tx in transactions {
            let dateStr = dateFormatter.string(from: tx.date)
            let typeStr = tx.type.title
            let categoryStr = tx.category?.name ?? (tx.type == .transfer ? "Chuyển khoản" : "Khác")
            let amountStr = "\(tx.amount)"
            let sourceStr = tx.sourceAccount?.name ?? ""
            let destStr = tx.destinationAccount?.name ?? ""
            let sanitizedNote = tx.note.replacingOccurrences(of: "\"", with: "\"\"")
            
            let row = "\"\(dateStr)\",\"\(typeStr)\",\"\(categoryStr)\",\"\(amountStr)\",\"\(sourceStr)\",\"\(destStr)\",\"\(sanitizedNote)\"\n"
            csvText.append(row)
        }
        
        let fileName = "BaoCaoTaiChinh_\(Int(Date.now.timeIntervalSince1970)).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Lỗi xuất file CSV: \(error.localizedDescription)")
            return nil
        }
    }
}
