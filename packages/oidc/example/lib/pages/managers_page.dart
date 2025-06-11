import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import '../app_state.dart';

class ManagersPage extends StatefulWidget {
  const ManagersPage({super.key});

  @override
  State<ManagersPage> createState() => _ManagersPageState();
}

class _ManagersPageState extends State<ManagersPage> {
  // final List<OidcUserManager> _managers = [duendeManager];
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _discoveryUriController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _redirectUriController = TextEditingController();
  final _scopesController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _discoveryUriController.dispose();
    _clientIdController.dispose();
    _redirectUriController.dispose();
    _scopesController.dispose();
    super.dispose();
  }

  void _addManager() {
    if (!_formKey.currentState!.validate()) return;

    try {
      final manager = OidcUserManager.lazy(
        id: _idController.text,
        discoveryDocumentUri: Uri.parse(_discoveryUriController.text),
        clientCredentials: OidcClientAuthentication.none(
          clientId: _clientIdController.text,
        ),
        store: OidcDefaultStore(),
        httpClient: client,
        settings: OidcUserManagerSettings(
          scope: OidcInternalUtilities.splitSpaceDelimitedString(
            _scopesController.text,
          ),
          redirectUri: Uri.parse(_redirectUriController.text),
        ),
      );

      managersRx.update((managers) => managers..add(manager));

      _clearForm();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating manager: $e')),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _discoveryUriController.clear();
    _clientIdController.clear();
    _redirectUriController.clear();
    _scopesController.clear();
  }

  void _removeManager(int index) {
    managersRx.update((managers) => managers..removeAt(index));
  }

  void _selectManager(OidcUserManager manager) {
    currentManagerRx.$ = manager;
    Navigator.of(context).pop();
  }

  void _showAddManagerDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Manager'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _discoveryUriController,
                decoration: const InputDecoration(
                  labelText: 'Discovery URI',
                  hintText:
                      'https://example.com/.well-known/openid-configuration',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  try {
                    Uri.parse(value!);
                    return null;
                  } catch (e) {
                    return 'Invalid URI';
                  }
                },
              ),
              TextFormField(
                controller: _clientIdController,
                decoration: const InputDecoration(labelText: 'Client ID'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _redirectUriController,
                decoration: const InputDecoration(
                  labelText: 'Redirect URI',
                  hintText: 'http://localhost:22433/redirect.html',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  try {
                    Uri.parse(value!);
                    return null;
                  } catch (e) {
                    return 'Invalid URI';
                  }
                },
              ),
              TextFormField(
                controller: _scopesController,
                decoration: const InputDecoration(
                  labelText: 'Scopes',
                  hintText: 'openid profile email',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addManager,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserManager = currentManagerRx.of(context);
    final managers = managersRx.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('OIDC Managers'),
        actions: [
          IconButton(
            onPressed: _showAddManagerDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: managers.length,
        itemBuilder: (context, index) {
          final manager = managers[index];
          final isSelected = manager.id == currentUserManager.id;
          final isDefault = manager == duendeManager;

          return Card(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : null,
            child: ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? Theme.of(context).primaryColor : null,
              ),
              title: Text(
                isDefault
                    ? 'Duende Demo (Default)'
                    : 'Custom Manager ${index + 1}',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
              subtitle: Text(
                manager.clientCredentials.clientId,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: isDefault
                  ? null
                  : IconButton(
                      onPressed: () => _removeManager(index),
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                    ),
              onTap: () => _selectManager(manager),
            ),
          );
        },
      ),
    );
  }
}
