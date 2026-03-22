// ============================================================================
// SUDOKU DIFFICULTY SCALING ANALYSIS TEST
// ============================================================================
//
// PURPOSE:
// This test generates sample puzzles at each difficulty level, solves them
// with a step-by-step logical solver, and produces two analysis tables:
//
//   1. Difficulty Ratings — avg Sudoku Explainer (SE) rating and range per level
//   2. Technique Frequency — what % of puzzles at each level used each technique
//
// These tables validate that puzzle generation produces correct difficulty
// distributions and that harder levels genuinely require more advanced techniques.
//
// HOW TO ADAPT FOR YOUR APP:
// ─────────────────────────────────────────────────────────────────────────────
// You need three components in your codebase:
//
//   1. A PUZZLE GENERATOR that can produce puzzles at a target difficulty.
//      - Must accept a difficulty level (enum or similar)
//      - Should accept a seed for reproducibility
//      - Returns a puzzle grid (9x9 int grid, 0 = empty cell)
//
//   2. A STEP-BY-STEP LOGICAL SOLVER that returns which techniques it used.
//      - Must solve the puzzle one technique at a time (not just brute-force)
//      - Must report the set of techniques used during the solve
//      - Each technique must have a difficulty rating (we use 1-10)
//
//   3. A TECHNIQUE ENUM (or equivalent) where each technique has:
//      - A human-readable display name (e.g., "Naked Pair")
//      - A difficulty rating integer (e.g., 3)
//
// Replace the imports and the three adapter functions marked with "ADAPT"
// below to wire in your own generator, solver, and technique types.
// ============================================================================
//
// DIFFICULTY RATING SYSTEM (SE-aligned, 1-10 scale):
// ─────────────────────────────────────────────────────────────────────────────
// The Sudoku Explainer (SE) is the de facto community standard for rating
// puzzle difficulty. It assigns a decimal rating (1.0-11.9) based on the
// hardest technique required to solve a puzzle logically. We map SE ranges
// to integer ratings 1-10:
//
// Rating | Label       | SE Range  | Techniques
// -------|-------------|-----------|-------------------------------------------
//   1    | Easy        | 1.0-2.3   | Full House, Naked Single, Hidden Single
//   2    | Medium      | 2.6-2.8   | Pointing, Claiming
//   3    | Hard        | 3.0-3.5   | Naked Pair, Hidden Pair, X-Wing,
//        |             |           | Skyscraper, 2-String Kite, Empty Rectangle
//   4    | Expert      | 3.6-4.4   | Naked Triple, Hidden Triple, Swordfish,
//        |             |           | XY-Wing, XYZ-Wing, X-Chain, Turbot Fish
//   5    | Pro (low)   | 4.5-5.0   | Naked Quad, UR Type 1/2/4, W-Wing,
//        |             |           | Remote Pairs
//   6    | Pro (high)  | 5.0-5.4   | Hidden Quad, Finned X-Wing/Swordfish,
//        |             |           | Sue de Coq, Anti-UR, BUG+1, XY-Chain,
//        |             |           | UR Type 3/5/6, Fireworks
//   7    | Master (low)| 5.5-6.0   | Jellyfish, Finned Jellyfish,
//        |             |           | Simple Coloring, 3D Medusa, Oddagon
//   8    | Master (mid)| 6.0-6.6   | AIC, Nice Loop, Grouped AIC,
//        |             |           | ALS-XZ, ALS-XY-Wing
//   9    | Master (hi) | 6.6-7.5+  | Branched AIC, Death Blossom,
//        |             |           | Impossible Pattern, Forcing Chains
//  10    | Diabolical  | N/A       | Backtracking (brute force, last resort)
//
// GENERATOR CONSTRAINTS:
// ─────────────────────────────────────────────────────────────────────────────
// The puzzle generator enforces difficulty by constraining the technique
// rating of generated puzzles. Each difficulty maps to a
// (minTechniqueRating, maxTechniqueRating) pair:
//
//   Easy:    (1, 1) — singles only
//   Medium:  (2, 2) — must require Pointing or Claiming
//   Hard:    (3, 3) — must require Pairs/X-Wing level techniques
//   Expert:  (4, 4) — must require Triples/Swordfish/Wings
//   Pro:     (5, 6) — must require Quads/URs/Finned Fish
//   Master:  (7, 9) — must require Jellyfish/AIC/Forcing Chains
//
// Generation works by:
//   1. Generate a random complete solution grid
//   2. Remove cells one at a time, checking solvability at each step
//   3. Refine via hill-climbing: swap filled/empty cells to push the
//      hardest-technique-used into the target [min, max] range
//   4. Score the result: distance=0 means technique rating is in range
//   5. Repeat up to N attempts, keeping the best puzzle found
//
// Harder difficulties get more generation attempts since qualifying puzzles
// are rarer (e.g., Easy: 20 attempts, Pro: 80, Master: 120).
//
// DIFFICULTY LABEL is derived from the HARDEST technique's rating, not from
// a composite score. This prevents step-count or variety bonuses from
// inflating the label beyond what the techniques warrant.
//
// EXPECTED OUTPUT (from our production solver, 20 samples per difficulty):
// ─────────────────────────────────────────────────────────────────────────────
//
// Difficulty Ratings
//
//                 Easy      Medium    Hard      Expert    Pro       Master
// ────────────────────────────────────────────────────────────────────────
// Avg SE Rating   1.00      2.00      3.55      4.10      5.67      6.15
// Rating Range    1-1       2-2       3-5       4-5       5-7       7-9
//
// Technique Frequency by Difficulty
//
// Technique               Easy      Medium    Hard      Expert    Pro       Master
// ────────────────────────────────────────────────────────────────────────────────
// Full House              100%      100%      100%      100%      100%      100%
// Hidden Single           5%        100%      100%      100%      100%      100%
// Naked Single            100%      100%      100%      100%      100%      100%
// Claiming                -         10%       35%       30%       50%       70%
// Pointing                -         90%       85%       85%       80%       95%
// 2-String Kite           -         -         5%        10%       15%       35%
// Hidden Pair             -         -         -         -         -         5%
// Naked Pair              -         -         60%       50%       60%       45%
// Skyscraper              -         -         35%       25%       20%       10%
// X-Wing                  -         -         -         20%       15%       15%
// Hidden Triple           -         -         -         -         -         5%
// Naked Triple            -         -         20%       50%       25%       55%
// Swordfish               -         -         -         -         -         5%
// X-Chain                 -         -         -         5%        5%        -
// XY-Wing                 -         -         15%       60%       10%       20%
// XYZ-Wing                -         -         10%       20%       10%       15%
// Naked Quad              -         -         10%       10%       30%       25%
// UR Type 1               -         -         -         -         -         5%
// UR Type 2               -         -         -         -         10%       5%
// W-Wing                  -         -         -         -         -         15%
// Anti-UR                 -         -         -         -         5%        15%
// UR Type 5               -         -         -         -         5%        5%
// UR Type 6               -         -         -         -         -         10%
// XY-Chain                -         -         -         -         25%       35%
// 3D Medusa               -         -         -         -         55%       85%
// Simple Coloring         -         -         -         -         -         5%
// AIC                     -         -         -         -         -         25%
// ALS-XZ                  -         -         -         -         -         5%
// Nice Loop               -         -         -         -         -         5%
// Branched AIC            -         -         -         -         -         5%
//
// KEY OBSERVATIONS:
// - Easy/Medium have tight rating ranges (exactly 1 and 2), confirming the
//   generator reliably constrains to basic techniques.
// - Hard/Expert occasionally exceed their target rating (range 3-5 and 4-5)
//   because the generator's hill-climbing may settle on a nearby solution.
//   This is acceptable — the puzzles are still appropriately challenging.
// - Pro puzzles center around rating 5-6 with occasional 7s from the
//   refinement pass overshooting slightly.
// - Master shows the broadest range (7-9) as expected, since this tier
//   encompasses the most advanced techniques.
// - 3D Medusa (coloring-based) is the workhorse technique for Pro/Master,
//   appearing in 55% of Pro and 85% of Master puzzles.
// - Basic techniques (Full House, Naked Single) appear at 100% across all
//   levels because even hard puzzles use simple techniques for easy cells.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/difficulty.dart';
import 'package:sudoku_app/services/sudoku_generator.dart';
import 'package:sudoku_solver/sudoku_solver.dart';

