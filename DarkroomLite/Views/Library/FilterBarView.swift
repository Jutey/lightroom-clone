import SwiftUI

/// Search/filter/sort toolbar shown above the grid and filmstrip. Bound directly to
/// `LibraryViewModel`'s filter properties, which `filteredAndSorted(_:)` consumes whenever
/// the underlying `@Query` results or any of these controls change.
struct FilterBarView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        @Bindable var library = app.library
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search file name, camera, lens", text: $library.searchText)
                    .textFieldStyle(.plain)
                if !library.searchText.isEmpty {
                    Button {
                        library.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 240)

            Menu {
                Button("Any Rating") { library.ratingFilter = 0 }
                Divider()
                ForEach(1...5, id: \.self) { stars in
                    Button("\(stars)+ Stars") { library.ratingFilter = stars }
                }
            } label: {
                Label(library.ratingFilter == 0 ? "Rating" : "\(library.ratingFilter)+ \u{2605}", systemImage: "star")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Picker("Flag", selection: $library.flagFilter) {
                Text("Any Flag").tag(PickFlag?.none)
                Text("Picked").tag(PickFlag?.some(.picked))
                Text("Rejected").tag(PickFlag?.some(.rejected))
            }
            .labelsHidden()
            .fixedSize()

            Menu {
                Button("Any Color") { library.colorLabelFilter = nil }
                Divider()
                ForEach(ColorLabelTag.allCases) { label in
                    Button {
                        library.colorLabelFilter = label
                    } label: {
                        HStack {
                            ColorLabelDot(label: label)
                            Text(label.displayName)
                        }
                    }
                }
            } label: {
                if let colorLabelFilter = library.colorLabelFilter {
                    Label(colorLabelFilter.displayName, systemImage: "circle.fill")
                } else {
                    Label("Color", systemImage: "circle")
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Picker("Type", selection: $library.fileTypeFilter) {
                ForEach(LibraryViewModel.FileTypeFilter.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .labelsHidden()
            .fixedSize()

            Toggle("Edited Only", isOn: $library.editedOnlyFilter)
                .toggleStyle(.checkbox)

            if library.hasActiveFilters {
                Button("Clear Filters") { library.clearFilters() }
                    .buttonStyle(.link)
            }

            Spacer()

            Toggle(isOn: $library.showTrashed) {
                Label("Trash", systemImage: "trash")
            }
            .toggleStyle(.button)
            .help("Show photos moved to trash")

            Picker("Sort", selection: $library.sortOrder) {
                ForEach(LibrarySortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
