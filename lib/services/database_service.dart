import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/direction.dart';
import '../models/processing_job.dart';

class DatabaseService {
  static const String _databaseName = 'recipe_ripper.db';
  static const int _databaseVersion = 1;

  static const String tableRecipes = 'recipes';
  static const String tableIngredients = 'ingredients';
  static const String tableDirections = 'directions';
  static const String tableMetadata = 'recipe_metadata';
  static const String tableProcessingJobs = 'processing_jobs';

  Database? _database;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create recipes table
    await db.execute('''
      CREATE TABLE $tableRecipes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        source_url TEXT,
        source_platform TEXT,
        thumbnail_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create ingredients table
    await db.execute('''
      CREATE TABLE $tableIngredients (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        quantity REAL,
        unit TEXT,
        item TEXT NOT NULL,
        notes TEXT,
        order_index INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (recipe_id) REFERENCES $tableRecipes (id) ON DELETE CASCADE
      )
    ''');

    // Create directions table
    await db.execute('''
      CREATE TABLE $tableDirections (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        step_number INTEGER NOT NULL,
        text TEXT NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES $tableRecipes (id) ON DELETE CASCADE
      )
    ''');

    // Create recipe metadata table
    await db.execute('''
      CREATE TABLE $tableMetadata (
        recipe_id TEXT PRIMARY KEY,
        transcript TEXT,
        ocr_text TEXT,
        processing_time_seconds INTEGER,
        video_duration TEXT,
        frame_count INTEGER,
        FOREIGN KEY (recipe_id) REFERENCES $tableRecipes (id) ON DELETE CASCADE
      )
    ''');

    // Create processing jobs table
    await db.execute('''
      CREATE TABLE $tableProcessingJobs (
        id TEXT PRIMARY KEY,
        source_url TEXT,
        local_video_path TEXT,
        status TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        current_step TEXT,
        error_message TEXT,
        created_at TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        recipe_id TEXT,
        FOREIGN KEY (recipe_id) REFERENCES $tableRecipes (id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for better query performance
    await db.execute(
      'CREATE INDEX idx_ingredients_recipe_id ON $tableIngredients(recipe_id)',
    );
    await db.execute(
      'CREATE INDEX idx_directions_recipe_id ON $tableDirections(recipe_id)',
    );
    await db.execute(
      'CREATE INDEX idx_recipes_created_at ON $tableRecipes(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_processing_jobs_status ON $tableProcessingJobs(status)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here in future versions
  }

  // Recipe CRUD operations
  Future<String> insertRecipe(Recipe recipe) async {
    final db = await database;
    final id = recipe.id ?? _uuid.v4();

    final recipeWithId = recipe.copyWith(id: id);

    await db.insert(
      tableRecipes,
      recipeWithId.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Insert ingredients
    for (var i = 0; i < recipeWithId.ingredients.length; i++) {
      final ingredient = recipeWithId.ingredients[i];
      await insertIngredient(
        ingredient.copyWith(
          id: ingredient.id ?? _uuid.v4(),
          recipeId: id,
          order: i,
        ),
      );
    }

    // Insert directions
    for (var i = 0; i < recipeWithId.directions.length; i++) {
      final direction = recipeWithId.directions[i];
      await insertDirection(
        direction.copyWith(
          id: direction.id ?? _uuid.v4(),
          recipeId: id,
          stepNumber: i + 1,
        ),
      );
    }

    // Insert metadata if present
    if (recipeWithId.metadata != null) {
      await insertRecipeMetadata(id, recipeWithId.metadata!);
    }

    return id;
  }

  Future<Recipe?> getRecipe(String id) async {
    final db = await database;

    final recipeMaps = await db.query(
      tableRecipes,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (recipeMaps.isEmpty) return null;

    final recipe = Recipe.fromMap(recipeMaps.first);
    final ingredients = await getIngredients(id);
    final directions = await getDirections(id);
    final metadata = await getRecipeMetadata(id);

    return recipe.copyWith(
      ingredients: ingredients,
      directions: directions,
      metadata: metadata,
    );
  }

  Future<List<Recipe>> getAllRecipes() async {
    final db = await database;

    final recipeMaps = await db.query(tableRecipes, orderBy: 'created_at DESC');

    final recipes = <Recipe>[];
    for (final map in recipeMaps) {
      final recipe = Recipe.fromMap(map);
      final ingredients = await getIngredients(recipe.id!);
      final directions = await getDirections(recipe.id!);
      final metadata = await getRecipeMetadata(recipe.id!);

      recipes.add(
        recipe.copyWith(
          ingredients: ingredients,
          directions: directions,
          metadata: metadata,
        ),
      );
    }

    return recipes;
  }

  Future<void> updateRecipe(Recipe recipe) async {
    if (recipe.id == null) {
      throw ArgumentError('Recipe ID cannot be null for update');
    }

    final db = await database;

    await db.update(
      tableRecipes,
      recipe.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [recipe.id],
    );

    // Update ingredients
    await deleteIngredients(recipe.id!);
    for (var i = 0; i < recipe.ingredients.length; i++) {
      final ingredient = recipe.ingredients[i];
      await insertIngredient(
        ingredient.copyWith(
          id: ingredient.id ?? _uuid.v4(),
          recipeId: recipe.id,
          order: i,
        ),
      );
    }

    // Update directions
    await deleteDirections(recipe.id!);
    for (var i = 0; i < recipe.directions.length; i++) {
      final direction = recipe.directions[i];
      await insertDirection(
        direction.copyWith(
          id: direction.id ?? _uuid.v4(),
          recipeId: recipe.id,
          stepNumber: i + 1,
        ),
      );
    }
  }

  Future<void> deleteRecipe(String id) async {
    final db = await database;
    await db.delete(tableRecipes, where: 'id = ?', whereArgs: [id]);
  }

  // Ingredient operations
  Future<void> insertIngredient(Ingredient ingredient) async {
    final db = await database;
    await db.insert(
      tableIngredients,
      ingredient.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Ingredient>> getIngredients(String recipeId) async {
    final db = await database;
    final maps = await db.query(
      tableIngredients,
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'order_index ASC',
    );

    return maps.map((map) => Ingredient.fromMap(map)).toList();
  }

  Future<void> deleteIngredients(String recipeId) async {
    final db = await database;
    await db.delete(
      tableIngredients,
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
  }

  // Direction operations
  Future<void> insertDirection(Direction direction) async {
    final db = await database;
    await db.insert(
      tableDirections,
      direction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Direction>> getDirections(String recipeId) async {
    final db = await database;
    final maps = await db.query(
      tableDirections,
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'step_number ASC',
    );

    return maps.map((map) => Direction.fromMap(map)).toList();
  }

  Future<void> deleteDirections(String recipeId) async {
    final db = await database;
    await db.delete(
      tableDirections,
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
  }

  // Metadata operations
  Future<void> insertRecipeMetadata(
    String recipeId,
    RecipeMetadata metadata,
  ) async {
    final db = await database;
    final map = metadata.toMap();
    map['recipe_id'] = recipeId;

    await db.insert(
      tableMetadata,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RecipeMetadata?> getRecipeMetadata(String recipeId) async {
    final db = await database;
    final maps = await db.query(
      tableMetadata,
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );

    if (maps.isEmpty) return null;

    return RecipeMetadata.fromMap(maps.first);
  }

  // Processing job operations
  Future<void> insertProcessingJob(ProcessingJob job) async {
    final db = await database;
    await db.insert(
      tableProcessingJobs,
      job.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ProcessingJob?> getProcessingJob(String id) async {
    final db = await database;
    final maps = await db.query(
      tableProcessingJobs,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    return ProcessingJob.fromMap(maps.first);
  }

  Future<List<ProcessingJob>> getAllProcessingJobs() async {
    final db = await database;
    final maps = await db.query(
      tableProcessingJobs,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => ProcessingJob.fromMap(map)).toList();
  }

  Future<List<ProcessingJob>> getActiveProcessingJobs() async {
    final db = await database;
    final maps = await db.query(
      tableProcessingJobs,
      where: 'status IN (?, ?, ?, ?)',
      whereArgs: [
        ProcessingStatus.downloading.name,
        ProcessingStatus.transcribing.name,
        ProcessingStatus.extractingText.name,
        ProcessingStatus.parsing.name,
      ],
      orderBy: 'created_at ASC',
    );

    return maps.map((map) => ProcessingJob.fromMap(map)).toList();
  }

  Future<void> updateProcessingJob(ProcessingJob job) async {
    final db = await database;
    await db.update(
      tableProcessingJobs,
      job.toMap(),
      where: 'id = ?',
      whereArgs: [job.id],
    );
  }

  Future<void> deleteProcessingJob(String id) async {
    final db = await database;
    await db.delete(tableProcessingJobs, where: 'id = ?', whereArgs: [id]);
  }

  // Utility methods
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(tableRecipes);
    await db.delete(tableIngredients);
    await db.delete(tableDirections);
    await db.delete(tableMetadata);
    await db.delete(tableProcessingJobs);
  }
}
