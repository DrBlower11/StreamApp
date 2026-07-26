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

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var sitesVM = SitesViewModel()
    @State private var showingAddSheet = false
    @State private var selectedURL: URL? = nil
    @State private var showBrowser = false
    @State private var showFavorites = false
    @State private var showHistory = false
    
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
                        Button(action: { showingAddSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    
                    // Siti
                    if sitesVM.sites.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Text("🎬")
                                .font(.system(size: 60))
                            Text("Nessun sito aggiunto")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("Clicca + per aggiungere il tuo primo sito streaming")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                SectionHeader(title: "I MIEI SITI")
                                ForEach(Array(sitesVM.sites.enumerated()), id: \.offset) { index, site in
                                    SiteCard(site: site) {
                                        selectedURL = site.url
                                        showBrowser = true
                                        sitesVM.addToHistory(site)
                                    } onDelete: {
                                        sitesVM.deleteSite(at: index)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Tab Bar
                    HStack(spacing: 0) {
                        TabBarButton(icon: "house.fill", label: "Home", isActive: true)
                        TabBarButton(icon: "heart.fill", label: "Preferiti") { showFavorites = true }
                        TabBarButton(icon: "clock.fill", label: "Cronologia") { showHistory = true }
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
                if let url = selectedURL {
                    BrowserView(
                        url: url,
                        siteName: sitesVM.sites.first(where: { $0.url == url })?.name ?? ""
                    )
                }
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView(sitesVM: sitesVM) { url in
                    showFavorites = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedURL = url
                        showBrowser = true
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(sitesVM: sitesVM) { url in
                    showHistory = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedURL = url
                        showBrowser = true
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Site Model
struct Site: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let urlString: String
    
    var url: URL? {
        var str = urlString
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "https://" + str
        }
        return URL(string: str)
    }
    
    var domain: String {
        url?.host ?? urlString
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
    @Published var favorites: [Site] = []
    @Published var history: [HistoryEntry] = []
    
    private let sitesKey = "sites_data"
    private let favsKey = "favs_data"
    private let histKey = "hist_data"
    
    init() {
        loadSites()
        loadFavorites()
        loadHistory()
    }
    
    func addSite(name: String, url: String) {
        var urlStr = url
        if !urlStr.hasPrefix("http://") && !urlStr.hasPrefix("https://") {
            urlStr = "https://" + urlStr
        }
        guard !sites.contains(where: { $0.urlString == urlStr }) else { return }
        sites.append(Site(name: name, urlString: urlStr))
        saveSites()
    }
    
    func deleteSite(at index: Int) {
        sites.remove(at: index)
        saveSites()
    }
    
    func addToHistory(_ site: Site) {
        history.insert(HistoryEntry(name: site.name, urlString: site.urlString, date: Date()), at: 0)
        if history.count > 100 { history.removeLast() }
        saveHistory()
    }
    
    func toggleFavorite(_ site: Site) {
        if let idx = favorites.firstIndex(where: { $0.urlString == site.urlString }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(site, at: 0)
        }
        saveFavorites()
    }
    
    func removeFavorite(at index: Int) {
        favorites.remove(at: index)
        saveFavorites()
    }
    
    func isFavorite(_ site: Site) -> Bool {
        favorites.contains(where: { $0.urlString == site.urlString })
    }
    
    private func saveSites() {
        if let data = try? JSONEncoder().encode(sites) {
            UserDefaults.standard.set(data, forKey: sitesKey)
        }
    }
    
    private func loadSites() {
        if let data = UserDefaults.standard.data(forKey: sitesKey),
           let loaded = try? JSONDecoder().decode([Site].self, from: data) {
            sites = loaded
        }
    }
    
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favsKey)
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favsKey),
           let loaded = try? JSONDecoder().decode([Site].self, from: data) {
            favorites = loaded
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: histKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: histKey),
           let loaded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            history = loaded
        }
    }
}

// MARK: - Site Card
struct SiteCard: View {
    let site: Site
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                    .overlay(Text("🎬").font(.title2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(site.domain)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
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
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10))
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
    @State private var url = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    TextField("Nome del sito", text: $name)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    TextField("URL (es. https://miosito.com)", text: $url)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    Button(action: {
                        if !name.isEmpty && !url.isEmpty {
                            sitesVM.addSite(name: name, url: url)
                            dismiss()
                        }
                    }) {
                        Text("Aggiungi")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                    .opacity(name.isEmpty || url.isEmpty ? 0.5 : 1)
                    
                    Spacer()
                }
                .padding()
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

// MARK: - Browser View (fullscreen con controlli flottanti)
struct BrowserView: View {
    let url: URL
    let siteName: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            // WebView a tutto schermo
            WebViewWrapper(url: url)
                .ignoresSafeArea()
            
            // Barra flottante semitrasparente
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 6, x: 0, y: 2)
                }
                
                Spacer()
                
                Text(siteName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 1)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { UIApplication.shared.open(url) }) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 6, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)   // sotto Dynamic Island / notch
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.55), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

// MARK: - WebView Wrapper
struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptEnabled = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - Favorites View
struct FavoritesView: View {
    @ObservedObject var sitesVM: SitesViewModel
    let onSelect: (URL) -> Void
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
                        ForEach(Array(sitesVM.favorites.enumerated()), id: \.offset) { index, site in
                            Button(action: {
                                if let url = site.url { onSelect(url) }
                            }) {
                                HStack {
                                    Text("★").font(.title3)
                                    VStack(alignment: .leading) {
                                        Text(site.name).foregroundColor(.white)
                                        Text(site.domain).font(.caption).foregroundColor(.gray)
                                    }
                                }
                            }
                            .swipeActions {
                                Button("Rimuovi") { sitesVM.removeFavorite(at: index) }.tint(.red)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Preferiti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - History View
struct HistoryView: View {
    @ObservedObject var sitesVM: SitesViewModel
    let onSelect: (URL) -> Void
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
                        Button(action: {
                            if let url = entry.url { onSelect(url) }
                        }) {
                            HStack {
                                Text("🕐").font(.title3)
                                VStack(alignment: .leading) {
                                    Text(entry.name).foregroundColor(.white)
                                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Cronologia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