// ============================================================================
// ADAPT: These three functions are the interface between this test and your
// codebase. Replace their implementations to wire in your own types.
// ============================================================================

/// ADAPT: Convert your puzzle object to a 9x9 int grid (0 = empty).
///
/// This is needed because generators often return rich puzzle objects with
/// Cell classes, candidate lists, etc. The solver and this analysis only
/// need the raw int values.
///
/// Your version might look like:
///   return puzzle.board.map((row) => row.map((cell) => cell.value).toList()).toList();
List<List<int>> _extractValues(puzzle) {
  return List.generate(
    9,
    (r) => List.generate(9, (c) {
      final cell = puzzle.grid[r][c];
      return cell.value ?? 0;
    }),
  );
}

/// ADAPT: Generate a puzzle and solve it, returning (rating, techniquesUsed).
///
/// This function encapsulates the generate-then-solve workflow. Replace the
/// generator and solver calls with your own equivalents.
///
/// The key contract:
///   - Generate a puzzle at the given difficulty with a deterministic seed
///   - Solve it with a step-by-step logical solver
///   - Return the hardest technique's difficulty rating (int, 1-10)
///   - Return the set of all techniques used during the solve
///
/// If your solver doesn't track techniques as an enum, you can use strings
/// and adjust the analysis code below accordingly.
Future<({int rating, Set<Technique> techniques})> _generateAndAnalyze(
  SudokuGenerator generator,
  Difficulty difficulty,
  int seed,
) async {
  // Step 1: Generate a puzzle at the target difficulty.
  // The generator uses technique-guided removal and hill-climbing refinement
  // to produce puzzles whose hardest required technique falls within the
  // difficulty's (minRating, maxRating) constraint range.
  final puzzle = await generator.generateAsync(difficulty, seed: seed);

  // Step 2: Convert to a raw int grid for the solver.
  final values = _extractValues(puzzle);

  // Step 3: Solve step-by-step and collect technique usage.
  // SolverGrid.fromValues() initializes candidates for all empty cells.
  // SudokuSolver.solve() applies techniques in priority order (simplest
  // first), recording each step and technique used.
  final grid = SolverGrid.fromValues(values);
  final result = SudokuSolver.solve(grid);

  // Step 4: Extract the hardest technique's rating.
  // The difficulty label is determined by this single value — not by a
  // composite score. This prevents easy techniques used many times from
  // inflating the perceived difficulty.
  final rating = result.difficulty.hardestTechnique.difficultyRating ?? 1;

  return (rating: rating, techniques: result.techniquesUsed);
}

