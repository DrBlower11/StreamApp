import SwiftUI
import WebKit

@main
struct StreamHubApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Models
struct Site: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var urlString: String
    var category: String
    var isFavorite: Bool = false
    var lastVisited: Date? = nil

    var url: URL? {
        var str = urlString
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "https://" + str
        }
        return URL(string: str)
    }

    var domain: String { url?.host ?? urlString }

    var faviconURL: URL? {
        guard let host = url?.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)")
    }
}

struct HistoryEntry: Identifiable, Codable {
    var id = UUID()
    let name: String
    let urlString: String
    let date: Date
    var url: URL? { URL(string: urlString) }
}

// MARK: - ViewModel
class SitesViewModel: ObservableObject {
    @Published var sites: [Site] = []
    @Published var history: [HistoryEntry] = []
    @Published var categories: [String] = ["Tutti"]

    private let sitesKey = "sites_data_v2"
    private let histKey  = "hist_data_v2"
    private let catsKey  = "cats_data_v2"

    init() { load() }

    // MARK: Sites
    func addSite(name: String, url: String, category: String) {
        var urlStr = url
        if !urlStr.hasPrefix("http://") && !urlStr.hasPrefix("https://") {
            urlStr = "https://" + urlStr
        }
        guard !sites.contains(where: { $0.urlString == urlStr }) else { return }
        sites.append(Site(name: name, urlString: urlStr, category: category))
        save()
    }

    func deleteSite(at offsets: IndexSet, in filtered: [Site]) {
        let ids = offsets.map { filtered[$0].id }
        sites.removeAll { ids.contains($0.id) }
        save()
    }

    func moveSite(from source: IndexSet, to destination: Int, in filtered: [Site]) {
        var ids = filtered.map { $0.id }
        ids.move(fromOffsets: source, toOffset: destination)
        let order = ids.enumerated().reduce(into: [UUID: Int]()) { $0[$1.element] = $1.offset }
        sites.sort { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
        save()
    }

    func markVisited(_ site: Site) {
        if let idx = sites.firstIndex(where: { $0.id == site.id }) {
            sites[idx].lastVisited = Date()
            save()
        }
    }

    func toggleFavorite(_ site: Site) {
        if let idx = sites.firstIndex(where: { $0.id == site.id }) {
            sites[idx].isFavorite.toggle()
            save()
        }
    }

    var favorites: [Site] { sites.filter { $0.isFavorite } }

    // MARK: History
    func addToHistory(_ site: Site) {
        history.insert(HistoryEntry(name: site.name, urlString: site.urlString, date: Date()), at: 0)
        if history.count > 100 { history.removeLast() }
        save()
    }

    func clearHistory() { history.removeAll(); save() }

    // MARK: Categories
    func addCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !categories.contains(trimmed) else { return }
        categories.append(trimmed)
        save()
    }

    func deleteCategory(_ name: String) {
        guard name != "Tutti" else { return }
        categories.removeAll { $0 == name }
        sites.indices.forEach { if sites[$0].category == name { sites[$0].category = "Tutti" } }
        save()
    }

