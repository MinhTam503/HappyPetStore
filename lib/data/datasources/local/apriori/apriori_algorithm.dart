import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_shop/data/datasources/local/apriori/apriori_logger.dart';

class AprioriAlgorithm {
  /// Fetches completed orders from Firestore and converts them to transactions of breeds.
  /// Each transaction is a set of unique breed strings purchased together in an order.
  Future<List<List<String>>> getAllBreedTransactions({String? runId}) async {
    try {
      debugPrint("🔍 Fetching completed orders...");
      final ordersT0 = DateTime.now();
      if (runId != null) {
        await AprioriLogger.append(runId, type: 'FETCH_ORDERS_START', data: {
          'query': {
            'collection': 'orders',
            'where': {'statusOrder': 'Completed'},
          }
        });
      }
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection("orders")
          .where("statusOrder", isEqualTo: "Completed")
          .get();

      final ordersMs = DateTime.now().difference(ordersT0).inMilliseconds;
      debugPrint("Found ${ordersSnapshot.docs.length} completed orders");
      if (runId != null) {
        await AprioriLogger.append(runId, type: 'FETCH_ORDERS_END', data: {
          'orderCount': ordersSnapshot.docs.length,
          'durationMs': ordersMs,
        });
      }

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
        if (runId != null) {
          await AprioriLogger.append(runId, type: 'PRODUCT_IDS_COLLECTED', data: {
            'count': 0,
          });
        }
        return [];
      }

      debugPrint(" Fetching breed info for ${neededProductIds.length} pets");
      if (runId != null) {
        await AprioriLogger.append(runId, type: 'PRODUCT_IDS_COLLECTED', data: {
          'count': neededProductIds.length,
        });
      }

      // Tách ID thành nhiều phần nếu vượt quá giới hạn
      final chunks = <List<String>>[];
      final ids = neededProductIds.toList();
      for (var i = 0; i < ids.length; i += 10) {
        chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
      }
      if (runId != null) {
        await AprioriLogger.append(runId, type: 'FETCH_PETS_START', data: {
          'chunkCount': chunks.length,
          'chunkSizes': chunks.map((c) => c.length).toList(),
        });
      }

      Map<String, String> productIdToBreed = {};
      for (var chunk in chunks) {
        final tChunk = DateTime.now();
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
        if (runId != null) {
          await AprioriLogger.append(runId, type: 'FETCH_PETS_CHUNK', data: {
            'chunkSize': chunk.length,
            'fetched': petsSnapshot.docs.length,
            'durationMs': DateTime.now().difference(tChunk).inMilliseconds,
          });
        }
      }

      debugPrint(" Found breed info for ${productIdToBreed.length} pets");
      if (runId != null) {
        final missing = neededProductIds.length - productIdToBreed.length;
        final missingIds = neededProductIds
            .where((id) => !productIdToBreed.containsKey(id))
            .take(20)
            .toList();
        await AprioriLogger.append(runId, type: 'MAP_BREEDS_SUMMARY', data: {
          'mappedCount': productIdToBreed.length,
          'missingCount': missing,
          'missingSample': missingIds,
        });
      }

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
      if (runId != null) {
        // Build a small histogram of transaction sizes
        final hist = <int, int>{};
        for (final t in breedTransactions) {
          final s = t.length;
          hist[s] = (hist[s] ?? 0) + 1;
        }
        await AprioriLogger.append(runId, type: 'TRANSACTIONS_BUILT', data: {
          'transactionCount': breedTransactions.length,
          'sizeHistogram': hist.map((k, v) => MapEntry(k.toString(), v)),
        });
      }
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

      final fetchT0 = DateTime.now();
      final transactions = await getAllBreedTransactions(runId: runId);
      final fetchMs = DateTime.now().difference(fetchT0).inMilliseconds;
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
      final miningResult = await _mineApriori(
        transactions,
        minSupport: minSupport,
        minConfidence: minConfidence,
        maxItemsetSize: maxItemsetSize,
        runId: runId,
        detailedLog: true,
      );
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

      // rules by antecedent size
      final rulesBySize = <int, int>{};
      for (final r in miningResult.rules) {
        rulesBySize[r.antecedent.length] = (rulesBySize[r.antecedent.length] ?? 0) + 1;
      }

      await AprioriLogger.append(runId, type: 'MINING_SUMMARY', data: {
        'durationMs': miningDuration.inMilliseconds,
        'minSupport': minSupport,
        'minSupportCount': minSupportCount,
        'frequentItemsets': miningResult.frequentItemsets.map((k, v) => MapEntry(k.toString(), v.length)),
        'topL1': topL1Trimmed,
        'ruleCount': miningResult.rules.length,
        'rulesByAntecedentSize': rulesBySize.map((k, v) => MapEntry(k.toString(), v)),
        'ruleSamples': ruleSamples,
        'candidateStats': miningResult.candidateStats,
      });

      // Build suggestions for the selected breeds using rules where antecedent intersects selection
      final selectedSet = selectedBreeds.toSet();
      final scoreMap = _computeScoresMulti(selectedSet, miningResult.rules, maxConsequents: maxConsequents);
      final rankedBreeds = scoreMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final rankedBreedList = rankedBreeds.map((e) => e.key).toList();

      await AprioriLogger.append(runId, type: 'RANKING_SCORES', data: {
        'selectedBreeds': selectedBreeds,
        'top': rankedBreeds.take(10).map((e) => {
          'breed': e.key,
          'score': double.parse(e.value.toStringAsFixed(6)),
        }).toList(),
      });

      await AprioriLogger.append(runId, type: 'SUGGESTED_BREEDS', data: {
        'count': rankedBreedList.length,
        'top': rankedBreedList.take(10).toList(),
      });

      if (rankedBreedList.isEmpty) {
        // Fallback to legacy co-occurrence pairs to still provide something
        final pairCounts = analyzeBreedPairs(transactions);
        // Extra visibility: compute global pair stats and per-selected details
        try {
          // Flatten all pairs for global top view
          final allPairs = <Map<String, dynamic>>[];
          pairCounts.forEach((a, mapB) {
            mapB.forEach((b, c) {
              allPairs.add({'a': a, 'b': b, 'count': c});
            });
          });

          allPairs.sort((x, y) => (y['count'] as int).compareTo(x['count'] as int));
          final topPairsGlobal = allPairs.take(20).toList();

          // Build L1 support map from mining result to compute confidences
          final l1map = miningResult.frequentItemsets[1] ?? const {};
          final supportMap = <String, int>{};
          for (final e in l1map.entries) {
            final item = e.key.first;
            supportMap[item] = e.value;
          }

          final selectedDetails = <Map<String, dynamic>>[];
          for (final sel in selectedBreeds) {
            final fromA = Map<String, int>.from(pairCounts[sel] ?? const {});
            // Where selected appears on the RHS side
            final rhs = <String, int>{};
            pairCounts.forEach((a, mapB) {
              final c = mapB[sel];
              if (c != null) rhs[a] = c;
            });

            // Combine counts from both directions
            final combined = <String, int>{}..addAll(fromA);
            rhs.forEach((k, v) => combined[k] = (combined[k] ?? 0) + v);

            // Build ranked list with confidence relative to support(sel)
            final supSel = supportMap[sel] ?? 0;
            final combinedList = combined.entries
                .map((e) => {
                      'with': e.key,
                      'count': e.value,
                      'confidence': supSel > 0 ? (e.value / supSel) : 0.0,
                    })
                .toList()
              ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

            selectedDetails.add({
              'breed': sel,
              'support': supSel,
              'topCombined': combinedList.take(10).toList(),
              'topFromKey': (fromA.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(10)
                  .map((e) => {'with': e.key, 'count': e.value})
                  .toList(),
              'topFromRhs': (rhs.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(10)
                  .map((e) => {'with': e.key, 'count': e.value})
                  .toList(),
            });
          }

          await AprioriLogger.append(runId, type: 'PAIR_COUNT_DETAILS', data: {
            'uniquePairCount': allPairs.length,
            'topPairsGlobal': topPairsGlobal,
            'selectedDetails': selectedDetails,
          });
        } catch (e) {
          // Swallow logging errors to avoid breaking suggestions
          debugPrint('PAIR_COUNT_DETAILS log failed: $e');
        }
        // Log a small top snapshot of pair counts related to selected breeds
        final pairTops = <Map<String, dynamic>>[];
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
          // capture a small snapshot per selected breed
          final selTop = (fromA.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(5)
              .map((e) => {'with': e.key, 'count': e.value})
              .toList();
          pairTops.add({'breed': sel, 'topPairs': selTop});
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

          final petQueryT0 = DateTime.now();
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
            'pets': suggestions.take(20).map((p) => {
                  'id': p['id'],
                  'name': p['name'],
                  'breed': p['breed'],
                }).toList(),
          });

          await AprioriLogger.complete(runId, success: true, metrics: {
            'totalTimeMs': DateTime.now().difference(t0).inMilliseconds,
            'selectedBreeds': selectedBreeds,
            'results': suggestions.length,
            'timelineMs': {
              'fetchMs': fetchMs,
              'miningMs': miningDuration.inMilliseconds,
              'petQueryMs': DateTime.now().difference(petQueryT0).inMilliseconds,
            }
          });
          return suggestions;
        }

        await AprioriLogger.append(runId, type: 'FALLBACK_PAIRS', data: {
          'pairSuggestionCount': queryBreeds.length,
          'topPairs': coOccurRanked.take(10).map((e) => {'breed': e.key, 'count': e.value}).toList(),
          'selectedPairSnapshots': pairTops,
        });

        final petQueryT0 = DateTime.now();
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
          'pets': suggestions.take(20).map((p) => {
                'id': p['id'],
                'name': p['name'],
                'breed': p['breed'],
              }).toList(),
        });

