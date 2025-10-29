class RecommendationConfig {
  // How many recommendations to fetch per request (usable by UI/manager)
  static int defaultLimit = 24; // Large e-comm sites often show 12–24 per section

  // If true and favoriteBreeds is not empty, fill category picks with breed-matched pets first
  // and skip generic category fill unless there are not enough breed results.
  static bool strictBreed = false; // keep off by default

  // Portion of each category reserved for exploration (non-breed matches) when strictBreed=false
  // Example: 0.34 means ~1/3 of per-category items can be exploratory within the same category.
  static double exploreRatio = 0.34; // balanced: most breed-first, some exploration
}
