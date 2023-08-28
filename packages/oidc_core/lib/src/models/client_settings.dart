class OidcClientSettings {
  /*
   /** The URL of the OIDC/OAuth2 provider */
    authority: string;
    metadataUrl?: string;
    /** Provide metadata when authority server does not allow CORS on the metadata endpoint */
    metadata?: Partial<OidcMetadata>;
    /** Can be used to seed or add additional values to the results of the discovery request */
    metadataSeed?: Partial<OidcMetadata>;
    /** Provide signingKeys when authority server does not allow CORS on the jwks uri */
    signingKeys?: SigningKey[];

    /** Your client application's identifier as registered with the OIDC/OAuth2 */
    client_id: string;
    client_secret?: string;
    /** The type of response desired from the OIDC/OAuth2 provider (default: "code") */
    response_type?: string;
    /** The scope being requested from the OIDC/OAuth2 provider (default: "openid") */
    scope?: string;
    /** The redirect URI of your client application to receive a response from the OIDC/OAuth2 provider */
    redirect_uri: string;
    /** The OIDC/OAuth2 post-logout redirect URI */
    post_logout_redirect_uri?: string;

    /**
     * Client authentication method that is used to authenticate when using the token endpoint (default: "client_secret_post")
     * - "client_secret_basic": using the HTTP Basic authentication scheme
     * - "client_secret_post": including the client credentials in the request body
     *
     * See https://openid.net/specs/openid-connect-core-1_0.html#ClientAuthentication
     */
    client_authentication?: "client_secret_basic" | "client_secret_post";

    /** optional protocol param */
    prompt?: string;
    /** optional protocol param */
    display?: string;
    /** optional protocol param */
    max_age?: number;
    /** optional protocol param */
    ui_locales?: string;
    /** optional protocol param */
    acr_values?: string;
    /** optional protocol param */
    resource?: string | string[];

    /** optional protocol param (default: "query") */
    response_mode?: "query" | "fragment";

    /**
     * Should optional OIDC protocol claims be removed from profile or specify the ones to be removed (default: true)
     * When true, the following claims are removed by default: ["nbf", "jti", "auth_time", "nonce", "acr", "amr", "azp", "at_hash"]
     * When specifying claims, the following claims are not allowed: ["sub", "iss", "aud", "exp", "iat"]
    */
    filterProtocolClaims?: boolean | string[];
    /** Flag to control if additional identity data is loaded from the user info endpoint in order to populate the user's profile (default: false) */
    loadUserInfo?: boolean;
    /** Number (in seconds) indicating the age of state entries in storage for authorize requests that are considered abandoned and thus can be cleaned up (default: 900) */
    staleStateAgeInSeconds?: number;

    /** @deprecated Unused */
    clockSkewInSeconds?: number;
    /** @deprecated Unused */
    userInfoJwtIssuer?: /*"ANY" | "OP" |*/ string;

    /**
     * Indicates if objects returned from the user info endpoint as claims (e.g. `address`) are merged into the claims from the id token as a single object.
     * Otherwise, they are added to an array as distinct objects for the claim type. (default: false)
     */
    mergeClaims?: boolean;

    /**
     * Storage object used to persist interaction state (default: window.localStorage, InMemoryWebStorage iff no window).
     * E.g. `stateStore: new WebStorageStateStore({ store: window.localStorage })`
     */
    stateStore?: StateStore;

    /**
     * An object containing additional query string parameters to be including in the authorization request.
     * E.g, when using Azure AD to obtain an access token an additional resource parameter is required. extraQueryParams: `{resource:"some_identifier"}`
     */
    extraQueryParams?: Record<string, string | number | boolean>;

    extraTokenParams?: Record<string, unknown>;

    /**
     * An object containing additional header to be including in request.
     */
    extraHeaders?: Record<string, ExtraHeader>;

    /**
     * @deprecated since version 2.1.0. Use fetchRequestCredentials instead.
     */
    refreshTokenCredentials?: "same-origin" | "include" | "omit";

    /**
     * Will check the content type header of the response of the revocation endpoint to match these passed values (default: [])
     */
    revokeTokenAdditionalContentTypes?: string[];
    /**
     * Will disable pkce validation, changing to true will not append to sign in request code_challenge and code_challenge_method. (default: false)
     */
    disablePKCE?: boolean;
    /**
     * Sets the credentials for fetch requests. (default: "same-origin")
     * Use this if you need to send cookies to the OIDC/OAuth2 provider or if you are using a proxy that requires cookies
     */
    fetchRequestCredentials?: RequestCredentials;

    /**
     * Only scopes in this list will be passed in the token refresh request.
     */
    refreshTokenAllowedScope?: string | undefined;
   */
}