        await AprioriLogger.complete(runId, success: true, metrics: {
          'totalTimeMs': DateTime.now().difference(t0).inMilliseconds,
          'selectedBreeds': selectedBreeds,
          'results': suggestions.length,
          'timelineMs': {
            'fetchMs': fetchMs,
            'miningMs': miningDuration.inMilliseconds,
            'petQueryMs': DateTime.now().difference(petQueryT0).inMilliseconds,
          }
        });
        return suggestions;
      }

      final queryBreeds = rankedBreedList.take(10).toList();
      final petQueryT0 = DateTime.now();
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
        'pets': suggestions.take(20).map((p) => {
              'id': p['id'],
              'name': p['name'],
              'breed': p['breed'],
            }).toList(),
      });

      await AprioriLogger.complete(runId, success: true, metrics: {
        'totalTimeMs': DateTime.now().difference(t0).inMilliseconds,
        'selectedBreeds': selectedBreeds,
        'results': suggestions.length,
        'timelineMs': {
          'fetchMs': fetchMs,
          'miningMs': miningDuration.inMilliseconds,
          'petQueryMs': DateTime.now().difference(petQueryT0).inMilliseconds,
        }
      });
      return suggestions;
    } catch (e) {
      debugPrint(" Error in getSuggestedPets: $e");
      return [];
    }
  }

  // ===== Apriori mining internals =====

  Future<_AprioriResult> _mineApriori(
    List<List<String>> transactions, {
    required double minSupport,
    required double minConfidence,
    required int maxItemsetSize,
    String? runId,
    bool detailedLog = false,
  }) async {
    final transactionCount = transactions.length;
    final minSupportCount = _minSupportCount(minSupport, transactionCount);

    // TID list for logging: T1..Tn
    final tids = List.generate(transactionCount, (i) => 'T${i + 1}');
    final tsets = transactions.map((t) => t.toSet()).toList(growable: false);

    // INIT log
    if (detailedLog && runId != null) {
      final avgLen = transactionCount == 0
          ? 0.0
          : tsets.map((s) => s.length).reduce((a, b) => a + b) / transactionCount;
      await AprioriLogger.append(runId, type: 'INIT', data: {
        'minSupport': minSupport,
        'minSupportCount': minSupportCount,
        'minConfidence': minConfidence,
      });
      await AprioriLogger.append(runId, type: 'DATA', data: {
        'transactions': transactionCount,
        'avgLen': avgLen,
      });
    }

    // L1 counts and TID sets
    final itemCounts = <String, int>{};
    final itemTidsets = <String, Set<int>>{};
    for (int ti = 0; ti < tsets.length; ti++) {
      final s = tsets[ti];
      for (final item in s) {
        itemCounts[item] = (itemCounts[item] ?? 0) + 1;
        (itemTidsets[item] ??= <int>{}).add(ti);
      }
    }

    if (detailedLog && runId != null) {
      final items = itemCounts.keys.toList()..sort();
      await AprioriLogger.append(runId, type: 'K1_CANDIDATES', data: {
        'items': items,
      });
      // Count with tidsets
      final k1Counts = items
          .map((it) => {
                'item': it,
                'support': itemCounts[it],
                'tids': (itemTidsets[it] ?? const {}).map((i) => tids[i]).toList(),
              })
          .toList();
      await AprioriLogger.append(runId, type: 'K1_COUNT', data: {
        'entries': k1Counts,
      });
    }
    Map<Set<String>, int> lk = {
      for (final e in itemCounts.entries.where((e) => e.value >= minSupportCount))
        {e.key}: e.value
    };

    final frequentBySize = <int, Map<Set<String>, int>>{1: lk};

    final candidateStats = <Map<String, int>>[];
    int k = 2;
    int totalCandidates = 0;
    int totalPruned = 0;
    int iterations = 1; // include k=1
    while (lk.isNotEmpty && k <= maxItemsetSize) {
      // Generate candidates Ck by self-join Lk-1
      final prev = frequentBySize[k - 1] ?? {};
      final prevKeys = prev.keys.toList();
      final candidates = <Set<String>>{};
      final joinLogs = <Map<String, dynamic>>[];
      final pruneLogs = <Map<String, dynamic>>[];
      for (int i = 0; i < prevKeys.length; i++) {
        for (int j = i + 1; j < prevKeys.length; j++) {
          final a = prevKeys[i];
          final b = prevKeys[j];
          final union = <String>{...a, ...b};
          if (union.length == k) {
            // Prune: all (k-1)-subsets must be frequent
            bool allSubsetsFrequent = true;
            final missingSubsets = <List<String>>[];
            for (final subset in _subsets(union, k - 1)) {
              if (!(prev.containsKey(subset))) {
                allSubsetsFrequent = false;
                missingSubsets.add(subset.toList()..sort());
                break;
              }
            }
            if (allSubsetsFrequent) {
              candidates.add(union);
              if (detailedLog && runId != null) {
                joinLogs.add({
                  'a': a.toList()..sort(),
                  'b': b.toList()..sort(),
                  'c': union.toList()..sort(),
                });
              }
            } else {
              totalPruned += 1;
              if (detailedLog && runId != null) {
                pruneLogs.add({
                  'candidate': union.toList()..sort(),
                  'missingSubsets': missingSubsets,
                });
              }
            }
          }
        }
      }
      totalCandidates += candidates.length;
      if (detailedLog && runId != null) {
        await AprioriLogger.append(runId, type: 'K_JOIN', data: {
          'k': k,
          'joins': joinLogs,
        });
        if (pruneLogs.isNotEmpty) {
          await AprioriLogger.append(runId, type: 'K_PRUNE', data: {
            'k': k,
            'pruned': pruneLogs,
          });
        }
      }
      // Count supports
      final counts = <Set<String>, int>{};
      final tidsetsK = <Set<String>, Set<int>>{};
      for (final t in transactions) {
        final tset = t.toSet();
        for (final c in candidates) {
          if (tset.containsAll(c)) {
            counts[c] = (counts[c] ?? 0) + 1;
            if (detailedLog && runId != null) {
              final idx = transactions.indexOf(t);
              (tidsetsK[c] ??= <int>{}).add(idx);
            }
          }
        }
      }

      // Filter by min support
      final lnext = <Set<String>, int>{
        for (final e in counts.entries.where((e) => e.value >= minSupportCount)) e.key: e.value
      };

      candidateStats.add({
        'k': k,
        'candidateCount': candidates.length,
        'retainedCount': lnext.length,
      });

      if (detailedLog && runId != null) {
        // K_COUNT
        final countEntries = counts.entries
            .map((e) => {
                  'itemset': e.key.toList()..sort(),
                  'support': e.value,
                  'tids': (tidsetsK[e.key] ?? const {}).map((i) => tids[i]).toList(),
                })
            .toList()
          ..sort((a, b) => (b['support'] as int).compareTo(a['support'] as int));
        await AprioriLogger.append(runId, type: 'K_COUNT', data: {
          'k': k,
          'entries': countEntries,
        });
      }

      if (detailedLog && runId != null) {
        final lEntries = lnext.entries
            .map((e) => {
                  'itemset': e.key.toList()..sort(),
                  'support': e.value,
                })
            .toList()
          ..sort((a, b) => (b['support'] as int).compareTo(a['support'] as int));
        await AprioriLogger.append(runId, type: 'L_LEVEL', data: {
          'k': k,
          'size': lEntries.length,
          'itemsets': lEntries,
        });
      }

      if (lnext.isEmpty) break;

      frequentBySize[k] = lnext;
      lk = lnext;
      k += 1;
      iterations += 1;
    }

    // Generate association rules from frequent itemsets
    int supportOf(Set<String> s) {
      final sizeMap = frequentBySize[s.length] ?? const {};
      return sizeMap[s] ?? 0;
    }

    final rules = <_Rule>[];
    int rulesEvaluated = 0;
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
          final supConsequent = supportOf(consequent);
          final lift = (supConsequent == 0)
              ? 0.0
              : (supItemset / transactionCount) /
                  ((supAntecedent / transactionCount) * (supConsequent / transactionCount));
          final pass = confidence + 1e-9 >= minConfidence;
          rulesEvaluated += 1;
          if (detailedLog && runId != null) {
            await AprioriLogger.append(runId, type: 'RULE_EVAL', data: {
              'A': antecedent.toList()..sort(),
              'B': consequent.toList()..sort(),
              'supportF': supItemset,
              'supportA': supAntecedent,
              'supportB': supConsequent,
              'confidence': double.parse(confidence.toStringAsFixed(6)),
              'lift': double.parse(lift.toStringAsFixed(6)),
              'passMinConfidence': pass,
            });
          }
          if (!pass) continue;
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

    if (detailedLog && runId != null) {
      int totalFrequent = 0;
      final perLevel = <String, int>{};
      for (final e in frequentBySize.entries) {
        final count = e.value.length;
        totalFrequent += count;
        perLevel[e.key.toString()] = count;
      }
      await AprioriLogger.append(runId, type: 'SUMMARY', data: {
        'iterations': iterations,
        'totalCandidates': totalCandidates,
        'totalPruned': totalPruned,
        'frequentItemsets': totalFrequent,
        'frequentByLevel': perLevel,
        'rulesKept': rules.length,
        'rulesEvaluated': rulesEvaluated,
      });
    }

    return _AprioriResult(frequentItemsets: frequentBySize, rules: rules, candidateStats: candidateStats);
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
    final scores = _computeScoresMulti(selectedBreeds, rules, maxConsequents: maxConsequents);
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  Map<String, double> _computeScoresMulti(
    Set<String> selectedBreeds,
    List<_Rule> rules, {
    int maxConsequents = 1,
  }) {
    // Score suggestions by summing (confidence * lift) for consequents when antecedent intersects selectedBreeds
    final scores = <String, double>{};
    for (final rule in rules) {
      final intersect = rule.antecedent.intersection(selectedBreeds);
      if (intersect.isEmpty) continue;
      final consequents = rule.consequent.toList();
      if (maxConsequents > 0 && consequents.length > maxConsequents) continue;
      // Weight by overlap size to reward rules that match more of the selection
      final weight = intersect.length.toDouble();
      final score = weight * rule.confidence * max(1.0, rule.lift);
      for (final c in consequents) {
        if (selectedBreeds.contains(c)) continue; // don't suggest what was already purchased
        scores[c] = (scores[c] ?? 0) + score;
      }
    }
    return scores;
  }
}

class _AprioriResult {
  final Map<int, Map<Set<String>, int>> frequentItemsets;
  final List<_Rule> rules;
  final List<Map<String, int>> candidateStats;
  _AprioriResult({required this.frequentItemsets, required this.rules, required this.candidateStats});
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