/// ADAPT: Map internal technique ratings (1-10) to SE-equivalent values.
///
/// Sudoku Explainer ratings are decimal (1.0-11.9). Our internal system uses
/// integers 1-10. This map provides representative SE midpoints for each
/// internal rating, used to compute the "Avg SE Rating" column.
///
/// These midpoints were chosen based on the SE ranges each rating covers:
///   Rating 1 -> SE 1.0-2.3, midpoint ~1.0 (most puzzles are basic singles)
///   Rating 2 -> SE 2.6-2.8, midpoint ~2.0
///   Rating 3 -> SE 3.0-3.5, midpoint ~3.0
///   ...and so on.
///
/// If you use a different rating scale, adjust these values to match your
/// system's mapping to SE ratings (or remove the SE column entirely and
/// just report raw ratings).
const _seRatingMidpoints = <int, double>{
  1: 1.0,  // Easy: Full House, Naked Single, Hidden Single
  2: 2.0,  // Medium: Pointing, Claiming
  3: 3.0,  // Hard: Naked Pair, X-Wing, Skyscraper, etc.
  4: 4.0,  // Expert: Naked Triple, Swordfish, XY-Wing, etc.
  5: 5.0,  // Pro (low): Naked Quad, Unique Rectangles, W-Wing
  6: 5.5,  // Pro (high): Finned Fish, Sue de Coq, XY-Chain
  7: 6.0,  // Master (low): 3D Medusa, Simple Coloring, Jellyfish
  8: 6.5,  // Master (mid): AIC, Nice Loop, ALS-XZ
  9: 7.0,  // Master (high): Branched AIC, Forcing Chains
  10: 10.0, // Diabolical: Backtracking (brute force)
};

