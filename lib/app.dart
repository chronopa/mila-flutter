import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/mistakes_page.dart';
import 'pages/sessions_page.dart';
import 'pages/settings_page.dart';
import 'pages/vocab_page.dart';
import 'services/app_state.dart';
import 'services/storage_service.dart';

class MilaApp extends StatefulWidget {
  const MilaApp({super.key});

  @override
  State<MilaApp> createState() => _MilaAppState();
}

class _MilaAppState extends State<MilaApp> {
  final AppState _state = AppState(StorageService());

  @override
  void initState() {
    super.initState();
    _state.load();
  }

  @override
  void dispose() {
    _state.stopSession();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) => MaterialApp(
        title: 'mila',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2D4FD6), useMaterial3: true),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7894FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: _state.data.settings.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: RootPage(state: _state),
      ),
    );
  }
}

/// Το κέλυφος με τις τέσσερις καρτέλες και το κουμπί ρυθμίσεων.
class RootPage extends StatefulWidget {
  const RootPage({super.key, required this.state});

  final AppState state;

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  AppState get _state => widget.state;
  int _index = 0;

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsPage(state: _state)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/images/mila-logo.png', width: 32, height: 32),
                ),
                const SizedBox(width: 10),
                const Text('mila'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Ρυθμίσεις',
                onPressed: _openSettings,
              ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            children: [
              HomePage(state: _state),
              MistakesPage(state: _state),
              VocabPage(state: _state),
              SessionsPage(state: _state),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Συνομιλία'),
              NavigationDestination(icon: Icon(Icons.error_outline), label: 'Λάθη'),
              NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Λεξιλόγιο'),
              NavigationDestination(icon: Icon(Icons.history), label: 'Συνομιλίες'),
            ],
          ),
        );
      },
    );
  }
}
