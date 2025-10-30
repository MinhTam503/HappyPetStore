import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_shop/data/datasources/local/apriori/apriori_logger.dart';

class AprioriAlgorithm {
  /// Fetches completed orders from Firestore and converts them to transactions of breeds.
  /// Each transaction is a set of unique breed strings purchased together in an order.
  Future<List<List<String>>> getAllBreedTransactions() async {
    try {
      debugPrint("🔍 Fetching completed orders...");
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection("orders")
          .where("statusOrder", isEqualTo: "Completed")
          .get();

      debugPrint("Found ${ordersSnapshot.docs.length} completed orders");

      Set<String> neededProductIds = {};
      for (var doc in ordersSnapshot.docs) {
        final items = List<Map<String, dynamic>>.from(doc["items"] ?? []);
        for (var item in items) {
          if (item["productId"] != null) {
            neededProductIds.add(item["productId"]);
          }
        }
      }

      if (neededProductIds.isEmpty) {
        debugPrint(" No product IDs found in orders");
        return [];
      }

      debugPrint(" Fetching breed info for ${neededProductIds.length} pets");

      // Tách ID thành nhiều phần nếu vượt quá giới hạn
      final chunks = <List<String>>[];
      final ids = neededProductIds.toList();
      for (var i = 0; i < ids.length; i += 10) {
        chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
      }

      Map<String, String> productIdToBreed = {};
      for (var chunk in chunks) {
        final petsSnapshot = await FirebaseFirestore.instance
            .collection("Pets")
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in petsSnapshot.docs) {
          final breed = doc.data()["breed"] as String?;
          if (breed != null) {
            productIdToBreed[doc.id] = breed;
          }
        }
      }

      debugPrint(" Found breed info for ${productIdToBreed.length} pets");

      List<List<String>> breedTransactions = [];
      for (var doc in ordersSnapshot.docs) {
        final items = List<Map<String, dynamic>>.from(doc["items"] ?? []);
        Set<String> breedSet = {};

        for (var item in items) {
          final breed = productIdToBreed[item["productId"]];
          if (breed != null) {
            breedSet.add(breed);
          }
        }

        if (breedSet.length >= 2) {
          breedTransactions.add(breedSet.toList());
        }
      }

      debugPrint(" Generated ${breedTransactions.length} breed transactions");
      return breedTransactions;
    } catch (e) {
      debugPrint(" Error in getAllBreedTransactions: $e");
      return [];
    }
  }

  /// Simple pair co-occurrence counter (legacy behavior), kept for reference.
  Map<String, Map<String, int>> analyzeBreedPairs(List<List<String>> transactions) {
    Map<String, Map<String, int>> pairCounts = {};

    for (var transaction in transactions) {
      for (int i = 0; i < transaction.length; i++) {
        for (int j = i + 1; j < transaction.length; j++) {
          String a = transaction[i];
          String b = transaction[j];

          // Đảm bảo a < b để tránh trùng lặp
          if (a.compareTo(b) > 0) {
            final temp = a;
            a = b;
            b = temp;
          }

          pairCounts[a] ??= {};
          pairCounts[a]![b] = (pairCounts[a]![b] ?? 0) + 1;
        }
      }
    }

    return pairCounts;
  }

  /// Legacy suggestion using pair frequencies only (no confidence/lift)
  List<String> suggestBreeds(String selectedBreed, Map<String, Map<String, int>> pairCounts) {
    Map<String, int> suggestions = {};

    if (pairCounts.containsKey(selectedBreed)) {
      suggestions.addAll(pairCounts[selectedBreed]!);
    }

    for (var entry in pairCounts.entries) {
      final otherBreed = entry.key;
      final subMap = entry.value;

      if (subMap.containsKey(selectedBreed)) {
        suggestions[otherBreed] =
            (suggestions[otherBreed] ?? 0) + subMap[selectedBreed]!;
      }
    }

    final sortedSuggestions = suggestions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedSuggestions.map((e) => e.key).toList();
  }

  /// Full Apriori-based suggestion pipeline with logging.
  /// Returns pet documents for top suggested breeds derived from association rules.
  Future<List<Map<String, dynamic>>> getSuggestedPets(
    String selectedBreed, {
    double minSupport = 0.02,
    double minConfidence = 0.2,
    int maxConsequents = 1,
    int maxItemsetSize = 3,
    int maxResults = 5,
  }) async {
    return getSuggestedPetsForBreeds([selectedBreed],
        minSupport: minSupport,
        minConfidence: minConfidence,
        maxConsequents: maxConsequents,
        maxItemsetSize: maxItemsetSize,
        maxResults: maxResults);
  }

  /// Multi-breed variant: rank suggestions considering any/all of the purchased breeds.
  Future<List<Map<String, dynamic>>> getSuggestedPetsForBreeds(
    List<String> selectedBreeds, {
    double minSupport = 0.02,
    double minConfidence = 0.2,
    int maxConsequents = 1,
    int maxItemsetSize = 3,
    int maxResults = 5,
  }) async {
    try {
      final runId = await AprioriLogger.startRun(parameters: {
        'selectedBreeds': selectedBreeds,
        'minSupport': minSupport,
        'minConfidence': minConfidence,
        'maxConsequents': maxConsequents,
        'maxItemsetSize': maxItemsetSize,
        'maxResults': maxResults,
      });
      final t0 = DateTime.now();
      debugPrint("🐾 Apriori: Getting suggestions for ${selectedBreeds.join(', ')}");

      final transactions = await getAllBreedTransactions();
      if (transactions.isEmpty) {
        await AprioriLogger.append(runId, type: 'NO_DATA', data: {
          'message': 'No transactions available',
        });
        return [];
      }

      // Basic stats
      final transactionCount = transactions.length;
      final avgSize = transactions.isEmpty
          ? 0
          : transactions.map((t) => t.length).reduce((a, b) => a + b) / transactions.length;

      await AprioriLogger.append(runId, type: 'TRANSACTIONS_INFO', data: {
        'transactionCount': transactionCount,
        'avgTransactionSize': avgSize,
      });

      final miningStart = DateTime.now();
      final miningResult = _mineApriori(transactions,
          minSupport: minSupport, minConfidence: minConfidence, maxItemsetSize: maxItemsetSize);
      final miningDuration = DateTime.now().difference(miningStart);

      // Extra diagnostics: support threshold and top L1 items
      final minSupportCount = _minSupportCount(minSupport, transactionCount);
      final l1 = miningResult.frequentItemsets[1] ?? const {};
      final topL1 = l1.entries
          .map((e) => {'item': e.key.first, 'supportCount': e.value})
          .toList()
        ..sort((a, b) => (b['supportCount'] as int).compareTo(a['supportCount'] as int));
      final topL1Trimmed = topL1.take(10).toList();

      // Include a few sample rules
      final ruleSamples = miningResult.rules.take(10).map((r) => {
            'antecedent': r.antecedent.toList(),
            'consequent': r.consequent.toList(),
            'supportCount': r.supportCount,
            'confidence': double.parse(r.confidence.toStringAsFixed(4)),
            'lift': double.parse(r.lift.toStringAsFixed(4)),
          }).toList();

      await AprioriLogger.append(runId, type: 'MINING_SUMMARY', data: {
        'durationMs': miningDuration.inMilliseconds,
        'minSupport': minSupport,
        'minSupportCount': minSupportCount,
        'frequentItemsets': miningResult.frequentItemsets.map((k, v) => MapEntry(k.toString(), v.length)),
        'topL1': topL1Trimmed,
        'ruleCount': miningResult.rules.length,
        'ruleSamples': ruleSamples,
      });

      // Build suggestions for the selected breeds using rules where antecedent intersects selection
      final rankedBreeds = _rankSuggestionsFromRulesMulti(
        selectedBreeds.toSet(),
        miningResult.rules,
        maxConsequents: maxConsequents,
      );

      await AprioriLogger.append(runId, type: 'SUGGESTED_BREEDS', data: {
        'count': rankedBreeds.length,
        'top': rankedBreeds.take(10).toList(),
      });

      if (rankedBreeds.isEmpty) {
        // Fallback to legacy co-occurrence pairs to still provide something
        final pairCounts = analyzeBreedPairs(transactions);
        final fallback = <String, int>{};
        for (final sel in selectedBreeds) {
          // boost breeds co-occurring with any selected
          final fromA = pairCounts[sel] ?? const {};
          for (final entry in fromA.entries) {
            fallback[entry.key] = (fallback[entry.key] ?? 0) + entry.value;
          }
          // also check where selected is in the RHS of the pair mapping
          for (final a in pairCounts.entries) {
            final count = a.value[sel];
            if (count != null) {
              fallback[a.key] = (fallback[a.key] ?? 0) + count;
            }
          }
        }
        // Remove selected breeds from suggestions
        for (final s in selectedBreeds) {
          fallback.remove(s);
        }

        final coOccurRanked = fallback.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final queryBreeds = coOccurRanked.map((e) => e.key).take(10).toList();

        if (queryBreeds.isEmpty) {
          // Last resort: use top L1 frequent items as generic popular suggestions
          final l1map = miningResult.frequentItemsets[1] ?? const {};
          final l1ranked = l1map.entries
              .map((e) => {'item': e.key.first, 'supportCount': e.value})
              .toList()
            ..sort((a, b) => (b['supportCount'] as int).compareTo(a['supportCount'] as int));
          final popularBreeds = l1ranked.map((e) => e['item'] as String).where((b) => !selectedBreeds.contains(b)).take(10).toList();

          if (popularBreeds.isEmpty) {
            await AprioriLogger.append(runId, type: 'NO_RULES', data: {
              'reason': 'No rules matched thresholds; pairs and popular also empty',
            });
            await AprioriLogger.complete(runId, success: true, metrics: {
              'totalTimeMs': DateTime.now().difference(t0).inMilliseconds,
              'selectedBreeds': selectedBreeds,
              'results': 0,
            });
            return [];
          }

          await AprioriLogger.append(runId, type: 'POPULAR_FALLBACK', data: {
            'popularCount': popularBreeds.length,
            'popularBreeds': popularBreeds,
          });

          final petsSnapshot = await FirebaseFirestore.instance
              .collection("Pets")
              .where("breed", whereIn: popularBreeds)
              .limit(maxResults)
              .get();
          final suggestions = petsSnapshot.docs
              .map((doc) => {
                    ...doc.data(),
                    'id': doc.id,
                  })
              .toList();

          await AprioriLogger.append(runId, type: 'PET_RESULTS', data: {
            'requestedBreeds': popularBreeds,
            'resultCount': suggestions.length,
          });

          await AprioriLogger.complete(runId, success: true, metrics: {
            'totalTimeMs': DateTime.now().difference(t0).inMilliseconds,
            'selectedBreeds': selectedBreeds,
            'results': suggestions.length,
          });
          return suggestions;
        }

        await AprioriLogger.append(runId, type: 'FALLBACK_PAIRS', data: {
          'pairSuggestionCount': queryBreeds.length,
          'topPairs': coOccurRanked.take(10).map((e) => {'breed': e.key, 'count': e.value}).toList(),
        });

        final petsSnapshot = await FirebaseFirestore.instance
            .collection("Pets")
            .where("breed", whereIn: queryBreeds)
            .limit(maxResults)
            .get();
        final suggestions = petsSnapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();

        await AprioriLogger.append(runId, type: 'PET_RESULTS', data: {
          'requestedBreeds': queryBreeds,
          'resultCount': suggestions.length,
        });

        await AprioriLogger.complete(runId, success: true, metrics: {
          'totalTimeMs': DateTime.now().difference(t0).inMilliseconds,
          'selectedBreeds': selectedBreeds,
          'results': suggestions.length,
        });
        return suggestions;
      }

      final queryBreeds = rankedBreeds.take(10).toList();
      final petsSnapshot = await FirebaseFirestore.instance
          .collection("Pets")
          .where("breed", whereIn: queryBreeds)
          .limit(maxResults)
          .get();

      final suggestions = petsSnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();

      await AprioriLogger.append(runId, type: 'PET_RESULTS', data: {
        'requestedBreeds': queryBreeds,
        'resultCount': suggestions.length,
      });

      await AprioriLogger.complete(runId, success: true, metrics: {
        'totalTimeMs': DateTime.now().difference(t0).inMilliseconds,
        'selectedBreeds': selectedBreeds,
        'results': suggestions.length,
      });
      return suggestions;
    } catch (e) {
      debugPrint(" Error in getSuggestedPets: $e");
      return [];
    }
  }

  // ===== Apriori mining internals =====

  _AprioriResult _mineApriori(
    List<List<String>> transactions, {
    required double minSupport,
    required double minConfidence,
    required int maxItemsetSize,
  }) {
    final transactionCount = transactions.length;
    final minSupportCount = _minSupportCount(minSupport, transactionCount);

    // L1 counts
    final itemCounts = <String, int>{};
    for (final t in transactions) {
      for (final item in t.toSet()) {
        itemCounts[item] = (itemCounts[item] ?? 0) + 1;
      }
    }
    Map<Set<String>, int> lk = {
      for (final e in itemCounts.entries.where((e) => e.value >= minSupportCount))
        {e.key}: e.value
    };

    final frequentBySize = <int, Map<Set<String>, int>>{1: lk};

    int k = 2;
    while (lk.isNotEmpty && k <= maxItemsetSize) {
      // Generate candidates Ck by self-join Lk-1
      final prev = frequentBySize[k - 1] ?? {};
      final prevKeys = prev.keys.toList();
      final candidates = <Set<String>>{};
      for (int i = 0; i < prevKeys.length; i++) {
        for (int j = i + 1; j < prevKeys.length; j++) {
          final a = prevKeys[i];
          final b = prevKeys[j];
          final union = <String>{...a, ...b};
          if (union.length == k) {
            // Prune: all (k-1)-subsets must be frequent
            bool allSubsetsFrequent = true;
            for (final subset in _subsets(union, k - 1)) {
              if (!(prev.containsKey(subset))) {
                allSubsetsFrequent = false;
                break;
              }
            }
            if (allSubsetsFrequent) candidates.add(union);
          }
        }
      }

      // Count supports
      final counts = <Set<String>, int>{};
      for (final t in transactions) {
        final tset = t.toSet();
        for (final c in candidates) {
          if (tset.containsAll(c)) {
            counts[c] = (counts[c] ?? 0) + 1;
          }
        }
      }

      // Filter by min support
      final lnext = <Set<String>, int>{
        for (final e in counts.entries.where((e) => e.value >= minSupportCount)) e.key: e.value
      };

      if (lnext.isEmpty) break;

      frequentBySize[k] = lnext;
      lk = lnext;
      k += 1;
    }

    // Generate association rules from frequent itemsets
    int supportOf(Set<String> s) {
      final sizeMap = frequentBySize[s.length] ?? const {};
      return sizeMap[s] ?? 0;
    }

    final rules = <_Rule>[];
    for (final entry in frequentBySize.entries) {
      final size = entry.key;
      if (size < 2) continue;
      for (final itemset in entry.value.keys) {
        final supItemset = entry.value[itemset]!;
        final subsets = _nonEmptyProperSubsets(itemset);
        for (final antecedent in subsets) {
          final consequent = itemset.difference(antecedent);
          if (consequent.isEmpty) continue;
          final supAntecedent = supportOf(antecedent);
          if (supAntecedent == 0) continue;
          final confidence = supItemset / supAntecedent;
          if (confidence + 1e-9 < minConfidence) continue;
          final supConsequent = supportOf(consequent);
          final lift = (supConsequent == 0)
              ? 0.0
              : (supItemset / transactionCount) /
                  ((supAntecedent / transactionCount) * (supConsequent / transactionCount));
          rules.add(_Rule(
            antecedent: antecedent,
            consequent: consequent,
            supportCount: supItemset,
            confidence: confidence,
            lift: lift,
          ));
        }
      }
    }

    // Sort rules by confidence then lift
    rules.sort((a, b) {
      final c = b.confidence.compareTo(a.confidence);
      if (c != 0) return c;
      return b.lift.compareTo(a.lift);
    });

    return _AprioriResult(frequentItemsets: frequentBySize, rules: rules);
  }

  int _minSupportCount(double minSupport, int transactionCount) {
    return max(1, (minSupport * transactionCount).ceil());
  }

  Iterable<Set<String>> _subsets(Set<String> set, int size) sync* {
    final list = set.toList();
    final n = list.length;
    final idx = List<int>.generate(size, (i) => i);
    while (true) {
      yield {for (final i in idx) list[i]};
      int i;
      for (i = size - 1; i >= 0; i--) {
        if (idx[i] != i + n - size) break;
      }
      if (i < 0) break;
      idx[i]++;
      for (int j = i + 1; j < size; j++) {
        idx[j] = idx[j - 1] + 1;
      }
    }
  }

  Iterable<Set<String>> _nonEmptyProperSubsets(Set<String> set) sync* {
    for (int r = 1; r < set.length; r++) {
      yield* _subsets(set, r);
    }
  }

  // Kept for potential future single-breed usage; call the multi variant directly.
  // ignore: unused_element
  List<String> _rankSuggestionsFromRules(
    String selectedBreed,
    List<_Rule> rules, {
    int maxConsequents = 1,
  }) {
    return _rankSuggestionsFromRulesMulti({selectedBreed}, rules, maxConsequents: maxConsequents);
  }

  List<String> _rankSuggestionsFromRulesMulti(
    Set<String> selectedBreeds,
    List<_Rule> rules, {
    int maxConsequents = 1,
  }) {
    // Score suggestions by summing (confidence * lift) for consequents when antecedent intersects selectedBreeds
    final scores = <String, double>{};
    for (final rule in rules) {
      if (rule.antecedent.intersection(selectedBreeds).isEmpty) continue;
      final consequents = rule.consequent.toList();
      if (maxConsequents > 0 && consequents.length > maxConsequents) continue;
      // Weight by overlap size to reward rules that match more of the selection
      final overlap = rule.antecedent.intersection(selectedBreeds).length;
      final weight = overlap.toDouble();
      final score = weight * rule.confidence * max(1.0, rule.lift);
      for (final c in consequents) {
        if (selectedBreeds.contains(c)) continue; // don't suggest what was already purchased
        scores[c] = (scores[c] ?? 0) + score;
      }
    }
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }
}

class _AprioriResult {
  final Map<int, Map<Set<String>, int>> frequentItemsets;
  final List<_Rule> rules;
  _AprioriResult({required this.frequentItemsets, required this.rules});
}

class _Rule {
  final Set<String> antecedent;
  final Set<String> consequent;
  final int supportCount;
  final double confidence;
  final double lift;
  _Rule({
    required this.antecedent,
    required this.consequent,
    required this.supportCount,
    required this.confidence,
    required this.lift,
  });
}