// ============================================================================
// TEST
// ============================================================================

void main() {
  test('Difficulty scaling analysis (20 puzzles per difficulty)', () async {
    // ── Configuration ──
    // 20 samples per difficulty is enough to show clear technique frequency
    // patterns while keeping runtime reasonable (~1 min). Increase to 50-100
    // for more statistically robust results (at the cost of longer runtime).
    const samplesPerDifficulty = 20;

    // ADAPT: Instantiate your generator. Ours is stateless — yours may need
    // configuration (grid size, variant rules, etc.).
    final generator = SudokuGenerator();

    // ── Phase 1: Generate and solve puzzles ──
    // For each difficulty level, generate `samplesPerDifficulty` puzzles with
    // sequential seeds (1, 2, 3, ...) for reproducibility. Solve each and
    // record the hardest technique rating and full technique set.
    //
    // ADAPT: Replace `Difficulty.values` with your difficulty enum values.
    // The key requirement is that each difficulty has a displayName getter.
    final results = <Difficulty, List<({int rating, Set<Technique> techniques})>>{};

    for (final difficulty in Difficulty.values) {
      results[difficulty] = [];

      for (var seed = 1; seed <= samplesPerDifficulty; seed++) {
        final analysis = await _generateAndAnalyze(generator, difficulty, seed);
        results[difficulty]!.add(analysis);
      }
    }

    // ── Phase 2: Print Difficulty Ratings table ──
    // Shows two rows:
    //   Avg SE Rating — average SE-equivalent rating across all samples
    //   Rating Range  — min and max technique rating observed
    //
    // This table answers: "Are the difficulty levels well-separated?"
    // Good results show non-overlapping or minimally-overlapping ranges.
    // ignore: avoid_print
    print('\n${'=' * 80}');
    // ignore: avoid_print
    print('DIFFICULTY SCALING ANALYSIS ($samplesPerDifficulty puzzles per difficulty)');
    // ignore: avoid_print
    print('${'=' * 80}\n');

    final diffNames = Difficulty.values.map((d) => d.displayName).toList();
    // ignore: avoid_print
    print('Difficulty Ratings\n');
    // ignore: avoid_print
    print('${''.padRight(16)}${diffNames.map((n) => n.padRight(10)).join()}');
    // ignore: avoid_print
    print('${'─' * (16 + diffNames.length * 10)}');

    // Avg SE Rating: For each difficulty, map each puzzle's internal rating
    // to its SE midpoint, then average. This makes the output comparable to
    // published SE benchmarks from other Sudoku apps.
    final avgLine = StringBuffer('Avg SE Rating'.padRight(16));
    for (final difficulty in Difficulty.values) {
      final ratings = results[difficulty]!.map((r) => r.rating).toList();
      final avgSE = ratings
              .map((r) => _seRatingMidpoints[r] ?? r.toDouble())
              .reduce((a, b) => a + b) /
          ratings.length;
      avgLine.write(avgSE.toStringAsFixed(2).padRight(10));
    }
    // ignore: avoid_print
    print(avgLine);

    // Rating Range: Shows the spread of technique ratings within each
    // difficulty. Tight ranges (e.g., 1-1 for Easy) indicate reliable
    // generation. Wider ranges (e.g., 7-9 for Master) are expected when
    // the difficulty tier spans multiple technique levels.
    final rangeLine = StringBuffer('Rating Range'.padRight(16));
    for (final difficulty in Difficulty.values) {
      final ratings = results[difficulty]!.map((r) => r.rating).toList();
      final minR = ratings.reduce((a, b) => a < b ? a : b);
      final maxR = ratings.reduce((a, b) => a > b ? a : b);
      rangeLine.write('$minR–$maxR'.padRight(10));
    }
    // ignore: avoid_print
    print(rangeLine);

    // ── Phase 3: Print Technique Frequency table ──
    // For each technique that appeared in ANY puzzle, shows the percentage
    // of puzzles at each difficulty that required it.
    //
    // This table answers: "What techniques define each difficulty level?"
    // Key patterns to look for:
    //   - Basic techniques (Full House, Naked Single) should be ~100% everywhere
    //   - Intermediate techniques (Pointing, Claiming) should appear at Medium+
    //   - Advanced techniques should only appear at their rated difficulty and above
    //   - The "signature" technique for a difficulty should have high frequency
    //     at that level (e.g., 3D Medusa at 55-85% for Pro/Master)
    // ignore: avoid_print
    print('\nTechnique Frequency by Difficulty\n');
    // ignore: avoid_print
    print('${'Technique'.padRight(24)}${diffNames.map((n) => n.padRight(10)).join()}');
    // ignore: avoid_print
    print('${'─' * (24 + diffNames.length * 10)}');

    // Collect all techniques that appeared in any puzzle across all difficulties.
    // ADAPT: Replace `Technique` with your technique type. It needs
    // `difficultyRating` (int) and `displayName` (String) getters.
    final allTechniques = <Technique>{};
    for (final diffResults in results.values) {
      for (final r in diffResults) {
        allTechniques.addAll(r.techniques);
      }
    }

    // Sort by difficulty rating (ascending), then alphabetically within each
    // rating. This groups techniques by tier in the output table.
    final sortedTechniques = allTechniques.toList()
      ..sort((a, b) {
        final cmp = a.difficultyRating.compareTo(b.difficultyRating);
        if (cmp != 0) return cmp;
        return a.displayName.compareTo(b.displayName);
      });

    // Exclude backtracking — it's a brute-force fallback, not a logical
    // technique. If it appears, the puzzle exceeds the solver's repertoire.
    sortedTechniques.removeWhere((t) => t == Technique.backtracking);

    // Print one row per technique showing frequency at each difficulty.
    for (final technique in sortedTechniques) {
      final line = StringBuffer(technique.displayName.padRight(24));
      for (final difficulty in Difficulty.values) {
        final diffResults = results[difficulty]!;
        // Count how many puzzles at this difficulty used this technique.
        final count =
            diffResults.where((r) => r.techniques.contains(technique)).length;
        // Convert to percentage (0-100).
        final pct = (count / diffResults.length * 100).round();
        if (pct == 0) {
          line.write('—'.padRight(10)); // em-dash for "not used"
        } else {
          line.write('$pct%'.padRight(10));
        }
      }
      // ignore: avoid_print
      print(line);
    }

    // ignore: avoid_print
    print('\n${'=' * 80}\n');

    // ── Assertion ──
    // This test is primarily diagnostic — the real output is the printed
    // tables. The only hard assertion is that generation completed for all
    // difficulties (no crashes, no infinite loops, no timeouts).
    for (final difficulty in Difficulty.values) {
      expect(results[difficulty]!.length, samplesPerDifficulty,
          reason:
              '${difficulty.displayName} should have $samplesPerDifficulty samples');
    }

    // ── Optional: Add validation assertions ──
    // Uncomment and adapt these if you want the test to FAIL when difficulty
    // calibration drifts:
    //
    // // Easy must be exactly rating 1 (singles only).
    // for (final r in results[Difficulty.easy]!) {
    //   expect(r.rating, 1, reason: 'Easy puzzle exceeded rating 1');
    // }
    //
    // // Medium must be exactly rating 2 (pointing/claiming).
    // for (final r in results[Difficulty.medium]!) {
    //   expect(r.rating, 2, reason: 'Medium puzzle exceeded rating 2');
    // }
    //
    // // Hard should be rating 3 (with occasional 4-5 acceptable).
    // final hardInRange = results[Difficulty.hard]!
    //     .where((r) => r.rating >= 3 && r.rating <= 5).length;
    // expect(hardInRange, greaterThanOrEqualTo(samplesPerDifficulty * 0.8),
    //     reason: 'Less than 80% of Hard puzzles in rating 3-5');
    //
    // // Master must be rating 7+.
    // for (final r in results[Difficulty.master]!) {
    //   expect(r.rating, greaterThanOrEqualTo(7),
    //       reason: 'Master puzzle below rating 7');
    // }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