    // MARK: Persistence
    private func save() {
        if let d = try? JSONEncoder().encode(sites)      { UserDefaults.standard.set(d, forKey: sitesKey) }
        if let d = try? JSONEncoder().encode(history)    { UserDefaults.standard.set(d, forKey: histKey) }
        if let d = try? JSONEncoder().encode(categories) { UserDefaults.standard.set(d, forKey: catsKey) }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: sitesKey),
           let v = try? JSONDecoder().decode([Site].self, from: d) { sites = v }
        if let d = UserDefaults.standard.data(forKey: histKey),
           let v = try? JSONDecoder().decode([HistoryEntry].self, from: d) { history = v }
        if let d = UserDefaults.standard.data(forKey: catsKey),
           let v = try? JSONDecoder().decode([String].self, from: d) {
            categories = v
        } else {
            categories = ["Tutti"]
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var sitesVM = SitesViewModel()
    @State private var showingAddSheet  = false
    @State private var selectedSite: Site? = nil
    @State private var showBrowser      = false
    @State private var showFavorites    = false
    @State private var showHistory      = false
    @State private var searchText       = ""
    @State private var selectedCategory = "Tutti"
    @State private var editMode: EditMode = .inactive

    var filteredSites: [Site] {
        sites(in: selectedCategory).filter {
            searchText.isEmpty ||
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.domain.localizedCaseInsensitiveContains(searchText)
        }
    }

    func sites(in category: String) -> [Site] {
        category == "Tutti" ? sitesVM.sites : sitesVM.sites.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {

                    // Header
                    HStack {
                        Text("StreamHub")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { editMode = editMode == .active ? .inactive : .active }) {
                            Image(systemName: editMode == .active ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle")
                                .font(.system(size: 24))
                                .foregroundColor(editMode == .active ? .green : .gray)
                        }
                        Button(action: { showingAddSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Cerca siti...", text: $searchText)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // Category pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sitesVM.categories, id: \.self) { cat in
                                CategoryPill(title: cat, isSelected: selectedCategory == cat) {
                                    selectedCategory = cat
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 8)

                    // Sites list
                    if sitesVM.sites.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Text("🎬").font(.system(size: 60))
                            Text("Nessun sito aggiunto")
                                .font(.title3).fontWeight(.semibold).foregroundColor(.white)
                            Text("Clicca + per aggiungere il tuo primo sito streaming")
                                .font(.subheadline).foregroundColor(.gray)
                                .multilineTextAlignment(.center).padding(.horizontal, 40)
                        }
                        Spacer()
                    } else if filteredSites.isEmpty {
                        Spacer()
                        Text("Nessun risultato").foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredSites) { site in
                                SiteCard(site: site, isFavorite: sitesVM.isFavorite(site)) {
                                    selectedSite = site
                                    sitesVM.markVisited(site)
                                    sitesVM.addToHistory(site)
                                    showBrowser = true
                                } onToggleFavorite: {
                                    sitesVM.toggleFavorite(site)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                            .onDelete { offsets in sitesVM.deleteSite(at: offsets, in: filteredSites) }
                            .onMove  { src, dst in sitesVM.moveSite(from: src, to: dst, in: filteredSites) }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .environment(\.editMode, $editMode)
                    }

                    Spacer(minLength: 0)

                    // Tab Bar
                    HStack(spacing: 0) {
                        TabBarButton(icon: "house.fill",  label: "Home",       isActive: true)
                        TabBarButton(icon: "heart.fill",  label: "Preferiti")  { showFavorites = true }
                        TabBarButton(icon: "clock.fill",  label: "Cronologia") { showHistory   = true }
                    }
                    .padding(.vertical, 10)
                    .padding(.bottom, 20)
                    .background(Color.black.opacity(0.95))
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSheet) {
                AddSiteView(sitesVM: sitesVM)
            }
            .fullScreenCover(isPresented: $showBrowser) {
                if let site = selectedSite, let url = site.url {
                    BrowserView(url: url)
                }
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView(sitesVM: sitesVM) { site in
                    showFavorites = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedSite = site
                        sitesVM.markVisited(site)
                        sitesVM.addToHistory(site)
                        showBrowser = true
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(sitesVM: sitesVM) { urlString in
                    showHistory = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let site = sitesVM.sites.first(where: { $0.urlString == urlString }),
                           site.url != nil {
                            selectedSite = site
                            sitesVM.markVisited(site)
                            showBrowser = true
                        } else if let url = URL(string: urlString) {
                            selectedSite = Site(name: urlString, urlString: urlString, category: "Tutti")
                            showBrowser = true
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Helpers
extension SitesViewModel {
    func isFavorite(_ site: Site) -> Bool { site.isFavorite }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.white : Color.white.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

// MARK: - Site Card
struct SiteCard: View {
    let site: Site
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AsyncImage(url: site.faviconURL) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFit()
                    } else {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(site.name)
                            .font(.headline).foregroundColor(.white)
                        if let visited = site.lastVisited {
                            Text(relativeTime(visited))
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(site.category)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(4)
                        Text(site.domain)
                            .font(.caption).foregroundColor(.gray)
                    }
                }

                Spacer()

                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(isFavorite ? .red : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    func relativeTime(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "ora" }
        if diff < 3600 { return "\(diff/60)m fa" }
        if diff < 86400 { return "\(diff/3600)h fa" }
        return "\(diff/86400)g fa"
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(.gray).textCase(.uppercase)
            Spacer()
        }
        .padding(.top, 8).padding(.horizontal, 4)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.system(size: 10))
            }
            .foregroundColor(isActive ? .blue : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Add Site View
struct AddSiteView: View {
    @ObservedObject var sitesVM: SitesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var url  = ""
    @State private var selectedCategory = "Tutti"
    @State private var newCategory = ""
    @State private var showCategoryField = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        TextField("Nome del sito", text: $name)
                            .padding().background(Color.white.opacity(0.1))
                            .cornerRadius(12).foregroundColor(.white)

                        TextField("URL (es. https://miosito.com)", text: $url)
                            .padding().background(Color.white.opacity(0.1))
                            .cornerRadius(12).foregroundColor(.white)
                            .keyboardType(.URL).autocapitalization(.none)

                        // Categoria
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Categoria").font(.caption).foregroundColor(.gray)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sitesVM.categories, id: \.self) { cat in
                                        CategoryPill(title: cat, isSelected: selectedCategory == cat) {
                                            selectedCategory = cat
                                        }
                                    }
                                    Button(action: { showCategoryField.toggle() }) {
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.blue).font(.system(size: 22))
                                    }
                                }
                            }
                            if showCategoryField {
                                HStack {
                                    TextField("Nuova categoria", text: $newCategory)
                                        .padding(8).background(Color.white.opacity(0.1))
                                        .cornerRadius(8).foregroundColor(.white)
                                    Button("Aggiungi") {
                                        sitesVM.addCategory(newCategory)
                                        selectedCategory = newCategory
                                        newCategory = ""
                                        showCategoryField = false
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                        }

                        Button(action: {
                            if !name.isEmpty && !url.isEmpty {
                                sitesVM.addSite(name: name, url: url, category: selectedCategory)
                                dismiss()
                            }
                        }) {
                            Text("Aggiungi")
                                .font(.headline).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.blue).cornerRadius(12)
                        }
                        .disabled(name.isEmpty || url.isEmpty)
                        .opacity(name.isEmpty || url.isEmpty ? 0.5 : 1)
                    }
                    .padding()
                }
            }
            .navigationTitle("Aggiungi sito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Browser View (fullscreen, nessun controllo)
struct BrowserView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        FullScreenWebView(url: url, onDismiss: { dismiss() })
            .ignoresSafeArea()
    }
}

struct FullScreenWebView: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> WebViewController {
        WebViewController(url: url, onDismiss: onDismiss)
    }
    func updateUIViewController(_ vc: WebViewController, context: Context) {}
}

class WebViewController: UIViewController {
    private let url: URL
    private let onDismiss: () -> Void
    private var webView: WKWebView!

    init(url: URL, onDismiss: @escaping () -> Void) {
        self.url = url
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptEnabled = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        webView.load(URLRequest(url: url))

        // Swipe giù per chiudere
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
        swipe.direction = .down
        view.addGestureRecognizer(swipe)
    }

    @objc private func handleSwipe() { onDismiss() }

    override var prefersStatusBarHidden: Bool { true }
}

// MARK: - Favorites View
struct FavoritesView: View {
    @ObservedObject var sitesVM: SitesViewModel
    let onSelect: (Site) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if sitesVM.favorites.isEmpty {
                    VStack(spacing: 12) {
                        Text("❤️").font(.system(size: 50))
                        Text("Nessun preferito").foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(sitesVM.favorites) { site in
                            Button(action: { onSelect(site) }) {
                                HStack(spacing: 12) {
                                    AsyncImage(url: site.faviconURL) { phase in
                                        if let img = phase.image {
                                            img.resizable().scaledToFit()
                                        } else {
                                            Image(systemName: "play.rectangle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)

                                    VStack(alignment: .leading) {
                                        Text(site.name).foregroundColor(.white)
                                        Text(site.domain).font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button(action: { sitesVM.toggleFavorite(site) }) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Preferiti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - History View
struct HistoryView: View {
    @ObservedObject var sitesVM: SitesViewModel
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if sitesVM.history.isEmpty {
                    VStack(spacing: 12) {
                        Text("🕐").font(.system(size: 50))
                        Text("Nessuna cronologia").foregroundColor(.gray)
                    }
                } else {
                    List(sitesVM.history) { entry in
                        Button(action: { onSelect(entry.urlString) }) {
                            HStack {
                                Image(systemName: "clock").foregroundColor(.gray)
                                VStack(alignment: .leading) {
                                    Text(entry.name).foregroundColor(.white)
                                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundColor(.gray)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Cronologia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancella tutto") { sitesVM.clearHistory() }
                        .foregroundColor(.red)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
