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
        network: NetworkMonitor = NetworkMonitor()
    ) {
        self.session = session
        self.auth = auth
        self.users = users
        self.items = items
        self.imageLoader = imageLoader
        self.tokenStore = tokenStore
        self.deepLinks = deepLinks
        self.network = network
    }

    static func live(
        tokenStore: any TokenStore = KeychainTokenStore(),
        onboarding: any OnboardingStoring = UserDefaultsOnboardingStore()
    ) -> AppDependencies {
        let link = SessionLink()
        let session = Self.urlSession()

        let metadata = MetadataInterceptor()
        let logging = LoggingInterceptor()

        let refreshClient = URLSessionAPIClient(
            session: session,
            interceptors: [metadata, logging],

            retryPolicy: .none
        )

        let coordinator = TokenRefreshCoordinator(
            store: tokenStore,
            refresher: LiveTokenRefresher(api: refreshClient),
            link: link
        )

        let api = URLSessionAPIClient(
            session: session,
            interceptors: [
                metadata,
                AuthInterceptor(coordinator: coordinator),
                SessionPolicyInterceptor(link: link),
                logging
            ]
        )

        let users = LiveUserRepository(api: api)

        let sessionManager = SessionManager(
            tokenStore: tokenStore,
            users: users,
            onboarding: onboarding
        )

        // The one place the link is set — everything above already holds it.
        link.session = sessionManager

        return AppDependencies(
            session: sessionManager,
            auth: LiveAuthRepository(api: api),
            users: users,
            items: LiveItemRepository(api: api),
            imageLoader: ImageLoader.shared,
            tokenStore: tokenStore,
            deepLinks: DeepLinkParser()
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

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel { [session] in
            session.completeOnboarding()
        }
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(auth: auth, session: session)
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
        HomeViewModel(repository: items, signOut: makeSignOutAction())
    }

    func makeFavoritesViewModel() -> FavoritesViewModel {
        FavoritesViewModel(signOut: makeSignOutAction())
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(signOut: makeSignOutAction())
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(
            repository: users,
            signOut: makeSignOutAction(),
            session: session,
            imageLoader: imageLoader
        )
    }

    func makeSignOutAction() -> SignOutAction {
        SignOutAction(auth: auth, session: session, tokenStore: tokenStore)
    }

}
