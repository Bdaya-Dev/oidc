# Using the plugin  <!-- omit from toc -->

all the classes that are exposed by this plugin start with `Oidc*`.


## OidcUserManager

### Construction

The main class this plugin provides, as the name suggests, it manages the current user session.

> NOTE: you should only maintain a single instance of this class in your app.

you have two ways to construct it, depending on the availability of the [Discovery Document](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderConfig).

1. If you have the discovery document already:
    ```dart
    final manager = OidcUserManager(
        discoveryDocument: OidcProviderMetadata.fromJson({
            'issuer': 'https://server.example.com',
            'authorization_endpoint':
                'https://server.example.com/connect/authorize',
            'token_endpoint': 'https://server.example.com/connect/token',
            //...other metadata
        }),      
        //...other parameters.
    );
    ```
2. If you don't have the discovery document
    ```dart
    final manager = OidcUserManager.lazy(
        // discoveryDocumentUri:
        //     Uri.parse('https://server.example.com/.well-known/openid-configuration'),
        //or
        discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
            Uri.parse('https://server.example.com'),
        ),
        //...other parameters.
    );
    ```

aside from the discovery document, both constructors share the same parameters:


### Initialization

after constructing the manager with the proper settings, you MUST call the `manager.init()` function, which will do the following:

### Login

#### Auth code flow

#### Implicit flow

#### Resource Owner Password flow

### Logout

## OidcFlutter