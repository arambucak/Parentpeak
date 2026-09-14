import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'package:flutter/material.dart';
import 'package:parentpeak/logic/marketplace_service.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);
  late TabController _educationSubTabController;
  List<Provider> _allProviders = [];
  String? _selectedCategory;
  bool _isLoading = true;
  String? _error;
  double _maxPrice = 50;
  double _minRating = 1;
  final TextEditingController _searchController = TextEditingController();
  bool _showEducationSubTabs = false; // Nur für Bildung

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _educationSubTabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _educationSubTabController.addListener(_onEducationSubTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    setState(() {
      _selectedCategory = null;
      _searchController.clear();
      if (_tabController.index == 0) {
        _showEducationSubTabs = true;
      } else {
        _showEducationSubTabs = false;
      }
    });
  }

  void _onEducationSubTabChanged() {
    setState(() {
      _selectedCategory = null;
      _searchController.clear();
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final providers = await MarketplaceService.getAllProviders();

      setState(() {
        _allProviders = providers;
        _isLoading = false;
        _error = null;
        // Setze Sub-Tabs für Bildung wenn Tab 0 aktiv ist
        if (_tabController.index == 0) {
          _showEducationSubTabs = true;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Laden: $e';
        _isLoading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = null;
      _maxPrice = 50;
      _minRating = 1;
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _educationSubTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'marketplace')),
        elevation: 0,
        backgroundColor: Colors.blue.shade600,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.school_rounded),
              text: 'Bildung',
            ),
            Tab(
              icon: Icon(Icons.people_rounded),
              text: 'Betreuung',
            ),
            Tab(
              icon: Icon(Icons.shopping_bag_rounded),
              text: 'Basar',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(_t('loading')),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text(AppStringsManager.getString(
                            languageService.currentLanguage, 'try_again')),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Bildung
                    _buildTabContent(0),
                    // Tab 2: Betreuung
                    _buildTabContent(1),
                    // Tab 3: Basar
                    _buildTabContent(2),
                  ],
                ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    // Für Bildung-Tab: Zeige Sub-Tabs für Nachhilfe und Außerschulisch
    if (tabIndex == 0 && _showEducationSubTabs && _selectedCategory == null) {
      return _buildEducationSubTabs();
    }

    // Bekome alle Provider für diesen Tab
    List<Provider> tabProviders;

    if (tabIndex == 0) {
      tabProviders = _allProviders
          .where((p) => p.categoryGroup == 'Bildungsangebote')
          .toList();
    } else if (tabIndex == 1) {
      tabProviders =
          _allProviders.where((p) => p.categoryGroup == 'Betreuung').toList();
    } else {
      tabProviders = _allProviders
          .where((p) => p.categoryGroup == 'Kaufen & Verkaufen')
          .toList();
    }

    // Bekome alle einzigartigen Kategorien für diesen Tab
    final uniqueCategories =
        tabProviders.map((p) => p.category).toSet().toList();
    uniqueCategories.sort();

    // Falls keine Kategorie ausgewählt, zeige Kategorien
    if (_selectedCategory == null) {
      return _buildCategorySelector(uniqueCategories, tabIndex);
    }

    // Falls Kategorie ausgewählt, zeige Anbieter für diese Kategorie
    final categoryProviders =
        tabProviders.where((p) => p.category == _selectedCategory).toList();

    // Wende Filter an
    List<Provider> filtered = categoryProviders;

    // Nach Preis filtern (nur für Betreuung & Bildung, nicht für Basar)
    if (tabIndex < 2) {
      filtered = filtered.where((p) => p.price <= _maxPrice).toList();
    }

    // Nach Bewertung filtern
    filtered = filtered.where((p) => p.rating >= _minRating).toList();

    // Nach Suchtext filtern
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query))
          .toList();
    }

    return Column(
      children: [
        // Zurück-Button und Kategorie-Name
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => _selectedCategory = null);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedCategory ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),

        // Suchleiste
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Anbieter suchen...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter Section - nur für Tab 0 und 1
        if (tabIndex < 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_t('market_filter'),
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                      onPressed: _resetFilters,
                      child: Text(AppStringsManager.getString(
                          languageService.currentLanguage, 'reset_filter')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Preis-Slider
                Text('Max. Preis: €${_maxPrice.toStringAsFixed(0)}/Stunde'),
                Slider(
                  value: _maxPrice,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() => _maxPrice = value);
                  },
                ),
                const SizedBox(height: 12),
                // Rating Filter
                Text('Min. Bewertung: ${_minRating.toStringAsFixed(1)} ⭐'),
                Slider(
                  value: _minRating,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (value) {
                    setState(() => _minRating = value);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

        // Anbieter-Liste
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(AppStringsManager.getString(
                          languageService.currentLanguage, 'no_offers')),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _resetFilters,
                        child: Text(AppStringsManager.getString(
                            languageService.currentLanguage, 'reset_filter')),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final provider = filtered[index];
                    return _buildProviderCard(provider);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEducationSubTabs() {
    return Column(
      children: [
        // Sub-Tabs für Bildung
        TabBar(
          controller: _educationSubTabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.school_rounded),
              text: 'Nachhilfe',
            ),
            Tab(
              icon: Icon(Icons.palette_rounded),
              text: 'Außerschulisch',
            ),
          ],
        ),
        // Sub-Tab Content
        Expanded(
          child: TabBarView(
            controller: _educationSubTabController,
            children: [
              // Nachhilfe Sub-Tab
              _buildEducationSubTabContent('Nachhilfe'),
              // Außerschulisch Sub-Tab
              _buildEducationSubTabContent('Außerschulisch'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEducationSubTabContent(String educationType) {
    // Bekome alle Education-Provider für diesen Sub-Tab
    List<Provider> educationProviders = _allProviders
        .where((p) =>
            p.categoryGroup == 'Bildungsangebote' &&
            p.educationType == educationType)
        .toList();

    // Bekome alle einzigartigen Kategorien
    final uniqueCategories =
        educationProviders.map((p) => p.category).toSet().toList();
    uniqueCategories.sort();

    // Falls keine Kategorie ausgewählt, zeige Kategorien
    if (_selectedCategory == null) {
      return _buildEducationCategorySelector(uniqueCategories);
    }

    // Falls Kategorie ausgewählt, zeige Anbieter
    final categoryProviders = educationProviders
        .where((p) => p.category == _selectedCategory)
        .toList();

    // Wende Filter an
    List<Provider> filtered = categoryProviders;
    filtered = filtered.where((p) => p.price <= _maxPrice).toList();
    filtered = filtered.where((p) => p.rating >= _minRating).toList();

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query))
          .toList();
    }

    return Column(
      children: [
        // Zurück-Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => _selectedCategory = null);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedCategory ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),

        // Suchleiste
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Anbieter suchen...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_t('market_filter'),
                      style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: _resetFilters,
                    child: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'reset_filter')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Max. Preis: €${_maxPrice.toStringAsFixed(0)}/Stunde'),
              Slider(
                value: _maxPrice,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (value) {
                  setState(() => _maxPrice = value);
                },
              ),
              const SizedBox(height: 12),
              Text('Min. Bewertung: ${_minRating.toStringAsFixed(1)} ⭐'),
              Slider(
                value: _minRating,
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (value) {
                  setState(() => _minRating = value);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Anbieter-Liste
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(AppStringsManager.getString(
                          languageService.currentLanguage, 'no_offers')),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _resetFilters,
                        child: Text(AppStringsManager.getString(
                            languageService.currentLanguage, 'reset_filter')),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final provider = filtered[index];
                    return _buildProviderCard(provider);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEducationCategorySelector(List<String> categories) {
    return Column(
      children: [
        // Suchleiste
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Kategorie suchen...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Kategorien als Grid
        Expanded(
          child: categories.isEmpty
              ? Center(
                  child: Text(_t('market_no_categories')),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _buildCategoryCard(category, 0);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(List<String> categories, int tabIndex) {
    return Column(
      children: [
        // Suchleiste für Kategorien
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Kategorie suchen...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Kategorien als Grid
        Expanded(
          child: categories.isEmpty
              ? Center(
                  child: Text(_t('market_no_categories')),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _buildCategoryCard(category, tabIndex);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String category, int tabIndex) {
    // Bekome Anzahl der Anbieter für diese Kategorie
    final providers =
        _allProviders.where((p) => p.category == category).toList();

    // Icons für verschiedene Kategorien
    IconData icon = Icons.school;
    if (tabIndex == 0) {
      if (category.contains('Mathematik')) icon = Icons.calculate;
      if (category.contains('Englisch')) icon = Icons.language;
      if (category.contains('Deutsch')) icon = Icons.menu_book;
      if (category.contains('Naturwissenschaften')) icon = Icons.science;
      if (category.contains('Fremdsprachen')) icon = Icons.translate;
      if (category.contains('Prüfung')) icon = Icons.assignment;
    } else if (tabIndex == 1) {
      icon = Icons.people;
    } else {
      icon = Icons.shopping_bag;
    }

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = category);
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.blue.shade600),
            const SizedBox(height: 12),
            Text(
              category,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '${providers.length} Anbieter',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(Provider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kopfzeile mit Foto und Name
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildProviderPhoto(provider, size: 80),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (provider.verified)
                            const Icon(Icons.verified,
                                color: Colors.blue, size: 20),
                        ],
                      ),
                      Text(
                        provider.category,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500),
                      ),
                      if (provider.age > 0)
                        Text(
                          '${provider.age} Jahre alt',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${provider.rating} (${provider.reviews})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (provider.price > 0)
                        Text(
                          '€${provider.price.toStringAsFixed(0)} ${provider.priceUnit}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Beschreibung
            Text(
              provider.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.message),
                  label: Text(_t('market_contact')),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Kontakt zu ${provider.name}')),
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.info),
                  label: Text(_t('market_details')),
                  onPressed: () {
                    _showProviderDetails(provider);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProviderDetails(Provider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header mit Foto
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildProviderPhoto(provider, size: 120),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      provider.name,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    if (provider.age > 0)
                      Text(
                        '${provider.age} Jahre, ${provider.location}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Details
              _detailRow('Bereich', provider.category),
              _detailRow('Spezialisierung', provider.subcategory),
              if (provider.price > 0)
                _detailRow('Preis', '€${provider.price}/${provider.priceUnit}'),
              _detailRow(
                  'Bewertung', '${provider.rating} ⭐ (${provider.reviews})'),
              if (provider.languages.isNotEmpty)
                _detailRow('Sprachen', provider.languages.join(', ')),
              _detailRow('Erreichbarkeit', provider.availability),
              const SizedBox(height: 16),
              const Text(
                'Beschreibung',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(provider.description),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.message),
                  label: Text(AppStringsManager.getString(
                      languageService.currentLanguage, 'contact_now')),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Nachricht an ${provider.name} gesendet!')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderPhoto(Provider provider, {required double size}) {
    if (provider.photo.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey[300],
        child: Icon(Icons.person, size: size / 2),
      );
    }

    return Image.network(
      provider.photo,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          color: Colors.grey[300],
          child: Icon(Icons.person, size: size / 2),
        );
      },
    );
  }
}
