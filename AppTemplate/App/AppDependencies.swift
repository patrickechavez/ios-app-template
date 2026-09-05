//
//  AppDependencies.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

@MainActor
final class AppDependencies {

    let session: SessionManager
    let deepLinks: DeepLinkParser
    let analytics: any AnalyticsTracking
    let crashes: any CrashReporting
    let network: NetworkMonitor

    private let auth: any AuthRepository
    private let users: any UserRepository
    private let items: any ItemRepository
    private let imageLoader: any ImageLoading
    private let tokenStore: any TokenStore

    init(
        session: SessionManager,
        auth: any AuthRepository,
        users: any UserRepository,
        items: any ItemRepository,
        imageLoader: any ImageLoading,
        tokenStore: any TokenStore,
        deepLinks: DeepLinkParser,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting,
        network: NetworkMonitor = NetworkMonitor()
    ) {
        self.session = session
        self.auth = auth
        self.users = users
        self.items = items
        self.imageLoader = imageLoader
        self.tokenStore = tokenStore
        self.deepLinks = deepLinks
        self.analytics = analytics
        self.crashes = crashes
        self.network = network
    }

    static func live(tokenStore: any TokenStore = KeychainTokenStore()) -> AppDependencies {
        // No plist, or no Firebase at all — the no-op adapters take over.
        let (analytics, crashes) = FirebaseBootstrap.start()
            ?? (NoopAnalyticsTracker(), NoopCrashReporter())

        Observability.install(analytics: analytics, crashes: crashes)

        let link = SessionLink()
        let session = Self.urlSession()

        let metadata = MetadataInterceptor()
        let logging = LoggingInterceptor()

        // Present only when the active environment targets Supabase —
        // its absence is what selects the Live* repositories below instead.
        let supabaseAPIKey = APIConfig.supabaseAnonKey.map(SupabaseAPIKeyInterceptor.init(anonKey:))

        var refreshInterceptors: [any RequestInterceptor] = [metadata]
        if let supabaseAPIKey { refreshInterceptors.append(supabaseAPIKey) }
        refreshInterceptors.append(logging)

        let refreshClient = URLSessionAPIClient(
            session: session,
            interceptors: refreshInterceptors,
            retryPolicy: .none
        )

        let tokenRefresher: any TokenRefreshing = supabaseAPIKey != nil
            ? SupabaseTokenRefresher(api: refreshClient)
            : LiveTokenRefresher(api: refreshClient)

        let coordinator = TokenRefreshCoordinator(
            store: tokenStore,
            refresher: tokenRefresher,
            link: link
        )

        var apiInterceptors: [any RequestInterceptor] = [metadata]
        if let supabaseAPIKey { apiInterceptors.append(supabaseAPIKey) }
        apiInterceptors.append(AuthInterceptor(coordinator: coordinator))
        apiInterceptors.append(SessionPolicyInterceptor(link: link))
        apiInterceptors.append(logging)

        let api = URLSessionAPIClient(session: session, interceptors: apiInterceptors)

        let users = LiveUserRepository(api: api)

        let sessionManager = SessionManager(
            tokenStore: tokenStore,
            users: users,
            crashes: crashes
        )

        // The one place the link is set — everything above already holds it.
        link.session = sessionManager

        let auth: any AuthRepository = supabaseAPIKey != nil
            ? SupabaseAuthRepository(api: api)
            : LiveAuthRepository(api: api)

        let items: any ItemRepository = supabaseAPIKey != nil
            ? SupabaseItemRepository(api: api)
            : LiveItemRepository(api: api)

        return AppDependencies(
            session: sessionManager,
            auth: auth,
            users: users,
            items: items,
            imageLoader: ImageLoader.shared,
            tokenStore: tokenStore,
            deepLinks: DeepLinkParser(),
            analytics: analytics,
            crashes: crashes
        )
    }

    private static func urlSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfig.timeout

        configuration.timeoutIntervalForResource = 300

        configuration.waitsForConnectivity = false

        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        let languages = Locale.preferredLanguages.prefix(3).joined(separator: ", ")
        configuration.httpAdditionalHeaders = ["Accept-Language": languages]

        let pinner = CertificatePinner(pinnedHashes: APIConfig.pinnedPublicKeyHashes)
        return URLSession(configuration: configuration, delegate: pinner, delegateQueue: nil)
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(auth: auth, session: session, analytics: analytics)
    }

    func makeRegisterViewModel() -> RegisterViewModel {
        RegisterViewModel(auth: auth)
    }

    func makeForgotPasswordViewModel() -> ForgotPasswordViewModel {
        ForgotPasswordViewModel(auth: auth)
    }

    func makeResetPasswordViewModel(token: String) -> ResetPasswordViewModel {
        ResetPasswordViewModel(token: token, auth: auth)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(repository: items)
    }

    func makeItemDetailViewModel(item: Item) -> ItemDetailViewModel {
        ItemDetailViewModel(item: item, repository: items)
    }

    func makeItemDetailViewModel(id: UUID) -> ItemDetailViewModel {
        ItemDetailViewModel(itemID: id, repository: items)
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(
            repository: users,
            auth: auth,
            session: session,
            tokenStore: tokenStore,
            imageLoader: imageLoader
        )
    }

    func makeHomeSheetViewModel() -> HomeSheetViewModel { HomeSheetViewModel() }
    func makeHomeCoverViewModel() -> HomeCoverViewModel { HomeCoverViewModel() }
}
