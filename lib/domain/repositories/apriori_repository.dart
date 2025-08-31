import '../entities/breed_entities.dart';

abstract class AprioriRepository {
  /// Lấy tất cả transactions từ orders đã hoàn thành
  Future<List<BreedTransaction>> getBreedTransactions();
  
  /// Lấy thông tin pets dựa trên danh sách breeds
  Future<List<Map<String, dynamic>>> getPetsByBreeds(List<String> breeds, {int limit = 10});
  
  /// Lưu kết quả phân tích để cache (optional)
  Future<void> saveAnalysisResult(String key, Map<String, dynamic> result);
  
  /// Lấy kết quả phân tích đã cache (optional)
  Future<Map<String, dynamic>?> getCachedAnalysisResult(String key);
}
