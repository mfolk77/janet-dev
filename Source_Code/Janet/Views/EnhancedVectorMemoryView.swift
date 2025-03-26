import SwiftUI
import Combine

// MARK: - MemoryItem Struct
struct MemoryItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var content: String
    var title: String
    var timestamp: Date
    var tags: [String]
    var source: String
    var type: MemoryType
    
    enum MemoryType: String, Codable {
        case text
        case image
        case audio
        case code
        case link
        
        var icon: String {
            switch self {
            case .text: return "doc.text"
            case .image: return "photo"
            case .audio: return "waveform"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .link: return "link"
            }
        }
        
        var color: Color {
            switch self {
            case .text: return .blue
            case .image: return .green
            case .audio: return .orange
            case .code: return .purple
            case .link: return .red
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MemoryItem, rhs: MemoryItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data
let sampleMemoryItems: [MemoryItem] = [
    MemoryItem(
        content: "This is a sample text memory item with some content that might be useful later.",
        title: "Sample Text Memory",
        timestamp: Date().addingTimeInterval(-86400), // Yesterday
        tags: ["sample", "text", "important"],
        source: "Manual Entry",
        type: .text
    ),
    MemoryItem(
        content: "func calculateTotal(items: [Item]) -> Double {\n    return items.reduce(0) { $0 + $1.price }\n}",
        title: "Calculate Total Function",
        timestamp: Date().addingTimeInterval(-172800), // 2 days ago
        tags: ["code", "swift", "function"],
        source: "Code Editor",
        type: .code
    ),
    MemoryItem(
        content: "https://example.com/important-resource",
        title: "Important Resource Link",
        timestamp: Date().addingTimeInterval(-259200), // 3 days ago
        tags: ["link", "resource", "reference"],
        source: "Web Browser",
        type: .link
    ),
    MemoryItem(
        content: "Meeting notes: Discussed project timeline and resource allocation.",
        title: "Project Planning Meeting",
        timestamp: Date().addingTimeInterval(-345600), // 4 days ago
        tags: ["meeting", "project", "planning"],
        source: "Meeting Recorder",
        type: .text
    ),
    MemoryItem(
        content: "Image of whiteboard diagram",
        title: "System Architecture Diagram",
        timestamp: Date().addingTimeInterval(-432000), // 5 days ago
        tags: ["diagram", "architecture", "system"],
        source: "Camera",
        type: .image
    )
]

struct EnhancedVectorMemoryView: View {
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var memoryManager: MemoryManager
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    
    // State variables
    @State private var searchText: String = ""
    @State private var selectedMemoryItem: MemoryItem? = nil
    @State private var selectedViewMode: ViewMode = .timeline
    @State private var selectedTimeRange: TimeRange = .all
    @State private var selectedTags: Set<String> = []
    @State private var showTagSelector: Bool = false
    @State private var isSearching: Bool = false
    @State private var searchResults: [MemoryItem] = []
    @State private var showingDeleteConfirmation: Bool = false
    @State private var itemToDelete: MemoryItem? = nil
    @State private var showingExportOptions: Bool = false
    @State private var showingImportOptions: Bool = false
    
    // Memory items (would be fetched from memory manager in a real implementation)
    @State private var memoryItems: [MemoryItem] = sampleMemoryItems
    
    // View modes
    enum ViewMode: String, CaseIterable, Identifiable {
        case timeline = "Timeline"
        case list = "List"
        case grid = "Grid"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .timeline: return "timeline.selection"
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    // Time range filter
    enum TimeRange: String, CaseIterable, Identifiable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main content
            VStack(spacing: 0) {
                // Search and filter bar
                searchAndFilterBar
                
                // Memory content
                ZStack {
                    switch selectedViewMode {
                    case .timeline:
                        timelineView
                    case .list:
                        listView
                    case .grid:
                        gridView
                    }
                    
                    // Memory detail overlay
                    if let selectedItem = selectedMemoryItem {
                        memoryDetailView(for: selectedItem)
                            .transition(.move(edge: .trailing))
                    }
                }
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
        )
        .onAppear {
            // Load memory items
            loadMemoryItems()
        }
        .alert("Delete Memory Item", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete, let index = memoryItems.firstIndex(of: item) {
                    memoryItems.remove(at: index)
                    if selectedMemoryItem == item {
                        selectedMemoryItem = nil
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this memory item? This action cannot be undone.")
        }
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        HStack {
            Button(action: {
                navigationState.navigateToHome()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Enhanced Memory")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            // View mode selector
            Picker("View Mode", selection: $selectedViewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 300)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search memories...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        searchMemories()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        isSearching = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: {
                    searchMemories()
                }) {
                    Text("Search")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(searchText.isEmpty)
            }
            .padding(.horizontal)
            
            // Filters
            HStack {
                // Time range filter
                Picker("Time", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
                
                Divider()
                    .frame(height: 20)
                
                // Tags filter
                Button(action: {
                    showTagSelector.toggle()
                }) {
                    HStack {
                        Text("Tags: \(selectedTags.isEmpty ? "All" : "\(selectedTags.count) selected")")
                        Image(systemName: "chevron.down")
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showTagSelector) {
                    tagSelectorView
                }
                
                Spacer()
                
                // Import/Export buttons
                Button(action: {
                    showingExportOptions = true
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingImportOptions = true
                }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }
    
    private var timelineView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupedMemoryItems.keys.sorted(by: >), id: \.self) { date in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatDate(date))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(groupedMemoryItems[date] ?? []) { item in
                            TimelineItemView(item: item) {
                                selectedMemoryItem = item
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var listView: some View {
        List {
            ForEach(filteredMemoryItems) { item in
                ListItemView(item: item) {
                    selectedMemoryItem = item
                }
            }
            .onDelete { indexSet in
                let itemsToDelete = indexSet.map { filteredMemoryItems[$0] }
                if let firstItem = itemsToDelete.first {
                    itemToDelete = firstItem
                    showingDeleteConfirmation = true
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredMemoryItems) { item in
                    GridItemView(item: item) {
                        selectedMemoryItem = item
                    }
                }
            }
            .padding()
        }
    }
    
    private func memoryDetailView(for item: MemoryItem) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    withAnimation {
                        selectedMemoryItem = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Memory Details")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button(action: {
                        // Edit memory
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        itemToDelete = item
                        showingDeleteConfirmation = true
                    }) {
                        Label("Delete", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            
            // Memory details content
            // This is a placeholder and should be replaced with the actual implementation
            Text("Memory details content will be displayed here")
        }
    }
    
    // Tag selector view
    private var tagSelectorView: some View {
        VStack(spacing: 12) {
            Text("Select Tags")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(allTags, id: \.self) { tag in
                        Button(action: {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedTags.contains(tag) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedTags.contains(tag) ? .blue : .gray)
                                
                                Text(tag)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 200)
            
            HStack {
                Button("Clear All") {
                    selectedTags.removeAll()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Select All") {
                    selectedTags = Set(allTags)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            Button("Done") {
                showTagSelector = false
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Helper Methods
    
    // Load memory items from memory manager
    private func loadMemoryItems() {
        // In a real implementation, this would fetch items from the memory manager
        // For now, we'll use the sample data
        memoryItems = sampleMemoryItems
    }
    
    // Search memories based on search text
    private func searchMemories() {
        guard !searchText.isEmpty else {
            isSearching = false
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Simple search implementation
        searchResults = memoryItems.filter { item in
            item.title.lowercased().contains(searchText.lowercased()) ||
            item.content.lowercased().contains(searchText.lowercased()) ||
            item.tags.contains { $0.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    // Format date for display
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Computed Properties
    
    // All available tags
    private var allTags: [String] {
        var tags = Set<String>()
        for item in memoryItems {
            for tag in item.tags {
                tags.insert(tag)
            }
        }
        return Array(tags).sorted()
    }
    
    // Filtered memory items based on search and filters
    private var filteredMemoryItems: [MemoryItem] {
        var items = isSearching ? searchResults : memoryItems
        
        // Apply time range filter
        items = items.filter { item in
            switch selectedTimeRange {
            case .today:
                return Calendar.current.isDateInToday(item.timestamp)
            case .week:
                let startOfWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                return item.timestamp >= startOfWeek
            case .month:
                let startOfMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
                return item.timestamp >= startOfMonth
            case .all:
                return true
            }
        }
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            items = items.filter { item in
                for tag in item.tags {
                    if selectedTags.contains(tag) {
                        return true
                    }
                }
                return false
            }
        }
        
        // Sort by timestamp (newest first)
        return items.sorted { $0.timestamp > $1.timestamp }
    }
    
    // Group memory items by date for timeline view
    private var groupedMemoryItems: [Date: [MemoryItem]] {
        let calendar = Calendar.current
        var result = [Date: [MemoryItem]]()
        
        for item in filteredMemoryItems {
            // Get start of day for the item's timestamp
            let startOfDay = calendar.startOfDay(for: item.timestamp)
            
            // Add item to the appropriate day group
            if result[startOfDay] == nil {
                result[startOfDay] = [item]
            } else {
                result[startOfDay]?.append(item)
            }
        }
        
        return result
    }
}

// MARK: - Item View Components

// Timeline item view
struct TimelineItemView: View {
    let item: MemoryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: item.type.icon)
                    .font(.title2)
                    .foregroundColor(item.type.color)
                    .frame(width: 40, height: 40)
                    .background(item.type.color.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Preview
                    Text(item.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Tags
                    FlowLayout(spacing: 4) {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        if item.tags.count > 3 {
                            Text("+\(item.tags.count - 3)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                // Time
                Text(formatTime(item.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// List item view
struct ListItemView: View {
    let item: MemoryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: item.type.icon)
                    .font(.title3)
                    .foregroundColor(item.type.color)
                    .frame(width: 32, height: 32)
                    .background(item.type.color.opacity(0.1))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Date and source
                    HStack {
                        Text(formatDate(item.timestamp))
                            .font(.caption)
                        
                        Text("•")
                            .font(.caption)
                        
                        Text(item.source)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// Grid item view
struct GridItemView: View {
    let item: MemoryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header with icon and type
                HStack {
                    Image(systemName: item.type.icon)
                        .foregroundColor(item.type.color)
                    
                    Text(item.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(item.type.color)
                    
                    Spacer()
                    
                    Text(formatDate(item.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Title
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .topLeading)
                
                // Preview
                Text(item.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(height: 50, alignment: .topLeading)
                
                Spacer()
                
                // Tags
                if !item.tags.isEmpty {
                    HStack {
                        Text(item.tags[0])
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(2)
                        
                        if item.tags.count > 1 {
                            Text("+\(item.tags.count - 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .frame(height: 180)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views

// Flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            
            if x + size.width > width {
                // Move to next row
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            // Place the view
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
        
        height = y + maxHeight
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let _ = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            
            if x + size.width > bounds.maxX {
                // Move to next row
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            // Place the view
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}