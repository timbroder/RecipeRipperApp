import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/processing_job.dart';
import '../services/database_service.dart';

/// State management provider for recipes.
/// Handles loading, caching, and updating recipes.
class RecipeProvider extends ChangeNotifier {
  final DatabaseService _databaseService;

  List<Recipe> _recipes = [];
  List<ProcessingJob> _processingJobs = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _searchQuery;

  RecipeProvider(this._databaseService);

  // Getters
  List<Recipe> get recipes => _searchQuery != null && _searchQuery!.isNotEmpty
      ? _filteredRecipes
      : _recipes;

  List<Recipe> get _filteredRecipes {
    if (_searchQuery == null || _searchQuery!.isEmpty) return _recipes;
    final query = _searchQuery!.toLowerCase();
    return _recipes.where((recipe) {
      // Search in title
      if (recipe.title.toLowerCase().contains(query)) return true;
      // Search in ingredients
      for (final ingredient in recipe.ingredients) {
        if (ingredient.item.toLowerCase().contains(query)) return true;
      }
      // Search in source platform
      if (recipe.sourcePlatform?.toLowerCase().contains(query) ?? false) {
        return true;
      }
      return false;
    }).toList();
  }

  List<ProcessingJob> get processingJobs => _processingJobs;
  List<ProcessingJob> get activeJobs =>
      _processingJobs.where((job) => job.isActive).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get searchQuery => _searchQuery;
  bool get hasRecipes => _recipes.isNotEmpty;
  bool get hasActiveJobs => activeJobs.isNotEmpty;

  /// Loads all recipes from the database.
  Future<void> loadRecipes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _recipes = await _databaseService.getAllRecipes();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load recipes: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads processing jobs from the database.
  Future<void> loadProcessingJobs() async {
    try {
      _processingJobs = await _databaseService.getAllProcessingJobs();
      notifyListeners();
    } catch (e) {
      // Silently fail for processing jobs
      debugPrint('Failed to load processing jobs: $e');
    }
  }

  /// Refreshes both recipes and processing jobs.
  Future<void> refresh() async {
    await Future.wait([
      loadRecipes(),
      loadProcessingJobs(),
    ]);
  }

  /// Gets a single recipe by ID.
  Future<Recipe?> getRecipe(String id) async {
    try {
      return await _databaseService.getRecipe(id);
    } catch (e) {
      _errorMessage = 'Failed to load recipe: $e';
      notifyListeners();
      return null;
    }
  }

  /// Adds a new recipe.
  Future<Recipe?> addRecipe(Recipe recipe) async {
    try {
      final id = await _databaseService.insertRecipe(recipe);
      final newRecipe = recipe.copyWith(id: id);
      _recipes.insert(0, newRecipe);
      notifyListeners();
      return newRecipe;
    } catch (e) {
      _errorMessage = 'Failed to add recipe: $e';
      notifyListeners();
      return null;
    }
  }

  /// Updates an existing recipe.
  Future<bool> updateRecipe(Recipe recipe) async {
    try {
      await _databaseService.updateRecipe(recipe);
      final index = _recipes.indexWhere((r) => r.id == recipe.id);
      if (index >= 0) {
        _recipes[index] = recipe;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update recipe: $e';
      notifyListeners();
      return false;
    }
  }

  /// Deletes a recipe.
  Future<bool> deleteRecipe(String id) async {
    try {
      await _databaseService.deleteRecipe(id);
      _recipes.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete recipe: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sets the search query.
  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Clears the search query.
  void clearSearch() {
    _searchQuery = null;
    notifyListeners();
  }

  /// Clears any error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Updates a processing job in the list.
  void updateProcessingJob(ProcessingJob job) {
    final index = _processingJobs.indexWhere((j) => j.id == job.id);
    if (index >= 0) {
      _processingJobs[index] = job;
    } else {
      _processingJobs.insert(0, job);
    }
    notifyListeners();
  }

  /// Removes a processing job from the list.
  void removeProcessingJob(String jobId) {
    _processingJobs.removeWhere((j) => j.id == jobId);
    notifyListeners();
  }
}
