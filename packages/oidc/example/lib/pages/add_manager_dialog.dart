import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:oidc_example/app_state.dart' as app_state;

class AddManagerDialog extends StatefulWidget {
  const AddManagerDialog({super.key});

  @override
  State<AddManagerDialog> createState() => _AddManagerDialogState();
}

class _AddManagerDialogState extends State<AddManagerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _managerIdController = TextEditingController();
  final _discoveryUriController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _redirectUriController = TextEditingController();
  final _postLogoutRedirectUriController = TextEditingController();
  final _scopeController = TextEditingController(text: 'openid profile email');

  OidcClientAuthenticationType _authType = OidcClientAuthenticationType.none;
  bool _strictJwtVerification = true;
  bool _supportOfflineAuth = false;

  @override
  void dispose() {
    _managerIdController.dispose();
    _discoveryUriController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _redirectUriController.dispose();
    _postLogoutRedirectUriController.dispose();
    _scopeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New OIDC Manager'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _managerIdController,
                  decoration: const InputDecoration(
                    labelText: 'Manager ID',
                    helperText: 'Unique identifier for this manager',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a manager ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _discoveryUriController,
                  decoration: const InputDecoration(
                    labelText: 'Discovery Document URI',
                    helperText: 'OIDC provider discovery endpoint',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a discovery URI';
                    }
                    try {
                      Uri.parse(value);
                    } catch (e) {
                      return 'Please enter a valid URI';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Client ID',
                    helperText: 'OAuth2/OIDC client identifier',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a client ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<OidcClientAuthenticationType>(
                  value: _authType,
                  decoration: const InputDecoration(
                    labelText: 'Client Authentication Type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: OidcClientAuthenticationType.none,
                      child: Text('None (Public Client)'),
                    ),
                    DropdownMenuItem(
                      value: OidcClientAuthenticationType.clientSecretPost,
                      child: Text('Client Secret (POST)'),
                    ),
                    DropdownMenuItem(
                      value: OidcClientAuthenticationType.clientSecretBasic,
                      child: Text('Client Secret (Basic)'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _authType = value!;
                    });
                  },
                ),
                if (_authType != OidcClientAuthenticationType.none) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _clientSecretController,
                    decoration: const InputDecoration(
                      labelText: 'Client Secret',
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (_authType != OidcClientAuthenticationType.none &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter a client secret';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _redirectUriController,
                  decoration: const InputDecoration(
                    labelText: 'Redirect URI',
                    helperText: 'URI to redirect after authentication',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a redirect URI';
                    }
                    try {
                      Uri.parse(value);
                    } catch (e) {
                      return 'Please enter a valid URI';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _postLogoutRedirectUriController,
                  decoration: const InputDecoration(
                    labelText: 'Post Logout Redirect URI (Optional)',
                    helperText: 'URI to redirect after logout',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      try {
                        Uri.parse(value);
                      } catch (e) {
                        return 'Please enter a valid URI';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _scopeController,
                  decoration: const InputDecoration(
                    labelText: 'Scopes',
                    helperText: 'Space-separated list of scopes',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter at least one scope';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Strict JWT Verification'),
                  subtitle: const Text('Enable strict JWT token verification'),
                  value: _strictJwtVerification,
                  onChanged: (value) {
                    setState(() {
                      _strictJwtVerification = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Support Offline Auth'),
                  subtitle: const Text('Allow authentication when offline'),
                  value: _supportOfflineAuth,
                  onChanged: (value) {
                    setState(() {
                      _supportOfflineAuth = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createManager,
          child: const Text('Add Manager'),
        ),
      ],
    );
  }

  void _createManager() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final OidcClientAuthentication credentials;
      switch (_authType) {
        case OidcClientAuthenticationType.none:
          credentials = OidcClientAuthentication.none(
            clientId: _clientIdController.text,
          );
        case OidcClientAuthenticationType.clientSecretPost:
          credentials = OidcClientAuthentication.clientSecretPost(
            clientId: _clientIdController.text,
            clientSecret: _clientSecretController.text,
          );
        case OidcClientAuthenticationType.clientSecretBasic:
          credentials = OidcClientAuthentication.clientSecretBasic(
            clientId: _clientIdController.text,
            clientSecret: _clientSecretController.text,
          );
      }

      final scopes = OidcInternalUtilities.splitSpaceDelimitedString(
        _scopeController.text,
      );

      final manager = OidcUserManager.lazy(
        id: _managerIdController.text,
        discoveryDocumentUri: Uri.parse(_discoveryUriController.text),
        clientCredentials: credentials,
        store: OidcDefaultStore(),
        httpClient: app_state.client,
        settings: OidcUserManagerSettings(
          scope: scopes,
          strictJwtVerification: _strictJwtVerification,
          supportOfflineAuth: _supportOfflineAuth,
          redirectUri: Uri.parse(_redirectUriController.text),
          postLogoutRedirectUri: _postLogoutRedirectUriController.text.isEmpty
              ? null
              : Uri.parse(_postLogoutRedirectUriController.text),
        ),
      );

      Navigator.of(context).pop(manager);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Manager "${_managerIdController.text}" added successfully',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating manager: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

enum OidcClientAuthenticationType { none, clientSecretPost, clientSecretBasic }
