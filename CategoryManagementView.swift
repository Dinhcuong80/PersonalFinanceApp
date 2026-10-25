import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var showingAddCategory = false
    @State private var name = ""
    @State private var isIncome = false
    @State private var selectedIcon = "tag.fill"
    @State private var selectedColorHex = "#FF9500"
    
    private let availableIcons = [
        "fork.knife", "cup.and.saucer.fill", "car.fill", "fuelpump.fill",
        "bolt.fill", "house.fill", "bag.fill", "cart.fill",
        "cross.case.fill", "heart.fill", "book.fill", "graduationcap.fill",
        "gamecontroller.fill", "airplane", "briefcase.fill", "chart.bar.fill",
        "gift.fill", "pawprint.fill", "tag.fill"
    ]
    
    private let availableColors = [
        "#FF9500", "#FF3B30", "#FF2D55", "#AF52DE",
        "#5856D6", "#007AFF", "#30B0C7", "#34C759", "#00C7BE"
    ]
    
    private var expenseCategories: [Category] {
        categories.filter { !$0.isIncomeCategory }
    }
    
    private var incomeCategories: [Category] {
        categories.filter { $0.isIncomeCategory }
    }
    
    var body: some View {
        List {
            Section("Danh mục Chi tiêu (\(expenseCategories.count))") {
                ForEach(expenseCategories) { category in
                    categoryRow(category)
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(expenseCategories[index])
                    }
                    try? modelContext.save()
                }
            }
            
            Section("Danh mục Thu nhập (\(incomeCategories.count))") {
                ForEach(incomeCategories) { category in
                    categoryRow(category)
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(incomeCategories[index])
                    }
                    try? modelContext.save()
                }
            }
        }
        .navigationTitle("Quản lý Danh mục")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            NavigationStack {
                Form {
                    Section("Thông tin danh mục") {
                        TextField("Tên danh mục (VD: Cà phê, Thể thao...)", text: $name)
                        Picker("Loại danh mục", selection: $isIncome) {
                            Text("Chi tiêu").tag(false)
                            Text("Thu nhập").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section("Chọn Biểu tượng (SF Symbols)") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                                    .background(selectedIcon == icon ? Color(hex: selectedColorHex) : Color(.systemGray5), in: Circle())
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    
                    Section("Chọn Màu sắc") {
                        HStack(spacing: 12) {
                            ForEach(availableColors, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 2.5 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColorHex = hex
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Thêm Danh mục")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") { showingAddCategory = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") {
                            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            let newCat = Category(
                                name: trimmed,
                                iconName: selectedIcon,
                                colorHex: selectedColorHex,
                                isIncomeCategory: isIncome
                            )
                            modelContext.insert(newCat)
                            try? modelContext.save()
                            name = ""
                            showingAddCategory = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color(hex: category.colorHex), in: Circle())
            
            Text(category.name)
                .font(.body.weight(.medium))
            
            Spacer()
            
            Text("\(category.transactions.count) giao dịch")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
